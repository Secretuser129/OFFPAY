import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/global_apple_dock.dart';

class OtherOptionsScreen extends StatelessWidget {
  const OtherOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101018) : const Color(0xFFF4F4F8),
      appBar: AppBar(
        title: const Text(
          'Menu',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              label: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUICK TRANSACTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.45,
              children: [
                _buildQuickCard(
                  context: context,
                  title: 'Send Money',
                  subtitle: 'BLE or Server Relay',
                  icon: Icons.send_rounded,
                  color: const Color(0xFF3B82F6), // Blue
                  route: '/send_options',
                  isDark: isDark,
                ),
                _buildQuickCard(
                  context: context,
                  title: 'Receive Money',
                  subtitle: 'Generate Request',
                  icon: Icons.call_received_rounded,
                  color: const Color(0xFF10B981), // Green
                  route: '/receive',
                  isDark: isDark,
                ),
                _buildQuickCard(
                  context: context,
                  title: 'My QR',
                  subtitle: 'Offline Payment QR',
                  icon: Icons.qr_code_2_rounded,
                  color: const Color(0xFF8B5CF6), // Purple
                  route: '/custom_qr',
                  isDark: isDark,
                ),
                _buildQuickCard(
                  context: context,
                  title: 'Scan QR Code',
                  subtitle: 'Camera Scanner',
                  icon: Icons.qr_code_scanner_rounded,
                  color: const Color(0xFFF59E0B), // Orange
                  route: '/qr_scanner',
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 28),
            Text(
              'REWARDS, SETTINGS & ACCOUNT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildGroupedSection(
              isDark: isDark,
              children: [
                _buildListItem(
                  context: context,
                  icon: Icons.card_giftcard_rounded,
                  iconColor: const Color(0xFFF59E0B), // Amber gold
                  title: 'My Rewards',
                  subtitle: 'Cashback coupons & collectible roles',
                  route: '/rewards',
                ),
                _buildDivider(isDark),
                _buildListItem(
                  context: context,
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFF06B6D4),
                  title: 'Profile & Account',
                  subtitle: 'Manage identity and balances',
                  route: '/profile',
                ),
                _buildDivider(isDark),
                _buildListItem(
                  context: context,
                  icon: Icons.settings_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Settings, Security & Diagnostics',
                  subtitle: 'Manage theme, PIN, audit logs & system update',
                  route: '/settings',
                ),
                _buildDivider(isDark),
                _buildListItem(
                  context: context,
                  icon: Icons.dashboard_customize_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Customize Navbar',
                  subtitle: 'Change docked items and layout',
                  onTap: () => _showCustomizeNavbarDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, route);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E2C).withValues(alpha: 0.85)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedSection({
    required bool isDark,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E2C).withValues(alpha: 0.85)
              : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildListItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? route,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap();
        } else if (route != null) {
          Navigator.pushNamed(context, route);
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
    );
  }

  void _showCustomizeNavbarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final themeProvider = Provider.of<ThemeProvider>(ctx);
          final order = List<String>.from(themeProvider.navbarOrder);
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          String nameForRoute(String r) {
            switch (r) {
              case '/home':
                return 'Home';
              case '/discovery':
                return 'Connect';
              case '/contacts':
                return 'Trusted';
              case '/other_options':
              default:
                return 'Menu';
            }
          }

          IconData iconForRoute(String r) {
            switch (r) {
              case '/home':
                return Icons.home_rounded;
              case '/discovery':
                return Icons.radar_rounded;
              case '/contacts':
                return Icons.devices_rounded;
              case '/other_options':
              default:
                return Icons.grid_view_rounded;
            }
          }

          void moveItem(int oldIndex, int newIndex) {
            if (newIndex < 0 || newIndex >= order.length) return;
            HapticFeedback.lightImpact();
            final item = order.removeAt(oldIndex);
            order.insert(newIndex, item);
            themeProvider.setNavbarOrder(order);
            setDialogState(() {});
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
            title: const Row(
              children: [
                Icon(Icons.dashboard_customize_rounded, color: Colors.indigoAccent),
                SizedBox(width: 10),
                Text('Customize Navbar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reorder tiles using arrows. Notice the Live Preview below updates instantly!',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.length,
                    itemBuilder: (ctx, i) {
                      final route = order[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(iconForRoute(route), color: Colors.indigoAccent),
                          title: Text(nameForRoute(route), style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                                onPressed: i > 0 ? () => moveItem(i, i - 1) : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                                onPressed: i < order.length - 1 ? () => moveItem(i, i + 1) : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('LIVE PREVIEW:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: GlobalAppleDock(activeRoute: '/home'),
                    ),
                  ),
                ],
              ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
