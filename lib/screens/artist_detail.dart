import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/library.dart';
import '../services/player.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/detail_page.dart';
import '../widgets/glass.dart';
import '../widgets/song_tile.dart';
import 'routes.dart';

class ArtistDetailScreen extends StatelessWidget {
  final String name;
  const ArtistDetailScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final player = context.read<PlayerController>();
    final artist = lib.artistByName(name);
    if (artist == null) {
      return const DetailScaffold(slivers: [
        SliverFillRemaining(child: Center(child: Text('Artist not found', style: TextStyle(color: YColors.muted)))),
      ]);
    }
    final songs = [...artist.songs]..sort((a, b) => b.playCount != a.playCount
        ? b.playCount.compareTo(a.playCount)
        : a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final albumKeys = <String>{for (final s in artist.songs) s.albumKey};
    final albums = lib.albums.where((a) => albumKeys.contains(a.key)).toList();
    final width = MediaQuery.sizeOf(context).width;
    return DetailScaffold(
      slivers: [
        SliverToBoxAdapter(
          child: DetailHeader(
            cover: Hero(
              tag: 'artist-${artist.name}',
              child: CoverArt(song: artist.coverSong, size: width * 0.5, circle: true),
            ),
            title: artist.name,
            subtitle: '${songsLabel(songs.length)} · ${albums.length == 1 ? '1 album' : '${albums.length} albums'}',
            onPlay: () => player.playSongs(songs, shuffled: false),
            onShuffle: () => player.shuffleAll(songs),
          ),
        ),
        if (albums.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader('Albums')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: albums.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) => _AlbumCard(album: albums[i]),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SectionHeader('Songs')),
        SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, i) => SongTile(
            song: songs[i],
            subtitleOverride: songs[i].displayAlbum,
            onTap: () => player.playSongs(songs, index: i),
          ),
        ),
      ],
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  const _AlbumCard({required this.album});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openAlbum(context, album.key),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(song: album.coverSong, size: 140, radius: 22),
            const SizedBox(height: 8),
            Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(album.year?.toString() ?? songsLabel(album.songs.length),
                style: const TextStyle(color: YColors.muted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
