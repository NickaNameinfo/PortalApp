import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';
import 'secure_http_client.dart';
import 'error_handler.dart';

class CategoryService {
  static Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      final response = await SecureHttpClient.get('${AppConfig.baseApi}/category/getAllCategory');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(ErrorHandler.getErrorMessage(response));
        }
      } else {
        throw Exception(ErrorHandler.getErrorMessage(response));
      }
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }
}