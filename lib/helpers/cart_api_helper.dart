import 'dart:convert';
import 'package:http/http.dart' as http;

Future<http.Response> fetchCartItems(String userId) async {
  final url = Uri.parse('https://nicknameinfo.net/api/cart/list/$userId');
  return await http.get(url);
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
      ? 'https://nicknameinfo.net/api/cart/create'
      : 'https://nicknameinfo.net/api/cart/update/$userId/$productId';

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

  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: json.encode(requestBody),
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    return json.decode(response.body);
  } else {
    throw Exception('Cart API Error: ${response.statusCode} ${response.reasonPhrase}');
  }
}