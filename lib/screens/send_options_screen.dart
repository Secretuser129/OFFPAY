import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;

import 'discovery_screen.dart';
import 'payment_input_screen.dart';
import 'qr_scanner_screen.dart';

class SendOptionsScreen extends StatelessWidget {
  const SendOptionsScreen({super.key});

  void _showEnterDeviceIdDialog(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Enter Device ID'),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'e.g. AA:BB:CC:DD:EE:FF',
              labelText: 'Recipient Device ID / MAC',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.bluetooth),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a device ID.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final id = controller.text.trim();
                Navigator.pop(ctx);
                // Create a device handle using the entered remote ID
                final device = fb.BluetoothDevice(remoteId: fb.DeviceIdentifier(id));
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PaymentInputScreen(),
                    settings: RouteSettings(arguments: device),
                  ),
                );
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
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

            const SizedBox(height: 16),

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

            const SizedBox(height: 16),

            // Option 3: Enter Device ID manually
            _OptionCard(
              icon: Icons.keyboard,
              title: 'Enter Device ID',
              subtitle: 'Type the recipient\'s device ID or MAC address',
              color: Colors.deepOrange,
              onTap: () => _showEnterDeviceIdDialog(context),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
