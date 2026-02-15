import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import 'dashboard_screens/account_balance.dart';
import 'dashboard_screens/manage_products.dart';
import 'dashboard_screens/orders.dart';
import 'dashboard_screens/statistics.dart';
import 'dashboard_screens/store_setup.dart';
import 'dashboard_screens/upload_product.dart';
import 'dashboard_screens/subscription_screen.dart';
import 'dashboard_screens/billing_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nickname_portal/helpers/secure_http_client.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _hasValidBillingSubscription = false;
  bool _isLoadingSubscription = true;

  // Updated menu list with an additional placeholder service for 'Admin/Services'
  List<dynamic> get menuList {
    final baseMenuList = [
    // {
    //   'title': 'Store Setup',
    //   'icon': Icons.settings_outlined, // Modern icon
    //   'routeName': StoreSetupScreen.routeName,
    // },
    {
      'title': 'Manage Products',
      'icon': Icons.inventory_2_outlined, // Modern icon
      'routeName': ManageProductsScreen.routeName,
    },
    {
      'title': 'Subscriptions',
      'icon': Icons.subscriptions_outlined, // Modern icon
      'routeName': '/subscription-screen',
    },
    {
      'title': 'Orders',
      'icon': Icons.shopping_bag_outlined, // Modern icon
      'routeName': OrdersScreen.routeName,
    },
    if (_hasValidBillingSubscription)
      {
        'title': 'Billing',
        'icon': Icons.receipt_long_outlined, // Modern icon
        'routeName': '/billing-list',
      },
    {
      'title': 'Statistics (Coming Soon)',
      'icon': Icons.bar_chart_outlined, // Modern icon
      // 'routeName': StatisticsScreen.routeName,
    },
    {
      'title': 'Account/Balance (Coming Soon)',
      'icon': Icons.account_balance_wallet_outlined, // Modern icon
      // 'routeName': AccountBalanceScreen.routeName,
    },
    // Adding a placeholder for future 'Multiple Services' or Admin tasks
    {
      'title': 'Admin/Services (Coming Soon)',
      'icon': Icons.business_center_outlined, // Placeholder for multi-services
      // 'routeName': StoreSetupScreen.routeName, // Placeholder route
    },
    ];
    return baseMenuList;
  }

  @override
  void initState() {
    super.initState();
    _checkBillingSubscription();
  }

  Future<void> _checkBillingSubscription() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId == null || userId.isEmpty || userId == '0') {
        setState(() {
          _hasValidBillingSubscription = false;
          _isLoadingSubscription = false;
        });
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
          
          if (mounted) {
            setState(() {
              // Check if any subscription matches PL1_005 and Plan1 with active status
              _hasValidBillingSubscription = subscriptions != null &&
                  subscriptions.any((sub) =>
                      sub['subscriptionPlan'] == 'PL1_005' &&
                      sub['subscriptionType'] == 'Plan1' &&
                      sub['status'] == '1');
              _isLoadingSubscription = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _hasValidBillingSubscription = false;
              _isLoadingSubscription = false;
            });
          }
        }
      } else {
        debugPrint('Failed to fetch user data. Status code: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _hasValidBillingSubscription = false;
            _isLoadingSubscription = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking billing subscription: $e');
      if (mounted) {
        setState(() {
          _hasValidBillingSubscription = false;
          _isLoadingSubscription = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Updated Grid View for Seller Dashboard
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16, // Increased spacing
                mainAxisSpacing: 16, // Increased spacing
                childAspectRatio: 1, // Make the cards square
              ),
              itemCount: menuList.length,
              itemBuilder: (context, index) {
                final item = menuList[index];
                return GestureDetector(
                  onTap: () {
                    if (item['routeName'] != null) {
                      if (item['routeName'] == '/billing-list') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const BillingListScreen(),
                          ),
                        );
                      } else {
                        Navigator.of(context).pushNamed(
                          item['routeName'], 
                          arguments: {'customerId': 'temp_customer_id', 'subscriptionType': 'Plan1'}
                        );
                      }
                    }
                  },
                  child: Card(
                    // Modern elevated card style
                    elevation: 10,
                    shadowColor: primaryColor.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20), // More rounded corners
                      side: BorderSide(
                        color: primaryColor.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item['icon'],
                            size: 48, // Slightly larger icon
                            color: primaryColor,
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          Text(
                            item['title'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
