import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nickname_portal/main.dart'; // For navigatorKey

/// Secure HTTP Client with authentication and timeout support
/// All HTTP requests should use this client instead of direct http.get/http.post
/// Based on Dashboard baseQuery.mjs and authHelper.mjs
class SecureHttpClient {
  /// Default timeout duration
  static const Duration defaultTimeout = Duration(seconds: 10);
  
  /// Public routes that don't require authentication
  /// Based on Dashboard backend middleware PUBLIC_ROUTES
  static const List<String> publicRoutes = [
    '/api/auth/register',
    '/api/auth/rootLogin',
    '/api/customer/register',
    '/api/customer/login',
  ];
  
  /// Check if a route is public (doesn't require authentication)
  static bool isPublicRoute(String url) {
    return publicRoutes.any((route) => url.contains(route));
  }
  
  /// Get authentication headers
  /// Based on Dashboard authHelper.mjs prepareHeaders()
  /// Note: Dashboard uses plain token (no Bearer prefix) - line 151
  static Future<Map<String, String>> _getHeaders({String? url}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    // Skip authentication for public routes
    if (url != null && isPublicRoute(url)) {
      return headers;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null && token.isNotEmpty) {
      // Dashboard authHelper.mjs line 151 uses: headers.set("Authorization", `${token}`)
      // No Bearer prefix - backend middleware expects plain token
      headers['Authorization'] = token;
    }
    
    return headers;
  }
  
  /// Handle 401 Unauthorized response
  /// This is a callback that can be set to handle logout
  static Function(BuildContext)? onUnauthorized;
  
  /// GET request with authentication and timeout
  static Future<http.Response> get(
    String url, {
    Duration timeout = defaultTimeout,
    Map<String, String>? additionalHeaders,
    BuildContext? context, // Optional context for 401 handling
  }) async {
    try {
      final headers = await _getHeaders(url: url);
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(timeout);
      
      // Handle 401 Unauthorized
      if (response.statusCode == 401) {
        if (context != null && onUnauthorized != null) {
          onUnauthorized!(context);
        } else if (navigatorKey.currentContext != null && onUnauthorized != null) {
          // Use global navigator if context not provided
          onUnauthorized!(navigatorKey.currentContext!);
        }
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  /// POST request with authentication and timeout
  static Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    Duration timeout = defaultTimeout,
    Map<String, String>? additionalHeaders,
    BuildContext? context, // Optional context for 401 handling
  }) async {
    try {
      final headers = await _getHeaders(url: url);
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(timeout);
      
      // Handle 401 Unauthorized
      if (response.statusCode == 401) {
        if (context != null && onUnauthorized != null) {
          onUnauthorized!(context);
        } else if (navigatorKey.currentContext != null && onUnauthorized != null) {
          // Use global navigator if context not provided
          onUnauthorized!(navigatorKey.currentContext!);
        }
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  /// PUT request with authentication and timeout
  static Future<http.Response> put(
    String url, {
    Map<String, dynamic>? body,
    Duration timeout = defaultTimeout,
    Map<String, String>? additionalHeaders,
    BuildContext? context, // Optional context for 401 handling
  }) async {
    try {
      final headers = await _getHeaders(url: url);
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(timeout);
      
      // Handle 401 Unauthorized
      if (response.statusCode == 401) {
        if (context != null && onUnauthorized != null) {
          onUnauthorized!(context);
        } else if (navigatorKey.currentContext != null && onUnauthorized != null) {
          // Use global navigator if context not provided
          onUnauthorized!(navigatorKey.currentContext!);
        }
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  /// DELETE request with authentication and timeout
  static Future<http.Response> delete(
    String url, {
    Duration timeout = defaultTimeout,
    Map<String, String>? additionalHeaders,
    BuildContext? context, // Optional context for 401 handling
  }) async {
    try {
      final headers = await _getHeaders(url: url);
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      ).timeout(timeout);
      
      // Handle 401 Unauthorized
      if (response.statusCode == 401) {
        if (context != null && onUnauthorized != null) {
          onUnauthorized!(context);
        } else if (navigatorKey.currentContext != null && onUnauthorized != null) {
          // Use global navigator if context not provided
          onUnauthorized!(navigatorKey.currentContext!);
        }
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  /// POST request with FormData (for file uploads)
  static Future<http.Response> postFormData(
    String url, {
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
    Duration timeout = defaultTimeout,
    BuildContext? context, // Optional context for 401 handling
  }) async {
    try {
      final headers = await _getHeaders(url: url);
      // Remove Content-Type for multipart/form-data (http library sets it automatically)
      headers.remove('Content-Type');
      
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(headers);
      request.fields.addAll(fields);
      request.files.addAll(files);
      
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      
      // Handle 401 Unauthorized
      if (response.statusCode == 401) {
        if (context != null && onUnauthorized != null) {
          onUnauthorized!(context);
        } else if (navigatorKey.currentContext != null && onUnauthorized != null) {
          // Use global navigator if context not provided
          onUnauthorized!(navigatorKey.currentContext!);
        }
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
