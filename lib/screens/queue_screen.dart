import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/player.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/glass.dart';
import '../widgets/sheets.dart';
import '../widgets/song_tile.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final queue = player.queue;
    final cur = player.currentIndex ?? 0;
    return Scaffold(
      backgroundColor: YColors.bg,
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  children: [
                    GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Queue', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    ),
                    if (queue.length > cur + 1)
                      TextButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          player.clearUpcoming();
                        },
                        child: const Text('Clear upcoming', style: TextStyle(color: YColors.amber, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                child: Row(
                  children: [
                    Text(
                      '${queue.length} songs · ${player.shuffle ? 'shuffled' : 'in order'}'
                      '${player.repeat == RepeatSetting.off ? '' : player.repeat == RepeatSetting.one ? ' · repeat one' : ' · repeat all'}',
                      style: const TextStyle(color: YColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: queue.isEmpty
                    ? const Center(child: Text('The queue is empty', style: TextStyle(color: YColors.muted)))
                    : ReorderableListView.builder(
                        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 30),
                        itemCount: queue.length,
                        buildDefaultDragHandles: false,
                        proxyDecorator: (child, i, anim) => Material(
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xEE2A1F18),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 24)],
                            ),
                            child: child,
                          ),
                        ),
                        onReorder: (o, n) {
                          HapticFeedback.selectionClick();
                          player.move(o, n);
                        },
                        itemBuilder: (context, i) {
                          final s = queue[i];
                          return _QueueRow(
                            key: ObjectKey(player.player.sequence[i]),
                            song: s,
                            index: i,
                            isCurrent: i == cur,
                            isPast: i < cur,
                            playing: player.playing,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final Song song;
  final int index;
  final bool isCurrent;
  final bool isPast;
  final bool playing;
  const _QueueRow({
    super.key,
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.isPast,
    required this.playing,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return Dismissible(
      key: ValueKey('dismiss-${key.hashCode}'),
      direction: isCurrent ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        color: const Color(0x33E88A7A),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE88A7A)),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        player.removeAt(index);
      },
      child: Opacity(
        opacity: isPast ? 0.5 : 1,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isCurrent ? const Color(0x1FF2A65A) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => player.jumpTo(index),
            onLongPress: () => _menu(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CoverArt(song: song, size: 46, radius: 13),
                      if (isCurrent)
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: const Color(0x99140E0A), borderRadius: BorderRadius.circular(13)),
                          child: EqualizerIcon(animate: playing, size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w600, color: isCurrent ? YColors.amber : YColors.cream, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(song.displayArtist,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: YColors.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, color: YColors.muted),
                    onPressed: () => _menu(context),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Icon(Icons.drag_handle_rounded, color: YColors.faint),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _menu(BuildContext context) {
    final player = context.read<PlayerController>();
    showGlassSheet(context, (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          SheetAction(
            icon: Icons.play_arrow_rounded,
            label: 'Play now',
            onTap: () {
              Navigator.of(ctx).pop();
              player.jumpTo(index);
            },
          ),
          if (!isCurrent)
            SheetAction(
              icon: Icons.playlist_play_rounded,
              label: 'Play next',
              onTap: () {
                Navigator.of(ctx).pop();
                final cur = player.currentIndex ?? 0;
                player.move(index, cur + 1);
              },
            ),
          SheetAction(
            icon: Icons.playlist_add_rounded,
            label: 'Add to playlist',
            onTap: () {
              Navigator.of(ctx).pop();
              showAddToPlaylist(context, [song]);
            },
          ),
          if (!isCurrent)
            SheetAction(
              icon: Icons.remove_circle_outline_rounded,
              label: 'Remove from queue',
              color: const Color(0xFFE88A7A),
              onTap: () {
                Navigator.of(ctx).pop();
                player.removeAt(index);
              },
            ),
          const SizedBox(height: 12),
        ],
      );
    });
  }
}
