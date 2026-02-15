/// Stub implementation for non-web platforms
/// This file is used when dart.library.html is not available (mobile/desktop)

/// Initialize developer tools protection (stub - does nothing on non-web)
/// Public function for conditional import access
void initializeWebProtection() {
  // No-op for non-web platforms
  // This function is only called on web builds
}

/// Disable console (stub - does nothing on non-web)
/// Public function for conditional import access
void disableConsoleWeb() {
  // No-op for non-web platforms
  // This function is only called on web builds
}
