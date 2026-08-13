import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';
import '../theme/app_theme.dart';

class ThemeGrid extends StatelessWidget {
  const ThemeGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: theme.palettes
          .map((p) => _ThemeCard(
                palette: p,
                selected: p.id == theme.id,
              ))
          .toList(),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemePalette palette;
  final bool selected;

  const _ThemeCard({required this.palette, required this.selected});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.read<ThemeService>().select(palette.id),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: palette.gradient,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.secondary.withValues(alpha: 0.5),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
              border: Border.all(
                color: selected
                    ? palette.textPrimary
                    : Colors.white.withValues(alpha: 0.15),
                width: selected ? 2.5 : 1,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 28)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            palette.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? palette.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
