import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/player.dart';
import '../theme.dart';
import 'cover.dart';
import 'sheets.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? subtitleOverride;
  final int? playlistId;
  final int? playlistIndex;
  final bool showCover;
  final int? number;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.trailing,
    this.subtitleOverride,
    this.playlistId,
    this.playlistIndex,
    this.showCover = true,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    final currentId = context.select<PlayerController, String?>((p) => p.current?.id);
    final isPlaying = context.select<PlayerController, bool>((p) => p.playing);
    final active = currentId == song.id;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showSongMenu(context, song, playlistId: playlistId, playlistIndex: playlistIndex);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        child: Row(
          children: [
            if (showCover)
              Stack(
                alignment: Alignment.center,
                children: [
                  CoverArt(song: song, size: 52, radius: 14),
                  if (active)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0x99140E0A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: EqualizerIcon(animate: isPlaying),
                    ),
                ],
              )
            else
              SizedBox(
                width: 32,
                child: active
                    ? EqualizerIcon(animate: isPlaying, size: 18)
                    : Text(
                        number?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: YColors.faint, fontWeight: FontWeight.w600),
                      ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: active ? YColors.amber : YColors.cream,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitleOverride ?? '${song.displayArtist} · ${song.displayAlbum}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: YColors.muted),
                  ),
                ],
              ),
            ),
            if (song.favourite)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.favorite_rounded, size: 15, color: YColors.rose),
              ),
            trailing ??
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, color: YColors.muted),
                  onPressed: () => showSongMenu(context, song, playlistId: playlistId, playlistIndex: playlistIndex),
                ),
          ],
        ),
      ),
    );
  }
}

/// Three little animated bars.
class EqualizerIcon extends StatefulWidget {
  final bool animate;
  final double size;
  const EqualizerIcon({super.key, required this.animate, this.size = 20});
  @override
  State<EqualizerIcon> createState() => _EqualizerIconState();
}

class _EqualizerIconState extends State<EqualizerIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant EqualizerIcon old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        double h(double phase) {
          final v = (t + phase) % 1.0;
          return 0.3 + 0.7 * (v < 0.5 ? v * 2 : (1 - v) * 2);
        }

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [0.0, 0.35, 0.7].map((p) {
              return Container(
                width: widget.size / 6,
                height: widget.size * (widget.animate ? h(p) : 0.35),
                margin: EdgeInsets.symmetric(horizontal: widget.size / 24),
                decoration: BoxDecoration(
                  color: YColors.amber,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
