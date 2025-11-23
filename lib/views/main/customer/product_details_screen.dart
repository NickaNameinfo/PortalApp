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
import 'package:nickname_portal/views/main/customer/checkout_screen.dart';
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
  Map<int, String?> _cartSizes = {}; // Store size from cart for each product
  Set<int> _cartLoadingIds = {};
  late String _userId = ''; // Initialize with an empty string
  // The cart API endpoint for listing is 'https://nicknameinfo.net/api/cart/list/$_userId'
  
  // Size selection state
  String? _selectedSize;
  String? _selectedWeight;
  double _currentPrice = 0.0;
  int _currentStock = 0;
  Map<String, dynamic>? _sizeUnitSizeMap;

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
    });
    // Fetch cart first, then initialize size data (so cart size can be used)
    await _fetchCartQuantities(); // Call _fetchCartQuantities after _userId is loaded
  }
  
  // Initialize size data from product
  void _initializeSizeData() {
    try {
      final sizeUnitSizeMapStr = widget.product['sizeUnitSizeMap'];
      if (sizeUnitSizeMapStr != null && sizeUnitSizeMapStr is String) {
        _sizeUnitSizeMap = json.decode(sizeUnitSizeMapStr) as Map<String, dynamic>?;
      } else if (sizeUnitSizeMapStr is Map) {
        _sizeUnitSizeMap = Map<String, dynamic>.from(sizeUnitSizeMapStr);
      }
      
      // Set default size (first available or from cart)
      if (_sizeUnitSizeMap != null && _sizeUnitSizeMap!.isNotEmpty) {
        final productId = widget.product['id'] as int?;
        // Check cart for existing size (prioritize cart size)
        final cartSize = productId != null 
            ? (_cartSizes[productId] ?? widget.product['size']?.toString())
            : widget.product['size']?.toString();
        if (cartSize != null && _sizeUnitSizeMap!.containsKey(cartSize)) {
          _selectedSize = cartSize;
        } else {
          _selectedSize = _sizeUnitSizeMap!.keys.first;
        }
        _updatePriceAndStock();
      }
    } catch (e) {
      debugPrint('Error initializing size data: $e');
    }
  }
  
  // Update price and stock based on selected size
  void _updatePriceAndStock() {
    if (_selectedSize != null && _sizeUnitSizeMap != null) {
      final sizeData = _sizeUnitSizeMap![_selectedSize];
      if (sizeData is Map) {
        _currentPrice = double.tryParse(sizeData['price']?.toString() ?? 
                                        sizeData['total']?.toString() ?? 
                                        sizeData['grandTotal']?.toString() ?? 
                                        widget.product['total']?.toString() ?? 
                                        widget.product['price']?.toString() ?? '0') ?? 0.0;
        _currentStock = int.tryParse(sizeData['unitSize']?.toString() ?? '0') ?? 0;
      }
    } else {
      // Fallback to default product price and stock
      _currentPrice = double.tryParse(widget.product['total']?.toString() ?? 
                                     widget.product['price']?.toString() ?? '0') ?? 0.0;
      _currentStock = int.tryParse(widget.product['unitSize']?.toString() ?? '0') ?? 0;
    }
  }
  
// Global/Top-Level Quantity Selector Widget (Defined here for scope)
Widget buildQuantitySelector({
  required int quantity,
  required VoidCallback onIncrement,
  required VoidCallback onDecrement
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white, 
      borderRadius: BorderRadius.circular(12), 
      boxShadow: [
        BoxShadow( 
          color: Colors.black.withOpacity(0.08), 
          blurRadius: 8, 
          offset: const Offset(0, 2)
        )
      ], 
      border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5)
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onDecrement,
            icon: Icon(
              Icons.remove,
              size: 18,
              color: quantity > 0 ? primaryColor : Colors.grey[400],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            quantity.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onIncrement,
            icon: Icon(Icons.add, size: 18, color: primaryColor),
          ),
        ),
      ],
    ),
  );
}
// ----------------------------------------------------

Widget _buildCircleIcon(IconData icon, Color color) {
  return Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      shape: BoxShape.circle,
      border: Border.all(color: color.withOpacity(0.3), width: 2),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Icon(icon, color: color, size: 22),
  );
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
          final Map<int, String?> fetchedSizes = {};

          for (var item in cartItems) {
            final int? productId = item['productId'] as int?;
            final int? quantity = item['qty'] as int?;
            final String? size = item['size']?.toString();

            if (productId != null && quantity != null && quantity > 0) {
              fetchedQuantities[productId] = quantity;
              if (size != null && size.isNotEmpty) {
                fetchedSizes[productId] = size;
              }
            }
          }

          if (mounted) {
            // Update the cart quantities and sizes state
            setState(() {
              _cartQuantities = fetchedQuantities;
              _cartSizes = fetchedSizes;
            });
            // Re-initialize size data after cart is loaded to use cart size
            _initializeSizeData();
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
    
    // Stock validation
    final availableStock = _selectedSize != null && _sizeUnitSizeMap != null
        ? _currentStock
        : int.tryParse(product['unitSize']?.toString() ?? '0') ?? 0;
    
    if (currentQuantity >= availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only $availableStock items available in stock')),
      );
      return;
    }
    
    final int newQuantity = currentQuantity + 1;
    
    // Include size and weight in product data
    final productWithSize = Map<String, dynamic>.from(product);
    if (_selectedSize != null) {
      productWithSize['size'] = _selectedSize;
      productWithSize['price'] = _currentPrice;
      productWithSize['total'] = _currentPrice;
    }
    if (_selectedWeight != null) {
      productWithSize['weight'] = _selectedWeight;
    }

    await _updateCart(productId, newQuantity, productWithSize, isAdd: true);
  }

  Future<void> _incrementQuantity(int productId, Map<String, dynamic> productData) async {
     final int currentQuantity = _cartQuantities[productId] ?? 0;
     
     // Stock validation
     final availableStock = _selectedSize != null && _sizeUnitSizeMap != null
         ? _currentStock
         : int.tryParse(productData['unitSize']?.toString() ?? '0') ?? 0;
     
     if (currentQuantity >= availableStock) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Only $availableStock items available in stock')),
       );
       return;
     }
     
     final int newQuantity = currentQuantity + 1;
     
     // Include size in product data
     final productWithSize = Map<String, dynamic>.from(productData);
     if (_selectedSize != null) {
       productWithSize['size'] = _selectedSize;
       productWithSize['price'] = _currentPrice;
       productWithSize['total'] = _currentPrice;
     }
     
     await _updateCart(productId, newQuantity, productWithSize, isAdd: false);
  }

  Future<void> _decrementQuantity(int productId, Map<String, dynamic> productData) async {
     final int currentQuantity = _cartQuantities[productId] ?? 0;
     if (currentQuantity <= 0) return;
     final int newQuantity = currentQuantity - 1;
     
     // Include size in product data
     final productWithSize = Map<String, dynamic>.from(productData);
     if (_selectedSize != null) {
       productWithSize['size'] = _selectedSize;
       productWithSize['price'] = _currentPrice;
       productWithSize['total'] = _currentPrice;
     }
     if (_selectedWeight != null) {
       productWithSize['weight'] = _selectedWeight;
     }
     
     await _updateCart(productId, newQuantity, productWithSize, isAdd: false);
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
                    child: Image.network( store?['storeImage'] ?? 'https://via.placeholder.com/100x100.png?text=Store', width: 100, height: 100, fit: BoxFit.contain,
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
    
    // Booking functionality
    final bool isBooking = product['isBooking']?.toString() == '1';
    final String stockQty = product['qty']?.toString() ?? '0';
    final bool available = isOnlineOrderAvailable;

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
      backgroundColor: Colors.grey[100],
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
          'Product Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- 1. Product Details Card ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
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
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                // 'Available' Badge
                                Positioned(
                                  top: 12, left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.green[400]!, Colors.green[600]!],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'Available',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                // 'Online Order Not Available' Badge
                                if (!isOnlineOrderAvailable && !isBooking)
                                  Positioned(
                                    bottom: 12, left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.red[400]!, Colors.red[600]!],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Online Order Not Available',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                // 'Booking Only' Badge
                                if (isBooking)
                                  Positioned(
                                    bottom: 12, right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.orange[400]!, Colors.orange[600]!],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.orange.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Booking Only',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
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
                            int.tryParse(stockQty) == null || int.parse(stockQty) <= 0 && !isBooking ? "Coming soon" : isBooking ? "Booking Only" : "${_currentStock > 0 ? _currentStock : stockQty} Stocks",
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold, 
                              color: int.tryParse(stockQty) == null || int.parse(stockQty) <= 0 ? Colors.orange[700] : Colors.green
                            ),
                          ),
                          Text(
                            'Rs : ${_currentPrice > 0 ? _currentPrice.toStringAsFixed(0) : (product['total'] ?? 0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ],
                      ),
                      
                      // Size Selection UI
                      if (_sizeUnitSizeMap != null && _sizeUnitSizeMap!.isNotEmpty) ...[
                        const SizedBox(height: 15),
                        const Divider(),
                        const SizedBox(height: 10),
                        const Text(
                          'Size:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _sizeUnitSizeMap!.keys.map((size) {
                            final sizeData = _sizeUnitSizeMap![size];
                            final isSelected = _selectedSize == size;
                            final unitSize = sizeData is Map 
                                ? sizeData['unitSize']?.toString() ?? ''
                                : '';
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedSize = size;
                                  _updatePriceAndStock();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? primaryColor : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  unitSize.isNotEmpty ? '$size: $unitSize' : size,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      
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
                                : Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.green[400]!, Colors.green[600]!],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: () => _addToCart(product),
                                      icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
                                      label: const Text(
                                        'Add to Cart',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      ),
                                    ),
                                  ),
                      
                      if (!isOnlineOrderAvailable)
                        const Text(
                          'Contact the store directly for orders.', 
                          style: TextStyle(color: Colors.grey),
                        ),
                     const SizedBox(height: 10),
                     Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                                  if (isBooking || available)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, primaryColor.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            // Create a 'cart-like' item map that CheckoutScreen understands
                            final checkoutProduct = {
                              'productId': productId,
                              'name': product['name'] ?? 'N/A',
                              'price': (_currentPrice > 0 ? _currentPrice : (double.tryParse(product['total']?.toString() ?? '0') ?? 0)),
                              'qty': 1, // Default quantity for "Buy Now"
                              'storeId': storeData?['id'], // Pass the storeId
                              'photo': product['photo'] ?? 'https://via.placeholder.com/150', // Pass photo for summary
                              'isBooking': isBooking, // Pass booking status
                              if (_selectedSize != null) 'size': _selectedSize,
                              if (_selectedWeight != null) 'weight': _selectedWeight,
                            };
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CheckoutScreen(product: checkoutProduct),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isBooking ? 'Book Now' : 'Order Now',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
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