// lib/screens/logs_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    LogService.init();
  }

  Color _getBadgeColor(String category) {
    switch (category) {
      case 'SECURITY':
        return Colors.purple;
      case 'BLE':
        return Colors.blue;
      case 'SUCCESS':
        return Colors.green;
      case 'WARN':
        return Colors.orange;
      case 'ERROR':
        return Colors.red;
      case 'SYSTEM':
      default:
        return Colors.indigo;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'SECURITY':
        return Icons.security;
      case 'BLE':
        return Icons.bluetooth;
      case 'SUCCESS':
        return Icons.check_circle_outline;
      case 'WARN':
        return Icons.warning_amber_rounded;
      case 'ERROR':
        return Icons.error_outline;
      case 'SYSTEM':
      default:
        return Icons.settings_system_daydream;
    }
  }

  void _shareLogs() {
    final report = LogService.exportAsText();
    SharePlus.instance.share(
      ShareParams(
        text: report,
        subject: 'OFFPAY System & Security Log Report',
      ),
    );
  }

  void _copyAllLogs() {
    final report = LogService.exportAsText();
    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All system logs copied to clipboard!'),
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addTestLog() {
    final categories = ['SECURITY', 'BLE', 'SYSTEM', 'SUCCESS'];
    final msgs = [
      'GATT Checksum verified for peer handshake payload',
      'AES-GCM cipher decrypted offline data packet successfully',
      'Zero-Net Defender scanned transaction — 0 replay anomalies',
      'Bluetooth LE peripheral scan sweep completed (0 dBm floor)',
      'PIN Gate cryptographic validation passed',
    ];
    msgs.shuffle();
    categories.shuffle();
    LogService.log(
      msgs.first,
      category: categories.first,
      source: 'ManualDiagnostic',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System & Security Logs'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy All Logs',
            onPressed: _copyAllLogs,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Log Report',
            onPressed: _shareLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear Logs',
            onPressed: () {
              LogService.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All logs cleared.')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Logs'),
                  const SizedBox(width: 8),
                  _buildFilterChip('SECURITY', 'Security & Crypto'),
                  const SizedBox(width: 8),
                  _buildFilterChip('BLE', 'BLE & Network'),
                  const SizedBox(width: 8),
                  _buildFilterChip('SYSTEM', 'System & Core'),
                  const SizedBox(width: 8),
                  _buildFilterChip('SUCCESS', 'Success Events'),
                ],
              ),
            ),
          ),

          // Logs List
          Expanded(
            child: ValueListenableBuilder<List<LogEntry>>(
              valueListenable: LogService.logNotifier,
              builder: (context, logs, child) {
                final filtered = _selectedFilter == 'ALL'
                    ? logs
                    : logs.where((e) => e.category == _selectedFilter).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notes_outlined, size: 64, color: theme.hintColor),
                        const SizedBox(height: 16),
                        Text(
                          'No logs found for this filter.',
                          style: TextStyle(color: theme.hintColor, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final badgeColor = _getBadgeColor(entry.category);
                    final icon = _getCategoryIcon(entry.category);

                    return InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                          text: '[${entry.formattedTime}] [${entry.category}] (${entry.source}): ${entry.message}',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied: "${entry.message}"'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Icon Badge
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, size: 20, color: badgeColor),
                            ),
                            const SizedBox(width: 12),

                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          entry.category,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: badgeColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        entry.formattedTime,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.hintColor,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    entry.message,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Source: ${entry.source}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTestLog,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Test Log Entry'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _selectedFilter == value;
    final badgeColor = _getBadgeColor(value);

    return FilterChip(
      selected: selected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? Colors.white : null,
        ),
      ),
      selectedColor: badgeColor,
      onSelected: (_) {
        setState(() => _selectedFilter = value);
      },
    );
  }
}
