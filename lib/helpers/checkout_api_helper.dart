import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_http_client.dart';
import 'error_handler.dart';

class CheckoutApiHelper {
  static const String _baseUrl = "https://nicknameinfo.net/api";

  static Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final response = await SecureHttpClient.post(
      '$_baseUrl$endpoint',
      body: body,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(ErrorHandler.getErrorMessage(response));
    }
  }

  // Corresponds to 'addPyament' (addPayment) in JS
  static Future<Map<String, dynamic>> createRazorpayOrder(double amount, String userId) async {
    final body = {
      "amount": amount,
      "currency": "INR",
      "order_id": userId, // Note: JS code uses userId, ideally this is a unique ID
      "payment_capture": 1
    };
    // Maps to /payment/orders
    return await _post('/payment/orders', body);
  }

  // Corresponds to 'addOrderlist' in JS
  static Future<Map<String, dynamic>> updatePaymentRecord({
    required String orderCreationId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
  }) async {
    final body = {
      "orderCreationId": orderCreationId,
      "razorpayPaymentId": razorpayPaymentId,
      "razorpayOrderId": razorpayOrderId,
    };
    // Maps to /payment/orderlist
    return await _post('/payment/orderlist', body);
  }

  // Corresponds to 'addOrder' in JS
  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> apiParams) async {
    // Maps to /order/create
    return await _post('/order/create', apiParams);
  }

  // --- Cart Management (from CartScreen) ---

  static Future<List<dynamic>> fetchCartItems(String userId) async {
    final response = await SecureHttpClient.get('$_baseUrl/cart/list/$userId');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'];
      } else {
        return [];
      }
    } else {
      throw Exception(ErrorHandler.getErrorMessage(response));
    }
  }
  
  static Future<void> deleteCartItem(String userId, int productId) async {
     try {
      final response = await SecureHttpClient.delete('$_baseUrl/cart/delete/$userId/$productId');
      if (response.statusCode != 200) {
         throw Exception(ErrorHandler.getErrorMessage(response));
      }
      final responseData = json.decode(response.body);
      if (responseData['success'] != true) {
         throw Exception(responseData['message'] ?? 'Failed to delete item from cart.');
      }
    } catch (e) {
      print("Error removing from cart: $e");
      // Don't re-throw, allow other deletions to proceed
    }
  }
}