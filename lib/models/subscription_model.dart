class SubscriptionCategory {
  final String name;
  final String key;
  final List<SubscriptionPlan> plans;

  SubscriptionCategory({
    required this.name,
    required this.key,
    required this.plans,
  });
}

class SubscriptionPlan {
  final String id;
  final String subscriptionType;
  final String subscriptionPlan;
  final double subscriptionPrice;
  final String customerId;
  final int status;
  final int subscriptionCount;
  final int freeCount;

  SubscriptionPlan({
    required this.id,
    required this.subscriptionType,
    required this.subscriptionPlan,
    required this.subscriptionPrice,
    required this.customerId,
    required this.status,
    required this.subscriptionCount,
    required this.freeCount,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'].toString(),
      subscriptionType: json['subscriptionType'] ?? '',
      subscriptionPlan: json['subscriptionPlan'] ?? '',
      subscriptionPrice: double.tryParse(json['subscriptionPrice'].toString()) ?? 0.0,
      customerId: json['customerId'].toString(),
      status: int.tryParse(json['status'].toString()) ?? 0,
      subscriptionCount: json['subscriptionCount'] ?? 0,
      freeCount: json['freeCount'] ?? 0,
    );
  }
}