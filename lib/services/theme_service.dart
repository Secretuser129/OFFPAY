import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'offpay_theme_mode';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);
      if (savedMode == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedMode == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mode == ThemeMode.dark) {
        await prefs.setString(_themeModeKey, 'dark');
      } else if (mode == ThemeMode.light) {
        await prefs.setString(_themeModeKey, 'light');
      } else {
        await prefs.setString(_themeModeKey, 'system');
      }
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
