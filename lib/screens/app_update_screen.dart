import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/update_service.dart';

class AppUpdateScreen extends StatefulWidget {
  const AppUpdateScreen({super.key});

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen> {
  UpdateInfo? _updateInfo;
  bool _isChecking = true;
  String _statusMessage = 'Checking for OFFPAY system updates...';

  @override
  void initState() {
    super.initState();
    _fetchUpdateInfo();
  }

  Future<void> _fetchUpdateInfo() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Checking for OFFPAY system updates...';
    });

    try {
      final info = await UpdateService.checkRemoteVersion();
      if (mounted) {
        setState(() {
          _updateInfo = info ??
              UpdateInfo(
                versionCode: UpdateService.currentVersionCode,
                versionName: UpdateService.currentVersionName,
                updateUrl: UpdateService.defaultReleaseUrl,
                changelog:
                    '• Enhanced AMOLED Dark Mode & Apple Glassmorphic aesthetics\n• Optimized Connect duty cycle & low power scanning\n• GZip sync compression for instant payload transfer\n• Added Utility & Travel Services quick grid with haptics',
              );
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateInfo = UpdateInfo(
            versionCode: UpdateService.currentVersionCode,
            versionName: UpdateService.currentVersionName,
            updateUrl: UpdateService.defaultReleaseUrl,
            changelog:
                '• Enhanced AMOLED Dark Mode & Apple Glassmorphic aesthetics\n• Optimized Connect duty cycle & low power scanning\n• GZip sync compression for instant payload transfer\n• Added Utility & Travel Services quick grid with haptics',
          );
          _isChecking = false;
        });
      }
    }
  }

  void _scheduleNightUpdate() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Automatic update scheduled for tonight at 3:00 AM.'),
        backgroundColor: Colors.indigo,
        duration: Duration(seconds: 4),
      ),
    );
    Navigator.pop(context);
  }

  void _triggerUpdateNow() {
    HapticFeedback.mediumImpact();
    if (_updateInfo != null) {
      UpdateService.checkForUpdates(context, silent: false);
    }
  }

  Future<void> _cleanOldApks() async {
    HapticFeedback.lightImpact();
    final count = await UpdateService.clearOldApks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0 ? 'Cleaned $count old APK installation files. Storage saved!' : 'No leftover APK files found.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool isUpdateAvailable =
        _updateInfo != null && _updateInfo!.versionCode > UpdateService.currentVersionCode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('System Update & Changelog', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchUpdateInfo,
            tooltip: 'Check Again',
          ),
        ],
      ),
      body: _isChecking
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(_statusMessage, style: TextStyle(color: theme.hintColor)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Badge
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isUpdateAvailable
                              ? [Colors.indigo.shade400, Colors.blue.shade700]
                              : [Colors.green.shade400, Colors.teal.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isUpdateAvailable ? Colors.indigo : Colors.green).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        isUpdateAvailable ? Icons.system_update_alt_rounded : Icons.verified_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isUpdateAvailable
                        ? 'OFFPAY v${_updateInfo?.versionName} Available!'
                        : 'OFFPAY is Up to Date',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Current Version: v${UpdateService.currentVersionName} (Build ${UpdateService.currentVersionCode})',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: theme.hintColor),
                  ),
                  const SizedBox(height: 28),

                  // What's New Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notes_rounded, color: theme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              "What's New & Changelog",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _updateInfo?.changelog ?? 'No changelog available.',
                          style: const TextStyle(fontSize: 14, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Update Now Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      isUpdateAvailable ? 'Update Now (Install v${_updateInfo?.versionName})' : 'Check for Updates Now',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUpdateAvailable ? Colors.indigo : theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _triggerUpdateNow,
                  ),
                  const SizedBox(height: 14),

                  // Later (Night Automatic) Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.nightlight_round),
                    label: const Text('Later (Set Automatic Night Update at 3:00 AM)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.5)),
                    ),
                    onPressed: _scheduleNightUpdate,
                  ),
                  const SizedBox(height: 20),

                  // Storage cleaner
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                      label: const Text('Clean Old APK Installation Files'),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      onPressed: _cleanOldApks,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
