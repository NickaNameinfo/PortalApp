import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:badges/badges.dart' as badges_lib;
import 'dart:ui';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:multivendor_shop/constants/colors.dart';
import 'package:multivendor_shop/components/loading.dart';
import 'package:multivendor_shop/components/gradient_background.dart';
import 'package:multivendor_shop/helpers/cart_api_helper.dart';
import 'package:multivendor_shop/views/main/customer/new_product_details_screen.dart';

// Assuming you have these files and constants defined:
// components/loading.dart
// constants/colors.dart
// helpers/cart_api_helper.dart
// views/main/customer/new_product_details_screen.dart

enum Operation { checkoutCart, clearCart }

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<dynamic>> _cartItemsFuture;
  final String userId = '48'; // This should ideally come from authentication

  Future<void> _updateCartItemQuantity(int productId, int newQuantity, Map<String, dynamic> productData) async {
    try {
      final responseData = await updateCart(
        productId: productId,
        newQuantity: newQuantity,
        productData: productData,
        isAdd: false, // Always update for existing items
        userId: userId,
        storeId: productData['storeId']?.toString() ?? '', // Assuming storeId is available in productData
      );

      if (responseData['success'] == true) {
        _refreshCart();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${productData['name'] ?? 'Item'} quantity updated to $newQuantity')),
        );
      } else {
        throw Exception(responseData['message'] ?? 'Failed to update cart item.');
      }
    } catch (e) {
      debugPrint("Error updating cart item: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update cart item: ${e.toString()}')));
    }
  }

  Future<void> _removeFromCart(int productId, String productName) async {
    try {
      final response = await http.delete(Uri.parse('https://nicknameinfo.net/api/cart/delete/$userId/$productId'));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _refreshCart();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$productName removed from cart.')),
          );
        } else {
          throw Exception(responseData['message'] ?? 'Failed to remove item from cart.');
        }
      } else {
        throw Exception('Failed to remove item from cart: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error removing from cart: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not remove item: ${e.toString()}')));
    }
  }

  void _increaseQuantity(Map<String, dynamic> item) {
    final int currentQty = item['qty'] ?? 0;
    final int newQuantity = currentQty + 1;
    _updateCartItemQuantity(item['productId'], newQuantity, item);
  }

  void _reduceQuantity(Map<String, dynamic> item) {
    final int currentQty = item['qty'] ?? 0;
    if (currentQty > 1) {
      final int newQuantity = currentQty - 1;
      _updateCartItemQuantity(item['productId'], newQuantity, item);
    } else {
      _removeFromCart(item['productId'], item['name']);
    }
  }

  @override
  void initState() {
    super.initState();
    _cartItemsFuture = _fetchCartItems();
  }

  Future<List<dynamic>> _fetchCartItems() async {
    final response = await http.get(Uri.parse('https://nicknameinfo.net/api/cart/list/$userId'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'];
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to load cart items');
    }
  }

  void _refreshCart() {
    setState(() {
      _cartItemsFuture = _fetchCartItems();
    });
  }

  Future<void> _checkoutCart() async {
    // Implement API call to checkout cart
    final response = await http.post(Uri.parse('https://nicknameinfo.net/api/cart/checkout/$userId'));
    if (response.statusCode == 200) {
      _refreshCart();
    } else {
      print('Checkout failed');
    }
  }

  Future<void> _clearCart() async {
    // Implement API call to clear cart
    final response = await http.delete(Uri.parse('https://nicknameinfo.net/api/cart/clear/$userId'));
    if (response.statusCode == 200) {
      _refreshCart();
    } else {
      print('Clear cart failed');
    }
  }

  void _confirmOptions(Operation operation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              operation == Operation.clearCart
                  ? Icons.remove_shopping_cart_outlined
                  : Icons.shopping_cart_checkout_outlined,
              color: primaryColor,
            ),
            Text(
              operation == Operation.clearCart
                  ? 'Confirm Clear'
                  : 'Confirm Checkout',
              style: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          operation == Operation.clearCart
              ? 'Are you sure you want to clear cart?'
              : 'Are you sure you want to checkout cart?',
          style: const TextStyle(
            color: primaryColor,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              operation == Operation.clearCart ? _clearCart() : _checkoutCart();
            },
            child: const Text(
              'Yes',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final int productId = item['productId'] ?? 0;
    final String productName = item['name'] ?? 'N/A';
    final String productImgUrl = item['photo'] ?? 'https://via.placeholder.com/100';
    final double productPrice = (item['price'] is num) ? (item['price'] as num).toDouble() : (double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0);
    final int quantity = item['qty'] ?? 0;
    final double totalPrice = productPrice * quantity;

    return Dismissible(
      onDismissed: (direction) => _removeFromCart(productId, productName),
      direction: DismissDirection.endToStart,
      background: Container(
        height: 115,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.red,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_forever,
          color: Colors.white,
          size: 40,
        ),
      ),
      confirmDismiss: (direction) => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Remove $productName'),
          content: Text(
            'Are you sure you want to remove $productName from cart?',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Yes',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      key: ValueKey(productId),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewProductDetailsScreen(product: item),
            ),
          );
        },
        child: Card(
          elevation: 3,
          child: ListTile(
            contentPadding: const EdgeInsets.only(
              left: 10,
              right: 10,
              top: 5,
            ),
            leading: CircleAvatar(
              backgroundColor: primaryColor,
              backgroundImage: NetworkImage(productImgUrl),
            ),
            title: Text(
              productName,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\$${totalPrice.toStringAsFixed(2)}'),
                const SizedBox(height: 5),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _increaseQuantity(item),
                      child: const Icon(
                        Icons.add,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      quantity.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _reduceQuantity(item),
                      child: const Icon(
                        Icons.remove,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              onPressed: () => _removeFromCart(productId, productName),
              icon: const Icon(
                Icons.delete_forever,
                color: primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartContent(List<dynamic> cartItems, double total) {
    final Size size = MediaQuery.of(context).size;
    final int cartItemCount = cartItems.length;

    if (cartItemCount < 1) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/sp2.png',
            width: 250,
          ),
          const SizedBox(height: 10),
          const Text(
            'Opps! No items to display',
            style: TextStyle(
              color: primaryColor,
              fontSize: 18,
            ),
          )
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: size.height / 1.3,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 5),
            itemCount: cartItemCount,
            itemBuilder: (context, index) {
              final item = cartItems[index];
              return _buildCartItem(item);
            },
          ),
        ),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 28,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.shopping_cart_checkout,
                      color: Colors.white,
                    ),
                    onPressed: () => _confirmOptions(Operation.checkoutCart),
                    label: const Text(
                      'Checkout',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A5ACD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Cart',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 30),
            onPressed: _refreshCart,
          ),
        ],
      ),
      body: Container(
        decoration: gradientBackgroundDecoration,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: FutureBuilder<List<dynamic>>(
          future: _cartItemsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Loading(
                  color: primaryColor,
                  kSize: 30,
                ),
              );
            } else if (snapshot.hasError) {
              return const Center(
                child: Text('Failed to load cart. Please try again.'),
              );
            }

            final cartItems = snapshot.data ?? [];
            double totalPrice = 0.0;
            for (var item in cartItems) {
              totalPrice += (item['price'] ?? 0) * (item['qty'] ?? 0);
            }

            return _buildCartContent(cartItems, totalPrice);
          },
        ),
      ),
      ),
    );
  }
}