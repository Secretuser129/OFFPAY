import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'firebase_service.dart';

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String updateUrl;
  final String changelog;
  final bool forceUpdate;

  UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.updateUrl,
    required this.changelog,
    required this.forceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      versionCode: json['versionCode'] ?? 6,
      versionName: json['versionName'] ?? '2.0.0-alpha+6',
      updateUrl: json['updateUrl'] ?? 'https://github.com',
      changelog: json['changelog'] ?? 'Performance & Android 14 Bluetooth stability enhancements.',
      forceUpdate: json['forceUpdate'] ?? false,
    );
  }
}

class UpdateService {
  static const int currentVersionCode = 13;
  static const String currentVersionName = '2.0.0-alpha+13';

  static const String defaultGithubRepo = 'Secretuser129/OFFPAY';
  static const String defaultGithubUrl = 'https://github.com/Secretuser129/OFFPAY/releases/latest';

  /// Check Firebase Cloud RTDB `/app_version.json` or GitHub Releases API for new updates
  static Future<UpdateInfo?> checkRemoteVersion() async {
    try {
      final firebaseUrl = await FirebaseService.getFirebaseUrl();
      final url = '$firebaseUrl/app_version.json';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.body != 'null') {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return UpdateInfo.fromJson(data);
      }
    } catch (e) {
      debugPrint('Firebase update check error: $e');
    }

    // Fallback: Query GitHub Releases API for Secretuser129/OFFPAY
    try {
      final ghResponse = await http.get(
        Uri.parse('https://api.github.com/repos/$defaultGithubRepo/releases/latest'),
      ).timeout(const Duration(seconds: 4));

      if (ghResponse.statusCode == 200) {
        final Map<String, dynamic> ghData = jsonDecode(ghResponse.body);
        final tag = (ghData['tag_name'] as String? ?? '').replaceAll('v', '');
        final body = ghData['body'] as String? ?? 'New version available on GitHub Releases.';

        // Extract version code from tag (e.g. 2.0.0-alpha+9, v9, 2.0.9 => 9)
        int remoteCode = 0;
        final match = RegExp(r'(\d+)(?=[^\d]*$)').firstMatch(tag);
        if (match != null) {
          remoteCode = int.tryParse(match.group(1)!) ?? 0;
        }

        String downloadUrl = defaultGithubUrl;
        if (ghData['assets'] != null && (ghData['assets'] as List).isNotEmpty) {
          downloadUrl = ghData['assets'][0]['browser_download_url'] ?? defaultGithubUrl;
        }

        return UpdateInfo(
          versionCode: remoteCode > 0 ? remoteCode : currentVersionCode + 1,
          versionName: tag.isEmpty ? '2.0.0-alpha+9' : tag,
          updateUrl: downloadUrl,
          changelog: body,
          forceUpdate: false,
        );
      }
    } catch (e) {
      debugPrint('GitHub API update check error: $e');
    }

    return null;
  }

  /// Trigger In-App Updater dialog check
  static Future<void> checkForUpdates(BuildContext context, {bool silent = false}) async {
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Checking for OFFPAY updates...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final info = await checkRemoteVersion();

    if (info != null && info.versionCode > currentVersionCode) {
      if (context.mounted) {
        showUpdateDialog(context, info);
      }
    } else {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OFFPAY is up to date! (v$currentVersionName)'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Show sleek modern AMOLED In-App Update Dialog
  static void showUpdateDialog(BuildContext context, UpdateInfo info) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardTheme.color,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_alt, color: Colors.indigo, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Update Available!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'v$currentVersionName ➔ v${info.versionName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'What\'s New in this Release:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                info.changelog,
                style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
              ),
            ),
          ],
        ),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Later', style: TextStyle(color: theme.hintColor)),
            ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Update Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(info.updateUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}
