import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'offpay_theme_mode';
const String _fontSizeKey = 'offpay_font_size';
const String _accentColorKey = 'offpay_accent_color';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSizeScale = 1.0;
  Color _accentColor = Colors.indigo;

  ThemeMode get themeMode => _themeMode;
  double get fontSizeScale => _fontSizeScale;
  Color get accentColor => _accentColor;

  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Theme Mode
      final savedMode = prefs.getString(_themeModeKey);
      if (savedMode == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedMode == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }

      // Load Font Size Scale
      _fontSizeScale = prefs.getDouble(_fontSizeKey) ?? 1.0;

      // Load Accent Color
      final colorValue = prefs.getInt(_accentColorKey);
      if (colorValue != null) {
        _accentColor = Color(colorValue);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme settings: $e');
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

  Future<void> setFontSizeScale(double scale) async {
    _fontSizeScale = scale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, scale);
    } catch (e) {
      debugPrint('Error saving font size: $e');
    }
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_accentColorKey, color.value);
    } catch (e) {
      debugPrint('Error saving accent color: $e');
    }
  }
}
