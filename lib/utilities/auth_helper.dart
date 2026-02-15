import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nickname_portal/constants/colors.dart';
import 'package:nickname_portal/routes/routes.dart';
import 'package:nickname_portal/views/auth/auth.dart';
import 'package:nickname_portal/views/auth/account_type_selector.dart';
import 'package:flutter/foundation.dart';

class AuthHelper {
  /// Check if user is logged in
  static Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    return userId != null && userId.isNotEmpty && userId != '0';
  }

  /// Get current user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  /// Show login required dialog and navigate to login
  static Future<bool> showLoginDialog(BuildContext context, {String? message}) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.login,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Login Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message ?? 'Please login to continue. You need to be logged in to add items to cart or place orders.',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                // First pop the dialog, then navigate to account type selector
                Navigator.of(context).pop(true);
                // Small delay to ensure dialog is dismissed before navigation
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AccountTypeSelector(),
                      ),
                    );
                  }
                });
              },
              child: const Text(
                'Login',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Check authentication and show dialog if not logged in
  /// Returns true if user is logged in, false otherwise
  static Future<bool> checkAuthAndShowDialog(BuildContext context, {String? message}) async {
    final isLoggedIn = await isUserLoggedIn();
    if (!isLoggedIn) {
      final shouldLogin = await showLoginDialog(context, message: message);
      return shouldLogin;
    }
    return true;
  }

  /// Logout user - clear all auth data
  /// Based on Dashboard authUtils.mjs logout()
  static Future<void> logout(BuildContext context) async {
    debugPrint('[AuthHelper] Logging out user');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    debugPrint('[AuthHelper] Auth data cleared');
    
    // Navigate to login screen
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const Auth(),
          settings: const RouteSettings(name: '/login'),
        ),
        (Route<dynamic> route) => false,
      );
    }
  }

  /// Get user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userRole');
  }

  /// Get store ID
  static Future<String?> getStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('storeId');
  }

  /// Get vendor ID
  static Future<String?> getVendorId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('vendorId');
  }

  /// Check if token exists
  static Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }
}

