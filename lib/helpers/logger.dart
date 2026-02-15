import 'package:flutter/foundation.dart';

/// Production-safe logging utility
/// Only logs in debug mode, prevents sensitive data exposure in production
class Logger {
  /// Log debug message (only in debug mode)
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  /// Log info message (only in debug mode)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  /// Log warning message (only in debug mode)
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[WARNING] $message');
    }
  }

  /// Log error message (always logged, but sanitized in production)
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    } else {
      // In production, only log error message without sensitive details
      debugPrint('[ERROR] $message');
    }
  }

  /// Log API request (only in debug mode, sanitizes sensitive data)
  static void apiRequest(String method, String url, {Map<String, dynamic>? body}) {
    if (kDebugMode) {
      debugPrint('[API] $method $url');
      if (body != null) {
        // Sanitize sensitive fields
        final sanitized = Map<String, dynamic>.from(body);
        if (sanitized.containsKey('password')) {
          sanitized['password'] = '***';
        }
        if (sanitized.containsKey('token')) {
          sanitized['token'] = '***';
        }
        debugPrint('Body: $sanitized');
      }
    }
  }

  /// Log API response (only in debug mode)
  static void apiResponse(int statusCode, String url) {
    if (kDebugMode) {
      debugPrint('[API] Response $statusCode for $url');
    }
  }
}
