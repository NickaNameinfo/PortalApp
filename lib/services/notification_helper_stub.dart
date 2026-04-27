// Stub for non-web platforms (mobile, desktop).

Future<bool> requestNotificationPermission() => Future.value(false);

void showBrowserNotification(String title, String body) {}
