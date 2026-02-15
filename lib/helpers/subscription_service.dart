import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nickname_portal/models/subscription_model.dart';
import 'package:nickname_portal/helpers/secure_http_client.dart';

class SubscriptionService {
  /// Base URL for user API endpoint
  /// API: https://nicknameinfo.net/api/auth/user/{userId}
  /// Response structure:
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "id": 119,
  ///     "subscriptions": [
  ///       {
  ///         "id": 137,
  ///         "subscriptionType": "Plan1" | "Plan2" | "Plan3",
  ///         "subscriptionPlan": "PL1_005",
  ///         "subscriptionPrice": "10016.00",
  ///         "customerId": 55,
  ///         "status": "1",
  ///         "subscriptionCount": 200,
  ///         "freeCount": 0
  ///       }
  ///     ]
  ///   }
  /// }
  static const String _baseUrl = 'https://nicknameinfo.net/api/auth/user';

  /// Fetches subscription details from user API endpoint
  /// 
  /// [userId] - The user ID to fetch subscriptions for
  /// [subscriptionType] - The subscription type to find ("Plan1", "Plan2", or "Plan3")
  /// 
  /// Returns the SubscriptionPlan if found, null otherwise
  static Future<SubscriptionPlan?> getSubscriptionDetails(String userId, String subscriptionType) async {
    final url = '$_baseUrl/$userId';
    try {
      final response = await SecureHttpClient.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final userData = responseData['data'];
          final subscriptions = userData['subscriptions'] as List<dynamic>?;
          
          if (subscriptions != null && subscriptions.isNotEmpty) {
            // Find subscription matching the subscriptionType with active status
            final matchingSubscriptions = subscriptions.where(
              (sub) => sub['subscriptionType'] == subscriptionType && sub['status'] == '1',
            ).toList();
            
            if (matchingSubscriptions.isNotEmpty) {
              return SubscriptionPlan.fromJson(matchingSubscriptions.first);
            } else {
              print('No active subscription found for type: $subscriptionType');
              return null;
            }
          } else {
            print('No subscriptions found in user data');
            return null;
          }
        } else {
          print('Failed to fetch subscription details: ${responseData['message'] ?? 'Unknown error'}');
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

  /// Creates a new subscription using the subscription API endpoint
  /// 
  /// [payload] - The subscription payload containing:
  ///   - subscriptionCount: int
  ///   - subscriptionPrice: int (in paisa)
  ///   - subscriptionType: String ("Plan1", "Plan2", or "Plan3")
  ///   - subscriptionPlan: String (e.g., "PL1_005")
  ///   - customerId: String
  ///   - status: int (1 for active)
  ///   - id: String? (optional, for updates)
  ///   - freeCount: int
  ///   - paymentId: String
  /// 
  /// Returns true if subscription was created successfully, false otherwise
  static Future<bool> createSubscription(Map<String, dynamic> payload) async {
    // Use subscription API endpoint for creating subscriptions
    const subscriptionApiUrl = 'https://nicknameinfo.net/api/subscription/create';
    try {
      final response = await SecureHttpClient.post(
        subscriptionApiUrl,
        body: payload,
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