import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nickname_portal/models/subscription_model.dart';

class SubscriptionService {
  static const String _baseUrl = 'https://nicknameinfo.net/api/subscription';

  static Future<SubscriptionPlan?> getSubscriptionDetails(String customerId, String subscriptionType) async {
    final url = Uri.parse('$_baseUrl/$customerId?subscriptionType=$subscriptionType');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return SubscriptionPlan.fromJson(responseData['data']);
        } else {
          print('Failed to fetch subscription details: ${responseData['message']}');
          return null;
        }
      } else {
        print('Failed to fetch subscription details. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching subscription details: $e');
      return null;
    }
  }

  static Future<bool> createSubscription(Map<String, dynamic> payload) async {
    final url = Uri.parse('$_baseUrl/create');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else {
        print('Failed to create subscription. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error creating subscription: $e');
      return false;
    }
  }
}