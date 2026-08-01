import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101018) : const Color(0xFFF4F4F8),
      appBar: AppBar(
        title: const Text(
          'Appearance & Glassify',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              const Text(
                'THEME MODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildUntitledThemeSwitcher(context, themeProvider, isDark),

              const SizedBox(height: 28),
              const Text(
                'GLASSMORPHISM & INTENSITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildGlassifyCard(context, themeProvider, isDark),

              const SizedBox(height: 28),
              const Text(
                'TYPOGRAPHY & ACCENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildTypographyAndAccentCard(context, themeProvider, isDark),

              const SizedBox(height: 28),
              const Text(
                'CURRENCY & LOCALIZATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildCurrencySelectorCard(context, themeProvider, isDark),

              const SizedBox(height: 36),
            ],
          );
        },
      ),
    );
  }

  /// Builds the Untitled.png style 3-node connected-circle switcher:
  /// [ Light (sun) ] ••• [ Auto (A) ] ••• [ Dark (moon) ]
  Widget _buildUntitledThemeSwitcher(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    final currentMode = themeProvider.themeMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'App Theme Switcher',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Inspired by OFFPAY badge aesthetic. Tap any node to activate.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Light Node
              _buildThemeNode(
                label: 'Light',
                icon: Icons.wb_sunny_rounded,
                isSelected: currentMode == ThemeMode.light,
                color: Colors.amber,
                onTap: () {
                  HapticFeedback.lightImpact();
                  themeProvider.setThemeMode(ThemeMode.light);
                },
              ),
              // Connector dots
              const Text('••••••', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
              // Auto Node
              _buildThemeNode(
                label: 'Auto',
                icon: Icons.hdr_auto_rounded,
                isSelected: currentMode == ThemeMode.system,
                color: Colors.indigoAccent,
                onTap: () {
                  HapticFeedback.lightImpact();
                  themeProvider.setThemeMode(ThemeMode.system);
                },
              ),
              // Connector dots
              const Text('••••••', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
              // Dark Node
              _buildThemeNode(
                label: 'Dark',
                icon: Icons.nightlight_round,
                isSelected: currentMode == ThemeMode.dark,
                color: Colors.purpleAccent,
                onTap: () {
                  HapticFeedback.lightImpact();
                  themeProvider.setThemeMode(ThemeMode.dark);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeNode({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
              border: Border.all(
                color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 2.5 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassifyCard(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.cyan.withValues(alpha: 0.15),
              child: const Icon(Icons.blur_on_rounded, color: Colors.cyan),
            ),
            title: const Text('Glassify Interface', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Enable frosted glassmorphic styling on navbar & cards'),
            trailing: Switch.adaptive(
              value: themeProvider.glassifyEnabled,
              activeTrackColor: Colors.cyan,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                themeProvider.setGlassifyEnabled(val);
              },
            ),
          ),
          if (themeProvider.glassifyEnabled) ...[
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Glass Intensity',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${(themeProvider.glassifyIntensity * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.cyan,
                      inactiveTrackColor: Colors.grey.withValues(alpha: 0.25),
                      thumbColor: Colors.cyan,
                    ),
                    child: Slider(
                      value: themeProvider.glassifyIntensity,
                      min: 0.2,
                      max: 1.0,
                      onChanged: (val) {
                        themeProvider.setGlassifyIntensity(val);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypographyAndAccentCard(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withValues(alpha: 0.15),
              child: const Icon(Icons.font_download_rounded, color: Colors.blue),
            ),
            title: const Text('Apple San Francisco Font', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              themeProvider.useAppleFont
                  ? 'Active (.SF Pro Display Apple typography)'
                  : 'System default font applied',
            ),
            trailing: Switch.adaptive(
              value: themeProvider.useAppleFont,
              activeTrackColor: Colors.blue,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                themeProvider.setUseAppleFont(val);
              },
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.pinkAccent.withValues(alpha: 0.15),
              child: const Icon(Icons.color_lens_rounded, color: Colors.pinkAccent),
            ),
            title: const Text('Accent Color', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Keep button backgrounds sleek black/white'),
            trailing: Switch.adaptive(
              value: themeProvider.accentColorOnlyForIcons,
              activeTrackColor: Colors.pinkAccent,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                themeProvider.setAccentColorOnlyForIcons(val);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ThemeProvider.accentColorPalette.map((color) {
                final isSelected = themeProvider.accentColor.value == color.value;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeProvider.setAccentColor(color);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySelectorCard(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    final currencies = [
      {'symbol': '₹', 'label': 'INR (₹)'},
      {'symbol': '\$', 'label': 'USD (\$)'},
      {'symbol': '€', 'label': 'EUR (€)'},
      {'symbol': '£', 'label': 'GBP (£)'},
      {'symbol': '¥', 'label': 'JPY (¥)'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Currency Symbol',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Select the currency symbol displayed across balances, payments & receipts. Default is Indian Rupee (₹).',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: currencies.map((curr) {
              final sym = curr['symbol']!;
              final lbl = curr['label']!;
              final isSelected = themeProvider.currencySymbol == sym;
              return ChoiceChip(
                label: Text(lbl),
                selected: isSelected,
                selectedColor: themeProvider.accentColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                onSelected: (selected) {
                  if (selected) {
                    HapticFeedback.lightImpact();
                    themeProvider.setCurrencySymbol(sym);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
