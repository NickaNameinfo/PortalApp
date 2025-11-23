import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BillingService {
  static const String baseUrl = 'https://nicknameinfo.net/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();  }
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
    };
  }

  // Add new bill
  static Future<Map<String, dynamic>> addBill(Map<String, dynamic> billData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/billing/add'),
        headers: headers,
        body: jsonEncode(billData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to add bill: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error adding bill: $e');
    }
  }

  // Get all bills
  static Future<List<dynamic>> getAllBills(String storeId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/billing/getByStoreId/${storeId}'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      } else {
        throw Exception('Failed to fetch bills: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching bills: $e');
    }
  }

  // Get bill by ID
  static Future<Map<String, dynamic>> getBillById(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/billing/getById/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to fetch bill: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching bill: $e');
    }
  }

  // Update bill
  static Future<Map<String, dynamic>> updateBill(Map<String, dynamic> billData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/billing/update'),
        headers: headers,
        body: jsonEncode(billData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update bill: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating bill: $e');
    }
  }
}

