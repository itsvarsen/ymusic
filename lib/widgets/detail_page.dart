import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass.dart';
import 'mini_player.dart';

/// Shared scaffold for album / artist / playlist pages: ambient background,
/// floating back button and the mini-player dock.
class DetailScaffold extends StatelessWidget {
  final List<Widget> slivers;
  final Color? accent;
  final List<Widget> actions;
  const DetailScaffold({super.key, required this.slivers, this.accent, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: YColors.bg,
      body: AmbientBackground(
        accent: accent,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: top + 64)),
                ...slivers,
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
            Positioned(
              top: top + 8,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  ...actions,
                ],
              ),
            ),
            const Positioned(left: 0, right: 0, bottom: 0, child: PageDock()),
          ],
        ),
      ),
    );
  }
}

/// Big centered header with cover, title, subtitle and play / shuffle.
class DetailHeader extends StatelessWidget {
  final Widget cover;
  final String title;
  final String subtitle;
  final String? meta;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;
  const DetailHeader({
    super.key,
    required this.cover,
    required this.title,
    required this.subtitle,
    this.meta,
    this.onPlay,
    this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        children: [
          cover,
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6),
          ),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: YColors.amber, fontWeight: FontWeight.w600)),
          if (meta != null) ...[
            const SizedBox(height: 4),
            Text(meta!, style: const TextStyle(fontSize: 13, color: YColors.muted)),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PillButton(label: 'Play', icon: Icons.play_arrow_rounded, onTap: onPlay),
              const SizedBox(width: 12),
              PillButton(label: 'Shuffle', icon: Icons.shuffle_rounded, primary: false, onTap: onShuffle),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
