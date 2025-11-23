import 'dart:convert';

class BillingModel {
  final int? id;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? customerAddress;
  final List<BillingProduct> products;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? notes;
  final String? billNumber;
  final DateTime? createdAt;

  BillingModel({
    this.id,
    required this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.customerAddress,
    required this.products,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    this.notes,
    this.billNumber,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'customerName': customerName,
      'customerEmail': customerEmail ?? '',
      'customerPhone': customerPhone ?? '',
      'products': products.map((p) => p.toJson()).toList(),
      'subtotal': subtotal.toStringAsFixed(2),
      'discount': discount.toStringAsFixed(2),
      'tax': tax.toStringAsFixed(2),
      'total': total.toStringAsFixed(2),
      'notes': notes ?? '',
      if (billNumber != null) 'billNumber': billNumber,
    };
  }

  factory BillingModel.fromJson(Map<String, dynamic> json) {
    List<BillingProduct> productsList = [];
    if (json['products'] != null) {
      if (json['products'] is String) {
        final decoded = jsonDecode(json['products']);
        productsList = (decoded as List).map((p) => BillingProduct.fromJson(p)).toList();
      } else if (json['products'] is List) {
        productsList = (json['products'] as List).map((p) => BillingProduct.fromJson(p)).toList();
      }
    }

    return BillingModel(
      id: json['id'],
      customerName: json['customerName'] ?? '',
      customerEmail: json['customerEmail'],
      customerPhone: json['customerPhone'],
      customerAddress: json['customerAddress'],
      products: productsList,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      tax: double.tryParse(json['tax']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      notes: json['notes'],
      billNumber: json['billNumber'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }
}

class BillingProduct {
  final int? id;
  final int? productId;
  final String? name;
  final String? productName;
  final String? photo;
  final double price;
  final int quantity;
  final double total;
  final int? unitSize; // Current unit size for inventory update
  final String? size; // Selected size for size-based products
  final String? weight; // Weight if applicable

  BillingProduct({
    this.id,
    this.productId,
    this.name,
    this.productName,
    this.photo,
    required this.price,
    required this.quantity,
    required this.total,
    this.unitSize,
    this.size,
    this.weight,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (photo != null) 'photo': photo,
      'price': price,
      'quantity': quantity,
      'total': total,
      if (size != null && size!.isNotEmpty) 'size': size,
      if (weight != null && weight!.isNotEmpty) 'weight': weight,
    };
  }

  factory BillingProduct.fromJson(Map<String, dynamic> json) {
    return BillingProduct(
      id: json['id'],
      productId: json['productId'],
      name: json['name'],
      productName: json['productName'],
      photo: json['photo'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      unitSize: json['unitSize'] != null ? int.tryParse(json['unitSize']?.toString() ?? '0') : null,
      size: json['size']?.toString(),
      weight: json['weight']?.toString(),
    );
  }

  BillingProduct copyWith({
    int? id,
    int? productId,
    String? name,
    String? productName,
    String? photo,
    double? price,
    int? quantity,
    double? total,
    int? unitSize,
    String? size,
    String? weight,
  }) {
    return BillingProduct(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      productName: productName ?? this.productName,
      photo: photo ?? this.photo,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      total: total ?? this.total,
      unitSize: unitSize ?? this.unitSize,
      size: size ?? this.size,
      weight: weight ?? this.weight,
    );
  }
}

