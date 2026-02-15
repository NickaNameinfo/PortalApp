import 'package:flutter/foundation.dart';

// Conditional import for web platform
// On web: imports dev_tools_protection_web.dart
// On mobile/desktop: imports dev_tools_protection_stub.dart
import 'dev_tools_protection_stub.dart'
    if (dart.library.html) 'dev_tools_protection_web.dart';

/// Developer Tools Protection for Flutter Web
/// Blocks common methods to access developer tools and inspect elements
/// 
/// Usage in main.dart:
/// ```dart
/// if (kIsWeb) {
///   DevToolsProtection.initialize(enabled: true);
/// }
/// ```
class DevToolsProtection {
  /// Initialize developer tools protection
  /// Call this in main() before runApp()
  /// Only works on web platform
  static void initialize({bool enabled = true}) {
    if (!kIsWeb || !enabled) return;
    // Call the function from the conditionally imported file
    // This will call initializeWebProtection from dev_tools_protection_web.dart on web
    // or from dev_tools_protection_stub.dart on mobile/desktop
    initializeWebProtection();
  }

  /// Disable console in production (optional)
  static void disableConsole() {
    if (kIsWeb && kReleaseMode) {
      // Call the function from the conditionally imported file
      disableConsoleWeb();
    }
  }
}
