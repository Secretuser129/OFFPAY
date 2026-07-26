import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/global_apple_dock.dart';

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
        ],
      ),
      bottomNavigationBar: const GlobalAppleDock(activeRoute: '/appearance'),
    );
  }
}
