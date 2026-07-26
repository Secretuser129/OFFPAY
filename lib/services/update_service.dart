import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
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
  static const int currentVersionCode = 225;
  static const String currentVersionName = '2.2.5';

  // Fallback version.json URL
  static const String rawJsonUrl = 'https://raw.githubusercontent.com/Secretuser129/OFFPAY/main/version.json';
  static const String defaultReleaseUrl = 'https://github.com/Secretuser129/OFFPAY/releases/latest';

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
            versionName: tag.isEmpty ? '2.2.4' : tag,
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
          versionCode: data['versionCode'] ?? 224,
          versionName: data['versionName'] ?? '2.2.4',
          updateUrl: data['downloadUrl'] ?? defaultReleaseUrl,
          changelog: data['changelog'] ?? 'Performance & Bluetooth stability improvements.',
        );
      }
    } catch (_) {}

    return UpdateInfo(
      versionCode: 224,
      versionName: '2.2.4',
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
      _showUpdateDialog(context, info);
    } else if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OFFPAY is up to date! (v$currentVersionName)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Download APK file to device and trigger install
  static Future<void> _downloadAndInstallApk(BuildContext context, UpdateInfo info) async {
    final url = info.updateUrl;
    final isApkUrl = url.toLowerCase().endsWith('.apk');

    // If the URL is not a direct APK link, open in browser as fallback
    if (!isApkUrl) {
      final uri = Uri.parse(url);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await launchUrl(uri);
      }
      return;
    }

    // Show download progress dialog
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('Connecting...');

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.download_rounded, color: Colors.indigo),
              SizedBox(width: 10),
              Text('Downloading Update', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (_, status, __) => Text(
                  status,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (_, progress, __) => Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        minHeight: 8,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progress > 0 ? '${(progress * 100).toStringAsFixed(0)}%' : 'Starting...',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Download APK
      statusNotifier.value = 'Downloading OFFPAY v${info.versionName}...';

      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }

      final dir = await getApplicationSupportDirectory();
      final filePath = '${dir.path}/offpay_update_v${info.versionName}.apk';
      final file = File(filePath);

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          progressNotifier.value = receivedBytes / totalBytes;
        }
      }
      await sink.flush();
      await sink.close();

      statusNotifier.value = 'Download complete! Installing...';
      progressNotifier.value = 1.0;

      // Close the download dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Open/install the APK
      final result = await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');

      if (result.type != ResultType.done && context.mounted) {
        // If open_filex fails, try url_launcher as fallback
        final uri = Uri.file(filePath);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open APK. File saved at: $filePath'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('APK download error: $e');
      // Close download dialog on error
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        // Fallback: open in browser
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download failed. Opening in browser...'),
            backgroundColor: Colors.orange,
          ),
        );
        final uri = Uri.parse(info.updateUrl);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          await launchUrl(uri);
        }
      }
    }
  }

  /// Update dialog with scrollable changelog (no overflow)
  static void _showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.indigo, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Update v${info.versionName}',
                style: const TextStyle(fontSize: 17),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'v$currentVersionName → v${info.versionName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
                const SizedBox(height: 12),
                const Text("What's New:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Text(info.changelog, style: const TextStyle(fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.cleaning_services, size: 14),
                label: const Text('Clear Old', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () async {
                  final count = await clearOldApks();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(count > 0 
                          ? 'Deleted $count old APK file(s). Storage saved!' 
                          : 'No old APKs found.'),
                        backgroundColor: count > 0 ? Colors.green : Colors.grey.shade700,
                      ),
                    );
                  }
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Later'),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Install'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _downloadAndInstallApk(context, info);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Clear old downloaded APK files to free storage
  static Future<int> clearOldApks() async {
    int deletedCount = 0;
    try {
      final dir = await getApplicationSupportDirectory();
      final files = dir.listSync();
      for (final file in files) {
        if (file is File && file.path.contains('offpay_update') && file.path.endsWith('.apk')) {
          await file.delete();
          deletedCount++;
        }
      }
      
      // Also clean up from temporary directory if any exist from before
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync();
      for (final file in tempFiles) {
        if (file is File && file.path.contains('offpay_update') && file.path.endsWith('.apk')) {
          await file.delete();
          deletedCount++;
        }
      }
    } catch (_) {}
    return deletedCount;
  }
}
