import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nickname_portal/constants/app_config.dart';
import 'package:nickname_portal/helpers/secure_http_client.dart';

class CheckoutApiHelper {
  static bool _isSuccessStatus(int code) => code >= 200 && code < 300;

  static Map<String, dynamic> _decodeJson(String body) {
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'success': false, 'message': 'Invalid response'};
  }

  /// Create an order record (backend: POST /order/create).
  /// Backend may respond with 201 Created; treat any 2xx as success.
  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) async {
    final http.Response response = await SecureHttpClient.post(
      '${AppConfig.baseApi}/order/create',
      body: body,
    );
    final out = _decodeJson(response.body);
    if (_isSuccessStatus(response.statusCode)) return out;
    throw Exception(out['message'] ?? out['error'] ?? 'Order create failed');
  }

  /// Delete cart item (backend: DELETE /cart/delete/:orderId/:productId).
  static Future<Map<String, dynamic>> deleteCartItem(String orderId, dynamic productId) async {
    final pid = productId is num
        ? productId.toInt()
        : int.tryParse(productId?.toString() ?? '') ?? 0;
    final http.Response response = await SecureHttpClient.delete(
      '${AppConfig.baseApi}/cart/delete/$orderId/$pid',
    );
    final out = _decodeJson(response.body);
    if (_isSuccessStatus(response.statusCode)) return out;
    throw Exception(out['message'] ?? out['error'] ?? 'Delete cart item failed');
  }

  /// Create Razorpay order (backend: POST /payment/orders).
  /// Used only for online payment flows.
  static Future<Map<String, dynamic>> createRazorpayOrder(double amount, String orderId) async {
    final http.Response response = await SecureHttpClient.post(
      '${AppConfig.baseApi}/payment/orders',
      body: {
        'amount': amount,
        'currency': 'INR',
        'order_id': orderId,
        'payment_capture': 1,
      },
    );
    final out = _decodeJson(response.body);
    if (_isSuccessStatus(response.statusCode)) return out;
    throw Exception(out['message'] ?? out['error'] ?? 'Payment order create failed');
  }

  /// Update payment record after Razorpay success (backend: POST /payment/orderlist).
  static Future<Map<String, dynamic>> updatePaymentRecord({
    required String orderCreationId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
  }) async {
    final http.Response response = await SecureHttpClient.post(
      '${AppConfig.baseApi}/payment/orderlist',
      body: {
        'orderCreationId': orderCreationId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpayOrderId': razorpayOrderId,
      },
    );
    final out = _decodeJson(response.body);
    if (_isSuccessStatus(response.statusCode)) return out;
    throw Exception(out['message'] ?? out['error'] ?? 'Payment update failed');
  }
}