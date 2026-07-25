import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String updateUrl;
  final String changelog;

  UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.updateUrl,
    required this.changelog,
  });
}

class UpdateService {
  static const int currentVersionCode = 206;
  static const String currentVersionName = '2.0.6';

  // Simple online version URL (Points to raw version.json file)
  static const String rawJsonUrl = 'https://raw.githubusercontent.com/Secretuser129/OFFPAY/main/version.json';
  static const String defaultReleaseUrl = 'https://github.com/Secretuser129/OFFPAY/releases/latest';

  /// Simple 1-step update check
  static Future<void> checkForUpdates(BuildContext context, {bool silent = false}) async {
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking for OFFPAY updates...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    UpdateInfo? info;

    try {
      final res = await http.get(Uri.parse(rawJsonUrl)).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        info = UpdateInfo(
          versionCode: data['versionCode'] ?? 206,
          versionName: data['versionName'] ?? '2.0.6',
          updateUrl: data['downloadUrl'] ?? defaultReleaseUrl,
          changelog: data['changelog'] ?? 'Performance & Bluetooth stability improvements.',
        );
      }
    } catch (e) {
      debugPrint('Simple updater info: $e');
    }

    // Fallback update info matching current version 2.0.6
    info ??= UpdateInfo(
      versionCode: 206,
      versionName: '2.0.6',
      updateUrl: defaultReleaseUrl,
      changelog: '• Initial release of OffPay with BLE P2P transactions.',
    );

    if (info.versionCode > currentVersionCode && context.mounted) {
      _showSimpleDialog(context, info);
    } else if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OFFPAY is up to date! (v$currentVersionName)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Clean, minimal Update Dialog
  static void _showSimpleDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update Available (v${info.versionName})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(info.changelog, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Update Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(info.updateUrl);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                await launchUrl(uri);
              }
            },
          ),
        ],
      ),
    );
  }
}
