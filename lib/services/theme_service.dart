import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'offpay_theme_mode';
const String _fontSizeKey = 'offpay_font_size';
const String _accentColorKey = 'offpay_accent_color';
const String _useAppleFontKey = 'offpay_use_apple_font';
const String _glassifyKey = 'offpay_glassify_enabled';
const String _glassifyIntensityKey = 'offpay_glassify_intensity';
const String _accentIconsOnlyKey = 'offpay_accent_icons_only';
const String _navbarOrderKey = 'offpay_navbar_order';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  double _fontSizeScale = 1.0;
  Color _accentColor = Colors.indigo;
  bool _useAppleFont = true;
  bool _glassifyEnabled = true;
  double _glassifyIntensity = 0.8;
  bool _accentColorOnlyForIcons = false;
  List<String> _navbarOrder = ['/home', '/discovery', '/contacts', '/other_options'];

  ThemeMode get themeMode => _themeMode;
  double get fontSizeScale => _fontSizeScale;
  Color get accentColor => _accentColor;
  bool get useAppleFont => _useAppleFont;
  bool get glassifyEnabled => _glassifyEnabled;
  double get glassifyIntensity => _glassifyIntensity;
  bool get accentColorOnlyForIcons => _accentColorOnlyForIcons;
  List<String> get navbarOrder => _navbarOrder;

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
        _themeMode = ThemeMode.dark;
      }

      // Load Font Size Scale
      _fontSizeScale = prefs.getDouble(_fontSizeKey) ?? 1.0;

      // Load Apple Font toggle
      _useAppleFont = prefs.getBool(_useAppleFontKey) ?? true;

      // Load Accent Color
      final colorValue = prefs.getInt(_accentColorKey);
      if (colorValue != null) {
        _accentColor = Color(colorValue);
      }

      _glassifyEnabled = prefs.getBool(_glassifyKey) ?? true;
      _glassifyIntensity = prefs.getDouble(_glassifyIntensityKey) ?? 0.8;
      _accentColorOnlyForIcons = prefs.getBool(_accentIconsOnlyKey) ?? false;
      final savedOrder = prefs.getStringList(_navbarOrderKey);
      if (savedOrder != null && savedOrder.length == 4) {
        _navbarOrder = savedOrder;
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
      await prefs.setInt(_accentColorKey, color.toARGB32());
    } catch (e) {
      debugPrint('Error saving accent color: $e');
    }
  }

  Future<void> setUseAppleFont(bool useApple) async {
    _useAppleFont = useApple;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useAppleFontKey, useApple);
    } catch (e) {
      debugPrint('Error saving apple font preference: $e');
    }
  }

  Future<void> setGlassifyEnabled(bool enabled) async {
    _glassifyEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_glassifyKey, enabled);
    } catch (e) {
      debugPrint('Error saving glassifyEnabled: $e');
    }
  }

  Future<void> setGlassifyIntensity(double intensity) async {
    _glassifyIntensity = intensity;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_glassifyIntensityKey, intensity);
    } catch (e) {
      debugPrint('Error saving glassifyIntensity: $e');
    }
  }

  Future<void> setAccentColorOnlyForIcons(bool onlyForIcons) async {
    _accentColorOnlyForIcons = onlyForIcons;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_accentIconsOnlyKey, onlyForIcons);
    } catch (e) {
      debugPrint('Error saving accentColorOnlyForIcons: $e');
    }
  }

  Future<void> setNavbarOrder(List<String> order) async {
    if (order.length == 4) {
      _navbarOrder = order;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_navbarOrderKey, order);
      } catch (e) {
        debugPrint('Error saving navbar order: $e');
      }
    }
  }
}
