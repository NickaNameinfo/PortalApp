// Web-only: browser Notification API.
import 'dart:html' as html;

bool _permissionAsked = false;

Future<bool> requestNotificationPermission() async {
  if (_permissionAsked) return html.Notification.permission == 'granted';
  _permissionAsked = true;
  if (html.Notification.permission == 'granted') return true;
  if (html.Notification.permission == 'denied') return false;
  final permission = await html.Notification.requestPermission();
  return permission == 'granted';
}

void showBrowserNotification(String title, String body) {
  if (html.Notification.permission != 'granted') return;
  try {
    html.Notification(title, body: body);
  } catch (_) {}
}
