import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'src/screens/home_screen.dart';
import 'src/services/download_service.dart';
import 'src/services/library_service.dart';
import 'src/services/player_service.dart';
import 'src/services/youtube_service.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.novamusic.nova_music.channel.audio',
    androidNotificationChannelName: 'Nova Music',
    androidNotificationChannelDescription:
        'Lecture musicale en arrière-plan',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    androidNotificationClickStartsActivity: true,
  );

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  final youtube = YoutubeService();
  final library = LibraryService();
  await library.init();
  final download = DownloadService(youtube, library);
  final player = PlayerService(youtube, library);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: download),
        ChangeNotifierProvider.value(value: player),
        Provider<YoutubeService>.value(value: youtube),
      ],
      child: const NovaMusicApp(),
    ),
  );
}

class NovaMusicApp extends StatelessWidget {
  const NovaMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova Music',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
