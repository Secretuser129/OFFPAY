import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlobalAppleDock extends StatelessWidget {
  final String activeRoute;
  final VoidCallback? onHistoryTap;

  const GlobalAppleDock({
    super.key,
    required this.activeRoute,
    this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(44),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E2C).withValues(alpha: 0.85)
                    : const Color(0xFF14141E).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(44),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDockItem(
                    context: context,
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isSelected: activeRoute == '/home',
                    onTap: () => _navigate(context, '/home'),
                  ),
                  _buildDockItem(
                    context: context,
                    icon: Icons.radar_rounded,
                    label: 'Radar',
                    isSelected: activeRoute == '/discovery',
                    onTap: () => _navigate(context, '/discovery'),
                  ),
                  _buildDockItem(
                    context: context,
                    icon: Icons.devices_rounded,
                    label: 'Trusted',
                    isSelected: activeRoute == '/contacts',
                    onTap: () => _navigate(context, '/contacts'),
                  ),
                  _buildDockItem(
                    context: context,
                    icon: Icons.grid_view_rounded,
                    label: 'Menu',
                    isSelected: false, // Menu opens bottom sheet
                    onTap: () => _showMoreMenuSheet(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    HapticFeedback.lightImpact();
    if (activeRoute == route) return;
    if (route == '/home') {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      return;
    }
    Navigator.pushNamed(context, route);
  }

  Widget _buildDockItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Apple Music style coral red/orange highlight capsule
    const Color activeColor = Color(0xFFFF453A); // Apple iOS Coral/Red accent
    const Color inactiveColor = Colors.white70;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          border: isSelected
              ? Border.all(
                  color: activeColor.withValues(alpha: 0.35),
                  width: 1.0,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreMenuSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E2C).withValues(alpha: 0.95)
                  : const Color(0xFF141420).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag pill
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.apps_rounded, color: Colors.white70, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'OFF-PAY • ALL OPTIONS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.95,
                  children: [
                    _buildSheetItem(
                      context: ctx,
                      icon: Icons.send_rounded,
                      label: 'Send Money',
                      color: const Color(0xFF3B82F6), // Blue
                      route: '/send_options',
                    ),
                    _buildSheetItem(
                      context: ctx,
                      icon: Icons.call_received_rounded,
                      label: 'Receive',
                      color: const Color(0xFF10B981), // Green
                      route: '/receive',
                    ),
                    _buildSheetItem(
                      context: ctx,
                      icon: Icons.qr_code_2_rounded,
                      label: 'QR Code',
                      color: const Color(0xFF8B5CF6), // Purple
                      route: '/custom_qr',
                    ),
                    _buildSheetItem(
                      context: ctx,
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan QR',
                      color: const Color(0xFFF59E0B), // Orange
                      route: '/qr_scanner',
                    ),
                    _buildSheetItem(
                      context: ctx,
                      icon: Icons.security_rounded,
                      label: 'Security',
                      color: const Color(0xFFEF4444), // Red
                      route: '/security_settings',
                    ),
                    _buildSheetItem(
                      context: ctx,
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      color: const Color(0xFF06B6D4), // Cyan
                      route: '/profile',
                    ),
                    _buildSheetItem(
                      context: ctx,
                      icon: Icons.palette_rounded,
                      label: 'Appearance',
                      color: const Color(0xFFEC4899), // Pink
                      route: '/appearance',
                    ),
                    _buildSheetItem(
                      context: ctx,
                      icon: Icons.health_and_safety_rounded,
                      label: 'Diagnostics',
                      color: const Color(0xFFF97316), // Amber
                      route: '/diagnostics',
                    ),
                    _buildSheetItem(
                      context: ctx,
                      icon: Icons.notes_rounded,
                      label: 'Logs',
                      color: const Color(0xFF14B8A6), // Teal
                      route: '/logs',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required String route,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context); // Close bottom sheet
        Navigator.pushNamed(context, route);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
