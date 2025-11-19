
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nickname_portal/models/subscription_model.dart';
import 'package:nickname_portal/helpers/subscription_service.dart'; // Assumed service for fetching data
import 'package:nickname_portal/components/subscription_card.dart' hide SubscriptionService;

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
    name: "Add's (Advertisements)",
    commingSoon: true,
    plans: [
      SubscriptionPlan(name: "Weekly", key: "PL3_001", price: 40.0, defaultValue: 1),
      SubscriptionPlan(name: "Monthly", key: "PL3_002", price: 140.0, defaultValue: 1),
      SubscriptionPlan(name: "Yearly", key: "PL3_003", price: 1780.0, defaultValue: 1),
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
  // Map to hold Futures for current plan details by category key
  Map<String, Future<SubscriptionPlan?>> _subscriptionFutures = {};
  String? _customerId;

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
        if (_customerId != null) {
          _refetchSubscriptions();
        } else {
          // Handle missing ID case gracefully
          final errorFuture = Future<SubscriptionPlan?>.error('Customer ID not found.');
          _subscriptionFutures = {
            'Plan1': errorFuture,
            'Plan2': errorFuture,
          };
        }
      });
    }
  }

  // Method to re-fetch subscription details after a purchase
  void _refetchSubscriptions() {
    if (_customerId != null) {
      setState(() {
        // Only fetch for categories that have plans and need the status checked
        for (var category in subscriptionData) {
          if (category.plans != null && category.plans!.isNotEmpty && !category.commingSoon) {
            _subscriptionFutures[category.key] = SubscriptionService.getSubscriptionDetails(_customerId!, category.key);
          }
        }
      });
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
            final future = _subscriptionFutures[subscription.key] ?? Future.value(null);
            
            return _buildSubscriptionCategory(subscription, future);
          }).toList(),
        ),
      ),
    );
  }

  // Helper to build the ExpansionTile (AccordionItem equivalent)
  Widget _buildSubscriptionCategory(
    SubscriptionCategory subscription,
    Future<SubscriptionPlan?> currentPlanFuture,
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

    return FutureBuilder<SubscriptionPlan?>(
      future: currentPlanFuture,
      builder: (context, snapshot) {
        final currentPlanDetails = snapshot.data;
    
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: ExpansionTile(
            title: Text(subscription.name),
            initiallyExpanded: subscription.key == 'Plan1',
            collapsedBackgroundColor: AppColors.cardBackground,
            backgroundColor: AppColors.cardBackground,
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.borderColor)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.borderColor)),
            
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
              
              if (snapshot.hasError && snapshot.error is! String) 
                Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error loading current plan: ${snapshot.error}'))),
              
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
                        currentSubscriptionDetails: currentPlanDetails,
                        onPaymentSuccess: _refetchSubscriptions,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}