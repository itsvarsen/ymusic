import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/db.dart';
import '../models/song.dart';
import 'library.dart';

enum RepeatSetting { off, all, one }

/// Playback + queue. The just_audio playlist is the single source of truth for
/// the queue; each source's tag is a MediaItem whose id is the song id.
/// Shuffle is implemented by physically re-ordering the queue around the
/// current item (so the current song never reloads and the queue screen shows
/// the real play order).
class PlayerController extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  final LibraryStore library;
  final AppDb db;

  PlayerController(this.library, this.db);

  bool shuffle = false;
  RepeatSetting repeat = RepeatSetting.off;
  List<String> _unshuffled = []; // queue order before shuffling
  final _subs = <StreamSubscription>[];
  Timer? _saveTimer;
  bool _pendingCount = true;

  // sleep timer
  Timer? _sleepTimer;
  DateTime? sleepAt;
  bool sleepAtEndOfSong = false;
  Timer? _sleepTick;

  // ---------------------------------------------------------------- getters
  List<Song> get queue {
    final out = <Song>[];
    for (final src in player.sequence) {
      final tag = src.tag;
      if (tag is MediaItem) {
        final s = library.byId(tag.id);
        if (s != null) out.add(s);
      }
    }
    return out;
  }

  List<String> get _queueIds =>
      player.sequence.map((s) => (s.tag as MediaItem).id).toList();

  int? get currentIndex => player.currentIndex;

  Song? get current {
    final i = player.currentIndex;
    final seq = player.sequence;
    if (i == null || i < 0 || i >= seq.length) return null;
    final tag = seq[i].tag;
    return tag is MediaItem ? library.byId(tag.id) : null;
  }

  bool get playing => player.playing;
  bool get hasQueue => player.sequence.isNotEmpty;
  Duration? get sleepRemaining => sleepAt?.difference(DateTime.now());

  // ---------------------------------------------------------------- init
  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}

    _subs.add(player.currentIndexStream.listen((i) {
      _pendingCount = true;
      if (sleepAtEndOfSong && _lastIndex != null && i != _lastIndex) {
        sleepAtEndOfSong = false;
        player.pause();
      }
      _lastIndex = i;
      _maybeCount();
      _save();
      notifyListeners();
    }));
    _subs.add(player.positionDiscontinuityStream.listen((d) {
      if (d.reason == PositionDiscontinuityReason.autoAdvance) {
        _pendingCount = true;
        if (sleepAtEndOfSong) {
          sleepAtEndOfSong = false;
          player.pause();
        }
        _maybeCount();
      }
    }));
    _subs.add(player.playingStream.listen((p) {
      _maybeCount();
      if (!p) _save();
      notifyListeners();
    }));
    _subs.add(player.sequenceStream.listen((_) => notifyListeners()));
    _subs.add(player.durationStream.listen((d) {
      final s = current;
      if (s != null && d != null && (s.durationMs - d.inMilliseconds).abs() > 1500) {
        library.updateDuration(s.id, d);
      }
    }));
    _subs.add(player.processingStateStream.listen((st) {
      if (st == ProcessingState.completed) {
        // End of queue with repeat off: rewind to the start, paused.
        player.pause();
        player.seek(Duration.zero, index: 0);
      }
    }));
    _subs.add(library.removedSongs.listen(_onSongRemoved));
    _saveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (player.playing) _save();
    });
    await _restore();
    _ready = true;
  }

  int? _lastIndex;

  void _maybeCount() {
    if (_pendingCount && player.playing) {
      final s = current;
      if (s != null) {
        _pendingCount = false;
        library.recordPlay(s.id);
      }
    }
  }

  // ---------------------------------------------------------------- sources
  AudioSource _source(Song s) => AudioSource.file(
        s.path,
        tag: MediaItem(
          id: s.id,
          title: s.title,
          artist: s.displayArtist,
          album: s.displayAlbum,
          genre: s.genre.isEmpty ? null : s.genre,
          duration: s.durationMs > 0 ? s.duration : null,
          artUri: s.artPath != null ? Uri.file(s.artPath!) : null,
        ),
      );

  // ---------------------------------------------------------------- playback
  /// Plays [songs] starting at [index]. With shuffle on, the tapped song plays
  /// first and the rest is shuffled.
  Future<void> playSongs(List<Song> songs, {int index = 0, bool? shuffled}) async {
    if (songs.isEmpty) return;
    if (shuffled != null && shuffled != shuffle) {
      shuffle = shuffled;
      db.setKv('shuffle', shuffle ? '1' : '0');
    }
    index = min(max(index, 0), songs.length - 1);
    _unshuffled = songs.map((s) => s.id).toList();
    List<Song> order;
    int start;
    if (shuffle) {
      final rest = [...songs]..removeAt(index);
      rest.shuffle(Random());
      order = [songs[index], ...rest];
      start = 0;
    } else {
      order = songs;
      start = index;
    }
    try {
      await player.setAudioSources(order.map(_source).toList(), initialIndex: start, initialPosition: Duration.zero);
      _pendingCount = true;
      player.play();
    } catch (e) {
      debugPrint('play failed: $e');
    }
    _save();
    notifyListeners();
  }

  Future<void> shuffleAll(List<Song> songs) async {
    if (songs.isEmpty) return;
    await playSongs(songs, index: Random().nextInt(songs.length), shuffled: true);
  }

  Future<void> togglePlay() async {
    if (!hasQueue) {
      if (library.songs.isNotEmpty) await shuffleAll(library.songs);
      return;
    }
    if (player.playing) {
      await player.pause();
    } else {
      player.play();
    }
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
    } else if (hasQueue) {
      await player.seek(Duration.zero, index: 0);
    }
  }

  Future<void> previous() async {
    if (player.position > const Duration(seconds: 3) || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> seek(Duration d) => player.seek(d);

  Future<void> jumpTo(int index) async {
    await player.seek(Duration.zero, index: index);
    if (!player.playing) player.play();
  }

  Future<void> cycleRepeat() async {
    repeat = RepeatSetting.values[(repeat.index + 1) % RepeatSetting.values.length];
    await player.setLoopMode(switch (repeat) {
      RepeatSetting.off => LoopMode.off,
      RepeatSetting.all => LoopMode.all,
      RepeatSetting.one => LoopMode.one,
    });
    db.setKv('repeat', repeat.name);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    shuffle = !shuffle;
    db.setKv('shuffle', shuffle ? '1' : '0');
    notifyListeners();
    final cur = player.currentIndex;
    final ids = _queueIds;
    if (cur == null || ids.length < 2) return;
    final currentId = ids[cur];
    List<String> before;
    List<String> after;
    if (shuffle) {
      _unshuffled = ids;
      final rest = [...ids]..removeAt(cur);
      rest.shuffle(Random());
      before = [];
      after = rest;
    } else {
      // Restore the original order around the current song.
      final orig = _unshuffled.where((id) => library.byId(id) != null).toList();
      var pos = orig.indexOf(currentId);
      if (pos < 0) {
        orig.insert(0, currentId);
        pos = 0;
      }
      before = orig.sublist(0, pos);
      after = orig.sublist(pos + 1);
    }
    await _rebuildAround(cur, before, after);
  }

  /// Keeps the playing item and replaces everything around it.
  Future<void> _rebuildAround(int cur, List<String> before, List<String> after) async {
    final len = player.sequence.length;
    if (cur + 1 < len) await player.removeAudioSourceRange(cur + 1, len);
    if (cur > 0) await player.removeAudioSourceRange(0, cur);
    final b = before.map(library.byId).whereType<Song>().map(_source).toList();
    final a = after.map(library.byId).whereType<Song>().map(_source).toList();
    if (a.isNotEmpty) await player.addAudioSources(a);
    if (b.isNotEmpty) await player.insertAudioSources(0, b);
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------- queue edits
  Future<void> playNext(Song s) async {
    if (!hasQueue) return playSongs([s]);
    final cur = player.currentIndex ?? -1;
    await player.insertAudioSource(cur + 1, _source(s));
    _addToUnshuffled(s.id);
    _save();
  }

  Future<void> addToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    if (!hasQueue) return playSongs(songs);
    await player.addAudioSources(songs.map(_source).toList());
    for (final s in songs) {
      _addToUnshuffled(s.id);
    }
    _save();
  }

  void _addToUnshuffled(String id) {
    if (!_unshuffled.contains(id)) _unshuffled.add(id);
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= player.sequence.length) return;
    if (player.sequence.length == 1) {
      await clearQueue();
      return;
    }
    await player.removeAudioSourceAt(index);
    _save();
  }

  Future<void> move(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    await player.moveAudioSource(oldIndex, newIndex);
    if (!shuffle) _unshuffled = _queueIds;
    _save();
  }

  Future<void> clearUpcoming() async {
    final cur = player.currentIndex;
    final len = player.sequence.length;
    if (cur == null || cur + 1 >= len) return;
    await player.removeAudioSourceRange(cur + 1, len);
    _save();
  }

  Future<void> clearQueue() async {
    await player.stop();
    await player.clearAudioSources();
    _unshuffled = [];
    _save();
    notifyListeners();
  }

  Future<void> _onSongRemoved(String id) async {
    final seq = player.sequence;
    for (var i = seq.length - 1; i >= 0; i--) {
      final tag = seq[i].tag;
      if (tag is MediaItem && tag.id == id) {
        if (seq.length == 1) {
          await clearQueue();
          return;
        }
        await player.removeAudioSourceAt(i);
      }
    }
    _unshuffled.remove(id);
    _save();
  }

  // ---------------------------------------------------------------- sleep timer
  void setSleepTimer(Duration? d) {
    _sleepTimer?.cancel();
    _sleepTick?.cancel();
    sleepAtEndOfSong = false;
    sleepAt = null;
    if (d != null) {
      sleepAt = DateTime.now().add(d);
      _sleepTimer = Timer(d, () {
        player.pause();
        sleepAt = null;
        _sleepTick?.cancel();
        notifyListeners();
      });
      _sleepTick = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    }
    notifyListeners();
  }

  void setSleepAtEndOfSong() {
    setSleepTimer(null);
    sleepAtEndOfSong = true;
    notifyListeners();
  }

  bool get sleepActive => sleepAt != null || sleepAtEndOfSong;

  // ---------------------------------------------------------------- persistence
  bool _ready = false;

  void _save() {
    if (!_ready) return;
    final ids = _queueIds;
    db.setKv(
      'player_state',
      jsonEncode({
        'queue': ids,
        'index': player.currentIndex ?? 0,
        'position': player.position.inMilliseconds,
        'unshuffled': _unshuffled,
      }),
    );
  }

  Future<void> saveNow() async => _save();

  Future<void> _restore() async {
    try {
      shuffle = (await db.getKv('shuffle')) == '1';
      final r = await db.getKv('repeat');
      repeat = RepeatSetting.values.firstWhere((e) => e.name == r, orElse: () => RepeatSetting.off);
      await player.setLoopMode(switch (repeat) {
        RepeatSetting.off => LoopMode.off,
        RepeatSetting.all => LoopMode.all,
        RepeatSetting.one => LoopMode.one,
      });
      final raw = await db.getKv('player_state');
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final ids = (m['queue'] as List).cast<String>();
      var index = (m['index'] as int?) ?? 0;
      final pos = Duration(milliseconds: (m['position'] as int?) ?? 0);
      _unshuffled = ((m['unshuffled'] as List?) ?? const []).cast<String>();
      final songs = <Song>[];
      String? currentId = (index >= 0 && index < ids.length) ? ids[index] : null;
      for (final id in ids) {
        final s = library.byId(id);
        if (s != null) songs.add(s);
      }
      if (songs.isEmpty) return;
      index = currentId == null ? 0 : songs.indexWhere((s) => s.id == currentId);
      if (index < 0) index = 0;
      await player.setAudioSources(
        songs.map(_source).toList(),
        initialIndex: index,
        initialPosition: pos,
        preload: false,
      );
      _pendingCount = true;
      notifyListeners();
    } catch (e) {
      debugPrint('restore failed: $e');
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTick?.cancel();
    player.dispose();
    super.dispose();
  }
}
