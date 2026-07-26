import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Appearance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section A: Theme Mode
          const Text(
            'Theme Mode',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your preferred visual theme',
            style: TextStyle(
              fontSize: 14,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Card(
                elevation: 0,
                color: theme.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.dividerColor.withAlpha(50),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark
                        ? Colors.purple.withAlpha(38) // 0.15 alpha
                        : Colors.amber.withAlpha(38), // 0.15 alpha
                    child: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: isDark ? Colors.purple.shade300 : Colors.amber.shade800,
                    ),
                  ),
                  title: Text(
                    isDark ? 'Normal Dark Mode' : 'Light Mode',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isDark
                        ? 'Sleek Material dark background (#121212)'
                        : 'Clean, bright interface',
                  ),
                  trailing: Switch.adaptive(
                    value: isDark,
                    activeThumbColor: Colors.indigo,
                    onChanged: (value) {
                      themeProvider.toggleTheme(value);
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Section C: Display Settings
          const Text(
            'Display',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Column(
                children: [
                  Card(
                    elevation: 0,
                    color: theme.cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.dividerColor.withAlpha(50),
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.format_size),
                      title: const Text('Font Size'),
                      subtitle: Text(_getFontSizeLabel(themeProvider.fontSizeScale)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showFontSizeDialog(context, themeProvider),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: theme.cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.dividerColor.withAlpha(50),
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.color_lens),
                      title: const Text('Accent Color'),
                      subtitle: Text(_getColorLabel(themeProvider.accentColor)),
                      trailing: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: themeProvider.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      onTap: () => _showColorPicker(context, themeProvider),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _getFontSizeLabel(double scale) {
    if (scale <= 0.8) return 'Small';
    if (scale >= 1.2) return 'Large';
    return 'Medium (Default)';
  }

  void _showFontSizeDialog(BuildContext context, ThemeProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Font Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ignore: deprecated_member_use
              RadioListTile<double>(
                title: const Text('Small'),
                value: 0.8,
                // ignore: deprecated_member_use
                groupValue: provider.fontSizeScale,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) provider.setFontSizeScale(val);
                  Navigator.pop(context);
                },
              ),
              // ignore: deprecated_member_use
              RadioListTile<double>(
                title: const Text('Medium (Default)'),
                value: 1.0,
                // ignore: deprecated_member_use
                groupValue: provider.fontSizeScale,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) provider.setFontSizeScale(val);
                  Navigator.pop(context);
                },
              ),
              // ignore: deprecated_member_use
              RadioListTile<double>(
                title: const Text('Large'),
                value: 1.2,
                // ignore: deprecated_member_use
                groupValue: provider.fontSizeScale,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) provider.setFontSizeScale(val);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _getColorLabel(Color color) {
    if (color == Colors.indigo) return 'Indigo (Default)';
    if (color == Colors.blue) return 'Blue';
    if (color == Colors.green) return 'Green';
    if (color == Colors.orange) return 'Orange';
    if (color == Colors.purple) return 'Purple';
    if (color == Colors.red) return 'Red';
    return 'Custom';
  }

  void _showColorPicker(BuildContext context, ThemeProvider provider) {
    final colors = [
      Colors.indigo,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Accent Color'),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map((color) {
              return GestureDetector(
                onTap: () {
                  provider.setAccentColor(color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: provider.accentColor == color
                        ? Border.all(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white, width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
