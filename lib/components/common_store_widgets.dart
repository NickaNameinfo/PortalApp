import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart.dart';
import 'package:multivendor_shop/views/main/customer/new_product_details_screen.dart';
import 'package:multivendor_shop/views/main/customer/cart.dart';
import 'package:multivendor_shop/views/main/customer/order.dart';

Widget buildCircleIcon(IconData icon, Color color) {
  return Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(
        color: color.withOpacity(0.3),
        blurRadius: 6,
        offset: const Offset(0, 3)
      )]
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

Widget buildBottomButton(IconData icon, {Color? color}) {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 4,
        offset: const Offset(0, 2)
      )]
    ),
    child: Icon(icon, color: color ?? Colors.black87, size: 20),
  );
}

Widget buildQuantitySelector({
  required int quantity,
  required VoidCallback onIncrement,
  required VoidCallback onDecrement
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(
        color: Colors.grey.withOpacity(0.2),
        blurRadius: 4,
        offset: const Offset(0, 2)
      )],
      border: Border.all(color: Colors.grey.shade300, width: 1)
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onDecrement,
          child: Icon(
            Icons.remove,
            size: 20,
            color: quantity > 0 ? Colors.black54 : Colors.grey[300]
          ),
        ),
        const SizedBox(width: 10),
        Text(quantity.toString(), style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold
        )),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onIncrement,
          child: const Icon(Icons.add, size: 20, color: Colors.black54),
        ),
      ],
    ),
  );
}

Widget buildProductCard(
  BuildContext context,
  Map<String, dynamic> item,
  Map<int, int> cartQuantities,
  Set<int> cartLoadingIds,
  Function(int) incrementQuantity,
  Function(int) decrementQuantity,
  Function(Map<String, dynamic>) addToCart
) {
  if (item['product'] == null || item['product'] is! Map) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text('Error: Invalid product data', style: TextStyle(color: Colors.red[700])),
    );
  }
  final product = item['product'] as Map<String, dynamic>;
  final int? productIdRaw = product['id'] as int?;
  if (productIdRaw == null) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text('Error: Missing product ID', style: TextStyle(color: Colors.red[700])),
    );
  }
  final int productId = productIdRaw;

  final bool available = product['isEnableEcommerce']?.toString() == '1';
  final String? photoUrl = product['photo'] as String?;
  final String productName = product['name']?.toString() ?? 'Unnamed Product';
  final String priceString = product['price']?.toString() ?? 'N/A';
  final String totalString = product['total']?.toString() ?? 'N/A';
  final String unitSize = product['unitSize']?.toString() ?? '';
  final String priceDisplay = unitSize.isNotEmpty ? "$totalString ($unitSize)" : totalString;
  final String stockQty = product['qty']?.toString() ?? '0';
  final String discount = product['discountPer']?.toString() ?? '0';
  final double discountValue = double.tryParse(discount) ?? 0.0;

  final int currentQuantity = cartQuantities[productId] ?? 0;
  final bool isInCart = currentQuantity > 0;
  final bool isCartLoading = cartLoadingIds.contains(productId);

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
        color: Colors.grey.withOpacity(0.15),
        blurRadius: 6,
        offset: const Offset(0, 2)
      )]
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(fit: StackFit.passthrough, children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NewProductDetailsScreen(product: product),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                topLeft: Radius.circular(16)
              ),
              child: Image.network(
                photoUrl ?? 'https://via.placeholder.com/300x200.png?text=Product',
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      topLeft: Radius.circular(16)
                    )
                  ),
                  child: Icon(Icons.image_not_supported,
                    color: Colors.grey[400],
                    size: 50
                  ),
                ),
              ),
            ),
          ),
          if (discountValue > 0) Positioned(
            top: 10, left: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6)
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                "$discount %",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
          if (!available) Positioned(
            bottom: 8, right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12)
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: const Text(
                "Online Order Not Available",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500
                ),
              ),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(productName, style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold
              )),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Rs : $priceDisplay", style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                  )),
                  const SizedBox(width: 8),
                  if (priceString != totalString) Text("Rs : $priceString", style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    decoration: TextDecoration.lineThrough
                  )),
                  const Spacer(),
                  Text(
                    int.tryParse(stockQty) == null || int.parse(stockQty) <= 0
                      ? "Coming soon"
                      : "$stockQty Stocks",
                    style: TextStyle(
                      color: int.tryParse(stockQty) == null || int.parse(stockQty) <= 0
                        ? Colors.orange[700]
                        : Colors.green,
                      fontWeight: FontWeight.w500,
                      fontSize: 13
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Per order", style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54
                      )),
                      Text("Online payment", style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54
                      )),
                      Text("Cash on delivery", style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54
                      )),
                    ],
                  ),
                  if(available)
                    isCartLoading
                      ? const SizedBox(
                          height: 30,
                          width: 30,
                          child: Padding(
                            padding: EdgeInsets.all(4.0),
                            child: CircularProgressIndicator(strokeWidth: 2)
                          )
                        )
                      : isInCart
                        ? buildQuantitySelector(
                            quantity: currentQuantity,
                            onIncrement: () => incrementQuantity(productId),
                            onDecrement: () => decrementQuantity(productId)
                          )
                        : GestureDetector(
                            onTap: () => addToCart(product),
                            child: const Icon(Icons.add_shopping_cart,
                              color: Colors.green,
                              size: 28
                            ),
                          )
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CartScreen()),
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      color: Colors.pink[300] ?? Colors.pink,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewProductDetailsScreen(product: product),
                      ),
                    ),
                    child: const Icon(Icons.remove_red_eye_outlined,
                      color: Colors.black54
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CartScreen()),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.shopping_bag_outlined,
                          color: Colors.purple
                        ),
                        if (currentQuantity > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 14,
                                minHeight: 14
                              ),
                              child: Text(
                                currentQuantity.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CustomerOrderScreen()),
                    ),
                    child: const Icon(Icons.receipt_long,
                      color: Colors.green
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    ),
  );
}