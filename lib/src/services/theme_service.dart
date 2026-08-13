import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Gère le thème actif et le conserve entre les lancements.
class ThemeService extends ChangeNotifier {
  static const _prefsKey = 'nova_theme_id';

  final SharedPreferences _prefs;
  String _id;

  ThemeService(this._prefs)
      : _id = _prefs.getString(_prefsKey) ?? kThemePalettes.first.id {
    _apply();
  }

  String get id => _id;

  ThemePalette get current => kThemePalettes.firstWhere(
        (p) => p.id == _id,
        orElse: () => kThemePalettes.first,
      );

  List<ThemePalette> get palettes => kThemePalettes;

  Future<void> select(String id) async {
    if (id == _id) return;
    if (!kThemePalettes.any((p) => p.id == id)) return;
    _id = id;
    _apply();
    await _prefs.setString(_prefsKey, id);
    notifyListeners();
  }

  void _apply() => AppColors.apply(current);
}
