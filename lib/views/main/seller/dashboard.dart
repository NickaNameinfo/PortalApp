import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import 'dashboard_screens/account_balance.dart';
import 'dashboard_screens/manage_products.dart';
import 'dashboard_screens/orders.dart';
import 'dashboard_screens/statistics.dart';
import 'dashboard_screens/store_setup.dart';
import 'dashboard_screens/upload_product.dart';
import 'dashboard_screens/subscription_screen.dart';
class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  // Updated menu list with an additional placeholder service for 'Admin/Services'
  final List<dynamic> menuList = [
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
      'title': 'Orders (Coming Soon)',
      'icon': Icons.shopping_bag_outlined, // Modern icon
      // 'routeName': OrdersScreen.routeName,
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
                  onTap: () => Navigator.of(context).pushNamed(item['routeName'], arguments: {'customerId': 'temp_customer_id', 'subscriptionType': 'Plan1'}),
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
