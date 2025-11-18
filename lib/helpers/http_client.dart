import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class HttpClient {
  static const Duration _defaultTimeout = Duration(seconds: 15);
  
  static Future<http.Response> get(
    Uri url, {
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    try {
      return await http.get(
        url,
        headers: headers,
      ).timeout(
        timeout ?? _defaultTimeout,
        onTimeout: () {
          throw TimeoutException('Request timeout after ${timeout ?? _defaultTimeout}');
        },
      );
    } on SocketException catch (e) {
      throw Exception('No internet connection: $e');
    } on TimeoutException catch (e) {
      throw Exception('Request timeout: $e');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  static Future<http.Response> post(
    Uri url, {
    Object? body,
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    try {
      return await http.post(
        url,
        body: body,
        headers: headers,
      ).timeout(
        timeout ?? _defaultTimeout,
        onTimeout: () {
          throw TimeoutException('Request timeout after ${timeout ?? _defaultTimeout}');
        },
      );
    } on SocketException catch (e) {
      throw Exception('No internet connection: $e');
    } on TimeoutException catch (e) {
      throw Exception('Request timeout: $e');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  static Future<http.Response> delete(
    Uri url, {
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    try {
      return await http.delete(
        url,
        headers: headers,
      ).timeout(
        timeout ?? _defaultTimeout,
        onTimeout: () {
          throw TimeoutException('Request timeout after ${timeout ?? _defaultTimeout}');
        },
      );
    } on SocketException catch (e) {
      throw Exception('No internet connection: $e');
    } on TimeoutException catch (e) {
      throw Exception('Request timeout: $e');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  static Future<http.Response> put(
    Uri url, {
    Object? body,
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    try {
      return await http.put(
        url,
        body: body,
        headers: headers,
      ).timeout(
        timeout ?? _defaultTimeout,
        onTimeout: () {
          throw TimeoutException('Request timeout after ${timeout ?? _defaultTimeout}');
        },
      );
    } on SocketException catch (e) {
      throw Exception('No internet connection: $e');
    } on TimeoutException catch (e) {
      throw Exception('Request timeout: $e');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

