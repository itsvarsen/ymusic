import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../data/db.dart';
import '../models/song.dart';
import 'cover_art.dart';
import 'importer.dart';

enum SortField { title, artist, album, dateAdded, duration, mostPlayed, recentlyPlayed }

extension SortFieldLabel on SortField {
  String get label => switch (this) {
        SortField.title => 'Title',
        SortField.artist => 'Artist',
        SortField.album => 'Album',
        SortField.dateAdded => 'Date added',
        SortField.duration => 'Duration',
        SortField.mostPlayed => 'Most played',
        SortField.recentlyPlayed => 'Recently played',
      };
}

/// The user's library: songs, playlists and derived views.
class LibraryStore extends ChangeNotifier {
  final AppDb db;
  final Importer importer;
  LibraryStore(this.db, this.importer);

  List<Song> _songs = [];
  final Map<String, Song> _byId = {};
  List<Playlist> _playlists = [];
  bool loaded = false;

  /// Non-null while an import is running.
  final ValueNotifier<ImportProgress?> importProgress = ValueNotifier(null);

  /// Listeners interested in removals (e.g. the player queue).
  final _removed = StreamController<String>.broadcast();
  Stream<String> get removedSongs => _removed.stream;

  // ---- view state (sort / filter for the Songs tab)
  SortField sortField = SortField.dateAdded;
  bool ascending = false;
  String? filterGenre;
  String? filterArtist;
  int? filterYear;
  bool favouritesOnly = false;

  List<Song> get songs => _songs;
  List<Playlist> get playlists => _playlists;
  bool get isEmpty => _songs.isEmpty;
  Song? byId(String id) => _byId[id];

  Future<void> load() async {
    _songs = await db.allSongs();
    _reindex();
    _playlists = await db.allPlaylists();
    final sf = await db.getKv('sort_field');
    final asc = await db.getKv('sort_asc');
    if (sf != null) {
      sortField = SortField.values.firstWhere((e) => e.name == sf, orElse: () => SortField.dateAdded);
    }
    if (asc != null) ascending = asc == '1';
    loaded = true;
    notifyListeners();
  }

  void _reindex() {
    _byId
      ..clear()
      ..addEntries(_songs.map((s) => MapEntry(s.id, s)));
    _albumsCache = null;
    _artistsCache = null;
  }

  void _replace(Song s) {
    final i = _songs.indexWhere((e) => e.id == s.id);
    if (i >= 0) _songs[i] = s;
    _byId[s.id] = s;
    _albumsCache = null;
    _artistsCache = null;
  }

  // ---------------------------------------------------------------- import
  Future<ImportSummary> importFiles(List<PlatformFile> files) async {
    final summary = ImportSummary();
    for (var i = 0; i < files.length; i++) {
      importProgress.value = ImportProgress(i, files.length, files[i].name);
      final (outcome, song) = await importer.importPicked(files[i]);
      _count(summary, outcome, song);
    }
    _finishImport();
    return summary;
  }

  Future<ImportSummary> importPaths(List<String> paths) async {
    final summary = ImportSummary();
    for (var i = 0; i < paths.length; i++) {
      importProgress.value = ImportProgress(i, paths.length, paths[i].split('/').last);
      final (outcome, song) = await importer.importPath(paths[i]);
      _count(summary, outcome, song);
    }
    _finishImport();
    return summary;
  }

  void _count(ImportSummary s, ImportOutcome o, Song? song) {
    switch (o) {
      case ImportOutcome.added:
        s.added++;
        if (song != null) {
          _songs.add(song);
          _byId[song.id] = song;
          _albumsCache = null;
          _artistsCache = null;
          notifyListeners();
        }
      case ImportOutcome.duplicate:
        s.duplicates++;
      case ImportOutcome.failed:
        s.failed++;
      case ImportOutcome.skipped:
        s.skipped++;
    }
  }

  void _finishImport() {
    importProgress.value = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- edits
  Future<void> toggleFavourite(String id) async {
    final s = _byId[id];
    if (s == null) return;
    final n = s.copyWith(favourite: !s.favourite);
    _replace(n);
    notifyListeners();
    await db.updateSong(n);
  }

  Future<void> recordPlay(String id) async {
    final s = _byId[id];
    if (s == null) return;
    final n = s.copyWith(playCount: s.playCount + 1, lastPlayed: DateTime.now().millisecondsSinceEpoch);
    _replace(n);
    notifyListeners();
    await db.updateSong(n);
  }

  Future<void> updateDuration(String id, Duration d) async {
    final s = _byId[id];
    if (s == null || d.inMilliseconds <= 0 || s.durationMs == d.inMilliseconds) return;
    final n = s.copyWith(durationMs: d.inMilliseconds);
    _replace(n);
    notifyListeners();
    await db.updateSong(n);
  }

  Future<void> updateTags(
    String id, {
    required String title,
    required String artist,
    required String album,
    required String genre,
    int? year,
    int? track,
  }) async {
    final s = _byId[id];
    if (s == null) return;
    final n = s.copyWith(
      title: title.trim().isEmpty ? s.title : title.trim(),
      artist: artist.trim(),
      album: album.trim(),
      genre: genre.trim(),
      year: year,
      clearYear: year == null,
      track: track,
      clearTrack: track == null,
    );
    _replace(n);
    notifyListeners();
    await db.updateSong(n);
    unawaited(importer.writeTags(n));
  }

  Future<void> removeSong(String id) async {
    final s = _byId[id];
    if (s == null) return;
    _songs.removeWhere((e) => e.id == id);
    _reindex();
    _playlists = _playlists
        .map((p) => p.songIds.contains(id) ? p.copyWith(songIds: p.songIds.where((x) => x != id).toList()) : p)
        .toList();
    _removed.add(id);
    notifyListeners();
    await db.deleteSong(id);
    forgetDominant(s.artPath);
    await importer.deleteFiles(s);
  }

  // ---------------------------------------------------------------- playlists
  Playlist? playlist(int id) {
    for (final p in _playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Song> playlistSongs(Playlist p) => p.songIds.map((id) => _byId[id]).whereType<Song>().toList();

  Future<int> createPlaylist(String name) async {
    final id = await db.createPlaylist(name.trim().isEmpty ? 'New playlist' : name.trim());
    _playlists = await db.allPlaylists();
    notifyListeners();
    return id;
  }

  Future<void> renamePlaylist(int id, String name) async {
    if (name.trim().isEmpty) return;
    await db.renamePlaylist(id, name.trim());
    _playlists = _playlists.map((p) => p.id == id ? p.copyWith(name: name.trim()) : p).toList();
    notifyListeners();
  }

  Future<void> deletePlaylist(int id) async {
    await db.deletePlaylist(id);
    _playlists = _playlists.where((p) => p.id != id).toList();
    notifyListeners();
  }

  Future<void> _setSongs(int id, List<String> ids) async {
    _playlists = _playlists.map((p) => p.id == id ? p.copyWith(songIds: ids) : p).toList();
    notifyListeners();
    await db.setPlaylistSongs(id, ids);
  }

  /// Returns how many songs were actually added (skips ones already there).
  Future<int> addToPlaylist(int id, List<String> songIds) async {
    final p = playlist(id);
    if (p == null) return 0;
    final ids = [...p.songIds];
    var added = 0;
    for (final s in songIds) {
      if (!ids.contains(s)) {
        ids.add(s);
        added++;
      }
    }
    await _setSongs(id, ids);
    return added;
  }

  Future<void> removeFromPlaylist(int id, int index) async {
    final p = playlist(id);
    if (p == null || index < 0 || index >= p.songIds.length) return;
    final ids = [...p.songIds]..removeAt(index);
    await _setSongs(id, ids);
  }

  Future<void> reorderPlaylist(int id, int oldIndex, int newIndex) async {
    final p = playlist(id);
    if (p == null) return;
    final ids = [...p.songIds];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);
    await _setSongs(id, ids);
  }

  // ---------------------------------------------------------------- derived
  List<Album>? _albumsCache;
  List<Artist>? _artistsCache;

  List<Album> get albums {
    if (_albumsCache != null) return _albumsCache!;
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      map.putIfAbsent(s.albumKey, () => []).add(s);
    }
    final list = map.entries.map((e) {
      final songs = e.value
        ..sort((a, b) {
          final d = (a.disc ?? 0).compareTo(b.disc ?? 0);
          if (d != 0) return d;
          final t = (a.track ?? 9999).compareTo(b.track ?? 9999);
          return t != 0 ? t : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      return Album(e.key, songs.first.displayAlbum, songs.first.albumOwner, songs);
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return _albumsCache = list;
  }

  Album? albumByKey(String key) {
    for (final a in albums) {
      if (a.key == key) return a;
    }
    return null;
  }

  List<Artist> get artists {
    if (_artistsCache != null) return _artistsCache!;
    final map = <String, List<Song>>{};
    final names = <String, String>{};
    for (final s in _songs) {
      final k = s.displayArtist.toLowerCase();
      names.putIfAbsent(k, () => s.displayArtist);
      map.putIfAbsent(k, () => []).add(s);
    }
    final list = map.entries.map((e) => Artist(names[e.key]!, e.value)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _artistsCache = list;
  }

  Artist? artistByName(String name) {
    final k = name.toLowerCase();
    for (final a in artists) {
      if (a.name.toLowerCase() == k) return a;
    }
    return null;
  }

  List<String> get genres {
    final set = <String>{};
    for (final s in _songs) {
      if (s.genre.trim().isNotEmpty) set.add(s.genre.trim());
    }
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<int> get years {
    final set = <int>{};
    for (final s in _songs) {
      if (s.year != null) set.add(s.year!);
    }
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  List<Song> get favourites => sortSongs(_songs.where((s) => s.favourite).toList());

  List<Song> get recentlyPlayed {
    final l = _songs.where((s) => s.lastPlayed != null).toList()
      ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    return l.take(20).toList();
  }

  List<Song> get mostPlayed {
    final l = _songs.where((s) => s.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return l.take(20).toList();
  }

  List<Song> get recentlyAdded {
    final l = [..._songs]..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return l.take(20).toList();
  }

  Duration get totalDuration => _songs.fold(Duration.zero, (a, s) => a + s.duration);

  bool get hasActiveFilter =>
      filterGenre != null || filterArtist != null || filterYear != null || favouritesOnly;

  /// Songs tab: filtered and sorted.
  List<Song> get visibleSongs {
    var l = _songs.where((s) {
      if (favouritesOnly && !s.favourite) return false;
      if (filterGenre != null && s.genre.trim().toLowerCase() != filterGenre!.toLowerCase()) return false;
      if (filterArtist != null && s.displayArtist.toLowerCase() != filterArtist!.toLowerCase()) return false;
      if (filterYear != null && s.year != filterYear) return false;
      return true;
    }).toList();
    return sortSongs(l);
  }

  List<Song> sortSongs(List<Song> l) {
    int cmpStr(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
    int c(Song a, Song b) {
      switch (sortField) {
        case SortField.title:
          return cmpStr(a.title, b.title);
        case SortField.artist:
          final r = cmpStr(a.displayArtist, b.displayArtist);
          return r != 0 ? r : cmpStr(a.title, b.title);
        case SortField.album:
          final r = cmpStr(a.displayAlbum, b.displayAlbum);
          return r != 0 ? r : (a.track ?? 9999).compareTo(b.track ?? 9999);
        case SortField.dateAdded:
          return a.dateAdded.compareTo(b.dateAdded);
        case SortField.duration:
          return a.durationMs.compareTo(b.durationMs);
        case SortField.mostPlayed:
          return a.playCount.compareTo(b.playCount);
        case SortField.recentlyPlayed:
          return (a.lastPlayed ?? 0).compareTo(b.lastPlayed ?? 0);
      }
    }

    l.sort((a, b) => ascending ? c(a, b) : c(b, a));
    return l;
  }

  void setSort(SortField f, bool asc) {
    sortField = f;
    ascending = asc;
    notifyListeners();
    db.setKv('sort_field', f.name);
    db.setKv('sort_asc', asc ? '1' : '0');
  }

  void setFilters({String? genre, String? artist, int? year, bool? favOnly}) {
    filterGenre = genre;
    filterArtist = artist;
    filterYear = year;
    favouritesOnly = favOnly ?? favouritesOnly;
    notifyListeners();
  }

  void clearFilters() {
    filterGenre = null;
    filterArtist = null;
    filterYear = null;
    favouritesOnly = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- search
  ({List<Song> songs, List<Album> albums, List<Artist> artists}) search(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return (songs: <Song>[], albums: <Album>[], artists: <Artist>[]);
    bool m(String s) => s.toLowerCase().contains(query);
    final songs = _songs.where((s) => m(s.title) || m(s.displayArtist) || m(s.displayAlbum)).toList()
      ..sort((a, b) {
        final ap = a.title.toLowerCase().startsWith(query) ? 0 : 1;
        final bp = b.title.toLowerCase().startsWith(query) ? 0 : 1;
        return ap != bp ? ap - bp : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    final albums = this.albums.where((a) => m(a.title) || m(a.artist)).toList();
    final artists = this.artists.where((a) => m(a.name)).toList();
    return (songs: songs, albums: albums, artists: artists);
  }
}
