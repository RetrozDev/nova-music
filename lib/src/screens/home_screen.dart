import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../services/theme_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/update_flow.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(autoCheckForUpdate(context, context.read<UpdateService>()));
      _listenPlayerErrors();
    });
  }

  void _listenPlayerErrors() {
    final player = context.read<PlayerService>();
    player.errorStream.listen((message) {
      if (!mounted) return;
      final track = player.current;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            track == null
                ? 'Lecture impossible : $message'
                : '« ${track.title} » : lecture impossible ($message). '
                    'Vérifie ta connexion.',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    return Scaffold(
      body: KeyedSubtree(
        key: ValueKey(theme.id),
        child: IndexedStack(
          index: _index,
          children: const [
            SearchScreen(),
            LibraryScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.35),
            height: 66,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                selectedIcon: Icon(Icons.search_rounded, color: AppColors.secondary),
                label: 'Recherche',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_rounded, color: AppColors.textSecondary),
                selectedIcon:
                    Icon(Icons.library_music_rounded, color: AppColors.secondary),
                label: 'Bibliothèque',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                selectedIcon:
                    Icon(Icons.settings_rounded, color: AppColors.secondary),
                label: 'Réglages',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
