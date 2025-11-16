import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nickname_portal/constants/colors.dart';
import 'package:nickname_portal/views/main/customer/checkout_screen.dart';
import 'package:nickname_portal/helpers/cart_api_helper.dart';
import 'package:nickname_portal/views/main/customer/cart.dart';
import 'package:nickname_portal/views/main/customer/order.dart';
import 'package:nickname_portal/views/main/store/store_details.dart';
import 'package:nickname_portal/utilities/url_launcher_utils.dart';

class NewProductDetailsScreen extends StatefulWidget {
  static const routeName = '/new_product_details_screen';
  final Map<String, dynamic> product;

  const NewProductDetailsScreen({super.key, required this.product});

  @override
  State<NewProductDetailsScreen> createState() => _NewProductDetailsScreenState();
}

class _NewProductDetailsScreenState extends State<NewProductDetailsScreen> {
  // Store data variables
  Map<String, dynamic>? store;
  List<dynamic> products = [];
  bool isLoading = false;
  // Cart state management
  final Map<int, int> _cartQuantities = {};
  final Set<int> _cartLoadingIds = {};
  late String _userId = ''; // Initialize with an empty string

  // Helper to safely access dynamic product fields
  String _safeGet(String key, String fallback) {
    // Accessing map safely and converting to String
    return widget.product[key] is String ? widget.product[key] : widget.product[key]?.toString() ?? fallback;
  }

  // Cart API helper functions will be imported and used directly

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  // Load user ID from shared preferences
  Future<void> _loadUserId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('userId');
    if (userId != null) {
      setState(() {
        _userId = userId;
      });
      _fetchStoreData(); // Load store data after user ID is loaded
    }
  }

  // Fetch store and product data
  Future<void> _fetchStoreData() async {
    if (!isLoading) {
      setState(() {
        isLoading = true;
      });
    }
    try {
      final storeFuture = http.get(Uri.parse(
          'https://nicknameinfo.net/api/store/list/${widget.product['store']['id']}'));
      final productFuture = http.get(Uri.parse(
          'https://nicknameinfo.net/api/store/product/getAllProductById/${widget.product['store']['id']}'));
      final responses = await Future.wait([storeFuture, productFuture]);
      final storeResponse = responses[0];
      final productResponse = responses[1];

      if (storeResponse.statusCode == 200 &&
          productResponse.statusCode == 200) {
        final storeJson = json.decode(storeResponse.body);
        final productJson = json.decode(productResponse.body);

        bool storeSuccess = storeJson['success'] ?? false;
        bool productSuccess = productJson['success'] ?? false;

        if (storeSuccess && productSuccess) {
          // AWAITING THE CART FETCH HERE to ensure _cartQuantities is populated
          await _loadCartData();
          if (mounted) {
            setState(() {
              store = storeJson['data'];
              products = (productJson['data'] as List<dynamic>?) ?? [];
              isLoading = false;
            });
          }
        } else {
          String errorMsg = '';
          if (!storeSuccess) errorMsg += 'Store API error. ';
          if (!productSuccess) errorMsg += 'Product API error. ';
          throw Exception(errorMsg.trim());
        }
      } else {
        String errorMsg = '';
        if (storeResponse.statusCode != 200) errorMsg += 'Store fetch failed: ${storeResponse.statusCode}. ';
        if (productResponse.statusCode != 200) errorMsg += 'Product fetch failed: ${productResponse.statusCode}.';
        throw Exception(errorMsg.trim());
      }
    } catch (e) {
      if (mounted) {
        setState(() { isLoading = false; });
        debugPrint("Error fetching store data: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading store details: ${e.toString()}')));
      }
    }
  }

  Future<void> _loadCartData() async {
    try {
      final response = await fetchCartItems(_userId);
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] is List) {
          final List<dynamic> cartItems = responseData['data'];
          if (mounted) {
            setState(() {
              _cartQuantities.clear();
              for (var item in cartItems) {
                final productId = item['productId'] as int?;
                final quantity = item['qty'] as int?;
                if (productId != null && quantity != null) {
                  _cartQuantities[productId] = quantity;
                }
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error loading cart data: $e');
    }
  }

  Future<void> _addToCart(Map<String, dynamic> productData) async {
    final productId = productData['id'] as int;
    final currentQuantity = _cartQuantities[productId] ?? 0;
    final newQuantity = currentQuantity + 1;

    await _updateCart(productId, newQuantity, productData, isAdd: true);
  }

  Future<void> _incrementQuantity(int productId, Map<String, dynamic> productData) async {
    final currentQuantity = _cartQuantities[productId] ?? 0;
    final newQuantity = currentQuantity + 1;

    await _updateCart(productId, newQuantity, productData, isAdd: false);
  }

  Future<void> _decrementQuantity(int productId, Map<String, dynamic> productData) async {
    final currentQuantity = _cartQuantities[productId] ?? 0;
    if (currentQuantity <= 0) return;
    
    final newQuantity = currentQuantity - 1;

    await _updateCart(productId, newQuantity, productData, isAdd: false);
  }

  Future<void> _removeFromCart(int productId) async {
    if (_cartLoadingIds.contains(productId)) return;
    
    setState(() {
      _cartLoadingIds.add(productId);
    });

    try {
      // Get product data for the updateCart function
      final productData = widget.product;
      final responseData = await updateCart(
        productId: productId,
        newQuantity: 0,
        productData: productData,
        isAdd: false,
        userId: _userId,
        storeId: widget.product['store']?['id']?.toString() ?? 'N/A',
      );
      
      if (responseData['success'] == true) {
        if (mounted) {
          setState(() {
            _cartQuantities.remove(productId);
            _cartLoadingIds.remove(productId);
          });
        }
      } else {
        throw Exception(responseData['message'] ?? 'Failed to remove from cart.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cartLoadingIds.remove(productId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing from cart: $e')),
        );
      }
    }
  }

  // Enhanced cart update method
  Future<void> _updateCart(int productId, int newQuantity, Map<String, dynamic> productData, {required bool isAdd}) async {
    if (!mounted || _cartLoadingIds.contains(productId)) return;

    final int currentQuantity = _cartQuantities[productId] ?? 0;

    setState(() { _cartLoadingIds.add(productId); });

    try {
      // Use the cart API helper to update cart
      if (newQuantity == 0) {
        // For removal, we can use updateCart with quantity 0 or implement a separate remove function
        final responseData = await updateCart(
          productId: productId,
          newQuantity: 0,
          productData: productData,
          isAdd: false,
          userId: _userId,
          storeId: widget.product['store']?['id']?.toString() ?? 'N/A',
        );
        if (responseData['success'] != true) {
          throw Exception(responseData['message'] ?? 'Failed to remove from cart.');
        }
      } else if (currentQuantity == 0 && newQuantity > 0) {
        // Adding new item to cart
        final responseData = await updateCart(
          productId: productId,
          newQuantity: newQuantity,
          productData: productData,
          isAdd: true,
          userId: _userId,
          storeId: widget.product['store']?['id']?.toString() ?? 'N/A',
        );
        if (responseData['success'] != true) {
          throw Exception(responseData['message'] ?? 'Failed to add to cart.');
        }
      } else {
        // Updating existing item
        final responseData = await updateCart(
          productId: productId,
          newQuantity: newQuantity,
          productData: productData,
          isAdd: false,
          userId: _userId,
          storeId: widget.product['store']?['id']?.toString() ?? 'N/A',
        );
        if (responseData['success'] != true) {
          throw Exception(responseData['message'] ?? 'Failed to update cart.');
        }
      }

      if (!mounted) return;

      setState(() {
        if (newQuantity == 0) {
          _cartQuantities.remove(productId);
        } else {
          _cartQuantities[productId] = newQuantity;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${productData['name'] ?? 'Item'} quantity updated to $newQuantity')),
      );
    } catch (e) {
      debugPrint("Error updating cart: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update cart: ${e.toString()}')));
      }
    } finally {
      if (mounted) { setState(() { _cartLoadingIds.remove(productId); }); }
    }
  }

  // Helper method to build a store action icon button
  Widget _buildStoreActionButton(
      {required IconData icon, required Color color, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      splashRadius: 24.0, 
    );
  }

  // Helper method to build circle icon
  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(
      width: 42, 
      height: 42, 
      decoration: BoxDecoration(
        color: color.withOpacity(0.15), 
        shape: BoxShape.circle, 
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3), 
            blurRadius: 6, 
            offset: const Offset(0, 3)
          )
        ]
      ), 
      child: Icon(icon, color: color, size: 20)
    );
  }

  // Store header widget
  Widget buildStoreHeader() {
    final String openTime = store?['openTime'] ?? 'N/A';
    final String closeTime = store?['closeTime'] ?? 'N/A';
    final String openCloseTime = (openTime != 'N/A' && closeTime != 'N/A') ? 'Open : $openTime - $closeTime' : 'Timings not available';
    final String? storePhone = store?['phone'];
    final String? storeWebsite = store?['website'];
    final String storeName = store?['storename'] ?? 'This Store';
    final String? location = store?['location'] ?? store?['storeaddress'];
    final String shareText = 'Check out $storeName! ${storeWebsite != null ? storeWebsite : ""}';

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoreDetails(storeId: widget.product['store']?['id']),
                ),
              );
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    store?['storeImage'] ?? 'https://via.placeholder.com/100x100.png?text=Store', 
                    width: 100, 
                    height: 100, 
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 100, 
                      height: 100, 
                      decoration: BoxDecoration(
                        color: Colors.grey[200], 
                        borderRadius: BorderRadius.circular(12)
                      ), 
                      child: Icon(Icons.storefront, color: Colors.grey[400], size: 40)
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(
                        storeName, 
                        style: const TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.w700, 
                          color: Colors.black
                        ), 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16), 
                          const SizedBox(width: 4), 
                          Text(
                            store?['rating']?.toString() ?? "4.2", 
                            style: const TextStyle(color: Colors.black87, fontSize: 14)
                          )
                        ]
                      ),
                      const SizedBox(height: 4),
                      Text(openCloseTime, style: const TextStyle(color: Colors.black87)),
                      Text("Products : ${products.length}", style: const TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, 
            children: [
              GestureDetector(
                onTap: () { 
                  if (storePhone != null) launchWhatsApp(storePhone); 
                  else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp number not available.'))); 
                }, 
                child: _buildCircleIcon(FontAwesomeIcons.whatsapp, Colors.green)
              ),
              GestureDetector(
                onTap: () { 
                  if (storePhone != null) makePhoneCall(storePhone); 
                  else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not available.'))); 
                }, 
                child: _buildCircleIcon(Icons.phone, Colors.blue)
              ),
              GestureDetector(
                onTap: () { 
                  if (location != null && location.isNotEmpty) openMap(location); 
                  else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available.'))); 
                }, 
                child: _buildCircleIcon(Icons.location_on, Colors.purple)
              ),
              GestureDetector(
                onTap: () { launchWebsite(storeWebsite ?? '', widget.product['store']?['id'] ?? 0); }, 
                child: _buildCircleIcon(Icons.language, Colors.red)
              ),
              GestureDetector(
                onTap: () { 
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StoreDetails(storeId: widget.product['store']?['id']),
                    ),
                  );
                }, 
                child: _buildCircleIcon(Icons.play_arrow_rounded, Colors.teal)
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Quantity selector widget
  Widget buildQuantitySelector({
    required int quantity,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, color: primaryColor, size: 16),
            onPressed: onDecrement,
          ),
          Text(
            quantity.toString(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: primaryColor, size: 16),
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while data is being fetched
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Safely parse data based on the provided API response structure
    final double price = double.tryParse(_safeGet('price', '0')) ?? 0.0;
    // Calculate final price after discount (API: total = 44100)
    final double discountedPrice = double.tryParse(_safeGet('total', price.toString())) ?? price;
    final double discountPer = double.tryParse(_safeGet('discountPer', '0')) ?? 0.0;
    final int stockQty = int.tryParse(_safeGet('unitSize', '0')) ?? 0;
    
    // Check payment modes (API: paymentMode = "1,3")
    final String paymentMode = _safeGet('paymentMode', '');
    final bool isPerOrder = paymentMode.contains('1');
    final bool isOnline = paymentMode.contains('2'); // Not in API example, but safe check
    final bool isCOD = paymentMode.contains('3');

    // Booking functionality
    final bool isBooking = widget.product['isBooking']?.toString() == '1';
    final bool available = stockQty > 0 || isBooking;

    // Tab view height estimation
    const double tabViewHeight = 300; 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Use DefaultTabController for the tabbed interface at the bottom
      body: DefaultTabController(
        length: 3, // Description, Customization, and FeedBack
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Product Image & Main Info Card (Full Width) ---
              Padding(
                padding: const EdgeInsets.all(16.0), 
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _safeGet('photo', 'https://placehold.co/600x400/5E5E5E/FFFFFF/png?text=No+Image'),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 180,
                              color: Colors.grey.shade200,
                              child: const Center(child: Text('Image Failed to Load')),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Product Name & Price
                        Text(
                          _safeGet('name', 'Product Name'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // Discounted Price
                                Text(
                                  '₹${discountedPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Original Price
                                Text(
                                  '₹${price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                            // Stock Indicator
                            Text(
                              isBooking ? 'Booking Only' : (stockQty > 0 ? '($stockQty) Stocks' : 'Out of Stock'),
                              style: TextStyle(
                                fontSize: 16,
                                color: isBooking ? Colors.orange.shade600 : (stockQty > 0 ? Colors.green.shade600 : Colors.red.shade600),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            
                            // Booking Badge
                            if (isBooking)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: Text(
                                  'Booking Only',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),
                        
                        // Payment Mode Checkboxes
                        const Text(
                          'Payment Methods:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 15,
                          runSpacing: 5,
                          children: [
                            _buildCheckItem(isPerOrder, 'Per Order'),
                            _buildCheckItem(isOnline, 'Online Payment'),
                            _buildCheckItem(isCOD, 'Cash On Delivery'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // --- Quantity Selector / Add to Cart ---
                        const SizedBox(height: 15),
                        // --- Quantity Selector / Add to Cart ---
                        Builder(
                          builder: (context) {
                            final productId = widget.product['id'] as int?;
                            final bool isOnlineOrderAvailable = widget.product['isEnableEcommerce']?.toString() == '1';
                            
                            if (productId == null) {
                              return const Text('Product ID not available');
                            }
                            
                            final int currentQuantity = _cartQuantities[productId] ?? 0;
                            final bool isInCart = currentQuantity > 0;
                            final bool isCartLoading = _cartLoadingIds.contains(productId);
                            
                            if (isOnlineOrderAvailable) {
                                return Column(
                                  children: [
                                    // --- NEW ROW TO ALIGN BUTTONS ---
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // --- CHILD 1: Add to Cart / Quantity ---
                                        Expanded(
                                          child: Column(
                                            children: [
                                              if (isCartLoading)
                                                const Center(
                                                  child: SizedBox(
                                                    height: 30,
                                                    width: 30,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                )
                                              else if (isInCart)
                                                buildQuantitySelector(
                                                  quantity: currentQuantity,
                                                  onIncrement: () => _incrementQuantity(
                                                      productId, widget.product),
                                                  onDecrement: () => _decrementQuantity(
                                                      productId, widget.product),
                                                )
                                              else
                                                ElevatedButton.icon(
                                                  onPressed: () => _addToCart(widget.product),
                                                  icon: const Icon(Icons.add_shopping_cart,
                                                      color: Colors.white, size: 18),
                                                  label: const Text('Add to Cart',
                                                      style: TextStyle(
                                                          color: Colors.white, fontSize: 14)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8)),
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 10),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 10), // Spacing between buttons

                                        // --- CHILD 2: Buy Now / Book Now ---
                                        Expanded(
                                          child: Column(
                                            children: [
                                              if (!available)
                                                Text(
                                                  "This product is currently unavailable.",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              if (!available) SizedBox(height: 10),
                                              ElevatedButton(
                                                onPressed: available
                                                    ? () {
                                                        // Create a 'cart-like' item map that CheckoutScreen understands
                                                        final checkoutProduct = {
                                                          'productId': widget.product['id'] ?? '',
                                                          'name': _safeGet('name', 'Product Name'),
                                                          'price': discountedPrice.toString(),
                                                          'qty': 1, // Default quantity for "Buy Now"
                                                          'storeId': widget.product['storeId'] ?? '',
                                                          'photo': _safeGet('photo', ''),
                                                          'isBooking': isBooking, // Pass booking status
                                                          'total': discountedPrice.toString(),
                                                        };

                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => CheckoutScreen(
                                                              product: checkoutProduct,
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    : null,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryColor,
                                                  padding: const EdgeInsets.symmetric(
                                                      vertical: 10, horizontal: 16), // Adjusted padding
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                                child: Text(
                                                  isBooking ? 'Book Now' : 'Order Now',
                                                  style: const TextStyle(
                                                      fontSize: 14, // Adjusted font size
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // --- END OF NEW ROW ---

                                    const SizedBox(height: 10),

                                    // --- This row for icons was already here ---
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        // Cart icon with badge
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => CartScreen(),
                                              ),
                                            );
                                          },
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              const Icon(Icons.shopping_bag_outlined,
                                                  color: Colors.purple),
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
                                                        minWidth: 14, minHeight: 14),
                                                    child: Text(
                                                      currentQuantity.toString(),
                                                      style: const TextStyle(
                                                          color: Colors.white, fontSize: 8),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Orders icon
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => CustomerOrderScreen(),
                                              ),
                                            );
                                          },
                                          child: const Icon(Icons.receipt_long, color: Colors.green),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              } else {
                              return const Text(
                                'Contact the store directly for orders.',
                                style: TextStyle(color: Colors.grey),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // --- 2. Tab Bar for Description/Customization ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10)
                      ),
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: primaryColor,
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.black87,
                        tabs: const [
                          Tab(text: 'Description'),
                          // Tab(text: 'Customization'),
                          Tab(text: 'FeedBack'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Tab Content
                    SizedBox(
                      height: tabViewHeight, // Use a fixed height for the TabBarView
                      child: TabBarView(
                        children: [
                          // Tab 1: Description Card
                          _buildDescriptionCard(_safeGet('sortDesc', 'No detailed description available.')),
                          // Tab 2: Customization Card
                          // _buildCustomizationCard(),
                          // Tab 3: Customization Card
                          _buildFeedBackCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Store Header
              if (store != null) buildStoreHeader(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper widget for payment check items
  Widget _buildCheckItem(bool isChecked, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isChecked ? Icons.check_circle : Icons.cancel,
          color: isChecked ? Colors.green.shade600 : Colors.red.shade400,
          size: 20,
        ),
        const SizedBox(width: 5),
        Text(text),
      ],
    );
  }

  // Helper widget for action icons
  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3))
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  // Helper widget for Description Card content
  Widget _buildDescriptionCard(String description) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor
              ),
            ),
            const SizedBox(height: 10),
            Expanded( // Use Expanded to ensure the text content fills the available height within the TabBarView/SizedBox
              child: SingleChildScrollView( // Allow scrolling for long descriptions
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for Customization Card content
  Widget _buildCustomizationCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customize Product and order items *',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your customization details',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedBackCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give Feed back to imporve our business',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor
              ),
            ),
            const SizedBox(height: 10),
            // TextField(
            //   maxLines: 5,
            //   decoration: InputDecoration(
            //     hintText: 'Enter your feedback',
            //     border: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(10),
            //       borderSide: BorderSide(color: Colors.grey.shade400),
            //     ),
            //     focusedBorder: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(10),
            //       borderSide: const BorderSide(color: primaryColor, width: 2),
            //     ),
            //   ),
            // ),
            const Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}