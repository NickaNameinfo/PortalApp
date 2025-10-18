import 'package:url_launcher/url_launcher.dart';

Future<void> makePhoneCall(String phoneNumber) async {
  final Uri launchUri = Uri(
    scheme: 'tel',
    path: phoneNumber,
  );
  await launchUrl(launchUri);
}

Future<void> launchWebsite(String websiteUrl) async {
  final Uri launchUri = Uri.parse(websiteUrl);
  await launchUrl(launchUri);
}

Future<void> openMap(String location) async {
  final Uri launchUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}');
  await launchUrl(launchUri);
}