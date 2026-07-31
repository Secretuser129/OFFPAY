import 'package:flutter/material.dart';

import '../services/nfc_service.dart';
import 'discovery_screen.dart';
import 'qr_scanner_screen.dart';
import 'nfc_tap_screen.dart';
import '../widgets/global_apple_dock.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SendOptionsScreen extends StatefulWidget {
  const SendOptionsScreen({super.key});

  @override
  State<SendOptionsScreen> createState() => _SendOptionsScreenState();
}

class _SendOptionsScreenState extends State<SendOptionsScreen> {
  bool _nfcUnlocked = false;

  @override
  void initState() {
    super.initState();
    _checkNfcUnlocked();
  }

  Future<void> _checkNfcUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('nfc_developer_enabled') ?? false;
    if (mounted) {
      setState(() {
        _nfcUnlocked = enabled;
      });
    }
  }

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
              'Choose how to connect & pay offline',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),

            // Option 1: NFC Contactless Tap (HIDDEN UNLESS 10 TAPS DEVELOPER MODE UNLOCKED)
            if (_nfcUnlocked) ...[
              _OptionCard(
                icon: Icons.contactless,
                title: 'NFC Contactless Tap',
                subtitle: 'Touch phones back-to-back (<100ms transfer)',
                color: Colors.cyan.shade700,
                onTap: () async {
                  final supported = await NfcService.isNfcSupported();
                  if (!supported && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '🔒 NFC Contactless is locked or unsupported on this device.',
                        ),
                        backgroundColor: Colors.red.shade700,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NfcTapScreen()),
                    );
                  }
                },
              ),
              const SizedBox(height: 18),
            ],

            // Option 2: Bluetooth Scan
            _OptionCard(
              icon: Icons.bluetooth_searching,
              title: 'Scan Nearby Devices',
              subtitle: 'Auto-detect Bluetooth devices around you',
              color: Colors.indigo,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiscoveryScreen()),
              ),
            ),

            const SizedBox(height: 18),

            // Option 3: QR Code
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
      // bottomNavigationBar removed for clean full-screen view
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
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
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
