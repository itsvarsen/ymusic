import 'dart:io';
import 'dart:ui' show ImageFilter, TileMode, FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/cover_art.dart';
import '../services/player.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/glass.dart';
import '../widgets/sheets.dart';
import 'routes.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});
  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  Color _accent = YColors.amber;
  String? _accentFor;

  void _updateAccent(Song? s) {
    if (s == null || _accentFor == s.id) return;
    _accentFor = s.id;
    final fallback = accentFor('${s.album.isEmpty ? s.title : s.album}|${s.artist}');
    if (!s.hasArt) {
      setState(() => _accent = fallback);
      return;
    }
    dominantColorOf(s.artPath).then((c) {
      if (!mounted || _accentFor != s.id) return;
      setState(() => _accent = c ?? fallback);
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateAccent(song));
    final size = MediaQuery.sizeOf(context);
    final coverSize = (size.width - 64).clamp(200.0, size.height * 0.42);

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: _accent),
      duration: const Duration(milliseconds: 700),
      builder: (context, accent, _) {
        final a = accent ?? YColors.amber;
        return Scaffold(
          backgroundColor: YColors.bg,
          body: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).maybePop();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Blurred cover background
                if (song != null && song.artPath != null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: ImageFiltered(
                      key: ValueKey(song.id),
                      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70, tileMode: TileMode.decal),
                      child: Transform.scale(
                        scale: 1.4,
                        child: Image.file(
                          File(song.artPath!),
                          fit: BoxFit.cover,
                          cacheWidth: 200,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        ),
                      ),
                    ),
                  ),
                // Warm tinted veil
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(YColors.bg, a, 0.28)!.withValues(alpha: 0.72),
                        YColors.bg.withValues(alpha: 0.80),
                        YColors.bg.withValues(alpha: 0.97),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
                SafeArea(
                  child: song == null
                      ? const Center(child: Text('Nothing playing', style: TextStyle(color: YColors.muted)))
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          child: Column(
                            children: [
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  GlassIconButton(
                                    icon: Icons.keyboard_arrow_down_rounded,
                                    onTap: () => Navigator.of(context).maybePop(),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        const Text('NOW PLAYING',
                                            style: TextStyle(
                                                fontSize: 11, letterSpacing: 2, color: YColors.muted, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(
                                          song.displayAlbum,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GlassIconButton(
                                    icon: Icons.more_horiz_rounded,
                                    onTap: () => showSongMenu(context, song),
                                  ),
                                ],
                              ),
                              const Spacer(flex: 2),
                              Hero(
                                tag: 'np-cover',
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  switchInCurve: Curves.easeOutCubic,
                                  transitionBuilder: (c, an) => FadeTransition(
                                    opacity: an,
                                    child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(an), child: c),
                                  ),
                                  child: AnimatedScale(
                                    key: ValueKey(song.id),
                                    scale: player.playing ? 1.0 : 0.9,
                                    duration: const Duration(milliseconds: 450),
                                    curve: Curves.easeOutBack,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(32),
                                        boxShadow: [
                                          BoxShadow(color: a.withValues(alpha: 0.30), blurRadius: 60, offset: const Offset(0, 24)),
                                        ],
                                      ),
                                      child: CoverArt(song: song, size: coverSize, radius: 32),
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(flex: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                                        ),
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            openArtist(context, song.displayArtist);
                                          },
                                          child: Text(
                                            song.displayArtist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 16, color: Color.lerp(YColors.muted, a, 0.45)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _LikeButton(song: song),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _SeekBar(player: player, accent: a),
                              const SizedBox(height: 10),
                              _Controls(player: player, accent: a),
                              const SizedBox(height: 18),
                              Glass(
                                radius: 26,
                                opacity: 0.35,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _BottomAction(
                                      icon: Icons.bedtime_outlined,
                                      label: player.sleepRemaining != null
                                          ? formatDuration(player.sleepRemaining!)
                                          : (player.sleepAtEndOfSong ? 'End of song' : 'Sleep'),
                                      active: player.sleepActive,
                                      accent: a,
                                      onTap: () => showSleepTimer(context),
                                    ),
                                    _BottomAction(
                                      icon: Icons.playlist_add_rounded,
                                      label: 'Playlist',
                                      accent: a,
                                      onTap: () => showAddToPlaylist(context, [song]),
                                    ),
                                    _BottomAction(
                                      icon: Icons.queue_music_rounded,
                                      label: 'Queue',
                                      accent: a,
                                      onTap: () => openQueue(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LikeButton extends StatelessWidget {
  final Song song;
  const _LikeButton({required this.song});
  @override
  Widget build(BuildContext context) {
    final fav = song.favourite;
    return IconButton(
      iconSize: 30,
      onPressed: () {
        HapticFeedback.mediumImpact();
        context.read<PlayerController>().library.toggleFavourite(song.id);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (c, a) => ScaleTransition(
          scale: Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.elasticOut)),
          child: c,
        ),
        child: Icon(
          fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(fav),
          color: fav ? YColors.rose : YColors.cream,
        ),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  final PlayerController player;
  final Color accent;
  const _SeekBar({required this.player, required this.accent});
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final p = widget.player.player;
    return StreamBuilder<Duration>(
      stream: p.positionStream,
      builder: (context, snap) {
        final dur = p.duration ?? widget.player.current?.duration ?? Duration.zero;
        final pos = snap.data ?? Duration.zero;
        final max = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
        final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max);
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: widget.accent,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                min: 0,
                max: max,
                value: value,
                onChangeStart: (v) => setState(() => _drag = v),
                onChanged: (v) => setState(() => _drag = v),
                onChangeEnd: (v) {
                  HapticFeedback.selectionClick();
                  widget.player.seek(Duration(milliseconds: v.round()));
                  setState(() => _drag = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(Duration(milliseconds: value.round())),
                      style: const TextStyle(color: YColors.muted, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                  Text('-${formatDuration(Duration(milliseconds: (max - value).round()))}',
                      style: const TextStyle(color: YColors.muted, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final PlayerController player;
  final Color accent;
  const _Controls({required this.player, required this.accent});

  @override
  Widget build(BuildContext context) {
    final repeatIcon = player.repeat == RepeatSetting.one ? Icons.repeat_one_rounded : Icons.repeat_rounded;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ToggleIcon(
          icon: Icons.shuffle_rounded,
          active: player.shuffle,
          accent: accent,
          onTap: player.toggleShuffle,
        ),
        IconButton(
          iconSize: 40,
          onPressed: () {
            HapticFeedback.selectionClick();
            player.previous();
          },
          icon: const Icon(Icons.skip_previous_rounded, color: YColors.cream),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            player.togglePlay();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(accent, Colors.white, 0.25)!, accent],
              ),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(player.playing),
                size: 40,
                color: const Color(0xFF1C120A),
              ),
            ),
          ),
        ),
        IconButton(
          iconSize: 40,
          onPressed: () {
            HapticFeedback.selectionClick();
            player.next();
          },
          icon: const Icon(Icons.skip_next_rounded, color: YColors.cream),
        ),
        _ToggleIcon(
          icon: repeatIcon,
          active: player.repeat != RepeatSetting.off,
          accent: accent,
          onTap: player.cycleRepeat,
        ),
      ],
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  const _ToggleIcon({required this.icon, required this.active, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      radius: 26,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? accent : YColors.muted, size: 24),
            const SizedBox(height: 4),
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(width: 4, height: 4, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color accent;
  const _BottomAction({required this.icon, required this.label, required this.onTap, this.active = false, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = active ? accent : YColors.cream;
    return TextButton.icon(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      icon: Icon(icon, color: c, size: 20),
      label: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );
  }
}
