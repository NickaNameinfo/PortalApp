import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Web-specific implementation of DevTools Protection
/// This file is only imported when dart.library.html is available (web platform)

bool _isInitialized = false;

/// Initialize developer tools protection for web
/// This function is called from dev_tools_protection.dart
/// Public function for conditional import access
void initializeWebProtection() {
  if (_isInitialized) return;
  _isInitialized = true;

  // Disable right-click context menu
  html.document.addEventListener('contextmenu', (html.Event e) {
    e.preventDefault();
    return false;
  }, true);

  // Block keyboard shortcuts for DevTools
  html.document.addEventListener('keydown', (html.Event event) {
    final e = event as html.KeyboardEvent;
    // F12
    if (e.keyCode == 123) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }

    // Ctrl+Shift+I (73 = I)
    if (e.ctrlKey && e.shiftKey && e.keyCode == 73) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }

    // Ctrl+Shift+J (74 = J)
    if (e.ctrlKey && e.shiftKey && e.keyCode == 74) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }

    // Ctrl+Shift+C (67 = C)
    if (e.ctrlKey && e.shiftKey && e.keyCode == 67) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }

    // Ctrl+Shift+K (75 = K) - Firefox Console
    if (e.ctrlKey && e.shiftKey && e.keyCode == 75) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }

    // Ctrl+U (85 = U) - View Source
    if (e.ctrlKey && e.keyCode == 85) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }

    // Ctrl+S (83 = S) - Save Page
    if (e.ctrlKey && e.keyCode == 83) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }

    // Ctrl+P (80 = P) - Print
    if (e.ctrlKey && e.keyCode == 80) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }
  }, true);

  // Disable text selection (optional)
  html.document.addEventListener('selectstart', (html.Event e) {
    e.preventDefault();
    return false;
  }, true);

  // Disable drag
  html.document.addEventListener('dragstart', (html.Event e) {
    e.preventDefault();
    return false;
  }, true);

  // Basic DevTools detection
  _detectDevTools();
}

/// Detect if DevTools is open (basic detection)
void _detectDevTools() {
  if (kDebugMode) return; // Skip in debug mode

  // Use Timer.periodic instead of window.setInterval
  Timer.periodic(const Duration(seconds: 1), (timer) {
    final width = html.window.outerWidth ?? 0;
    final height = html.window.outerHeight ?? 0;
    final screenWidth = html.window.screen?.width ?? 0;
    final screenHeight = html.window.screen?.height ?? 0;

    // If window size is smaller than screen, DevTools might be open
    // This is a basic detection and not 100% accurate
    if (width < screenWidth || height < screenHeight) {
      // DevTools might be open
      // You can add additional logic here if needed
    }
  });
}

/// Disable console in production
/// Public function for conditional import access
void disableConsoleWeb() {
  if (kReleaseMode) {
    // Override console methods using dart:js_interop or direct JS
    // Since eval is not available, we'll use a script tag injection method
    // or rely on the HTML script for console blocking
    // For now, console blocking is handled in the HTML script
    // This function can be extended if needed with dart:js_interop package
  }
}
