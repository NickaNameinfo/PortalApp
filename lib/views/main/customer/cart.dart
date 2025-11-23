import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:badges/badges.dart' as badges_lib;
import 'dart:ui';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nickname_portal/constants/colors.dart';
import 'package:nickname_portal/components/loading.dart';
import 'package:nickname_portal/components/gradient_background.dart';
import 'package:nickname_portal/helpers/cart_api_helper.dart';
import 'package:nickname_portal/views/main/customer/new_product_details_screen.dart';
import 'package:nickname_portal/views/main/customer/checkout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Assuming you have these files and constants defined:
// components/loading.dart
// constants/colors.dart
// helpers/cart_api_helper.dart
// views/main/customer/new_product_details_screen.dart

enum Operation { checkoutCart, clearCart }

class CartScreen extends StatefulWidget {
  static const routeName = '/cart_screen';
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<dynamic>> _cartItemsFuture;
  late String _userId = ''; // Initialize with an empty string

  @override
  void initState() {
    super.initState();
    _cartItemsFuture = Future.value([]); // Initialize with an empty future
    _loadUserId();
  }
  
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = (prefs.getString('userId') ?? '0');
      if (_userId != '0') { // Only fetch cart items if a valid userId is present
        _cartItemsFuture = _fetchCartItems();
      }
    });
  }

  Future<void> _updateCartItemQuantity(int productId, int newQuantity, Map<String, dynamic> productData) async {
    try {
      final responseData = await updateCart(
        productId: productId,
        newQuantity: newQuantity,
        productData: productData,
        isAdd: false, // Always update for existing items
        userId: _userId,
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
      final response = await http.delete(
        Uri.parse('https://nicknameinfo.net/api/cart/delete/$_userId/$productId')
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timeout');
        },
      );
      
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
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
    } on SocketException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection.')),
      );
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


  Future<List<dynamic>> _fetchCartItems() async {
    print('Fetching cart items for userId: $_userId');
    try {
      final response = await http.get(
        Uri.parse('https://nicknameinfo.net/api/cart/list/$_userId')
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timeout');
        },
      );
      
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
    } on TimeoutException {
      throw Exception('Request timeout. Please check your internet connection.');
    } on SocketException {
      throw Exception('No internet connection.');
    }
  }

  void _refreshCart() {
    setState(() {
      _cartItemsFuture = _fetchCartItems();
    });
  }

  Future<void> _checkoutCart() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(),
      ),
      );
  }

  Future<void> _clearCart() async {
    // Implement API call to clear cart
    try {
      final response = await http.delete(
        Uri.parse('https://nicknameinfo.net/api/cart/clear/$_userId')
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timeout');
        },
      );
      
      if (response.statusCode == 200) {
        _refreshCart();
      } else {
        print('Clear cart failed');
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
    } on SocketException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection.')),
      );
    } catch (e) {
      print('Clear cart error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear cart: ${e.toString()}')),
      );
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
    final String? size = item['size']?.toString();
    final String? weight = item['weight']?.toString();

    return Dismissible(
      onDismissed: (direction) => _removeFromCart(productId, productName),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.red[400]!, Colors.red[600]!],
          ),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(
          Icons.delete_forever,
          color: Colors.white,
          size: 32,
        ),
      ),
      confirmDismiss: (direction) => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Remove Item',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove $productName from cart?',
            style: TextStyle(color: Colors.grey[700]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove', style: TextStyle(color: Colors.white)),
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
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Product Image
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      productImgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[400],
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (size != null && size.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Size: $size',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (weight != null && weight.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.scale, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Weight: $weight',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '\₹${productPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Quantity Controls
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () => _reduceQuantity(item),
                              icon: Icon(Icons.remove, color: primaryColor, size: 18),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              quantity.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () => _increaseQuantity(item),
                              icon: Icon(Icons.add, color: primaryColor, size: 18),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '\₹${totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 80,
                color: primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your cart is empty',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to get started',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: size.height / 1.5,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 5),
            itemCount: cartItemCount,
            itemBuilder: (context, index) {
              final item = cartItems[index];
              return _buildCartItem(item);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\₹${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: const Icon(
                            Icons.shopping_cart_checkout,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () => _confirmOptions(Operation.checkoutCart),
                          label: const Text(
                            'Checkout',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
        title: const Text(
          'Shopping Cart',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
              onPressed: _refreshCart,
            ),
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