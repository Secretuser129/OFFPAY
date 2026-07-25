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
                    isDark ? 'AMOLED Dark Mode' : 'Light Mode',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isDark
                        ? 'Pure black background • Saves battery on OLED'
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
          
          // Section B: Theme Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withAlpha(15), // 0.06 alpha
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.primaryColor.withAlpha(38), // 0.15 alpha
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette,
                      size: 18,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Current Theme Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isDark
                      ? 'Background: Pure AMOLED Black (#000000)'
                      : 'Background: Clean White (#FFFFFF)',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
                const SizedBox(height: 4),
                Text(
                  isDark
                      ? 'Cards: Dark Surface (#121218)'
                      : 'Cards: White (#FFFFFF)',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accent: Indigo (#3F51B5)',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Section C: Display Settings (Future)
          const Text(
            'Display',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.dividerColor.withAlpha(50),
              ),
            ),
            child: const ListTile(
              leading: Icon(Icons.format_size),
              title: Text('Font Size'),
              subtitle: Text('Medium (Default)'),
              trailing: Icon(Icons.chevron_right),
              onTap: null, // Disabled for now
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
              subtitle: const Text('Indigo (Default)'),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.indigo,
                  shape: BoxShape.circle,
                ),
              ),
              onTap: null, // Disabled for now
            ),
          ),
        ],
      ),
    );
  }
}
