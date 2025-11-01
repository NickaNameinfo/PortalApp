import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductApiService {
  static Future<List<dynamic>> getAllProductsBySupplierId(String supplierId) async {
    final url = Uri.parse('https://nicknameinfo.net/api/store/product/getAllProductById/$supplierId');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return responseData['data'];
        } else {
          throw Exception('Failed to load products: ${responseData['message']}');
        }
      } else {
        throw Exception('Failed to load products, status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: \$e');
    }
  }
}