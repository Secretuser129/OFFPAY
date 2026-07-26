import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../services/profile_service.dart';
import '../models/wallet_model.dart';
import 'package:provider/provider.dart';

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
            subtitle: 'Version 2.2.2 pre release 222',
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
    final circleBg = isDark ? theme.primaryColor.withValues(alpha: 0.35) : theme.primaryColor.withValues(alpha: 0.12);

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
            border: Border.all(color: isDark ? Colors.white24 : theme.primaryColor.withValues(alpha: 0.3)),
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
}
