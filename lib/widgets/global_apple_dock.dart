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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E2C).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isDark ? Colors.white24 : theme.primaryColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDockItem(
              context: context,
              icon: Icons.send_rounded,
              label: 'Send',
              isSelected: activeRoute == '/send_options',
              onTap: () => _navigate(context, '/send_options'),
            ),
            _buildDockItem(
              context: context,
              icon: Icons.call_received_rounded,
              label: 'Receive',
              isSelected: activeRoute == '/receive',
              onTap: () => _navigate(context, '/receive'),
            ),

            // Left curved divider line for middle Home button
            Container(
              height: 28,
              width: 1.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Home button in the middle
            _buildDockItem(
              context: context,
              icon: Icons.home_rounded,
              label: 'Home',
              isSelected: activeRoute == '/home',
              isMiddle: true,
              onTap: () => _navigate(context, '/home'),
            ),

            // Right curved divider line for middle Home button
            Container(
              height: 28,
              width: 1.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            _buildDockItem(
              context: context,
              icon: Icons.qr_code_2_rounded,
              label: 'QR Code',
              isSelected: activeRoute == '/custom_qr',
              onTap: () => _navigate(context, '/custom_qr'),
            ),
            _buildDockItem(
              context: context,
              icon: Icons.devices_rounded,
              label: 'Trusted',
              isSelected: activeRoute == '/contacts',
              onTap: () => _navigate(context, '/contacts'),
            ),
          ],
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
    bool isMiddle = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Ensure icon and text are always bright and visible in dark mode
    final Color activeColor = isDark ? Colors.white : theme.primaryColor;
    final Color inactiveColor = isDark ? Colors.white70 : Colors.black87;
    final Color textColor = isSelected ? activeColor : inactiveColor;
    final Color iconColor = isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isMiddle ? 14 : 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : theme.primaryColor.withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isMiddle ? 24 : 22,
              color: iconColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
