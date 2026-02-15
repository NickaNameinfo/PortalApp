
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nickname_portal/models/subscription_model.dart';
import 'package:nickname_portal/components/subscription_card.dart';
import 'package:nickname_portal/helpers/secure_http_client.dart';
import 'dart:convert';

// AppColors class for consistent styling
class AppColors {
  static const Color success = Colors.green;
  static const Color primary = Colors.blue;
  static const Color secondary = Colors.purple;
  static const Color error = Colors.red;
  static const Color warning = Colors.orange;
  static const Color warningLight = Color(0xFFFFE0B2);
  static const Color warningBg = Color(0xFFFFF3E0);
  static const Color textLight = Colors.grey;
  static const Color white = Colors.white;
  static const Color borderColor = Colors.black12;
  static const Color cardBackground = Colors.white;
  static const String primaryHex = "#3399cc";
}

// Helper function to build Book Service features widget
Widget _buildBookServiceFeatures() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Key Features:',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      const SizedBox(height: 8),
      _buildFeatureItem('Unlimited Service Booking'),
      _buildFeatureItem('No Commission'),
      _buildFeatureItem('Booking Support'),
      _buildFeatureItem('Store Branding'),
    ],
  );
}

// Helper function to build individual feature items
Widget _buildFeatureItem(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    ),
  );
}

final List<SubscriptionCategory> subscriptionData = [
  SubscriptionCategory(
    key: "Plan1",
    name: "Convert to E-Commerce",
    commingSoon: false,
    plans: [
      SubscriptionPlan(name: "Starter", key: "PL1_001", price: 38.0, defaultValue: 1, saveLabel: 'Best Offer'),
      SubscriptionPlan(name: "Standard", key: "PL1_002", price: 2799.0, defaultValue: 100, saveLabel: 'Save 10%'),
      SubscriptionPlan(name: "Premium", key: "PL1_003", price: 3799.0, defaultValue: 200, oldPrice: '4500.0', saveLabel: 'Most Popular'),
      SubscriptionPlan(name: "Customized", key: "PL1_004", price: 17.0, basePrice: 3799.0, defaultValue: 1),
      SubscriptionPlan(name: "Premium Plus with Billing", key: "PL1_005", price: 17.0, basePrice: 9999.0, defaultValue: 1),
    ],
  ),
  
  SubscriptionCategory(
    key: "Plan2",
    name: "Product Customization",
    commingSoon: false,
    plans: [
      SubscriptionPlan(name: "Starter", key: "PL2_001", price: 9.0, defaultValue: 1),
    ],
  ),
  SubscriptionCategory(
    key: "Plan3",
    name: "Book Service",
    commingSoon: false,
    plans: [
      SubscriptionPlan(
        name: "Starter", 
        key: "PL3_001", 
        price: 1999.0, 
        defaultValue: 1,
        label: "Enter number of item",
        discription: _buildBookServiceFeatures(),
      ),
    ],
  ),
  SubscriptionCategory(key: "five", name: "Customer Support for Product", commingSoon: true),
  SubscriptionCategory(key: "six", name: "Invoice Generation", commingSoon: true),
  SubscriptionCategory(key: "seven", name: "Customer List", commingSoon: true),
  SubscriptionCategory(key: "eight", name: "Request List", commingSoon: true),
  SubscriptionCategory(key: "nine", name: "Transaction List", commingSoon: true),
  SubscriptionCategory(key: "tem", name: "Setup Store Payment Gateway", commingSoon: true),
  SubscriptionCategory(key: "leven", name: "Delivery Partner Customizations", commingSoon: true),
];


// --- SubscriptionScreen Implementation ---

class SubscriptionScreen extends StatefulWidget {
  final String customerId;
  final String subscriptionType;

  const SubscriptionScreen({
    super.key,
    required this.customerId,
    required this.subscriptionType,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Map to hold current subscription details by category key
  Map<String, SubscriptionPlan?> _subscriptions = {};
  String? _customerId;
  bool _isLoadingSubscriptions = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerIdAndFetchSubscriptions();
  }

  Future<void> _loadCustomerIdAndFetchSubscriptions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final loadedCustomerId = prefs.getString('storeId');

    if (mounted) {
      setState(() {
        _customerId = loadedCustomerId;
      });
      
      if (_customerId != null) {
        await _fetchUserSubscriptions();
      } else {
        if (mounted) {
          setState(() {
            _subscriptions = {};
            _isLoadingSubscriptions = false;
          });
        }
      }
    }
  }

  /// Fetches user subscriptions from the API endpoint: https://nicknameinfo.net/api/auth/user/{userId}
  /// 
  /// API Response Structure:
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
  Future<void> _fetchUserSubscriptions() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId == null || userId.isEmpty || userId == '0') {
        if (mounted) {
          setState(() {
            _subscriptions = {};
            _isLoadingSubscriptions = false;
          });
        }
        return;
      }

      // Fetch user data with subscriptions from api/auth/user/{userId}
      final url = 'https://nicknameinfo.net/api/auth/user/$userId';
      final response = await SecureHttpClient.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final userData = data['data'];
          final subscriptions = userData['subscriptions'] as List<dynamic>?;
          
          Map<String, SubscriptionPlan?> subscriptionMap = {};
          
          if (subscriptions != null && subscriptions.isNotEmpty) {
            // Find Plan1 subscription (Ecommerce)
            final plan1List = subscriptions.where(
              (sub) => sub['subscriptionType'] == 'Plan1' && sub['status'] == '1',
            ).toList();
            if (plan1List.isNotEmpty) {
              subscriptionMap['Plan1'] = SubscriptionPlan.fromJson(plan1List.first);
            }
            
            // Find Plan2 subscription (Customize)
            final plan2List = subscriptions.where(
              (sub) => sub['subscriptionType'] == 'Plan2' && sub['status'] == '1',
            ).toList();
            if (plan2List.isNotEmpty) {
              subscriptionMap['Plan2'] = SubscriptionPlan.fromJson(plan2List.first);
            }
            
            // Find Plan3 subscription (Booking)
            final plan3List = subscriptions.where(
              (sub) => sub['subscriptionType'] == 'Plan3' && sub['status'] == '1',
            ).toList();
            if (plan3List.isNotEmpty) {
              subscriptionMap['Plan3'] = SubscriptionPlan.fromJson(plan3List.first);
            }
          }
          
          if (mounted) {
            setState(() {
              _subscriptions = subscriptionMap;
              _isLoadingSubscriptions = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _subscriptions = {};
              _isLoadingSubscriptions = false;
            });
          }
        }
      } else {
        debugPrint('Failed to fetch user data. Status code: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _subscriptions = {};
            _isLoadingSubscriptions = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user subscriptions: $e');
      if (mounted) {
        setState(() {
          _subscriptions = {};
          _isLoadingSubscriptions = false;
        });
      }
    }
  }

  // Method to re-fetch subscription details after a purchase
  void _refetchSubscriptions() {
    if (_customerId != null) {
      _fetchUserSubscriptions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: subscriptionData.map((subscription) {
            final currentPlan = _subscriptions[subscription.key];
            
            return _buildSubscriptionCategory(subscription, currentPlan);
          }).toList(),
        ),
      ),
    );
  }

  // Helper to build the ExpansionTile (AccordionItem equivalent)
  Widget _buildSubscriptionCategory(
    SubscriptionCategory subscription,
    SubscriptionPlan? currentPlan,
  ) {
    // For categories with no plans or coming soon, show a simple ListTile
    if (subscription.plans == null || subscription.commingSoon) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: ListTile(
          title: Text(subscription.name),
          trailing: subscription.commingSoon
              ? const Chip(label: Text('Coming soon'), backgroundColor: AppColors.error, labelStyle: TextStyle(color: AppColors.white))
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.borderColor),
          ),
          tileColor: AppColors.cardBackground,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ExpansionTile(
        title: Text(subscription.name),
        collapsedBackgroundColor: AppColors.cardBackground,
        backgroundColor: AppColors.cardBackground,
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.borderColor)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.borderColor)),
        
        children: [
          if (_isLoadingSubscriptions)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
          
          // Grid layout equivalent to the React component's grid
          Builder(
            builder: (context) {
              final width = MediaQuery.of(context).size.width;
              final isTablet = width >= 600;
              // Lower ratio = taller tiles. Tune these if needed.
              final childAspectRatio = isTablet ? 0.55 : 0.64;
  
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  childAspectRatio: childAspectRatio,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: subscription.plans!.length,
                itemBuilder: (context, index) {
                  final item = subscription.plans![index];
                  return SubscriptionCard(
                    item: item,
                    subscription: subscription,
                    currentSubscriptionDetails: currentPlan,
                    onPaymentSuccess: _refetchSubscriptions,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}