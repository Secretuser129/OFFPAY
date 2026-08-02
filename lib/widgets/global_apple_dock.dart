import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final order = themeProvider.navbarOrder;

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
                children: order.map((r) => _buildItemForRoute(context, r)).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemForRoute(BuildContext context, String route) {
    switch (route) {
      case '/home':
        return _buildDockItem(
          context: context,
          icon: Icons.home_rounded,
          label: 'Home',
          isSelected: activeRoute == '/home',
          onTap: () => _navigate(context, '/home'),
        );
      case '/discovery':
        return _buildDockItem(
          context: context,
          icon: Icons.radar_rounded,
          label: 'Connect',
          isSelected: activeRoute == '/discovery',
          onTap: () => _navigate(context, '/discovery'),
        );
      case '/contacts':
        return _buildDockItem(
          context: context,
          icon: Icons.devices_rounded,
          label: 'Trusted',
          isSelected: activeRoute == '/contacts',
          onTap: () => _navigate(context, '/contacts'),
        );
      case '/other_options':
      default:
        return _buildDockItem(
          context: context,
          icon: Icons.grid_view_rounded,
          label: 'Menu',
          isSelected: activeRoute == '/other_options',
          onTap: () => _navigate(context, '/other_options'),
        );
    }
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
    final Color activeColor = Provider.of<ThemeProvider>(context).accentColor;
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
}
