import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/library.dart';
import '../services/player.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/glass.dart';
import '../widgets/sheets.dart';
import '../widgets/song_tile.dart';
import 'routes.dart';
import 'shell.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback onOpenLibrary;
  const HomeTab({super.key, required this.onOpenLibrary});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late night';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final player = context.read<PlayerController>();
    final addBtn = GlassIconButton(icon: Icons.add_rounded, tooltip: 'Add music', onTap: () => showAddMusic(context));
    if (!lib.loaded) return const SizedBox();
    if (lib.isEmpty) {
      return Column(
        children: [
          TabTopBar(actions: [addBtn]),
          Expanded(child: EmptyLibrary(onAdd: () => showAddMusic(context))),
        ],
      );
    }
    final recent = lib.recentlyPlayed;
    final most = lib.mostPlayed;
    final added = lib.recentlyAdded;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: TabTopBar(actions: [addBtn])),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 4),
                Text(
                  '${songsLabel(lib.songs.length)} · ${formatTotal(lib.totalDuration)} of music',
                  style: const TextStyle(color: YColors.muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: _QuickCard(
                    icon: Icons.shuffle_rounded,
                    label: 'Shuffle all',
                    colors: const [Color(0x40F2A65A), Color(0x14F2A65A)],
                    onTap: () => player.shuffleAll(lib.songs),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.favorite_rounded,
                    label: 'Favourites',
                    colors: const [Color(0x40E4949B), Color(0x14E4949B)],
                    onTap: () {
                      final f = lib.favourites;
                      if (f.isEmpty) {
                        showToast(context, 'Tap ♥ on a song to add favourites');
                      } else {
                        player.playSongs(f);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (recent.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader('Recently played')),
          SliverToBoxAdapter(child: _CoverCarousel(songs: recent)),
        ],
        if (most.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              'Most played',
              action: 'Play',
              onAction: () => player.playSongs(most, shuffled: false),
            ),
          ),
          SliverList.builder(
            itemCount: math.min(most.length, 5),
            itemBuilder: (context, i) => SongTile(
              song: most[i],
              subtitleOverride: '${most[i].displayArtist} · ${most[i].playCount} plays',
              onTap: () => player.playSongs(most, index: i),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SectionHeader('Recently added')),
        SliverToBoxAdapter(child: _CoverCarousel(songs: added)),
        if (lib.albums.length > 1) ...[
          SliverToBoxAdapter(child: SectionHeader('Albums', action: 'See all', onAction: onOpenLibrary)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: math.min(lib.albums.length, 12),
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final a = lib.albums[i];
                  return GestureDetector(
                    onTap: () => openAlbum(context, a.key),
                    child: SizedBox(
                      width: 142,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CoverArt(song: a.coverSong, size: 142, radius: 22),
                          const SizedBox(height: 8),
                          Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text(a.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: YColors.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 190)),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.label, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x1FFFF1E0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Row(
              children: [
                Icon(icon, color: YColors.cream, size: 22),
                const SizedBox(width: 10),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverCarousel extends StatelessWidget {
  final List<Song> songs;
  const _CoverCarousel({required this.songs});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final s = songs[i];
          return GestureDetector(
            onTap: () => player.playSongs(songs, index: i),
            onLongPress: () => showSongMenu(context, s),
            child: SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoverArt(song: s, size: 140, radius: 24),
                  const SizedBox(height: 8),
                  Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(s.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: YColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
