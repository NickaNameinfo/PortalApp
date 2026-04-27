import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';
import 'secure_http_client.dart';

Future<http.Response> fetchCartItems(String userId) async {
  return await SecureHttpClient.get(
    '${AppConfig.baseApi}/cart/list/$userId',
  );
}

Future<Map<String, dynamic>> updateCart({
  required int productId,
  required int newQuantity,
  required Map<String, dynamic> productData,
  required bool isAdd,
  required String userId,
  required String storeId,
}) async {
  final String name = productData['name']?.toString() ?? 'N/A';
  final double price = (productData['price'] is num)
      ? (productData['price'] as num).toDouble()
      : (double.tryParse(productData['price']?.toString() ?? '0.0') ?? 0.0);
  final double total = price * newQuantity;

  final String url = isAdd
      ? '${AppConfig.baseApi}/cart/create'
      : '${AppConfig.baseApi}/cart/update/$userId/$productId';

  // Build the request body
  final Map<String, dynamic> requestBody = {
    'productId': productId,
    'name': name,
    'orderId': userId,
    'price': price,
    'total': total,
    'qty': newQuantity,
    'photo': productData['photo']?.toString() ?? '',
    'storeId': productData['createdId']?.toString() ?? storeId,
  };
  
  // Include size if available
  if (productData['size'] != null) {
    requestBody['size'] = productData['size'].toString();
  }
  
  // Include weight if available
  if (productData['weight'] != null) {
    requestBody['weight'] = productData['weight'].toString();
  }

  final response = await SecureHttpClient.post(
    url,
    body: requestBody,
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    return json.decode(response.body);
  } else {
    throw Exception('Cart API Error: ${response.statusCode} ${response.reasonPhrase}');
  }
}