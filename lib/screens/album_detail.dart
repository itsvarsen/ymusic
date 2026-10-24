import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library.dart';
import '../services/player.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/detail_page.dart';
import '../widgets/glass.dart';
import '../widgets/sheets.dart';
import '../widgets/song_tile.dart';
import 'routes.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String albumKey;
  const AlbumDetailScreen({super.key, required this.albumKey});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final player = context.read<PlayerController>();
    final album = lib.albumByKey(albumKey);
    if (album == null) {
      return const DetailScaffold(slivers: [
        SliverFillRemaining(child: Center(child: Text('Album not found', style: TextStyle(color: YColors.muted)))),
      ]);
    }
    final width = MediaQuery.sizeOf(context).width;
    final meta = [
      if (album.year != null) '${album.year}',
      songsLabel(album.songs.length),
      formatTotal(album.total),
    ].join(' · ');
    final sameArtistTracks = album.songs.any((s) => s.displayArtist != album.artist);
    return DetailScaffold(
      actions: [
        GlassIconButton(
          icon: Icons.playlist_add_rounded,
          onTap: () => showAddToPlaylist(context, album.songs),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: DetailHeader(
            cover: Hero(
              tag: 'album-${album.key}',
              child: CoverArt(song: album.coverSong, size: width * 0.62, radius: 30),
            ),
            title: album.title,
            subtitle: album.artist,
            meta: meta,
            onPlay: () => player.playSongs(album.songs, shuffled: false),
            onShuffle: () => player.shuffleAll(album.songs),
          ),
        ),
        SliverList.builder(
          itemCount: album.songs.length,
          itemBuilder: (context, i) {
            final s = album.songs[i];
            return SongTile(
              song: s,
              showCover: false,
              number: s.track ?? (i + 1),
              subtitleOverride: sameArtistTracks ? s.displayArtist : formatDuration(s.duration),
              onTap: () => player.playSongs(album.songs, index: i),
            );
          },
        ),
      ],
    );
  }
}
