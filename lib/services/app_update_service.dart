import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nickname_portal/constants/app_config.dart';

/// Compares two version strings (e.g. "12.0.0").
/// Returns: -1 if a < b, 0 if a == b, 1 if a > b
int compareVersions(String a, String b) {
  final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final len = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (int i = 0; i < len; i++) {
    final av = i < aParts.length ? aParts[i] : 0;
    final bv = i < bParts.length ? bParts[i] : 0;
    if (av != bv) return av < bv ? -1 : 1;
  }
  return 0;
}

class AppUpdateService {
  static final AppUpdateService instance = AppUpdateService._();
  AppUpdateService._();

  static const _versionPath = '/app/version';

  /// Check for update and show dialog if a newer version is available.
  /// Uses [navigatorKey] from main.dart to show the dialog.
  Future<void> checkAndNotify(BuildContext? context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final uri = Uri.parse(AppConfig.baseApi).replace(path: _versionPath);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('', 408),
      );
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body);
      if (body is! Map || body['success'] != true) return;
      final data = body['data'];
      if (data is! Map) return;
      final latest = (data['latestVersion'] as dynamic)?.toString();
      final updateUrl = (data['updateUrl'] as dynamic)?.toString();
      if (latest == null || latest.isEmpty) return;
      if (compareVersions(currentVersion, latest) >= 0) return;

      if (context == null || !context.mounted) return;
      _showUpdateDialog(context!, updateUrl: updateUrl, latestVersion: latest);
    } catch (e) {
      debugPrint('[AppUpdateService] Check failed: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, {String? updateUrl, required String latestVersion}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'A new version ($latestVersion) is available. Please update the app for the best experience.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openStore(updateUrl);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _openStore(String? updateUrl) async {
    final url = updateUrl?.trim();
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // Fallback: platform store links (optional)
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        final uri = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.nickname.portal',
        );
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (Platform.isIOS) {
        final uri = Uri.parse('https://apps.apple.com/app/idXXXXXXXXX');
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
