import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../screens/routes.dart';
import '../services/library.dart';
import '../services/player.dart';
import '../theme.dart';
import 'cover.dart';
import 'glass.dart';

/// Shows a frosted bottom sheet.
Future<T?> showGlassSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99080605),
    elevation: 0,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        bottom: MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom + 10,
      ),
      child: Glass(
        radius: 32,
        blur: 36,
        opacity: 0.82,
        tint: const Color(0xFF241A14),
        child: SafeArea(
          top: false,
          bottom: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.86),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0x40FFF1E0), borderRadius: BorderRadius.circular(2)),
                ),
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;
  const SheetAction({super.key, required this.icon, required this.label, required this.onTap, this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color ?? YColors.cream, size: 22),
            const SizedBox(width: 18),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: color ?? YColors.cream)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- song menu
Future<void> showSongMenu(BuildContext context, Song song, {int? playlistId, int? playlistIndex}) {
  final lib = context.read<LibraryStore>();
  final player = context.read<PlayerController>();
  final messengerCtx = context;
  return showGlassSheet(context, (ctx) {
    final s = lib.byId(song.id) ?? song;
    void close() => Navigator.of(ctx).pop();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
            child: Row(
              children: [
                CoverArt(song: s, size: 56, radius: 14),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text('${s.displayArtist} · ${s.displayAlbum}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: YColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: YColors.line, height: 1),
          SheetAction(
            icon: Icons.playlist_play_rounded,
            label: 'Play next',
            onTap: () {
              close();
              player.playNext(s);
              showToast(messengerCtx, 'Playing next');
            },
          ),
          SheetAction(
            icon: Icons.queue_music_rounded,
            label: 'Add to queue',
            onTap: () {
              close();
              player.addToQueue([s]);
              showToast(messengerCtx, 'Added to queue');
            },
          ),
          SheetAction(
            icon: Icons.playlist_add_rounded,
            label: 'Add to playlist',
            onTap: () {
              close();
              showAddToPlaylist(messengerCtx, [s]);
            },
          ),
          SheetAction(
            icon: s.favourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: s.favourite ? YColors.rose : null,
            label: s.favourite ? 'Remove from favourites' : 'Add to favourites',
            onTap: () {
              close();
              lib.toggleFavourite(s.id);
            },
          ),
          if (playlistId != null && playlistIndex != null)
            SheetAction(
              icon: Icons.playlist_remove_rounded,
              label: 'Remove from this playlist',
              onTap: () {
                close();
                lib.removeFromPlaylist(playlistId, playlistIndex);
              },
            ),
          SheetAction(
            icon: Icons.album_rounded,
            label: 'Go to album',
            onTap: () {
              close();
              openAlbum(messengerCtx, s.albumKey);
            },
          ),
          SheetAction(
            icon: Icons.person_rounded,
            label: 'Go to artist',
            onTap: () {
              close();
              openArtist(messengerCtx, s.displayArtist);
            },
          ),
          SheetAction(
            icon: Icons.edit_rounded,
            label: 'Edit tags',
            onTap: () {
              close();
              showEditTags(messengerCtx, s);
            },
          ),
          SheetAction(
            icon: Icons.delete_outline_rounded,
            label: 'Remove from library',
            color: const Color(0xFFE88A7A),
            onTap: () async {
              close();
              final ok = await confirmDialog(
                messengerCtx,
                'Remove “${s.title}”?',
                'The copy inside ⅄music is deleted. The original file you picked is not touched.',
                'Remove',
              );
              if (ok) {
                await lib.removeSong(s.id);
                if (messengerCtx.mounted) showToast(messengerCtx, 'Removed from library');
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  });
}

// ---------------------------------------------------------------- playlists
Future<void> showAddToPlaylist(BuildContext context, List<Song> songs) {
  final lib = context.read<LibraryStore>();
  final outer = context;
  return showGlassSheet(context, (ctx) {
    final pls = lib.playlists;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 14),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 8),
          child: Text('Add to playlist', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        ),
        SheetAction(
          icon: Icons.add_rounded,
          label: 'New playlist',
          color: YColors.amber,
          onTap: () async {
            Navigator.of(ctx).pop();
            final name = await promptText(outer, 'New playlist', '', hint: 'Playlist name');
            if (name == null) return;
            final id = await lib.createPlaylist(name);
            await lib.addToPlaylist(id, songs.map((s) => s.id).toList());
            if (outer.mounted) showToast(outer, 'Added to “${name.trim().isEmpty ? 'New playlist' : name.trim()}”');
          },
        ),
        for (final p in pls)
          SheetAction(
            icon: Icons.queue_music_rounded,
            label: p.name,
            trailing: Text('${p.songIds.length}', style: const TextStyle(color: YColors.faint)),
            onTap: () async {
              Navigator.of(ctx).pop();
              final n = await lib.addToPlaylist(p.id, songs.map((s) => s.id).toList());
              if (outer.mounted) {
                showToast(outer, n == 0 ? 'Already in “${p.name}”' : 'Added to “${p.name}”');
              }
            },
          ),
      ],
    );
  });
}

// ---------------------------------------------------------------- edit tags
Future<void> showEditTags(BuildContext context, Song song) {
  final lib = context.read<LibraryStore>();
  final title = TextEditingController(text: song.title);
  final artist = TextEditingController(text: song.artist);
  final album = TextEditingController(text: song.album);
  final genre = TextEditingController(text: song.genre);
  final year = TextEditingController(text: song.year?.toString() ?? '');
  final track = TextEditingController(text: song.track?.toString() ?? '');
  return showGlassSheet(context, (ctx) {
    Widget field(String label, TextEditingController c, {TextInputType? type}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: type,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: label),
          ),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Edit tags', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          field('Title', title),
          field('Artist', artist),
          field('Album', album),
          field('Genre', genre),
          Row(
            children: [
              Expanded(child: field('Year', year, type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: field('Track', track, type: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PillButton(label: 'Cancel', primary: false, onTap: () => Navigator.of(ctx).pop()),
              const SizedBox(width: 10),
              PillButton(
                label: 'Save',
                icon: Icons.check_rounded,
                onTap: () {
                  lib.updateTags(
                    song.id,
                    title: title.text,
                    artist: artist.text,
                    album: album.text,
                    genre: genre.text,
                    year: int.tryParse(year.text.trim()),
                    track: int.tryParse(track.text.trim()),
                  );
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  });
}

// ---------------------------------------------------------------- sleep timer
Future<void> showSleepTimer(BuildContext context) {
  final player = context.read<PlayerController>();
  return showGlassSheet(context, (ctx) {
    void set(Duration? d) {
      player.setSleepTimer(d);
      Navigator.of(ctx).pop();
      if (d != null) showToast(context, 'Sleep timer: ${d.inMinutes} min');
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 14),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
          child: Row(
            children: [
              const Icon(Icons.bedtime_rounded, color: YColors.amber),
              const SizedBox(width: 12),
              const Text('Sleep timer', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (player.sleepRemaining != null)
                Text(formatDuration(player.sleepRemaining!), style: const TextStyle(color: YColors.amber)),
            ],
          ),
        ),
        for (final m in const [5, 15, 30, 45, 60, 90])
          SheetAction(icon: Icons.timer_outlined, label: '$m minutes', onTap: () => set(Duration(minutes: m))),
        SheetAction(
          icon: Icons.music_note_rounded,
          label: 'End of current song',
          onTap: () {
            player.setSleepAtEndOfSong();
            Navigator.of(ctx).pop();
            showToast(context, 'Stopping after this song');
          },
        ),
        if (player.sleepActive)
          SheetAction(
            icon: Icons.close_rounded,
            label: 'Turn off timer',
            color: const Color(0xFFE88A7A),
            onTap: () => set(null),
          ),
      ],
    );
  });
}

// ---------------------------------------------------------------- sort & filter
Future<void> showSortSheet(BuildContext context) {
  final lib = context.read<LibraryStore>();
  return showGlassSheet(context, (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 14),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 16, 6),
            child: Row(
              children: [
                const Text('Sort by', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const Spacer(),
                _SegChip(
                  label: 'Asc',
                  icon: Icons.arrow_upward_rounded,
                  selected: lib.ascending,
                  onTap: () => setState(() => lib.setSort(lib.sortField, true)),
                ),
                const SizedBox(width: 8),
                _SegChip(
                  label: 'Desc',
                  icon: Icons.arrow_downward_rounded,
                  selected: !lib.ascending,
                  onTap: () => setState(() => lib.setSort(lib.sortField, false)),
                ),
              ],
            ),
          ),
          for (final f in SortField.values)
            SheetAction(
              icon: lib.sortField == f ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: lib.sortField == f ? YColors.amber : null,
              label: f.label,
              onTap: () => setState(() => lib.setSort(f, lib.ascending)),
            ),
        ],
      );
    });
  });
}

Future<void> showFilterSheet(BuildContext context) {
  final lib = context.read<LibraryStore>();
  return showGlassSheet(context, (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      Widget group(String title, List<Widget> chips) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                child: Text(title.toUpperCase(),
                    style: const TextStyle(color: YColors.faint, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: chips,
                ),
              ),
            ],
          );
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 0),
              child: Row(
                children: [
                  const Text('Filter', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (lib.hasActiveFilter)
                    TextButton(
                      onPressed: () => setState(lib.clearFilters),
                      child: const Text('Clear', style: TextStyle(color: YColors.amber)),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: const Text('Favourites only', style: TextStyle(fontWeight: FontWeight.w600)),
              value: lib.favouritesOnly,
              activeTrackColor: YColors.amber,
              onChanged: (v) => setState(() => lib.setFilters(
                    genre: lib.filterGenre,
                    artist: lib.filterArtist,
                    year: lib.filterYear,
                    favOnly: v,
                  )),
            ),
            if (lib.genres.isNotEmpty)
              group('Genre', [
                for (final g in lib.genres)
                  _SegChip(
                    label: g,
                    selected: lib.filterGenre == g,
                    onTap: () => setState(() => lib.setFilters(
                          genre: lib.filterGenre == g ? null : g,
                          artist: lib.filterArtist,
                          year: lib.filterYear,
                        )),
                  ),
              ]),
            if (lib.artists.isNotEmpty)
              group('Artist', [
                for (final a in lib.artists)
                  _SegChip(
                    label: a.name,
                    selected: lib.filterArtist == a.name,
                    onTap: () => setState(() => lib.setFilters(
                          genre: lib.filterGenre,
                          artist: lib.filterArtist == a.name ? null : a.name,
                          year: lib.filterYear,
                        )),
                  ),
              ]),
            if (lib.years.isNotEmpty)
              group('Year', [
                for (final y in lib.years)
                  _SegChip(
                    label: '$y',
                    selected: lib.filterYear == y,
                    onTap: () => setState(() => lib.setFilters(
                          genre: lib.filterGenre,
                          artist: lib.filterArtist,
                          year: lib.filterYear == y ? null : y,
                        )),
                  ),
              ]),
          ],
        ),
      );
    });
  });
}

class _SegChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _SegChip({required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GlassChip(label: label, icon: icon, selected: selected, onTap: onTap),
    );
  }
}

class GlassChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const GlassChip({super.key, required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? YColors.amber : const Color(0x14FFF1E0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Colors.transparent : const Color(0x22FFF1E0)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: selected ? const Color(0xFF1C120A) : YColors.cream),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: selected ? const Color(0xFF1C120A) : YColors.cream,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- dialogs
Future<String?> promptText(BuildContext context, String title, String initial, {String? hint}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(color: YColors.muted))),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(c.text),
          child: const Text('Save', style: TextStyle(color: YColors.amber, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, String title, String message, String action) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(color: YColors.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: YColors.muted))),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(action, style: const TextStyle(color: Color(0xFFE88A7A), fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return r ?? false;
}
