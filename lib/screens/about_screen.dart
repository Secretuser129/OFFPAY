import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/global_apple_dock.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _secretTapCount = 0;

  Future<void> _onSecretTap() async {
    _secretTapCount++;
    if (_secretTapCount >= 3 && _secretTapCount < 10) {
      final remaining = 10 - _secretTapCount;
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tap $remaining more times to unlock Developer Mode...'),
            duration: const Duration(milliseconds: 700),
          ),
        );
      }
    } else if (_secretTapCount == 10) {
      _secretTapCount = 0;
      HapticFeedback.heavyImpact();
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getBool('nfc_developer_enabled') ?? false;
      await prefs.setBool('nfc_developer_enabled', !current);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !current
                  ? '🔓 Developer Mode Unlocked: NFC Contactless Pay Enabled!'
                  : '🔒 Developer Mode Disabled: NFC Toggle Locked',
            ),
            backgroundColor: !current ? Colors.green.shade700 : Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('About OFFPAY'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Logo & Name
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor,
                border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2) : null,
              ),
              child: const Icon(
                Icons.wifi_tethering,
                size: 52,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'OFFPAY',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            Text(
              'Offline Bluetooth Payments',
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isDark ? Colors.white.withValues(alpha: 0.16) : theme.primaryColor.withAlpha((0.1 * 255).round()),
                border: isDark ? Border.all(color: Colors.white24) : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Version 2.2.8 (228)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : theme.primaryColor,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Creator Section
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Created & Owned By',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.16) : Colors.indigo,
                  child: const Icon(Icons.shield, color: Colors.white),
                ),
                title: const Text(
                  'Vedansh Tyagi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Project Lead • Full Stack Developer'),
                trailing: Icon(Icons.verified, color: isDark ? Colors.white : Colors.indigo),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Team Section
            const Text(
              'Development Team',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.code, color: Colors.indigo),
                title: Text(
                  'Vedansh',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Lead Developer & Architect'),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.bug_report_outlined, color: Colors.green),
                title: Text(
                  '1. Ayush   2. Shaurya Prakash',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('OFFPAY Testers & Feedback'),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.campaign_outlined, color: Colors.orange),
                title: Text(
                  'Priyanshu',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Marketing Head'),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.people_outline, color: Colors.purple),
                title: Text(
                  'Mohit',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('HR Head'),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Tech Stack Section
            const Text(
              'Built With',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildTechChip('Flutter', Icons.flutter_dash, theme),
                _buildTechChip('Dart', Icons.code, theme),
                _buildTechChip('Bluetooth LE', Icons.bluetooth, theme),
                _buildTechChip('Firebase RTDB', Icons.cloud, theme),
                _buildTechChip('Hive', Icons.storage, theme),
                _buildTechChip('Provider', Icons.extension, theme),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Copyright Section
            const Divider(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.primaryColor.withAlpha((0.2 * 255).round()),
                ),
                color: theme.primaryColor.withAlpha((0.06 * 255).round()),
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copyright, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '2026 OFFPAY Protocol',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'All Rights Reserved • Original IP by Secretuser129',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // GitHub Link
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://github.com/Secretuser129/OFFPAY');
                  if (!await launchUrl(url)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not launch GitHub link')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.code),
                label: const Text('View on GitHub'),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: const GlobalAppleDock(activeRoute: '/about'),
    );
  }

  Widget _buildTechChip(String label, IconData icon, ThemeData theme) {
    final chip = Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: theme.cardTheme.color ?? theme.cardColor,
    );
    if (label == 'Flutter') {
      return InkWell(
        onTap: _onSecretTap,
        borderRadius: BorderRadius.circular(16),
        child: chip,
      );
    }
    return chip;
  }
}
