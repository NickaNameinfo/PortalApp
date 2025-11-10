import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:nickname_portal/components/gradient_background.dart';
import 'package:nickname_portal/components/nav_bar_container.dart';
import 'package:nickname_portal/utilities/url_launcher_utils.dart'; // Import the utils file
import 'package:nickname_portal/helpers/cart_api_helper.dart';
import 'package:nickname_portal/constants/colors.dart';
import 'package:nickname_portal/views/main/customer/new_product_details_screen.dart';
import 'package:nickname_portal/views/main/customer/cart.dart';
import 'package:nickname_portal/views/main/customer/order.dart';
import 'package:nickname_portal/views/main/store/store_details.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? store;
  List<dynamic> products = [];
  bool isLoading = true;
  int currentIndex = -1;

  // State for Cart
  Map<int, int> _cartQuantities = {};
  Set<int> _cartLoadingIds = {};
  late String _userId = ''; // Initialize with an empty string
  // The cart API endpoint for listing is 'https://nicknameinfo.net/api/cart/list/$_userId'

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
    _loadUserId();
  }

   Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId') ?? '0'; // Default to "0" or handle as needed
      _fetchCartQuantities(); // Call _fetchCartQuantities after _userId is loaded
    });
  }
  
// Global/Top-Level Quantity Selector Widget (Defined here for scope)
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
        blurRadius: 4, offset: const Offset(0, 2)
      )], 
      border: Border.all(color: Colors.grey.shade300, width: 1)
    ),
    child: Row( mainAxisSize: MainAxisSize.min, children: [
        GestureDetector( onTap: onDecrement, child: Icon( 
          Icons.remove, 
          size: 20, 
          color: quantity > 0 ? Colors.black54 : Colors.grey[300]
        )),
        const SizedBox(width: 10),
        Text(quantity.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        GestureDetector( onTap: onIncrement, child: const Icon(Icons.add, size: 20, color: Colors.black54)),
      ],
    ),
  );
}
// ----------------------------------------------------

Widget _buildCircleIcon(IconData icon, Color color) {
  return Container(width: 42, height: 42, decoration: BoxDecoration( color: color.withOpacity(0.15), shape: BoxShape.circle, boxShadow: [BoxShadow( color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]), child: Icon(icon, color: color, size: 20));
}

Future<void> _fetchCartQuantities() async {
    final url = Uri.parse('https://nicknameinfo.net/api/cart/list/$_userId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] is List) {
          final List<dynamic> cartItems = responseData['data'];
          final Map<int, int> fetchedQuantities = {};

          for (var item in cartItems) {
            final int? productId = item['productId'] as int?;
            final int? quantity = item['qty'] as int?;

            if (productId != null && quantity != null && quantity > 0) {
              fetchedQuantities[productId] = quantity;
            }
          }

          if (mounted) {
            // Update the cart quantities state
            setState(() {
              _cartQuantities = fetchedQuantities;
            });
          }
        } else {
          debugPrint("Cart list API returned success: false or invalid data structure.");
        }
      } else {
        debugPrint("Failed to fetch cart list. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching cart quantities: $e");
    }
  }

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
           await _fetchCartQuantities();
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
  // --- Cart Update Logic (Copied from your prompt) ---

  Future<void> _updateCart(int productId, int newQuantity, Map<String, dynamic> productData, {required bool isAdd}) async {
    if (!mounted || _cartLoadingIds.contains(productId)) return;

    setState(() { _cartLoadingIds.add(productId); });

    try {
      // NOTE: Using the mock 'updateCart' defined above.
      final responseData = await updateCart(
        productId: productId,
        newQuantity: newQuantity,
        productData: productData,
        isAdd: isAdd,
        userId: _userId,
        storeId: widget.product['store']?['id']?.toString() ?? 'N/A', // Assuming store ID is here
      );

      if (!mounted) return;

      if (responseData['success'] == true) {
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
      } else {
        throw Exception(responseData['message'] ?? 'Failed to update cart.');
      }
    } catch (e) {
      debugPrint("Error updating cart: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update cart: ${e.toString()}')));
      }
    } finally {
      if (mounted) { setState(() { _cartLoadingIds.remove(productId); }); }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final int? productIdRaw = product['id'] as int?;
    if (productIdRaw == null) {
       debugPrint("Error: Product ID is null in _addToCart");
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add item: Invalid product data.')));
       return;
    }
    final int productId = productIdRaw;
    final int currentQuantity = _cartQuantities[productId] ?? 0;
    final int newQuantity = currentQuantity + 1;

    await _updateCart(productId, newQuantity, product, isAdd: true);
  }

  Future<void> _incrementQuantity(int productId, Map<String, dynamic> productData) async {
     final int currentQuantity = _cartQuantities[productId] ?? 0;
     final int newQuantity = currentQuantity + 1;
     await _updateCart(productId, newQuantity, productData, isAdd: false);
  }

  Future<void> _decrementQuantity(int productId, Map<String, dynamic> productData) async {
     final int currentQuantity = _cartQuantities[productId] ?? 0;
     if (currentQuantity <= 0) return;
     final int newQuantity = currentQuantity - 1;
     
     await _updateCart(productId, newQuantity, productData, isAdd: false);
  }

  // Helper method to build a store action icon button (placeholder logic)
  Widget _buildStoreActionButton(
      {required IconData icon, required Color color, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      splashRadius: 24.0, 
    );
  }

Widget buildStoreHeader() {
    final String openTime = store?['openTime'] ?? 'N/A';
    final String closeTime = store?['closeTime'] ?? 'N/A';
    final String openCloseTime = (openTime != 'N/A' && closeTime != 'N/A') ? 'Open : $openTime - $closeTime' : 'Timings not available';
    final String? storePhone = store?['phone'];
    final String? storeWebsite = store?['website'];
    final String storeName = store?['storename'] ?? 'This Store';
    final String? location = store?['location'] ?? store?['storeaddress'];
    final String shareText = 'Check out $storeName! ${storeWebsite != null ? storeWebsite : ""}';

    return NavBarContainer(
      child: Padding(
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
                    child: Image.network( store?['storeImage'] ?? 'https://via.placeholder.com/100x100.png?text=Store', width: 100, height: 100, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Icon(Icons.storefront, color: Colors.grey[400], size: 40)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(storeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(children: [ const Icon(Icons.star, color: Colors.amber, size: 16), const SizedBox(width: 4), Text(store?['rating']?.toString() ?? "4.2", style: const TextStyle(color: Colors.black87, fontSize: 14))]),
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
            Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                GestureDetector( onTap: () { if (storePhone != null) launchWhatsApp(storePhone); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp number not available.'))); }, child: _buildCircleIcon(FontAwesomeIcons.whatsapp, Colors.green)),
                GestureDetector( onTap: () { if (storePhone != null) makePhoneCall(storePhone); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not available.'))); }, child: _buildCircleIcon(Icons.phone, Colors.blue)),
                GestureDetector( onTap: () { if (location != null && location.isNotEmpty) openMap(location); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available.'))); }, child: _buildCircleIcon(Icons.location_on, Colors.purple)),
                GestureDetector( onTap: () { launchWebsite(storeWebsite ?? '', widget.product['store']?['id'] ?? 0); }, child: _buildCircleIcon(Icons.language, Colors.red)),
                GestureDetector( onTap: () { Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StoreDetails(storeId: widget.product['store']?['id']),
                  ),
                );
                 }, child: _buildCircleIcon(Icons.play_arrow_rounded, Colors.teal)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safely extract product data
    final Map<String, dynamic> product = widget.product;
    final Map<String, dynamic>? storeData = product['store'] as Map<String, dynamic>?;
    final bool isOnlineOrderAvailable = product['isEnableEcommerce'] == '1';
    final int? productId = product['id'] as int?;

    // Cart state checks
    final int currentQuantity = productId != null ? (_cartQuantities[productId] ?? 0) : 0;
    final bool isInCart = currentQuantity > 0;
    final bool isCartLoading = productId != null ? _cartLoadingIds.contains(productId) : false;
    
    // Safely extract store details
    final String storeName = storeData?['storename'] ?? 'N/A';
    final String storeImage = storeData?['storeImage'] ?? 'https://via.placeholder.com/150';
    final String openTime = storeData?['openTime'] ?? 'N/A';
    final String closeTime = storeData?['closeTime'] ?? 'N/A';
    final String totalProducts = storeData?['totalProducts']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Store Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- 1. Product Details Card ---
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image with Badges
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NewProductDetailsScreen(product: product),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    product['photo'] ?? 'https://via.placeholder.com/150',
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                // 'Available' Badge
                                Positioned(
                                  top: 10, left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(5)),
                                    child: const Text('Available', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                // 'Online Order Not Available' Badge
                                if (!isOnlineOrderAvailable)
                                  Positioned(
                                    bottom: 10, left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)),
                                      child: const Text('Online Order Not Available', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            
                            // Product Name
                            Text(
                              product['name'] ?? 'N/A',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      
                      // Unit Size / Approx Weight
                      Text(
                        '${product['unitSize'] ?? 'N/A'} pcs (Approx. 550 - 640 g)',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      
                      // Stock and Price Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${product['qty'] ?? 0} Stocks',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          Text(
                            'Rs : ${product['total'] ?? 0}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 15),
                      // --- Quantity Selector / Add to Cart ---
                      if (isOnlineOrderAvailable && productId != null)
                        isCartLoading
                            ? const Center(
                                child: SizedBox(
                                  height: 30,
                                  width: 30,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : isInCart
                                ? buildQuantitySelector(
                                    quantity: currentQuantity,
                                    onIncrement: () => _incrementQuantity(productId, product),
                                    onDecrement: () => _decrementQuantity(productId, product),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () => _addToCart(product),
                                    icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                                    label: const Text('Add to Cart', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    ),
                                  ),
                      
                      if (!isOnlineOrderAvailable)
                        const Text(
                          'Contact the store directly for orders.', 
                          style: TextStyle(color: Colors.grey),
                        ),
                     const SizedBox(height: 10),
                     Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CartScreen(),
                                        ),
                                      );
                                    },
                                  child: Icon(
                                      Icons.favorite_border,
                                      color: Colors.pink[300] ?? Colors.pink, // <-- Fix applied here
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CartScreen(),
                                        ),
                                      );
                                    },
                                    child : Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(Icons.shopping_bag_outlined, color: Colors.purple),
                                      // Only show the badge if quantity > 0
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
                                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                            child: Text(
                                              currentQuantity.toString(), // Use the variable
                                              style: const TextStyle(color: Colors.white, fontSize: 8),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  ),
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
                              )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // --- 2. Store Information Card ---
               buildStoreHeader(),
            ],
          ),
        ),
      ),
    );
  }
}