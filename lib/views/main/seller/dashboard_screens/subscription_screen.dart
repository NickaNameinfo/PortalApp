import 'package:flutter/material.dart';
import 'package:nickname_portal/models/subscription_model.dart';
import 'package:nickname_portal/constants/colors.dart'; // Assuming this exists
import 'package:nickname_portal/helpers/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

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
  // late Future<SubscriptionPlan?> _subscriptionPlanFuture; // Unused, can be removed
  late Future<SubscriptionPlan?> _plan1SubscriptionFuture;
  late Future<SubscriptionPlan?> _plan2SubscriptionFuture;
  String? _customerId;
  String? _selectedCategoryKey; 

  @override
  void initState() {
    super.initState();
    _selectedCategoryKey = subscriptionData.first.key; // Initialize with the first category's key
    // _subscriptionPlanFuture = Future.value(null); // Unused, can be removed
    _plan1SubscriptionFuture = Future.value(null);
    _plan2SubscriptionFuture = Future.value(null);
    _loadCustomerId();
  }

  Future<void> _loadCustomerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final loadedCustomerId = prefs.getString('storeId');
    
    if (mounted) {
      setState(() {
        _customerId = loadedCustomerId; 
        if (_customerId != null) {
          // Fetch subscriptions for Plan1 and Plan2 keys
          _plan1SubscriptionFuture = SubscriptionService.getSubscriptionDetails(_customerId!, "Plan1");
          _plan2SubscriptionFuture = SubscriptionService.getSubscriptionDetails(_customerId!, "Plan2");
        } else {
          // Handle case where customerId is missing
          final errorFuture = Future<SubscriptionPlan?>.error('Customer ID not found.');
          _plan1SubscriptionFuture = errorFuture;
          _plan2SubscriptionFuture = errorFuture;
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
            
            // Current subscription cards in a horizontal scroll view
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
                        // FIX: Show a clear error message in the card space
                        return SizedBox(width: 250, child: Center(child: Text('Error loading Plan 1: Customer ID not found.', style: TextStyle(fontSize: 12, color: Colors.red))));
                      } else if (snapshot.hasData && snapshot.data != null) {
                        return _CurrentPlanCard(
                          plan: snapshot.data!,
                          categoryName: 'Plan 1 Current',
                          customerId: _customerId!,
                          subscriptionType: "Plan1", // Use the actual category key
                          isCurrentSubscription: true,
                        );
                      } else {
                        return const SizedBox(width: 250, child: Center(child: Text('No active Plan 1 subscription.', style: TextStyle(fontSize: 14, color: Colors.grey))));
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
                        // FIX: Show a clear error message in the card space
                        return SizedBox(width: 250, child: Center(child: Text('Error loading Plan 2: Customer ID not found.', style: TextStyle(fontSize: 12, color: Colors.red))));
                      } else if (snapshot.hasData && snapshot.data != null) {
                        return _CurrentPlanCard(
                          plan: snapshot.data!,
                          categoryName: 'Plan 2 Current',
                          customerId: _customerId!,
                          subscriptionType: "Plan2", // Use the actual category key
                          isCurrentSubscription: true,
                        );
                      } else {
                        return const SizedBox(width: 250, child: Center(child: Text('No active Plan 2 subscription.', style: TextStyle(fontSize: 14, color: Colors.grey))));
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
                    // Check for error/waiting state for active plan before rendering cards
                    if (activeSnapshot.connectionState == ConnectionState.waiting) {
                      // Optionally show a loading state for the expansion tile
                      // For now, proceed with null activePlan, which is safe.
                    } else if (activeSnapshot.hasError) {
                       // Handle error state, possibly logging it or showing a generic message
                       // For now, proceed with null activePlan
                    }
                    
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
            // FIX: Use optional chaining in toStringAsFixed for safety
            'Price: ₹${(plan.subscriptionPrice ?? 0.0).toStringAsFixed(0)}',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Text(
            'Plan: ${plan.subscriptionPlan ?? 'N/A'}',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Text(
            'Subscription Count: ${plan.subscriptionCount ?? 'N/A'}',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
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
  late Razorpay _razorpay;
  String? _userId;
  String? _userEmail;
  String? _userPhone;

  @override
  void initState() {
    super.initState();
    _checkActivePlan();
    _calculatePrice();
    _itemCountController.addListener(_calculatePrice);
    _loadUserDetails(); // Load user details
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // FIX: Added the missing logic for _checkActivePlan
  void _checkActivePlan() {
    // Check if the current plan's subscriptionPlan matches the active plan's subscriptionPlan
    // and if the categoryKey matches (implicit by the FutureBuilder in the parent).
    _isActivePlan = widget.activePlan?.subscriptionPlan == widget.plan.subscriptionPlan;
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _userEmail = prefs.getString('email');
    _userPhone = prefs.getString('phone');
    setState(() {}); // Trigger rebuild to update UI with fetched details
  }

  @override
  void didUpdateWidget(covariant _NewPlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activePlan != oldWidget.activePlan || widget.plan.subscriptionPlan != oldWidget.plan.subscriptionPlan) {
      _checkActivePlan();
    }
    // Recalculate price in case the plan data itself changed (though less common in this structure)
    if (widget.plan.subscriptionPrice != oldWidget.plan.subscriptionPrice) {
      _calculatePrice();
    }
  }

  @override
  void dispose() {
    _itemCountController.removeListener(_calculatePrice);
    _itemCountController.dispose();
    _razorpay.clear(); // Dispose Razorpay instance
    super.dispose();
  }

  void _calculatePrice() {
    // Safely use 0.0 if subscriptionPrice is null
    final basePrice = widget.plan.subscriptionPrice ?? 0.0;
    final count = int.tryParse(_itemCountController.text) ?? 1;

    if (mounted) {
      setState(() {
        calculatedPrice = basePrice * count;
      });
    }
  }



  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Do something when payment succeeds
    print("SUCCESS: " + response.paymentId!);
    _showSnackBar('Payment Successful: ${response.paymentId}');
    _createSubscriptionAfterPayment();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // Do something when payment fails
    print("ERROR: " + response.code.toString() + " - " + response.message!);
    _showSnackBar('Payment Failed: ${response.code} - ${response.message}');
    if (mounted) setState(() => _isOrdering = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Do something when an external wallet is selected
    print("EXTERNAL WALLET: " + response.walletName!);
    _showSnackBar('External Wallet Selected: ${response.walletName}');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _createSubscriptionAfterPayment() async {
    final int quantity = int.tryParse(_itemCountController.text) ?? 1;

    final Map<String, dynamic> payload = {
      "customerId": widget.customerId,
      "subscriptionType": widget.categoryKey,
      "planName": widget.plan.subscriptionType,
      "subscriptionCount": quantity,
      "totalPrice": calculatedPrice,
      "subscriptionPrice": calculatedPrice,
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
            const SnackBar(content: Text('Failed to create subscription after payment.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating subscription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }

  // FIX: Corrected the misplaced closing brace and the duplicate SnackBar call
  Future<void> _handleOrder() async {
    if (calculatedPrice <= 0) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price cannot be zero or negative.')),
      );
      return;
    }
    
    // if (_isActivePlan) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('This plan is already active.')),
    //   );
    //   return;
    // }

    if (mounted) setState(() => _isOrdering = true);

    // Razorpay integration starts here
    var options = {
      'key': 'rzp_live_efRIa318ph9lot', // Replace with your Razorpay Key ID
      'amount': (calculatedPrice * 100).toInt(), // Amount in paise
      'name': 'Nickname Portal',
      'description': 'Subscription for ${widget.plan.subscriptionType}',
      'prefill': {'contact': _userPhone ?? '', 'email': _userEmail ?? ''}, // Use dynamic user details
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
      _showSnackBar('Error initiating payment: $e');
      if (mounted) setState(() => _isOrdering = false);
    }
    // The previous code had a misplaced closing brace and duplicate logic here.
    // The `_razorpay.open` call is asynchronous and handles success/failure via the listeners.
    // We should not have any synchronous logic after `_razorpay.open(options);` that assumes failure.
    // The `_isOrdering = false` is handled in the payment error callback.
    // The final `finally` block at the end of the original function is now correctly removed/replaced by the try-catch block above.
  } // Corrected closing brace for _handleOrder


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
                  'Price: ₹${(widget.plan.subscriptionPrice ?? 0.0).toStringAsFixed(0)}',
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
                SizedBox( 
                  width: 60, // Set a fixed width for the input field
                  height: 40,
                  child: TextFormField(
                    controller: _itemCountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
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
                          fontSize: 12
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Order Button
                ElevatedButton(
                  onPressed:  _handleOrder, // Disable button if active
                  style: ElevatedButton.styleFrom(
                    backgroundColor:  primaryColor, // Use primary color for non-active
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(40, 40),
                    elevation: 0,
                  ),
                  child: (_isOrdering
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white, // Changed color for visibility on primaryColor background
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Order', style: TextStyle(fontWeight: FontWeight.bold))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}