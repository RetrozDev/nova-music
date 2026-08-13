import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/theme_grid.dart';
import '../widgets/update_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          'Réglages',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            fontFamily: 'Outfit',
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Personnalise ton app',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        SizedBox(height: 24),
        _SectionTitle(title: 'Thème'),
        SizedBox(height: 4),
        Text(
          'Choisis ton ambiance, ton choix est enregistré.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        SizedBox(height: 12),
        ThemeGrid(),
        SizedBox(height: 28),
        _SectionTitle(title: 'Mise à jour'),
        SizedBox(height: 4),
        UpdateSection(),
        SizedBox(height: 28),
        _SectionTitle(title: 'À propos'),
        SizedBox(height: 12),
        _AboutCard(),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: AppColors.gradient,
            ),
            child: const Icon(Icons.music_note_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nova Music',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'Outfit',
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Recherche, streaming sans pub et téléchargement pour écouter hors-ligne.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
