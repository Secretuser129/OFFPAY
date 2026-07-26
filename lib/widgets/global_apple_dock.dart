import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/wallet_model.dart';
import 'package:intl/intl.dart';

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

            // Left curved divider line for middle History button
            Container(
              height: 28,
              width: 1.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // History button in the middle
            _buildDockItem(
              context: context,
              icon: Icons.history_rounded,
              label: 'History',
              isSelected: activeRoute == '/history',
              isMiddle: true,
              onTap: () {
                HapticFeedback.lightImpact();
                if (onHistoryTap != null) {
                  onHistoryTap!();
                } else {
                  _showHistorySheet(context);
                }
              },
            ),

            // Right curved divider line for middle History button
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
    Navigator.pushNamed(context, route);
  }

  void _showHistorySheet(BuildContext context) {
    final walletModel = Provider.of<WalletModel>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Transaction History (30 Days)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: walletModel.history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No recent transactions',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: walletModel.history.length,
                          itemBuilder: (context, index) {
                            final tx = walletModel.history[index];
                            final formattedTime = DateFormat('MMM d, yyyy • HH:mm').format(tx.timestamp);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: tx.isCredit
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.red.withValues(alpha: 0.15),
                                child: Icon(
                                  tx.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: tx.isCredit ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                tx.isCredit ? 'Received offline' : 'Sent offline',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(formattedTime, style: const TextStyle(fontSize: 12)),
                              trailing: Text(
                                '${tx.isCredit ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tx.isCredit ? Colors.green : Colors.red,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
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
