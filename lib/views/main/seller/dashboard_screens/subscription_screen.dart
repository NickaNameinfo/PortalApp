import 'package:flutter/material.dart';
import 'package:multivendor_shop/models/subscription_model.dart';
import 'package:multivendor_shop/constants/colors.dart'; // Assuming this exists
import 'package:multivendor_shop/helpers/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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
  late Future<SubscriptionPlan?> _subscriptionPlanFuture;
  late Future<SubscriptionPlan?> _plan1SubscriptionFuture;
  late Future<SubscriptionPlan?> _plan2SubscriptionFuture;
  String? _customerId;
  String? _selectedCategoryKey; 

  @override
  void initState() {
    super.initState();
    _selectedCategoryKey = subscriptionData.first.key; // Initialize with the first category's key
    _subscriptionPlanFuture = Future.value(null);
    _plan1SubscriptionFuture = Future.value(null);
    _plan2SubscriptionFuture = Future.value(null);
    _loadCustomerId();
  }

  Future<void> _loadCustomerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _customerId = prefs.getString('storeId'); // Assuming 'storeId' is where customerId is stored
        if (_customerId != null) {
          // Fetch subscriptions for Plan1 and Plan2 keys
          _plan1SubscriptionFuture = SubscriptionService.getSubscriptionDetails(_customerId!, "Plan1");
          _plan2SubscriptionFuture = SubscriptionService.getSubscriptionDetails(_customerId!, "Plan2");
        } else {
          // Handle case where customerId is missing
          _plan1SubscriptionFuture = Future.error('Customer ID not found.');
          _plan2SubscriptionFuture = Future.error('Customer ID not found.');
        }
      });
    }
  }
  // Hardcoded data matching the visual structure for new subscriptions
  final List<SubscriptionCategory> subscriptionData = [
    SubscriptionCategory(
      name: 'Convert to E-Commerce',
      key: "Plan1",
      plans: [
        SubscriptionPlan(
          id: 'new_weekly_ecommerce',
          subscriptionType: 'Weekly',
          subscriptionPlan: 'PL1_001',
          subscriptionPrice: 80.0,
          customerId: "temp",
          status: 1,
          subscriptionCount: 1,
          freeCount: 0,
        ),
        SubscriptionPlan(
          id: 'new_monthly_ecommerce',
          subscriptionType: 'Monthly',
          subscriptionPlan: 'PL1_002',
          subscriptionPrice: 280.0,
          customerId: "temp",
          status: 1,
          subscriptionCount: 1,
          freeCount: 0,
        ),
        SubscriptionPlan(
          id: 'new_yearly_ecommerce',
          subscriptionType: 'Yearly',
          subscriptionPlan: 'PL1_003',
          subscriptionPrice: 2800.0,
          customerId: 'temp',
          status: 1,
          subscriptionCount: 1,
          freeCount: 0,
        ),
      ],
    ),
    SubscriptionCategory(
      name: 'Product Customization',
      key: "Plan2",
      plans: [
        SubscriptionPlan(
          id: 'new_weekly_customization',
          subscriptionType: 'Weekly',
          subscriptionPlan: 'PL2_001',
          subscriptionPrice: 80.0,
          customerId: 'temp',
          status: 1,
          subscriptionCount: 1,
          freeCount: 0,

        ),
        SubscriptionPlan(
          id: 'new_monthly_customization',
          subscriptionType: 'Monthly',
          subscriptionPlan: 'PL2_002',
          subscriptionPrice: 280.0,
          customerId: 'temp',
          status: 1,
          subscriptionCount: 1,
          freeCount: 0,
        ),
        SubscriptionPlan(
          id: 'new_yearly_customization',
          subscriptionType: 'Yearly',
          subscriptionPlan: 'PL2_003',
          subscriptionPrice: 2800.0,
          customerId: 'temp',
          status: 1,
          subscriptionCount: 1,
          freeCount: 0,

        ),
      ],
    ),
    SubscriptionCategory(
      name: 'Add\'s (Advertisements)',
      key: "Plan3",
      plans: [],
    ),
  ];



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Subscription Plans',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 24, color: primaryColor),
        ),
        backgroundColor: Colors.white,
        elevation: 0, // Flat app bar for modern look
        centerTitle: false,
        toolbarHeight: 70,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Current Subscription',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // FIX: Wrap current subscription cards in a horizontal scroll view
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Plan 1 Subscription
                  FutureBuilder<SubscriptionPlan?>(
                    future: _plan1SubscriptionFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        // Use a smaller loading widget for horizontal row
                        return const SizedBox(width: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                      } else if (snapshot.hasError) {
                        return SizedBox(width: 150, child: Center(child: Text('Error: ${snapshot.error}', style: TextStyle(fontSize: 12))));
                      } else if (snapshot.hasData && snapshot.data != null) {
                        return _CurrentPlanCard(
                          plan: snapshot.data!,
                          categoryName: 'Plan 1 Current',
                          customerId: _customerId!,
                          subscriptionType: "Plan1", // Use the actual category key
                          isCurrentSubscription: true,
                        );
                      } else {
                        return const SizedBox(width: 250, child: Center(child: Text('No Plan 1 subscription found.', style: TextStyle(fontSize: 14))));
                      }
                    },
                  ),
                  
                  const SizedBox(width: 16), // Spacing between the cards
                  
                  // Plan 2 Subscription
                  FutureBuilder<SubscriptionPlan?>(
                    future: _plan2SubscriptionFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(width: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                      } else if (snapshot.hasError) {
                        return SizedBox(width: 150, child: Center(child: Text('Error: ${snapshot.error}', style: TextStyle(fontSize: 12))));
                      } else if (snapshot.hasData && snapshot.data != null) {
                        return _CurrentPlanCard(
                          plan: snapshot.data!,
                          categoryName: 'Plan 2 Current',
                          customerId: _customerId!,
                          subscriptionType: "Plan2", // Use the actual category key
                          isCurrentSubscription: true,
                        );
                      } else {
                        return const SizedBox(width: 250, child: Center(child: Text('No Plan 2 subscription found.', style: TextStyle(fontSize: 14))));
                      }
                    },
                  ),
                  // Add extra padding/space at the end of the row
                  const SizedBox(width: 16), 
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Text(
              'New Subscription Options',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // New Subscription Options List (Vertical)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subscriptionData.length,
              itemBuilder: (context, categoryIndex) {
                final category = subscriptionData[categoryIndex];

                // Determine which active plan future to use for highlighting logic
                Future<SubscriptionPlan?> activePlanFuture;
                if (category.key == "Plan1") {
                  activePlanFuture = _plan1SubscriptionFuture;
                } else if (category.key == "Plan2") {
                  activePlanFuture = _plan2SubscriptionFuture;
                } else {
                  activePlanFuture = Future.value(null);
                }

                return FutureBuilder<SubscriptionPlan?>(
                  future: activePlanFuture,
                  builder: (context, activeSnapshot) {
                    final activePlan = activeSnapshot.data;
                    final bool isComingSoon = category.plans.any((plan) => plan.subscriptionPlan?.toLowerCase() == 'coming soon') || category.plans.isEmpty;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: category.name == 'Convert to E-Commerce',
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isComingSoon ? Colors.grey.shade600 : primaryColor,
                            ),
                          ),
                          onExpansionChanged: (isExpanded) {
                            if (isExpanded) {
                              if (mounted) {
                                setState(() {
                                  _selectedCategoryKey = category.key;
                                  // No need to reload future here, we use the specific plan futures.
                                });
                              }
                            }
                          },
                          trailing: isComingSoon
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Coming Soon',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : Icon(
                                  Icons.keyboard_arrow_down,
                                  color: primaryColor.withOpacity(0.8),
                                ),
                          children: [
                            if (isComingSoon)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16.0),
                                child: Text(
                                  'We are finalizing our plans for this service!',
                                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                                child: Row(
                                  children: category.plans.map((plan) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 16.0),
                                      child: _NewPlanCard( 
                                        plan: plan,
                                        categoryKey: category.key,
                                        customerId: _customerId ?? widget.customerId,
                                        activePlan: activePlan, // Pass the specific active plan
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// === WIDGET FOR DISPLAYING THE CURRENT ACTIVE SUBSCRIPTION ===
class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final String categoryName;
  final String customerId;
  final String subscriptionType;
  final bool isCurrentSubscription;

  const _CurrentPlanCard({
    required this.plan,
    required this.categoryName,
    required this.customerId,
    required this.subscriptionType,
    this.isCurrentSubscription = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the category name to display (Plan1/Plan2)
    final categoryDisplayName = plan.subscriptionType ?? plan.subscriptionPlan ?? categoryName;
    
    return Container(
      width: 250, // Fixed width to ensure horizontal scrolling
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryDisplayName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Price: ₹${double.tryParse(plan.subscriptionPrice.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Text(
            'Plan: ${plan.subscriptionPlan ?? 'N/A'}',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Manage Subscription details...')),
              );
            },
            icon: const Icon(Icons.manage_accounts, color: Colors.white),
            label: const Text('Manage Plan', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        ],
      ),
    );
  }
}

// === WIDGET FOR SELECTING A NEW SUBSCRIPTION PLAN ===
class _NewPlanCard extends StatefulWidget {
  final SubscriptionPlan plan;
  final String categoryKey;
  final String customerId;
  final SubscriptionPlan? activePlan; 

  const _NewPlanCard({
    required this.plan,
    required this.categoryKey,
    required this.customerId,
    this.activePlan, 
  });

  @override
  State<_NewPlanCard> createState() => _NewPlanCardState();
}

class _NewPlanCardState extends State<_NewPlanCard> {
  final TextEditingController _itemCountController = TextEditingController(text: '1');
  double calculatedPrice = 0.0;
  bool _isOrdering = false;
  late bool _isActivePlan;

  @override
  void initState() {
    super.initState();
    _checkActivePlan();
    _calculatePrice();
    _itemCountController.addListener(_calculatePrice);
  }
  
  void _checkActivePlan() {
    _isActivePlan = widget.activePlan != null && 
        widget.activePlan!.subscriptionPlan == widget.plan.subscriptionPlan; // Check based on PL1_001, PL2_003, etc.
  }

  @override
  void didUpdateWidget(covariant _NewPlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activePlan != oldWidget.activePlan) {
      _checkActivePlan();
    }
  }

  @override
  void dispose() {
    _itemCountController.removeListener(_calculatePrice);
    _itemCountController.dispose();
    super.dispose();
  }

  void _calculatePrice() {
    final basePrice = widget.plan.subscriptionPrice;
    final count = int.tryParse(_itemCountController.text) ?? 1;

    if (mounted) {
      setState(() {
        calculatedPrice = basePrice * count;
      });
    }
  }

  Future<void> _handleOrder() async {
    if (calculatedPrice <= 0) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price cannot be zero or negative.')),
      );
      return;
    }
    
    if (mounted) setState(() => _isOrdering = true);

    final int quantity = int.tryParse(_itemCountController.text) ?? 1;

    final Map<String, dynamic> payload = {
      "customerId": widget.customerId,
      "subscriptionType": widget.categoryKey,
      "planName": widget.plan.subscriptionType,
      "quantity": quantity,
      "totalPrice": calculatedPrice,
      "basePrice": widget.plan.subscriptionPrice,
      "subscriptionPlan": widget.plan.subscriptionPlan,
      "status": 1, 
    };

    try {
      final success = await SubscriptionService.createSubscription(payload);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription ordered successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to place order. Please try again.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Order error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define colors and border based on active status
    final cardColor = _isActivePlan ? litePrimary.withOpacity(0.15) : Colors.white;
    final borderColor = _isActivePlan ? primaryColor : Colors.grey.shade200;
    
    return Container(
      width: 250, 
      decoration: BoxDecoration(
        color: cardColor, // Use dynamic color
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: borderColor, width: _isActivePlan ? 2.0 : 1.0), // Use dynamic border
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(_isActivePlan ? 0.25 : 0.15),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Plan Title Section (Weekly/Monthly/Yearly)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan.subscriptionType ?? widget.plan.subscriptionPlan ?? 'Plan',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: _isActivePlan ? primaryColor : primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Price: ₹${widget.plan.subscriptionPrice.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                
                // Active Badge
                if (_isActivePlan)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CURRENTLY ACTIVE',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // 2. Description Section
          Container(
            padding: const EdgeInsets.all(16.0),
            height: 100, 
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Text(
              // Assuming subscriptionCount represents the items/ads included
              'Plan: ${widget.plan.subscriptionPlan}',
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // 3. Price/Order Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Input Field
                SizedBox( // FIX: Use fixed width instead of Expanded for better control in this small row segment
                  width: 60, // Set a fixed width for the input field
                  height: 40,
                  child: TextFormField(
                    controller: _itemCountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      // FIX: Removed unnecessary labelText to prevent cutoff/overflow
                      hintText: '1', 
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8), 
                        borderSide: BorderSide(color: Colors.grey.shade400)
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400)
                      ),
                    ),
                    onFieldSubmitted: (_) => _calculatePrice(),
                  ),
                ),
                const SizedBox(width: 8),

                // Price Badge
                // FIX: Use an Expanded widget here to allow the price to take available space if needed, 
                // but use a fixed padding for visual consistency.
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: litePrimary.withOpacity(0.1), 
                      borderRadius: BorderRadius.circular(8), 
                      border: Border.all(color: litePrimary, width: 1) 
                    ),
                    child: Center( // Center the price text inside the badge
                      child: Text(
                        '₹${calculatedPrice.toStringAsFixed(0)}', 
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Order Button
                ElevatedButton(
                  onPressed: _isActivePlan ? null : _handleOrder, // Disable order button if active
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isActivePlan ? Colors.green.shade600 : Colors.grey.shade300,
                    foregroundColor: _isActivePlan ? Colors.white : Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(60, 50),
                    elevation: 0,
                  ),
                  child: _isActivePlan
                      ? const Text('Active', style: TextStyle(fontWeight: FontWeight.bold))
                      : (_isOrdering
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Order')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}