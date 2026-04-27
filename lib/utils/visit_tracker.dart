import 'package:flutter/foundation.dart';
import 'package:nickname_portal/constants/app_config.dart';
import 'package:nickname_portal/helpers/secure_http_client.dart';

/// Fire-and-forget visit tracking (no auth required).
/// Mirrors Frontend `src/utils/visitTracker.mjs` → POST `/store/visit`.
class VisitTracker {
  static Future<void> recordSiteVisit() async {
    await _postVisit(null);
  }

  static Future<void> recordStoreVisit(int storeId) async {
    await _postVisit(storeId);
  }

  static Future<void> _postVisit(int? storeId) async {
    final url = '${AppConfig.baseApi}/store/visit';
    try {
      await SecureHttpClient.post(
        url,
        body: storeId != null ? {'storeId': storeId} : null,
        timeout: const Duration(seconds: 8),
      );
    } catch (_) {
      // Intentionally ignore (tracking must not break UX)
      if (kDebugMode) {
        // ignore: avoid_print
        print('[VisitTracker] failed to record visit');
      }
    }
  }
}

