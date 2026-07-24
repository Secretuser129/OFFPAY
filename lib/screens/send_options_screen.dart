import 'package:flutter/material.dart';

import 'discovery_screen.dart';
import 'qr_scanner_screen.dart';

class SendOptionsScreen extends StatelessWidget {
  const SendOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Choose how to find recipient',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // Option 1: Bluetooth Scan
            _OptionCard(
              icon: Icons.bluetooth_searching,
              title: 'Scan Nearby Devices',
              subtitle: 'Auto-detect Bluetooth devices around you',
              color: Colors.indigo,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiscoveryScreen()),
              ),
            ),

            const SizedBox(height: 20),

            // Option 2: QR Code
            _OptionCard(
              icon: Icons.qr_code_scanner,
              title: 'Scan QR Code',
              subtitle: 'Scan recipient\'s QR code to connect',
              color: Colors.teal,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QRScannerScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                padding: const EdgeInsets.all(14),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}
