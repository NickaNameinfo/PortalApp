
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // platform check
import 'dart:io'; // Platform.isAndroid/iOS
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nickname_portal/models/subscription_model.dart';
import 'package:nickname_portal/helpers/subscription_service.dart';
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

// class SubscriptionService {
//   // Placeholder for your actual API service functions
//   static Future<SubscriptionPlan?> getSubscriptionDetails(String customerId, String planKey) async {
//     // Mimic the async call to fetch the current subscription.
//     // Replace with your actual implementation (e.g., using Dio or http).
//     await Future.delayed(const Duration(milliseconds: 500));
//     if (customerId == 'temp_customer' && planKey == 'Plan1') {
//       // Simulate an active current plan for testing 'PL1_003'
//       return SubscriptionPlan(
//         name: 'Premium', key: 'PL1_003', price: 3799.0, defaultValue: 200,
//         subscriptionPlan: 'PL1_003', subscriptionCount: 200,
//       );
//     }
//     return null;
//   }
// }

// --- SubscriptionCard Implementation ---

Map<String, Map<String, dynamic>> planStyleMap = {
  "Starter": {"chipColor": AppColors.success, "buttonColor": AppColors.success, "borderColor": AppColors.success},
  "Standard": {"chipColor": AppColors.primary, "buttonColor": AppColors.primary, "borderColor": AppColors.primary},
  "Premium": {"chipColor": AppColors.secondary, "buttonColor": AppColors.secondary, "borderColor": AppColors.secondary},
  "Customized": {"chipColor": AppColors.textLight, "buttonColor": AppColors.textLight, "borderColor": AppColors.borderColor},
};

class SubscriptionCard extends StatefulWidget {
  final SubscriptionPlan item;
  final SubscriptionCategory subscription;
  // This is the currently active plan details fetched from the API
  final SubscriptionPlan? currentSubscriptionDetails;
  final VoidCallback onPaymentSuccess; // To trigger a refresh in the parent

  const SubscriptionCard({
    super.key,
    required this.item,
    required this.subscription,
    this.currentSubscriptionDetails,
    required this.onPaymentSuccess,
  });

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  late int _itemCount;
  late Razorpay _razorpay;

  bool get _isItemBased => widget.item.key == "PL1_004";
  bool get _isFixedPlan => widget.item.key == "PL1_002" || widget.item.key == "PL1_003";

  @override
  void initState() {
    super.initState();
    // Initialize item count
    _itemCount = widget.item.defaultValue;

    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // --- Price Logic ---

  double _calculateTotalPrice() {
    if (_isFixedPlan) {
      return widget.item.price;
    } else if (_isItemBased) {
      // Base Price + (Per Item Price * Quantity)
      return (widget.item.price * _itemCount) + (widget.item.basePrice ?? 0.0);
    } else {
      // Standard Plan: Per Item Price * Quantity
      return widget.item.price * _itemCount;
    }
  }

  // --- Payment Handlers ---

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _afterPaymentSuccess(response.paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // In React code, they call success temporarily even on error for dev. Mimicking that.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Failed (Dev Mode: Proceeding): ${response.code}')),
    );
    _afterPaymentSuccess("TEMP_PAYMENT_ID_DEV");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Log or handle external wallet selection
  }

  Future<void> _handleSubmit() async {
    final amountInRupees = _calculateTotalPrice();
    if (amountInRupees <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid payment amount.')),
      );
      return;
    }

    final amountInPaisa = (amountInRupees * 100).round();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('firstName') ?? "Guest User";
    final email = prefs.getString('email') ?? "guest@example.com";
    final phone = prefs.getString('phone') ?? "9999999999";

    final options = {
      'key': 'rzp_live_RgPc8rKEOZbHgf', // Replace with your actual key
      'amount': amountInPaisa,
      'currency': 'INR',
      'name': 'Nickname Infotech',
      'description': 'For Subscriptions',
      'prefill': {'name': firstName, 'email': email, 'contact': phone},
      'theme': {'color': AppColors.primaryHex},
      'payment_capture': 1,
    };

    final supportsRazorpay = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    try {
      if (supportsRazorpay) {
        _razorpay.open(options);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment UI not supported here; simulating success.')),
        );
        // Simulate payment success for unsupported platforms
        await _afterPaymentSuccess("TEMP_PAYMENT_ID_DEV", amountInPaisa);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing Razorpay: $e')),
      );
    }
  }

  Future<void> _afterPaymentSuccess(String? paymentId, [int? amountInPaisa]) async {
    int subscriptionCount;
    if (widget.item.key == 'PL1_002') {
      subscriptionCount = 100;
    } else if (widget.item.key == 'PL1_003') {
      subscriptionCount = 200;
    } else if (widget.item.key == 'PL1_004') {
      subscriptionCount = _itemCount + 200;
    } else {
      subscriptionCount = _itemCount;
    }

    final finalAmountInPaisa = amountInPaisa ?? (_calculateTotalPrice() * 100).round();
    final customerId = widget.currentSubscriptionDetails?.customerId ?? widget.item.customerId;

    final payload = {
      "subscriptionCount": subscriptionCount,
      "subscriptionPrice": finalAmountInPaisa,
      "subscriptionType": widget.subscription.key,
      "subscriptionPlan": widget.item.key,
      "customerId": customerId,
      "status": 1,
      "id": widget.currentSubscriptionDetails?.id,
      "freeCount": 0,
      "paymentId": paymentId ?? "TEMP_PAYMENT_ID_DEV",
    };

    final bool ok = await SubscriptionService.createSubscription(payload);
    if (ok) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription created successfully.')),
      );
      widget.onPaymentSuccess(); // refresh parent data
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create subscription.')),
      );
    }
  }

  // --- UI Builders ---

  Widget _buildPriceDisplay() {
    if (_isItemBased) {
      return Text.rich(
        TextSpan(
          text: '₹${widget.item.basePrice?.toStringAsFixed(0) ?? '0'} ',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          children: [
            TextSpan(
              text: '+ ₹${widget.item.price.toStringAsFixed(0)} Per Item',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.textLight),
            ),
          ],
        ),
      );
    }
    return Text(
      '₹${_calculateTotalPrice().toStringAsFixed(0)}',
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildProductRangeDisplay() {
    String range = '';
    if (widget.item.key == "PL1_002") {
      range = ' (1 - 100 Products)';
    } else if (widget.item.key == "PL1_003") {
      range = ' (1 - 200 Products)';
    } else if (widget.item.key == "PL1_004") {
      range = ' (Above 200 Products)';
    }
    return range.isNotEmpty
        ? Text(range, style: const TextStyle(color: AppColors.error, fontSize: 14))
        : const SizedBox.shrink();
  }
  
  // Replicating the feature list structure from the React component
  Widget _buildFeatureList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Key Features:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (var feature in const ['Unlimited Offline Products', 'No Commission', 'Delivery Partner', 'Order Support', 'Store Branding', 'Unlimited Orders'])
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text(feature, style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final planStyles = planStyleMap[widget.item.name] ?? planStyleMap["Customized"]!;
    final isCurrentPlan = widget.currentSubscriptionDetails?.subscriptionPlan == widget.item.key;
    final totalPrice = _calculateTotalPrice();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: planStyles["borderColor"] as Color, width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isCurrentPlan
              ? const LinearGradient(
                  colors: [AppColors.warningLight, AppColors.warningBg],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            // CardHeader
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.item.saveLabel != null)
                          Chip(
                            label: Text(widget.item.saveLabel!),
                            backgroundColor: planStyles["chipColor"] as Color,
                            labelStyle: const TextStyle(color: AppColors.white, fontSize: 12),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              widget.item.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            _buildProductRangeDisplay(),
                          ],
                        ),
                        const Text('Billed Annually (Yearly)', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        if (isCurrentPlan)
                          Text('Current Plan Items : ${widget.currentSubscriptionDetails!.subscriptionCount}',
                              style: const TextStyle(fontSize: 12, color: AppColors.error, height: 1.5)),
                      ],
                    ),
                  ),
                  if (isCurrentPlan)
                    const Chip(label: Text('Current Plan'), backgroundColor: AppColors.warning, labelStyle: TextStyle(color: AppColors.white)),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // CardBody (scrollable, expands to push footer to bottom)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPriceDisplay(),
                    if (widget.item.oldPrice != null)
                      Text('₹${widget.item.oldPrice}',
                          style: const TextStyle(color: AppColors.textLight, fontSize: 14, decoration: TextDecoration.lineThrough)),
                    const Text('Billed Annually', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                    const Divider(height: 24, thickness: 1),
                    if (!_isFixedPlan)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderColor),
                          boxShadow: const [BoxShadow(color: Color(0x21D5D5D5), blurRadius: 8, offset: Offset(0, 2))],
                        ),
                        child: TextFormField(
                          initialValue: _itemCount.toString(),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: widget.item.label ?? "Enter number of item",
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _itemCount = int.tryParse(value) ?? widget.item.defaultValue;
                              if (_itemCount < 1) _itemCount = 1;
                            });
                          },
                        ),
                      ),
                    _buildFeatureList(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // CardFooter (button pinned at bottom)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Price:', style: TextStyle(fontSize: 14, color: AppColors.textLight)),
                      Text('₹${totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  // inside the CardFooter button
                  ElevatedButton(
                    onPressed: (widget.subscription.commingSoon || totalPrice <= 0) ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: planStyles["buttonColor"] as Color,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(widget.item.contactSales ? "Contact Sales" : "Choose Plan"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}