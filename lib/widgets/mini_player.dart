import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../screens/routes.dart';
import '../services/player.dart';
import '../theme.dart';
import 'cover.dart';
import 'glass.dart';

/// Floating glass mini-player. Swipe left/right to skip, tap to expand.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SizeTransition(sizeFactor: a, axisAlignment: 1, child: c),
      ),
      child: song == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              key: const ValueKey('mini'),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: GestureDetector(
                onTap: () => openNowPlaying(context),
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) < -200) openNowPlaying(context);
                },
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -300) {
                    HapticFeedback.selectionClick();
                    player.next();
                  } else if (v > 300) {
                    HapticFeedback.selectionClick();
                    player.previous();
                  }
                },
                child: Glass(
                  radius: 26,
                  blur: 30,
                  opacity: 0.62,
                  child: SizedBox(
                    height: 66,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(9, 9, 8, 9),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'np-cover',
                                child: CoverArt(song: song, size: 48, radius: 15),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: Column(
                                    key: ValueKey(song.id),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                      const SizedBox(height: 2),
                                      Text(song.displayArtist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: YColors.muted, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  context.read<PlayerController>().library.toggleFavourite(song.id);
                                },
                                icon: Icon(
                                  song.favourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: song.favourite ? YColors.rose : YColors.muted,
                                  size: 22,
                                ),
                              ),
                              GlassIconButton(
                                icon: player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 44,
                                filled: true,
                                onTap: player.togglePlay,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 22,
                          right: 22,
                          bottom: 0,
                          child: _MiniProgress(player: player),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final PlayerController player;
  const _MiniProgress({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.player.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = player.player.duration ?? player.current?.duration ?? Duration.zero;
        final v = dur.inMilliseconds <= 0 ? 0.0 : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 2,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Color(0x1FFFF1E0))),
                FractionallySizedBox(
                  widthFactor: v,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [YColors.amber, YColors.rose]),
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

/// Floating glass bottom navigation.
class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const GlassNavBar({super.key, required this.index, required this.onChanged});

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.library_music_rounded, Icons.library_music_outlined, 'Library'),
    (Icons.search_rounded, Icons.search_rounded, 'Search'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(40, 0, 40, MediaQuery.paddingOf(context).bottom + 12),
      child: Glass(
        radius: 32,
        blur: 30,
        opacity: 0.66,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_items.length, (i) {
              final it = _items[i];
              final sel = i == index;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    if (!sel) HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0x26F2A65A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(sel ? it.$1 : it.$2, color: sel ? YColors.amber : YColors.muted, size: 23),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          child: sel
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 7),
                                  child: Text(it.$3,
                                      style: const TextStyle(color: YColors.amber, fontWeight: FontWeight.w700, fontSize: 13)),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Bottom dock used by pushed pages (mini-player only).
class PageDock extends StatelessWidget {
  const PageDock({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 4),
      child: const MiniPlayer(),
    );
  }
}
