import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // PROFILE / HEADER BRIEF
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OFFPAY Settings Engine',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage security policy, AMOLED themes & diagnostics',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            _buildSectionTitle('SECURITY', isDark),
            const SizedBox(height: 10),
            _buildGroupedSection(
              isDark: isDark,
              children: [
                _buildListItem(
                  context: context,
                  icon: Icons.security_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Security Settings',
                  subtitle: 'OFFPAY Policy, encryption & hardware security',
                  route: '/security_settings',
                ),

              ],
            ),

            const SizedBox(height: 28),
            _buildSectionTitle('APPEARANCE & INTERFACE', isDark),
            const SizedBox(height: 10),
            _buildGroupedSection(
              isDark: isDark,
              children: [
                _buildListItem(
                  context: context,
                  icon: Icons.palette_rounded,
                  iconColor: const Color(0xFFEC4899),
                  title: 'Appearance & Themes',
                  subtitle: 'AMOLED dark mode, Apple typography & colors',
                  route: '/appearance',
                ),
                _buildDivider(isDark),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.view_carousel_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Customize Navbar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Rearrange & organize bottom dock icons',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showCustomizeNavbarDialog(context);
                  },
                ),
              ],
            ),

            const SizedBox(height: 28),
            _buildSectionTitle('SYSTEM & DIAGNOSTICS', isDark),
            const SizedBox(height: 10),
            _buildGroupedSection(
              isDark: isDark,
              children: [
                _buildListItem(
                  context: context,
                  icon: Icons.system_update_rounded,
                  iconColor: const Color(0xFF6366F1),
                  title: 'System Update & Changelog',
                  subtitle: 'Check new releases & schedule updates',
                  route: '/app_update',
                ),
                _buildDivider(isDark),
                _buildListItem(
                  context: context,
                  icon: Icons.health_and_safety_rounded,
                  iconColor: const Color(0xFFF97316),
                  title: 'System Diagnostics',
                  subtitle: 'Hash chain, ledger & GZip compression audit',
                  route: '/diagnostics',
                ),
                _buildDivider(isDark),
                _buildListItem(
                  context: context,
                  icon: Icons.notes_rounded,
                  iconColor: const Color(0xFF14B8A6),
                  title: 'Security Logs',
                  subtitle: 'Real-time cryptographic audit trail',
                  route: '/logs',
                ),
                _buildDivider(isDark),
                _buildListItem(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF9CA3AF),
                  title: 'About OFFPAY v4.1.0 (Build 410)',
                  subtitle: 'Credits, version info & developer mode',
                  route: '/about',
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
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

  Widget _buildGroupedSection({
    required bool isDark,
    required List<Widget> children,
  }) {
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
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildListItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String route,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, route);
      },
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
                Icon(Icons.view_carousel_rounded, color: Colors.indigoAccent),
                SizedBox(width: 10),
                Text('Customize Navbar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reorder dock icons using arrows. Updates live instantly!',
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
                ],
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
