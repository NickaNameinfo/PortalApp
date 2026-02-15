import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_http_client.dart';
import 'error_handler.dart';

class OrderService {
  static Future<Map<String, dynamic>> placeOrder({
    required int customerId,
    required int paymentMethod,
    required int orderId,
    required double grandTotal,
    required List<int> productIds,
    required List<int> quantities,
  }) async {
    final response = await SecureHttpClient.post(
      'https://nicknameinfo.net/api/order/create',
      body: {
        'customerId': customerId,
        'paymentmethod': paymentMethod,
        'orderId': orderId,
        'grandTotal': grandTotal,
        'productIds': productIds,
        'qty': quantities,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception(ErrorHandler.getErrorMessage(response));
    }
  }

  static Future<void> deleteCartItem({required String userId, required int productId}) async {
    final response = await SecureHttpClient.delete(
      'https://nicknameinfo.net/api/cart/delete/$userId/$productId',
    );

    if (response.statusCode != 200) {
      throw Exception(ErrorHandler.getErrorMessage(response));
    }
  }
}