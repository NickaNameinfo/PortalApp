import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // <-- Import the new package

// --- For Phone Calls ---
Future<void> makePhoneCall(String phoneNumber) async {
  final Uri launchUri = Uri(
    scheme: 'tel',
    path: phoneNumber,
  );
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  } else {
    if (kDebugMode) {
      print('Could not launch $launchUri');
    }
    // You could show a snackbar error here
  }
}

// --- For Websites ---
Future<void> launchWebsite(String url,  int storeId) async {
  // Ensure the URL has a scheme (http or https)
  String properUrl = url;
  if (url.isEmpty) {
    properUrl = 'https://nicknameportal.shop/Store/StoreDetails/$storeId';
  }

  final Uri launchUri = Uri.parse(properUrl);
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  } else {
    if (kDebugMode) {
      print('Could not launch $launchUri');
    }
  }
}

// --- For Maps ---
Future<void> openMap(String location) async {
  // --- FIX ---
  // Corrected the URL format to use a query parameter
  // final String query = Uri.encodeComponent(location);
  final Uri launchUri = Uri.parse('$location'); 
  
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  } else {
    if (kDebugMode) {
      print('Could not launch $launchUri');
    }
  }
}

// --- NEW ---
// --- For WhatsApp ---
Future<void> launchWhatsApp(String phone, [String message = ""]) async {
  // Assumes phone number includes country code (e.g., 91xxxxxxxxxx for India)
  final String encodedMessage = Uri.encodeComponent(message);
  final Uri launchUri = Uri.parse('http://googleusercontent.com/maps.google.com/$phone?text=$encodedMessage');

  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  } else {
    if (kDebugMode) {
      print('Could not launch $launchUri');
    }
  }
}

// --- NEW ---
// --- For Native Share Sheet ---
Future<void> shareContent(String text, {String? subject}) async {
  // This uses the share_plus package to open the native share dialog
  try {
    await Share.share(text, subject: subject);
  } catch (e) {
    if (kDebugMode) {
      print('Error sharing content: $e');
    }
  }
}