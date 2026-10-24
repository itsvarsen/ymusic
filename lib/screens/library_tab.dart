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
import 'playlist_detail.dart';
import 'routes.dart';
import 'shell.dart';

enum LibView { songs, albums, artists, playlists, favourites }

extension on LibView {
  String get label => switch (this) {
        LibView.songs => 'Songs',
        LibView.albums => 'Albums',
        LibView.artists => 'Artists',
        LibView.playlists => 'Playlists',
        LibView.favourites => 'Favourites',
      };
}

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  LibView _view = LibView.songs;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final addBtn = GlassIconButton(icon: Icons.add_rounded, tooltip: 'Add music', onTap: () => showAddMusic(context));
    return Column(
      children: [
        TabTopBar(
          title: const Text('Library', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
          actions: [addBtn],
        ),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
            children: [
              for (final v in LibView.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GlassChip(label: v.label, selected: _view == v, onTap: () => setState(() => _view = v)),
                ),
            ],
          ),
        ),
        Expanded(
          child: !lib.loaded
              ? const SizedBox()
              : (lib.isEmpty && _view != LibView.playlists)
                  ? EmptyLibrary(onAdd: () => showAddMusic(context))
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      child: KeyedSubtree(key: ValueKey(_view), child: _body(lib)),
                    ),
        ),
      ],
    );
  }

  Widget _body(LibraryStore lib) {
    switch (_view) {
      case LibView.songs:
        return _SongsView(songs: lib.visibleSongs, showControls: true);
      case LibView.favourites:
        final f = lib.favourites;
        if (f.isEmpty) {
          return const _Hint(icon: Icons.favorite_border_rounded, text: 'Songs you ♥ will gather here.');
        }
        return _SongsView(songs: f, showControls: false);
      case LibView.albums:
        return _AlbumsGrid(albums: lib.albums);
      case LibView.artists:
        return _ArtistsList(artists: lib.artists);
      case LibView.playlists:
        return _PlaylistsView(playlists: lib.playlists);
    }
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 160),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: YColors.faint, size: 42),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: YColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _SongsView extends StatelessWidget {
  final List<Song> songs;
  final bool showControls;
  const _SongsView({required this.songs, required this.showControls});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final player = context.read<PlayerController>();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 12, 6),
            child: Row(
              children: [
                PillButton(
                  label: 'Play',
                  icon: Icons.play_arrow_rounded,
                  onTap: songs.isEmpty ? null : () => player.playSongs(songs, shuffled: false),
                ),
                const SizedBox(width: 8),
                PillButton(
                  label: 'Shuffle',
                  icon: Icons.shuffle_rounded,
                  primary: false,
                  onTap: songs.isEmpty ? null : () => player.shuffleAll(songs),
                ),
                const Spacer(),
                if (showControls) ...[
                  _IconChip(
                    icon: lib.ascending ? Icons.north_rounded : Icons.south_rounded,
                    label: lib.sortField.label,
                    onTap: () => showSortSheet(context),
                  ),
                  const SizedBox(width: 4),
                  _IconChip(
                    icon: Icons.tune_rounded,
                    active: lib.hasActiveFilter,
                    onTap: () => showFilterSheet(context),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showControls && lib.hasActiveFilter)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (lib.favouritesOnly) 'Favourites',
                        if (lib.filterGenre != null) lib.filterGenre!,
                        if (lib.filterArtist != null) lib.filterArtist!,
                        if (lib.filterYear != null) '${lib.filterYear}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: YColors.amber, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: lib.clearFilters,
                    child: const Text('Clear', style: TextStyle(color: YColors.muted, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
            child: Text(songsLabel(songs.length), style: const TextStyle(color: YColors.faint, fontSize: 12.5)),
          ),
        ),
        if (songs.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('No songs match these filters', style: TextStyle(color: YColors.muted))),
            ),
          ),
        SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, i) => SongTile(
            song: songs[i],
            onTap: () => player.playSongs(songs, index: i),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 190)),
      ],
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool active;
  final VoidCallback onTap;
  const _IconChip({required this.icon, this.label, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0x33F2A65A) : const Color(0x12FFF1E0),
      shape: const StadiumBorder(side: BorderSide(color: Color(0x1FFFF1E0))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: active ? YColors.amber : YColors.cream),
              if (label != null) ...[
                const SizedBox(width: 5),
                Text(label!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumsGrid extends StatelessWidget {
  final List<Album> albums;
  const _AlbumsGrid({required this.albums});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const pad = 18.0;
      const gap = 14.0;
      final cols = c.maxWidth > 600 ? 3 : 2;
      final w = (c.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(pad, 10, pad, 190),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: gap,
          mainAxisSpacing: 18,
          childAspectRatio: w / (w + 48),
        ),
        itemCount: albums.length,
        itemBuilder: (context, i) {
          final a = albums[i];
          return GestureDetector(
            onTap: () => openAlbum(context, a.key),
            onLongPress: () => showAddToPlaylist(context, a.songs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(tag: 'album-${a.key}', child: CoverArt(song: a.coverSong, size: w, radius: 24)),
                const SizedBox(height: 8),
                Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(a.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: YColors.muted, fontSize: 12.5)),
              ],
            ),
          );
        },
      );
    });
  }
}

class _ArtistsList extends StatelessWidget {
  final List<Artist> artists;
  const _ArtistsList({required this.artists});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 190),
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final a = artists[i];
        final albums = <String>{for (final s in a.songs) s.albumKey}.length;
        return InkWell(
          onTap: () => openArtist(context, a.name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Hero(tag: 'artist-${a.name}', child: CoverArt(song: a.coverSong, size: 56, circle: true)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      const SizedBox(height: 2),
                      Text('${songsLabel(a.songs.length)} · ${albums == 1 ? '1 album' : '$albums albums'}',
                          style: const TextStyle(color: YColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: YColors.faint),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlaylistsView extends StatelessWidget {
  final List<Playlist> playlists;
  const _PlaylistsView({required this.playlists});

  @override
  Widget build(BuildContext context) {
    final lib = context.read<LibraryStore>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 190),
      children: [
        InkWell(
          onTap: () async {
            final name = await promptText(context, 'New playlist', '', hint: 'Playlist name');
            if (name == null) return;
            final id = await lib.createPlaylist(name);
            if (context.mounted) openPlaylist(context, id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0x1FF2A65A),
                    border: Border.all(color: const Color(0x33F2A65A)),
                  ),
                  child: const Icon(Icons.add_rounded, color: YColors.amber, size: 28),
                ),
                const SizedBox(width: 14),
                const Text('New playlist', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: YColors.amber)),
              ],
            ),
          ),
        ),
        for (final p in playlists)
          InkWell(
            onTap: () => openPlaylist(context, p.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  PlaylistCover(songs: lib.playlistSongs(p), size: 60, seed: p.name, radius: 18),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                        const SizedBox(height: 2),
                        Text(songsLabel(p.songIds.length), style: const TextStyle(color: YColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: YColors.faint),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
