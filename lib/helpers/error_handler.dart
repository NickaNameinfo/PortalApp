import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nickname_portal/views/auth/auth.dart';

/// Centralized error handling for API responses
/// Based on Dashboard errorHandler.mjs
class ErrorHandler {
  /// Extract error message from API response
  /// Handles multiple response formats:
  /// - { error: { data: { message: "..." } } }
  /// - { message: "..." }
  /// - { error: "..." }
  static String getErrorMessage(dynamic error) {
    if (error is http.Response) {
      try {
        final errorData = json.decode(error.body);
        
        // Try error.data.message first (Dashboard format)
        if (errorData['error'] != null && 
            errorData['error']['data'] != null &&
            errorData['error']['data']['message'] != null) {
          return errorData['error']['data']['message'];
        }
        
        // Try error.message
        if (errorData['error'] != null && errorData['error']['message'] != null) {
          return errorData['error']['message'];
        }
        
        // Try top-level message
        if (errorData['message'] != null) {
          return errorData['message'];
        }
        
        // Try top-level error string
        if (errorData['error'] is String) {
          return errorData['error'];
        }
        
        // Fallback to status code message
        return 'Error ${error.statusCode}: ${error.reasonPhrase ?? 'Unknown error'}';
      } catch (e) {
        // If JSON parsing fails, return body or status message
        return error.body.isNotEmpty 
            ? error.body 
            : 'Error ${error.statusCode}: ${error.reasonPhrase ?? 'Unknown error'}';
      }
    }
    
    // Handle other error types
    if (error is Exception) {
      return error.toString();
    }
    
    return error.toString();
  }

  /// Check if response is an authentication error (401)
  static bool isAuthError(http.Response response) {
    return response.statusCode == 401;
  }

  /// Check if response is a rate limit error (429)
  static bool isRateLimitError(http.Response response) {
    return response.statusCode == 429;
  }

  /// Handle unauthorized error (401)
  /// Clears auth data and navigates to login
  static Future<void> handleUnauthorized(BuildContext context) async {
    debugPrint('[ErrorHandler] 401 Unauthorized - Clearing auth and redirecting to login');
    
    // Clear all auth data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Navigate to login
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

  /// Handle rate limit error (429)
  static String getRateLimitMessage(http.Response response) {
    try {
      final errorData = json.decode(response.body);
      return errorData['message'] ?? 
             'Too many requests. Please try again later.';
    } catch (e) {
      return 'Too many requests. Please try again later.';
    }
  }

  /// Format error message for display to user
  static String formatErrorMessage(String error) {
    // Remove technical details for user-facing messages
    if (error.contains('SocketException') || error.contains('Failed host lookup')) {
      return 'No internet connection. Please check your network.';
    }
    
    if (error.contains('TimeoutException') || error.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    
    if (error.contains('401') || error.contains('Unauthorized')) {
      return 'Your session has expired. Please login again.';
    }
    
    if (error.contains('403') || error.contains('Forbidden')) {
      return 'You do not have permission to perform this action.';
    }
    
    if (error.contains('404') || error.contains('Not Found')) {
      return 'The requested resource was not found.';
    }
    
    if (error.contains('500') || error.contains('Internal Server Error')) {
      return 'Server error. Please try again later.';
    }
    
    return error;
  }
}
