import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/library.dart';
import '../services/player.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/detail_page.dart';
import '../widgets/glass.dart';
import '../widgets/sheets.dart';
import '../widgets/song_tile.dart';
import 'routes.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final int playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final player = context.read<PlayerController>();
    final pl = lib.playlist(playlistId);
    if (pl == null) {
      return const DetailScaffold(slivers: [
        SliverFillRemaining(child: Center(child: Text('Playlist deleted', style: TextStyle(color: YColors.muted)))),
      ]);
    }
    final songs = lib.playlistSongs(pl);
    final total = songs.fold(Duration.zero, (a, s) => a + s.duration);
    final width = MediaQuery.sizeOf(context).width;
    return DetailScaffold(
      actions: [
        GlassIconButton(icon: Icons.add_rounded, onTap: () => showSongPicker(context, pl.id)),
        const SizedBox(width: 10),
        GlassIconButton(icon: Icons.more_horiz_rounded, onTap: () => _menu(context, pl)),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: DetailHeader(
            cover: PlaylistCover(songs: songs, size: width * 0.58, seed: pl.name),
            title: pl.name,
            subtitle: songsLabel(songs.length),
            meta: songs.isEmpty ? null : formatTotal(total),
            onPlay: songs.isEmpty ? null : () => player.playSongs(songs, shuffled: false),
            onShuffle: songs.isEmpty ? null : () => player.shuffleAll(songs),
          ),
        ),
        if (songs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  const Text('This playlist is empty', style: TextStyle(color: YColors.muted)),
                  const SizedBox(height: 14),
                  PillButton(label: 'Add songs', icon: Icons.add_rounded, onTap: () => showSongPicker(context, pl.id)),
                ],
              ),
            ),
          )
        else
          SliverReorderableList(
            itemCount: songs.length,
            onReorder: (o, n) {
              HapticFeedback.selectionClick();
              lib.reorderPlaylist(pl.id, o, n);
            },
            proxyDecorator: (child, i, anim) => Material(
              color: const Color(0xEE2A1F18),
              borderRadius: BorderRadius.circular(20),
              child: child,
            ),
            itemBuilder: (context, i) {
              final s = songs[i];
              return Dismissible(
                key: ValueKey('pl-${pl.id}-$i-${s.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 28),
                  color: const Color(0x33E88A7A),
                  child: const Icon(Icons.playlist_remove_rounded, color: Color(0xFFE88A7A)),
                ),
                onDismissed: (_) => lib.removeFromPlaylist(pl.id, i),
                child: SongTile(
                  song: s,
                  playlistId: pl.id,
                  playlistIndex: i,
                  onTap: () => player.playSongs(songs, index: i),
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.drag_handle_rounded, color: YColors.faint),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _menu(BuildContext context, Playlist pl) {
    final lib = context.read<LibraryStore>();
    final player = context.read<PlayerController>();
    showGlassSheet(context, (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          SheetAction(
            icon: Icons.queue_music_rounded,
            label: 'Add all to queue',
            onTap: () {
              Navigator.of(ctx).pop();
              player.addToQueue(lib.playlistSongs(pl));
              showToast(context, 'Added to queue');
            },
          ),
          SheetAction(
            icon: Icons.edit_rounded,
            label: 'Rename',
            onTap: () async {
              Navigator.of(ctx).pop();
              final name = await promptText(context, 'Rename playlist', pl.name);
              if (name != null) await lib.renamePlaylist(pl.id, name);
            },
          ),
          SheetAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete playlist',
            color: const Color(0xFFE88A7A),
            onTap: () async {
              Navigator.of(ctx).pop();
              final ok = await confirmDialog(context, 'Delete “${pl.name}”?', 'Songs stay in your library.', 'Delete');
              if (ok) {
                await lib.deletePlaylist(pl.id);
                if (context.mounted) Navigator.of(context).maybePop();
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      );
    });
  }
}

/// 2x2 mosaic of the first covers, or a gradient.
class PlaylistCover extends StatelessWidget {
  final List<Song> songs;
  final double size;
  final String seed;
  final double radius;
  const PlaylistCover({super.key, required this.songs, required this.size, required this.seed, this.radius = 30});

  @override
  Widget build(BuildContext context) {
    final withArt = <Song>[];
    final seen = <String>{};
    for (final s in songs) {
      if (seen.add(s.albumKey)) withArt.add(s);
      if (withArt.length == 4) break;
    }
    Widget child;
    if (withArt.length < 4) {
      child = withArt.isEmpty
          ? CoverArt(song: null, seed: seed, size: size, radius: 0)
          : CoverArt(song: withArt.first, size: size, radius: 0);
    } else {
      final h = size / 2;
      child = Column(children: [
        Row(children: [CoverArt(song: withArt[0], size: h, radius: 0), CoverArt(song: withArt[1], size: h, radius: 0)]),
        Row(children: [CoverArt(song: withArt[2], size: h, radius: 0), CoverArt(song: withArt[3], size: h, radius: 0)]),
      ]);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: size > 100 ? const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 14))] : null,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
    );
  }
}

/// Multi-select picker to add library songs to a playlist.
Future<void> showSongPicker(BuildContext context, int playlistId) {
  final lib = context.read<LibraryStore>();
  final pl = lib.playlist(playlistId);
  if (pl == null) return Future.value();
  final selected = <String>{};
  var query = '';
  return showGlassSheet(context, (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      final all = [...lib.songs]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      final q = query.toLowerCase();
      final list = q.isEmpty
          ? all
          : all
              .where((s) =>
                  s.title.toLowerCase().contains(q) ||
                  s.displayArtist.toLowerCase().contains(q) ||
                  s.displayAlbum.toLowerCase().contains(q))
              .toList();
      return SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Add to “${pl.name}”',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  PillButton(
                    label: selected.isEmpty ? 'Done' : 'Add ${selected.length}',
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      if (selected.isNotEmpty) {
                        final ordered = list.where((s) => selected.contains(s.id)).map((s) => s.id).toList();
                        final rest = selected.where((id) => !ordered.contains(id));
                        await lib.addToPlaylist(playlistId, [...ordered, ...rest]);
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search your library',
                  prefixIcon: Icon(Icons.search_rounded, color: YColors.muted),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final s = list[i];
                  final inPl = pl.songIds.contains(s.id);
                  final sel = selected.contains(s.id);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: CoverArt(song: s, size: 44, radius: 12),
                    title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(s.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: YColors.muted)),
                    trailing: inPl
                        ? const Icon(Icons.check_rounded, color: YColors.faint)
                        : Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: sel ? YColors.amber : YColors.faint),
                    onTap: inPl
                        ? null
                        : () => setState(() {
                              HapticFeedback.selectionClick();
                              if (!selected.remove(s.id)) selected.add(s.id);
                            }),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  });
}
