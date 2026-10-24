import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db.dart';
import '../models/song.dart';
import 'cover_art.dart';

const audioExtensions = ['mp3', 'm4a', 'flac', 'wav', 'ogg', 'opus', 'aac'];

bool isAudioName(String name) {
  final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
  return audioExtensions.contains(ext);
}

enum ImportOutcome { added, duplicate, failed, skipped }

class ImportProgress {
  final int done;
  final int total;
  final String current;
  const ImportProgress(this.done, this.total, this.current);
}

class ImportSummary {
  int added = 0;
  int duplicates = 0;
  int failed = 0;
  int skipped = 0;
  String get message {
    final parts = <String>[];
    if (added > 0) parts.add('$added added');
    if (duplicates > 0) parts.add('$duplicates already in library');
    if (skipped > 0) parts.add('$skipped not audio');
    if (failed > 0) parts.add('$failed failed');
    return parts.isEmpty ? 'Nothing imported' : parts.join(' · ');
  }
}

/// Plain data returned from the tag-reading isolate.
class _Tags {
  String? title, artist, album, albumArtist, genre;
  int? year, track, disc, durationMs;
  Uint8List? picture;
  String? mime;
}

_Tags _readTags(String path) {
  final t = _Tags();
  try {
    final m = readMetadata(File(path), getImage: true);
    t.title = m.title;
    t.artist = m.artist;
    t.album = m.album;
    t.albumArtist = m.albumArtist;
    t.genre = m.genres.isNotEmpty ? m.genres.first : null;
    t.year = m.year?.year;
    t.track = m.trackNumber;
    t.disc = m.discNumber;
    t.durationMs = m.duration?.inMilliseconds;
    if (m.pictures.isNotEmpty) {
      final front = m.pictures.firstWhere(
        (pic) => pic.pictureType == PictureType.coverFront,
        orElse: () => m.pictures.first,
      );
      if (front.bytes.isNotEmpty) {
        t.picture = front.bytes;
        t.mime = front.mimetype;
      }
    }
  } catch (_) {
    // unreadable tags -> filename fallback
  }
  return t;
}

Future<_Tags> _readTagsAsync(String path) => Isolate.run(() => _readTags(path));

Future<void> _writeTagsAsync(String path, String title, String artist, String album,
        String genre, int? year, int? track) =>
    Isolate.run(() {
      updateMetadata(File(path), (m) {
        m.setTitle(title);
        m.setArtist(artist);
        m.setAlbum(album);
        m.setGenres(genre.isEmpty ? <String>[] : [genre]);
        m.setYear(year == null ? null : DateTime(year));
        m.setTrackNumber(track);
      });
    });

class Importer {
  final AppDb db;
  late final Directory musicDir;
  late final Directory artDir;
  late final Directory tmpDir;

  Importer(this.db);

  Future<void> init() async {
    final base = await getApplicationSupportDirectory();
    musicDir = Directory(p.join(base.path, 'music'));
    artDir = Directory(p.join(base.path, 'art'));
    tmpDir = Directory(p.join(base.path, 'incoming'));
    for (final d in [musicDir, artDir, tmpDir]) {
      if (!d.existsSync()) d.createSync(recursive: true);
    }
  }

  /// Imports a file picked through the system picker (may be a content:// uri).
  Future<(ImportOutcome, Song?)> importPicked(PlatformFile f) async {
    final name = f.name;
    if (!isAudioName(name)) return (ImportOutcome.skipped, null);
    final tmp = File(p.join(tmpDir.path, '${DateTime.now().microsecondsSinceEpoch}_${_safe(name)}'));
    try {
      final sink = tmp.openWrite();
      await sink.addStream(f.readAsByteStream());
      await sink.close();
      return await _finish(tmp, name);
    } catch (_) {
      if (tmp.existsSync()) tmp.deleteSync();
      return (ImportOutcome.failed, null);
    }
  }

  /// Imports a regular file from a folder the user picked.
  Future<(ImportOutcome, Song?)> importPath(String path) async {
    final name = p.basename(path);
    if (!isAudioName(name)) return (ImportOutcome.skipped, null);
    final tmp = File(p.join(tmpDir.path, '${DateTime.now().microsecondsSinceEpoch}_${_safe(name)}'));
    try {
      await File(path).copy(tmp.path);
      return await _finish(tmp, name);
    } catch (_) {
      if (tmp.existsSync()) tmp.deleteSync();
      return (ImportOutcome.failed, null);
    }
  }

  String _safe(String s) => s.replaceAll(RegExp(r'[^\w\.\- ]'), '_');

  Future<(ImportOutcome, Song?)> _finish(File tmp, String originalName) async {
    final digest = await sha1.bind(tmp.openRead()).first;
    final id = digest.toString();
    if (await db.hasSong(id)) {
      await tmp.delete();
      return (ImportOutcome.duplicate, null);
    }
    final ext = p.extension(originalName).toLowerCase();
    final dest = p.join(musicDir.path, '$id$ext');
    final destFile = File(dest);
    if (destFile.existsSync()) destFile.deleteSync();
    await tmp.rename(dest);

    final tags = await _readTagsAsync(dest);
    final fb = _fromFilename(originalName);
    final title = _clean(tags.title) ?? fb.$2;
    final artist = _clean(tags.artist) ?? fb.$1 ?? '';

    String? artPath;
    var hasArt = false;
    if (tags.picture != null) {
      final aext = (tags.mime ?? '').contains('png') ? '.png' : '.jpg';
      artPath = p.join(artDir.path, '$id$aext');
      await File(artPath).writeAsBytes(tags.picture!, flush: true);
      hasArt = true;
    } else {
      try {
        final png = await renderFallbackCoverPng('${_clean(tags.album) ?? title}|$artist', title);
        artPath = p.join(artDir.path, '${id}_gen.png');
        await File(artPath).writeAsBytes(png, flush: true);
      } catch (_) {
        artPath = null;
      }
    }

    final song = Song(
      id: id,
      path: dest,
      title: title,
      artist: artist,
      album: _clean(tags.album) ?? '',
      albumArtist: _clean(tags.albumArtist) ?? '',
      genre: _clean(tags.genre) ?? '',
      year: (tags.year != null && tags.year! > 0) ? tags.year : null,
      track: (tags.track != null && tags.track! > 0) ? tags.track : null,
      disc: tags.disc,
      durationMs: tags.durationMs ?? 0,
      artPath: artPath,
      hasArt: hasArt,
      dateAdded: DateTime.now().millisecondsSinceEpoch,
      originalName: originalName,
    );
    await db.upsertSong(song);
    return (ImportOutcome.added, song);
  }

  String? _clean(String? s) {
    if (s == null) return null;
    final t = s.replaceAll('\u0000', '').trim();
    return t.isEmpty ? null : t;
  }

  /// "Artist - Title.mp3" -> (Artist, Title); "01 Title.mp3" -> (null, Title)
  (String?, String) _fromFilename(String name) {
    var base = p.basenameWithoutExtension(name).replaceAll('_', ' ').trim();
    base = base.replaceFirst(RegExp(r'^\d{1,3}[\s\.\-]+'), '');
    final parts = base.split(RegExp(r'\s+[-–—]\s+'));
    if (parts.length >= 2) {
      return (parts.first.trim(), parts.sublist(1).join(' - ').trim());
    }
    return (null, base.isEmpty ? name : base);
  }

  /// Best effort: write edited tags back into the private copy of the file.
  Future<void> writeTags(Song s) async {
    final ext = p.extension(s.path).toLowerCase();
    if (!['.mp3', '.m4a', '.flac', '.wav'].contains(ext)) return;
    final path = s.path;
    final title = s.title, artist = s.artist, album = s.album, genre = s.genre;
    final year = s.year, track = s.track;
    try {
      await _writeTagsAsync(path, title, artist, album, genre, year, track);
    } catch (_) {
      // The library copy of the tags is the source of truth; ignore write failures.
    }
  }

  Future<void> deleteFiles(Song s) async {
    for (final path in [s.path, s.artPath]) {
      if (path == null) continue;
      try {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
  }

  /// Lists audio files under a user-picked folder (recursive).
  Future<List<String>> listFolder(String dir) async {
    final out = <String>[];
    await for (final e in Directory(dir).list(recursive: true, followLinks: false)) {
      if (e is File && isAudioName(e.path)) out.add(e.path);
    }
    out.sort();
    return out;
  }
}
