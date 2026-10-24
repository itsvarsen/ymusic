import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'data/db.dart';
import 'screens/shell.dart';
import 'services/importer.dart';
import 'services/library.dart';
import 'services/player.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'tech.varsen.ymusic.playback',
    androidNotificationChannelName: '⅄music playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    androidNotificationIcon: 'drawable/ic_stat_ymusic',
    notificationColor: YColors.amber,
    preloadArtwork: true,
    artDownscaleWidth: 512,
    artDownscaleHeight: 512,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final db = await AppDb.open();
  final importer = Importer(db);
  await importer.init();
  final library = LibraryStore(db, importer);
  await library.load();
  final player = PlayerController(library, db);
  await player.init();

  runApp(YMusicApp(library: library, player: player));
}

class YMusicApp extends StatefulWidget {
  final LibraryStore library;
  final PlayerController player;
  const YMusicApp({super.key, required this.library, required this.player});

  @override
  State<YMusicApp> createState() => _YMusicAppState();
}

class _YMusicAppState extends State<YMusicApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Android 13+: ask once for notification permission (media controls).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final st = await Permission.notification.status;
        if (st.isDenied) await Permission.notification.request();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(widget.player.saveNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LibraryStore>.value(value: widget.library),
        ChangeNotifierProvider<PlayerController>.value(value: widget.player),
      ],
      child: MaterialApp(
        title: '⅄music',
        debugShowCheckedModeBanner: false,
        theme: YTheme.build(),
        darkTheme: YTheme.build(),
        themeMode: ThemeMode.dark,
        home: const Shell(),
      ),
    );
  }
}
