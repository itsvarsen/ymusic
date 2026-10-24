import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/song.dart';

/// Local library storage (sqflite).
class AppDb {
  final Database db;
  AppDb._(this.db);

  static Future<AppDb> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'ymusic.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE songs (
            id TEXT PRIMARY KEY,
            path TEXT NOT NULL,
            title TEXT,
            artist TEXT,
            album TEXT,
            album_artist TEXT,
            genre TEXT,
            year INTEGER,
            track INTEGER,
            disc INTEGER,
            duration_ms INTEGER,
            art_path TEXT,
            has_art INTEGER DEFAULT 0,
            date_added INTEGER,
            play_count INTEGER DEFAULT 0,
            last_played INTEGER,
            favourite INTEGER DEFAULT 0,
            original_name TEXT
          )''');
        await db.execute('''
          CREATE TABLE playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created INTEGER
          )''');
        await db.execute('''
          CREATE TABLE playlist_songs (
            playlist_id INTEGER NOT NULL,
            song_id TEXT NOT NULL,
            position INTEGER NOT NULL
          )''');
        await db.execute('CREATE INDEX idx_ps ON playlist_songs(playlist_id, position)');
        await db.execute('CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT)');
      },
    );
    return AppDb._(db);
  }

  // ---- songs
  Future<List<Song>> allSongs() async {
    final rows = await db.query('songs');
    return rows.map(Song.fromMap).toList();
  }

  Future<bool> hasSong(String id) async {
    final r = await db.query('songs', columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isNotEmpty;
  }

  Future<void> upsertSong(Song s) =>
      db.insert('songs', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> updateSong(Song s) =>
      db.update('songs', s.toMap(), where: 'id = ?', whereArgs: [s.id]);

  Future<void> deleteSong(String id) async {
    await db.delete('songs', where: 'id = ?', whereArgs: [id]);
    await db.delete('playlist_songs', where: 'song_id = ?', whereArgs: [id]);
  }

  // ---- playlists
  Future<List<Playlist>> allPlaylists() async {
    final pls = await db.query('playlists', orderBy: 'created DESC');
    final items = await db.query('playlist_songs', orderBy: 'playlist_id, position');
    final map = <int, List<String>>{};
    for (final r in items) {
      map.putIfAbsent(r['playlist_id'] as int, () => []).add(r['song_id'] as String);
    }
    return pls
        .map((r) => Playlist(
              r['id'] as int,
              r['name'] as String,
              map[r['id'] as int] ?? <String>[],
              (r['created'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<int> createPlaylist(String name) => db.insert('playlists', {
        'name': name,
        'created': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> renamePlaylist(int id, String name) =>
      db.update('playlists', {'name': name}, where: 'id = ?', whereArgs: [id]);

  Future<void> deletePlaylist(int id) async {
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
    await db.delete('playlist_songs', where: 'playlist_id = ?', whereArgs: [id]);
  }

  Future<void> setPlaylistSongs(int id, List<String> songIds) async {
    await db.transaction((txn) async {
      await txn.delete('playlist_songs', where: 'playlist_id = ?', whereArgs: [id]);
      final batch = txn.batch();
      for (var i = 0; i < songIds.length; i++) {
        batch.insert('playlist_songs', {'playlist_id': id, 'song_id': songIds[i], 'position': i});
      }
      await batch.commit(noResult: true);
    });
  }

  // ---- key/value
  Future<String?> getKv(String key) async {
    final r = await db.query('kv', where: 'key = ?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setKv(String key, String value) =>
      db.insert('kv', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
}
