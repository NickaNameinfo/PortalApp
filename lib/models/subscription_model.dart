
class SubscriptionPlan {
  // Fields inferred from React's 'item' object
  final String name;
  final String key;
  final dynamic discription; // Can be a String or a Widget/complex structure
  final String? label;
  final double price; // Per item price
  final String? oldPrice; // For display
  final double? basePrice; // For PL1_004 (Customized plan)
  final int defaultValue; // Initial quantity
  final String? saveLabel;
  final bool contactSales;

  // Fields required by the existing Flutter snippet (for consistency)
  final String id;
  final String subscriptionType;
  final String subscriptionPlan;
  final double subscriptionPrice;
  final String customerId;
  final int status;
  final int subscriptionCount;
  final int freeCount;

  SubscriptionPlan({
    required this.name,
    required this.key,
    this.discription,
    this.label,
    required this.price,
    this.oldPrice,
    this.basePrice,
    required this.defaultValue,
    this.saveLabel,
    this.contactSales = false,
    // Required fields from Flutter context
    this.id = 'temp_id',
    this.subscriptionType = 'temp_type',
    this.subscriptionPlan = 'temp_plan',
    this.subscriptionPrice = 0.0,
    this.customerId = 'temp_customer',
    this.status = 1,
    this.subscriptionCount = 1,
    this.freeCount = 0,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    int parseInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return SubscriptionPlan(
      // Try to map API fields; fallback to sensible defaults
      name: json['name']?.toString() ?? 'Plan',
      key: json['subscriptionPlan']?.toString() ?? json['key']?.toString() ?? 'temp_plan',
      price: parseDouble(json['subscriptionPrice']),
      oldPrice: json['oldPrice']?.toString(),
      basePrice: json['basePrice'] != null ? parseDouble(json['basePrice']) : null,
      defaultValue: parseInt(json['subscriptionCount']),
      saveLabel: json['saveLabel']?.toString(),
      label: json['label']?.toString(),
      // Persisted backend fields
      id: json['id']?.toString() ?? 'temp_id',
      subscriptionType: json['subscriptionType']?.toString() ?? 'temp_type',
      subscriptionPlan: json['subscriptionPlan']?.toString() ?? 'temp_plan',
      subscriptionPrice: parseDouble(json['subscriptionPrice']),
      customerId: json['customerId']?.toString() ?? 'temp_customer',
      status: parseInt(json['status']),
      subscriptionCount: parseInt(json['subscriptionCount']),
      freeCount: parseInt(json['freeCount']),
    );
  }
}

class SubscriptionCategory {
  // Fields inferred from React's 'subscription' object
  final String key;
  final String name;
  final bool commingSoon;
  final List<SubscriptionPlan>? plans;

  SubscriptionCategory({
    required this.key,
    required this.name,
    this.commingSoon = false,
    this.plans,
  });
}