import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/importer.dart';
import '../services/library.dart';
import '../widgets/glass.dart';
import '../widgets/sheets.dart';
import 'album_detail.dart';
import 'artist_detail.dart';
import 'now_playing.dart';
import 'playlist_detail.dart';
import 'queue_screen.dart';

void openAlbum(BuildContext context, String key) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumDetailScreen(albumKey: key)));
}

void openArtist(BuildContext context, String name) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtistDetailScreen(name: name)));
}

void openPlaylist(BuildContext context, int id) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlistId: id)));
}

void openNowPlaying(BuildContext context) {
  HapticFeedback.lightImpact();
  Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => const NowPlayingScreen(),
    transitionsBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  ));
}

void openQueue(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QueueScreen()));
}

/// "Add music" chooser: pick files, or a whole folder.
Future<void> showAddMusic(BuildContext context) {
  return showGlassSheet(context, (ctx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Add music', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Only what you choose is added. Files are copied into ⅄music so they keep working.',
              style: TextStyle(color: Color(0xFFB5A596), fontSize: 13),
            ),
          ),
        ),
        SheetAction(
          icon: Icons.library_music_rounded,
          label: 'Choose files',
          onTap: () {
            Navigator.of(ctx).pop();
            importFiles(context);
          },
        ),
        SheetAction(
          icon: Icons.folder_open_rounded,
          label: 'Choose a folder',
          onTap: () {
            Navigator.of(ctx).pop();
            importFolder(context);
          },
        ),
        const SizedBox(height: 14),
      ],
    );
  });
}

Future<void> importFiles(BuildContext context) async {
  final lib = context.read<LibraryStore>();
  List<PlatformFile> files;
  try {
    files = await FilePicker.pickFiles(
      dialogTitle: 'Choose music',
      type: FileType.audio,
    );
  } catch (e) {
    if (context.mounted) showToast(context, 'Could not open the file picker');
    return;
  }
  if (files.isEmpty) return;
  final summary = await lib.importFiles(files);
  if (context.mounted) showToast(context, summary.message);
}

Future<void> importFolder(BuildContext context) async {
  final lib = context.read<LibraryStore>();
  String? dir;
  try {
    dir = await FilePicker.getDirectoryPath(dialogTitle: 'Choose a music folder');
  } catch (_) {
    dir = null;
  }
  if (dir == null) return;
  // Reading files inside a picked folder needs media read access on Android.
  final statuses = await [Permission.audio, Permission.storage].request();
  final granted = statuses.values.any((s) => s.isGranted || s.isLimited);
  List<String> paths = const [];
  try {
    paths = await lib.importer.listFolder(dir);
  } catch (_) {
    paths = const [];
  }
  if (paths.isEmpty) {
    if (context.mounted) {
      showToast(
        context,
        granted ? 'No audio files found in that folder' : 'Allow music access to import a folder, or choose files instead',
      );
    }
    return;
  }
  final summary = await lib.importPaths(paths);
  if (context.mounted) showToast(context, summary.message);
}

/// Formats e.g. "12 songs".
String songsLabel(int n) => n == 1 ? '1 song' : '$n songs';

bool isAudio(String name) => isAudioName(name);
