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
  static const int currentVersionCode = 208;
  static const String currentVersionName = '2.0.8';

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

  /// Check GitHub Releases & Pre-releases API (Ignores raw commits)
  static Future<UpdateInfo?> checkRemoteVersion() async {
    try {
      final ghResponse = await http.get(
        Uri.parse('https://api.github.com/repos/Secretuser129/OFFPAY/releases'),
        headers: {
          'User-Agent': 'OffPay-App-Updater/2.0',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 4));

      if (ghResponse.statusCode == 200) {
        final List<dynamic> releases = jsonDecode(ghResponse.body);
        // Strictly filter for published Releases and Pre-releases (ignoring raw commits / drafts)
        final publishedReleases = releases.where((r) => r['draft'] == false).toList();
        if (publishedReleases.isNotEmpty) {
          final Map<String, dynamic> ghData = publishedReleases.first;
          final tag = (ghData['tag_name'] as String? ?? '').replaceAll('v', '');
          final body = ghData['body'] as String? ?? 'New version available on GitHub Releases.';

          int remoteCode = 0;
          final semanticMatch = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(tag);
          if (semanticMatch != null) {
            final major = int.tryParse(semanticMatch.group(1)!) ?? 0;
            final minor = int.tryParse(semanticMatch.group(2)!) ?? 0;
            final patch = int.tryParse(semanticMatch.group(3) ?? '0') ?? 0;
            remoteCode = (major * 100) + (minor * 10) + patch;
          }

          String downloadUrl = defaultReleaseUrl;
          if (ghData['assets'] != null && (ghData['assets'] as List).isNotEmpty) {
            final assets = ghData['assets'] as List;
            try {
              final apkAsset = assets.firstWhere(
                (asset) => (asset['name'] as String? ?? '').endsWith('.apk'),
                orElse: () => assets[0],
              );
              downloadUrl = apkAsset['browser_download_url'] ?? defaultReleaseUrl;
            } catch (_) {
              downloadUrl = assets[0]['browser_download_url'] ?? defaultReleaseUrl;
            }
          }

          return UpdateInfo(
            versionCode: remoteCode > 0 ? remoteCode : currentVersionCode + 1,
            versionName: tag.isEmpty ? '2.0.8' : tag,
            updateUrl: downloadUrl,
            changelog: body,
          );
        }
      }
    } catch (e) {
      debugPrint('GitHub Releases check info: $e');
    }

    // Fallback: Check raw version.json file
    try {
      final res = await http.get(Uri.parse(rawJsonUrl)).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return UpdateInfo(
          versionCode: data['versionCode'] ?? 208,
          versionName: data['versionName'] ?? '2.0.8',
          updateUrl: data['downloadUrl'] ?? defaultReleaseUrl,
          changelog: data['changelog'] ?? 'Performance & Bluetooth stability improvements.',
        );
      }
    } catch (_) {}

    return UpdateInfo(
      versionCode: 208,
      versionName: '2.0.8',
      updateUrl: defaultReleaseUrl,
      changelog: 'Performance & Bluetooth stability improvements.',
    );
  }

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

    final info = await checkRemoteVersion();

    if (info != null && info.versionCode > currentVersionCode && context.mounted) {
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
