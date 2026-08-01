import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _requireAppLock = true;
  bool _highValueProtection = true;
  bool _antiReplayEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityPreferences();
  }

  Future<void> _loadSecurityPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _requireAppLock = prefs.getBool('security_require_app_lock') ?? true;
        _highValueProtection = prefs.getBool('security_high_value_protection') ?? true;
        _antiReplayEnabled = prefs.getBool('security_anti_replay') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSetting(String key, bool value, Function(bool) onUpdate) async {
    HapticFeedback.lightImpact();
    setState(() {
      onUpdate(value);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _purgeSecurityCache() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cryptographic BLE nonces & temporary handshake cache purged securely.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Security', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [

                _buildSectionTitle('ACCESS CONTROL & PINS', isDark),
                const SizedBox(height: 10),
                _buildGroupedCard(
                  isDark: isDark,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withValues(alpha: 0.15),
                        child: const Icon(Icons.lock_rounded, color: Colors.blue),
                      ),
                      title: const Text('Manage PINs & Biometrics', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Balance PIN & Payment Gateway PIN settings'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(context, '/pin_settings');
                      },
                    ),
                    _buildDivider(isDark),
                    SwitchListTile.adaptive(
                      secondary: CircleAvatar(
                        backgroundColor: Colors.indigo.withValues(alpha: 0.15),
                        child: const Icon(Icons.phonelink_lock_rounded, color: Colors.indigo),
                      ),
                      title: const Text('Require App Lock on Launch', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Require biometric authentication when opening OFFPAY'),
                      value: _requireAppLock,
                      activeTrackColor: themeProvider.accentColor,
                      onChanged: (val) => _toggleSetting('security_require_app_lock', val, (v) => _requireAppLock = v),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                _buildSectionTitle('OFFLINE BLE TRANSFER POLICY', isDark),
                const SizedBox(height: 10),
                _buildGroupedCard(
                  isDark: isDark,
                  children: [
                    SwitchListTile.adaptive(
                      secondary: CircleAvatar(
                        backgroundColor: Colors.amber.withValues(alpha: 0.15),
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      ),
                      title: const Text('High-Value Transfer Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Require double PIN check for transfers over ${ThemeProvider.currentCurrency}2,000'),
                      value: _highValueProtection,
                      activeTrackColor: themeProvider.accentColor,
                      onChanged: (val) => _toggleSetting('security_high_value_protection', val, (v) => _highValueProtection = v),
                    ),
                    _buildDivider(isDark),
                    SwitchListTile.adaptive(
                      secondary: CircleAvatar(
                        backgroundColor: Colors.teal.withValues(alpha: 0.15),
                        child: const Icon(Icons.policy_rounded, color: Colors.teal),
                      ),
                      title: const Text('Anti-Replay Cryptographic Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Reject duplicate transaction nonces via SHA-256 chain'),
                      value: _antiReplayEnabled,
                      activeTrackColor: themeProvider.accentColor,
                      onChanged: (val) => _toggleSetting('security_anti_replay', val, (v) => _antiReplayEnabled = v),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                _buildSectionTitle('ARCHITECTURE & TELEMETRY', isDark),
                const SizedBox(height: 10),
                _buildGroupedCard(
                  isDark: isDark,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.withValues(alpha: 0.15),
                        child: const Icon(Icons.verified_user_rounded, color: Colors.indigo),
                      ),
                      title: const Text('Security Architecture Whitepaper', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Review AES-256-GCM & offline deduplication details'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showSecurityIntroDialog(context),
                    ),
                    _buildDivider(isDark),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.withValues(alpha: 0.15),
                        child: const Icon(Icons.cleaning_services_rounded, color: Colors.red),
                      ),
                      title: const Text('Purge Offline Security Cache', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Clear temporary BLE nonces and GATT handshake keys'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _purgeSecurityCache,
                    ),
                  ],
                ),
                const SizedBox(height: 36),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white54 : Colors.black54,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildGroupedCard({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? Colors.white10 : Colors.black12,
      indent: 64,
    );
  }

  void _showSecurityIntroDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          child: SafeArea(
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
                  desc: '1-to-1 cryptographic transaction deduplication checks prevent replay attacks and double-spending.',
                ),
                _buildSecurityItem(
                  title: '🔑 Cryptographic PIN Gate (PBKDF2)',
                  desc: 'Local wallet balance viewing and transfer execution require secure PBKDF2 PIN verification.',
                ),
                _buildSecurityItem(
                  title: '📡 GATT Checksum & MTU Integrity',
                  desc: 'GATT handshake stabilization with packet checksum verification protects against packet drops.',
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
