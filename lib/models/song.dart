class Song {
  final String id; // sha1 of file content
  final String path;
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final String genre;
  final int? year;
  final int? track;
  final int? disc;
  final int durationMs;
  final String? artPath;
  final bool hasArt; // true when the cover came from the file itself
  final int dateAdded;
  final int playCount;
  final int? lastPlayed;
  final bool favourite;
  final String originalName;

  const Song({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtist = '',
    this.genre = '',
    this.year,
    this.track,
    this.disc,
    this.durationMs = 0,
    this.artPath,
    this.hasArt = false,
    required this.dateAdded,
    this.playCount = 0,
    this.lastPlayed,
    this.favourite = false,
    this.originalName = '',
  });

  static const unknownArtist = 'Unknown artist';
  static const unknownAlbum = 'Unknown album';

  String get displayArtist => artist.trim().isEmpty ? unknownArtist : artist;
  String get displayAlbum => album.trim().isEmpty ? unknownAlbum : album;
  String get albumOwner => albumArtist.trim().isNotEmpty ? albumArtist : displayArtist;
  String get albumKey => '${displayAlbum.toLowerCase()}\u0000${albumOwner.toLowerCase()}';
  Duration get duration => Duration(milliseconds: durationMs);

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? year,
    bool clearYear = false,
    int? track,
    bool clearTrack = false,
    int? durationMs,
    int? playCount,
    int? lastPlayed,
    bool? favourite,
  }) {
    return Song(
      id: id,
      path: path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      genre: genre ?? this.genre,
      year: clearYear ? null : (year ?? this.year),
      track: clearTrack ? null : (track ?? this.track),
      disc: disc,
      durationMs: durationMs ?? this.durationMs,
      artPath: artPath,
      hasArt: hasArt,
      dateAdded: dateAdded,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      favourite: favourite ?? this.favourite,
      originalName: originalName,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'album_artist': albumArtist,
        'genre': genre,
        'year': year,
        'track': track,
        'disc': disc,
        'duration_ms': durationMs,
        'art_path': artPath,
        'has_art': hasArt ? 1 : 0,
        'date_added': dateAdded,
        'play_count': playCount,
        'last_played': lastPlayed,
        'favourite': favourite ? 1 : 0,
        'original_name': originalName,
      };

  factory Song.fromMap(Map<String, Object?> m) => Song(
        id: m['id'] as String,
        path: m['path'] as String,
        title: (m['title'] as String?) ?? '',
        artist: (m['artist'] as String?) ?? '',
        album: (m['album'] as String?) ?? '',
        albumArtist: (m['album_artist'] as String?) ?? '',
        genre: (m['genre'] as String?) ?? '',
        year: m['year'] as int?,
        track: m['track'] as int?,
        disc: m['disc'] as int?,
        durationMs: (m['duration_ms'] as int?) ?? 0,
        artPath: m['art_path'] as String?,
        hasArt: (m['has_art'] as int? ?? 0) == 1,
        dateAdded: (m['date_added'] as int?) ?? 0,
        playCount: (m['play_count'] as int?) ?? 0,
        lastPlayed: m['last_played'] as int?,
        favourite: (m['favourite'] as int? ?? 0) == 1,
        originalName: (m['original_name'] as String?) ?? '',
      );
}

class Album {
  final String key;
  final String title;
  final String artist;
  final List<Song> songs;
  const Album(this.key, this.title, this.artist, this.songs);

  Song get coverSong => songs.firstWhere((s) => s.hasArt, orElse: () => songs.first);
  int? get year {
    for (final s in songs) {
      if (s.year != null) return s.year;
    }
    return null;
  }

  Duration get total => songs.fold(Duration.zero, (a, s) => a + s.duration);
}

class Artist {
  final String name;
  final List<Song> songs;
  const Artist(this.name, this.songs);
  Song get coverSong => songs.firstWhere((s) => s.hasArt, orElse: () => songs.first);
}

class Playlist {
  final int id;
  final String name;
  final List<String> songIds;
  final int created;
  const Playlist(this.id, this.name, this.songIds, this.created);

  Playlist copyWith({String? name, List<String>? songIds}) =>
      Playlist(id, name ?? this.name, songIds ?? this.songIds, created);
}
