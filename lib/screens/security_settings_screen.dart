import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../services/profile_service.dart';
import '../models/wallet_model.dart';
import 'package:provider/provider.dart';
import '../widgets/global_apple_dock.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings Hub'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'General',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.primaryColor),
          ),
          const SizedBox(height: 8),
          
          _buildSettingsCard(
            context: context,
            icon: Icons.palette_outlined,
            title: 'App Appearance',
            subtitle: 'Dark Mode & Visuals',
            onTap: () => Navigator.pushNamed(context, '/appearance'),
          ),

          _buildSettingsCard(
            context: context,
            icon: Icons.verified_user_outlined,
            title: 'App Security Architecture',
            subtitle: 'How OFFPAY protects offline transfers & data',
            onTap: () => _showSecurityIntroDialog(context),
          ),
          
          _buildSettingsCard(
            context: context,
            icon: Icons.security_outlined,
            title: 'Custom PIN Security',
            subtitle: 'Balance & Transfer Protection',
            onTap: () => Navigator.pushNamed(context, '/pin_settings'),
          ),

          const SizedBox(height: 24),
          Text(
            'About & Updates',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.primaryColor),
          ),
          const SizedBox(height: 8),

          _buildSettingsCard(
            context: context,
            icon: Icons.system_update_outlined,
            title: 'Check for Updates',
            subtitle: 'Version 2.2.7 (227)',
            onTap: () => UpdateService.checkForUpdates(context, silent: false),
          ),

          _buildSettingsCard(
            context: context,
            icon: Icons.info_outline,
            title: 'About OFFPAY',
            subtitle: 'Creator, Version & Licensing',
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout Securely', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await ProfileService.setLoggedIn(false);
                if (context.mounted) {
                  final wallet = Provider.of<WalletModel>(context, listen: false);
                  await wallet.clearWallet();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const GlobalAppleDock(activeRoute: '/security_settings'),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : theme.primaryColor;
    final circleBg = isDark ? Colors.white.withValues(alpha: 0.16) : theme.primaryColor.withValues(alpha: 0.12);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.15) : theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.35) : theme.primaryColor.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : theme.hintColor)),
        trailing: Icon(Icons.chevron_right, color: iconColor),
        onTap: onTap,
      ),
    );
  }

  void _showSecurityIntroDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.indigo.shade400, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'OFFPAY Security Architecture',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'OFFPAY uses a multi-layered offline & online cryptographic defense system:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 18),
              _buildSecurityItem(
                title: '🔐 AES-GCM-256 Offline BLE Encryption',
                desc: 'All peer-to-peer Bluetooth LE packets are encrypted before transmission. Implemented in OffpayBluetoothService payload layer.',
              ),
              _buildSecurityItem(
                title: '🛡️ Zero-Net Defender Verification',
                desc: '1-to-1 cryptographic transaction deduplication checks prevent replay attacks and double-spending. Implemented in RewardService & Hive transaction engine.',
              ),
              _buildSecurityItem(
                title: '🔑 Cryptographic PIN Gate (PBKDF2)',
                desc: 'Local wallet balance viewing and transfer execution require secure PBKDF2 PIN verification. Implemented in PinSettingsScreen & WalletModel.',
              ),
              _buildSecurityItem(
                title: '📡 GATT Checksum & MTU Integrity',
                desc: 'GATT handshake stabilization with packet checksum verification protects against GATT_ERROR 133 and corrupted packets.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got It, Secure App!', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecurityItem({required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}
