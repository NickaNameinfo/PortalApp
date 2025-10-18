import 'dart:convert';
import 'package:http/http.dart' as http;

class CategoryService {
  static const String _baseUrl = 'https://nicknameinfo.net/api/category';

  static Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/getAllCategory'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception('Failed to load categories: ${data['message']}');
        }
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }
}