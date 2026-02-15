import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_http_client.dart';
import 'error_handler.dart';

class BillingService {
  static const String baseUrl = 'https://nicknameinfo.net/api';

  // Add new bill
  static Future<Map<String, dynamic>> addBill(Map<String, dynamic> billData) async {
    try {
      final response = await SecureHttpClient.post(
        '$baseUrl/billing/add',
        body: billData,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(ErrorHandler.getErrorMessage(response));
      }
    } catch (e) {
      throw Exception('Error adding bill: $e');
    }
  }

  // Get all bills
  static Future<List<dynamic>> getAllBills(String storeId) async {
    try {
      final response = await SecureHttpClient.get(
        '$baseUrl/billing/getByStoreId/${storeId}',
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      } else {
        throw Exception(ErrorHandler.getErrorMessage(response));
      }
    } catch (e) {
      throw Exception('Error fetching bills: $e');
    }
  }

  // Get bill by ID
  static Future<Map<String, dynamic>> getBillById(int id) async {
    try {
      final response = await SecureHttpClient.get(
        '$baseUrl/billing/getById/$id',
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception(ErrorHandler.getErrorMessage(response));
      }
    } catch (e) {
      throw Exception('Error fetching bill: $e');
    }
  }

  // Update bill
  static Future<Map<String, dynamic>> updateBill(Map<String, dynamic> billData) async {
    try {
      final response = await SecureHttpClient.post(
        '$baseUrl/billing/update',
        body: billData,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(ErrorHandler.getErrorMessage(response));
      }
    } catch (e) {
      throw Exception('Error updating bill: $e');
    }
  }
}

