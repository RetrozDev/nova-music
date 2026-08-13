import 'package:flutter/material.dart';

/// Palette de couleurs complète d'un thème.
class ThemePalette {
  final String id;
  final String label;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color secondary;
  final Color textPrimary;
  final Color textSecondary;

  const ThemePalette({
    required this.id,
    required this.label,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, secondary],
      );

  LinearGradient get gradientSoft => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, secondary.withValues(alpha: 0.9)],
      );
}

/// Tous les thèmes disponibles.
const kThemePalettes = <ThemePalette>[
  ThemePalette(
    id: 'nova',
    label: 'Nova',
    background: Color(0xFF0B0817),
    surface: Color(0xFF161226),
    surfaceAlt: Color(0xFF1E1833),
    primary: Color(0xFF8B5CF6),
    secondary: Color(0xFFEC4899),
    textPrimary: Color(0xFFF5F3FF),
    textSecondary: Color(0xFFA59EC4),
  ),
  ThemePalette(
    id: 'ocean',
    label: 'Océan',
    background: Color(0xFF081020),
    surface: Color(0xFF111B31),
    surfaceAlt: Color(0xFF182844),
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFF22D3EE),
    textPrimary: Color(0xFFEAF4FF),
    textSecondary: Color(0xFF9FB6D8),
  ),
  ThemePalette(
    id: 'emerald',
    label: 'Émeraude',
    background: Color(0xFF071410),
    surface: Color(0xFF0F201A),
    surfaceAlt: Color(0xFF173029),
    primary: Color(0xFF10B981),
    secondary: Color(0xFF34D399),
    textPrimary: Color(0xFFECFDF5),
    textSecondary: Color(0xFF9CC9B8),
  ),
  ThemePalette(
    id: 'fire',
    label: 'Feu',
    background: Color(0xFF1A0E06),
    surface: Color(0xFF26160C),
    surfaceAlt: Color(0xFF33200F),
    primary: Color(0xFFF97316),
    secondary: Color(0xFFEF4444),
    textPrimary: Color(0xFFFFF7ED),
    textSecondary: Color(0xFFD9B8A0),
  ),
  ThemePalette(
    id: 'neon',
    label: 'Néon',
    background: Color(0xFF0A1016),
    surface: Color(0xFF142029),
    surfaceAlt: Color(0xFF1D2B36),
    primary: Color(0xFF22D3EE),
    secondary: Color(0xFFE879F9),
    textPrimary: Color(0xFFECFEFF),
    textSecondary: Color(0xFF9FC7D0),
  ),
  ThemePalette(
    id: 'night',
    label: 'Nuit',
    background: Color(0xFF0C0A1E),
    surface: Color(0xFF151331),
    surfaceAlt: Color(0xFF1E1B44),
    primary: Color(0xFF6366F1),
    secondary: Color(0xFFA78BFA),
    textPrimary: Color(0xFFEEF2FF),
    textSecondary: Color(0xFFA7A3CE),
  ),
  ThemePalette(
    id: 'amber',
    label: 'Ambre',
    background: Color(0xFF171005),
    surface: Color(0xFF241A0B),
    surfaceAlt: Color(0xFF302415),
    primary: Color(0xFFF59E0B),
    secondary: Color(0xFFFB923C),
    textPrimary: Color(0xFFFFFBEB),
    textSecondary: Color(0xFFD4C4A8),
  ),
];

/// Couleurs actives de l'application (rechargées à chaque changement de thème).
class AppColors {
  static Color background = kThemePalettes.first.background;
  static Color surface = kThemePalettes.first.surface;
  static Color surfaceAlt = kThemePalettes.first.surfaceAlt;
  static Color primary = kThemePalettes.first.primary;
  static Color secondary = kThemePalettes.first.secondary;
  static Color textPrimary = kThemePalettes.first.textPrimary;
  static Color textSecondary = kThemePalettes.first.textSecondary;
  static LinearGradient gradient = kThemePalettes.first.gradient;
  static LinearGradient gradientSoft = kThemePalettes.first.gradientSoft;

  static void apply(ThemePalette palette) {
    background = palette.background;
    surface = palette.surface;
    surfaceAlt = palette.surfaceAlt;
    primary = palette.primary;
    secondary = palette.secondary;
    textPrimary = palette.textPrimary;
    textSecondary = palette.textSecondary;
    gradient = palette.gradient;
    gradientSoft = palette.gradientSoft;
  }
}

class AppTheme {
  static ThemeData build(ThemePalette palette) {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: Brightness.dark,
        surface: palette.surface,
      ),
      splashFactory: InkRipple.splashFactory,
      textTheme: base.textTheme.apply(
        fontFamily: 'Outfit',
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceAlt,
        contentTextStyle:
            const TextStyle(fontFamily: 'Outfit', color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: Color(0x1FFFFFFF)),
    );
  }
}
