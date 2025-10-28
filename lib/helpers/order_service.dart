import 'dart:convert';
import 'package:http/http.dart' as http;

class OrderService {
  static Future<Map<String, dynamic>> placeOrder({
    required int customerId,
    required int paymentMethod,
    required int orderId,
    required double grandTotal,
    required List<int> productIds,
    required List<int> quantities,
  }) async {
    final url = Uri.parse('https://nicknameinfo.net/api/order/create');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'customerId': customerId,
        'paymentmethod': paymentMethod,
        'orderId': orderId,
        'grandTotal': grandTotal,
        'productIds': productIds,
        'qty': quantities,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to place order: ${response.statusCode}');
    }
  }

  static Future<void> deleteCartItem({required String userId, required int productId}) async {
    final url = Uri.parse('https://nicknameinfo.net/api/cart/delete/$userId/$productId');
    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete cart item: ${response.statusCode}');
    }
  }
}