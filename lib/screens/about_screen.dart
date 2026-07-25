import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                color: theme.primaryColor.withAlpha((0.1 * 255).round()),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Version 2.1.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
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
            const Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.shield, color: Colors.white),
                ),
                title: Text(
                  'Secretuser129',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Project Lead • Full Stack Developer'),
                trailing: Icon(Icons.verified, color: Colors.indigo),
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
                title: Text(
                  'Secretuser129',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Lead Developer & Architect'),
              ),
            ),
            const Card(
              child: ListTile(
                title: Text(
                  'OFFPAY Contributors',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Testing & Feedback'),
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
    );
  }

  Widget _buildTechChip(String label, IconData icon, ThemeData theme) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: theme.cardTheme.color ?? theme.cardColor,
    );
  }
}
