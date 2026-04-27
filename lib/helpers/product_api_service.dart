import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';
import 'secure_http_client.dart';
import 'error_handler.dart';

class ProductApiService {
  static Future<List<dynamic>> getAllProductsBySupplierId(String supplierId) async {
    try {
      final response = await SecureHttpClient.get(
        '${AppConfig.baseApi}/store/product/getAllProductById/$supplierId',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return responseData['data'];
        } else {
          throw Exception(ErrorHandler.getErrorMessage(response));
        }
      } else {
        throw Exception(ErrorHandler.getErrorMessage(response));
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }
}