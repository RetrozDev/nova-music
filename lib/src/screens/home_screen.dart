import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'library_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          SearchScreen(),
          LibraryScreen(),
        ],
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
            destinations: const [
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
            ],
          ),
        ],
      ),
    );
  }
}
