import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nickname_portal/components/gradient_background.dart';
import 'package:nickname_portal/components/nav_bar_container.dart';
import 'package:nickname_portal/utilities/url_launcher_utils.dart'; // Import the utils file
import 'package:nickname_portal/helpers/cart_api_helper.dart';
import 'package:nickname_portal/views/main/customer/new_product_details_screen.dart';
import 'package:nickname_portal/views/main/customer/cart.dart';
import 'package:nickname_portal/views/main/customer/order.dart';
import 'package:nickname_portal/views/main/customer/checkout_screen.dart';
import 'package:nickname_portal/utilities/auth_helper.dart';
import 'package:nickname_portal/constants/app_config.dart';
import 'package:nickname_portal/helpers/secure_http_client.dart';
import 'package:nickname_portal/utils/visit_tracker.dart';

import '../../../constants/colors.dart';

class StoreDetails extends StatefulWidget {
  final int storeId;
  const StoreDetails({super.key, required this.storeId});

  @override
  State<StoreDetails> createState() => _StoreDetailsState();
}

class _StoreDetailsState extends State<StoreDetails> {
  Map<String, dynamic>? store;
  List<dynamic> products = [];
  bool isLoading = true;
  List<dynamic> allStores = [];
  int currentIndex = -1;
  final ScrollController _productsScrollController = ScrollController();
  bool _productsLoading = false;
  bool _productsHasMore = true;
  int _productsPage = 1;
  int _productsTotalCount = 0;
  final int _shuffleSeed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  final TextEditingController _productSearchController = TextEditingController();
  String _productSearchQuery = "";

  // State for Cart
  Map<int, int> _cartQuantities = {}; 
  Map<int, String?> _cartSizes = {}; // Store size from cart for each product
  Set<int> _cartLoadingIds = {};
  late String _userId = ''; // Initialize with an empty string
  // Cart list uses AppConfig.baseApi

  // Payment/Order Info flags
  bool isPerOrder = false;
  bool isOnline = false;
  bool isCOD = false;
  
  // Size selection state - Map of productId to selected size
  Map<int, String?> _selectedSizes = {};
  Map<int, double> _currentPrices = {};
  Map<int, int> _currentStocks = {};
  Map<int, double> _currentDiscounts = {}; // Store discount percentage for each product
  Map<int, double> _originalPrices = {}; // Store original price before discount for each product
  Map<int, Map<String, dynamic>?> _sizeUnitSizeMaps = {};

  @override
  void initState() {
    super.initState();
    VisitTracker.recordStoreVisit(widget.storeId);
    _loadUserId();
    _productsScrollController.addListener(() {
      if (!_productsHasMore || _productsLoading) return;
      final pos = _productsScrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 350) {
        _loadMoreProducts();
      }
    });
  }

  @override
  void dispose() {
    _productsScrollController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId') ?? '0'; // Default to "0" or handle as needed
      _fetchStoreData(); // Call _fetchStoreData after _userId is loaded
    });
  }

  // NEW: Function to fetch existing cart quantities for the user
  Future<void> _fetchCartQuantities() async {
    final url = Uri.parse('${AppConfig.baseApi}/cart/list/$_userId');

    try {
      final response = await SecureHttpClient.get(
        url.toString(),
        timeout: const Duration(seconds: 15),
        context: context,
      );

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
          }
        } else {
          debugPrint("Cart list API returned success: false or invalid data structure.");
        }
      } else {
        debugPrint("Failed to fetch cart list. Status: ${response.statusCode}");
      }
    } on TimeoutException {
      debugPrint("Cart quantities request timed out");
    } on SocketException {
      debugPrint("No internet connection while fetching cart quantities");
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
      // Add timeouts to all API calls to prevent infinite loading
      final storeFuture = SecureHttpClient.get(
        '${AppConfig.baseApi}/store/list/${widget.storeId}',
        timeout: const Duration(seconds: 15),
        context: context,
      );
      
      final allStoresFuture = SecureHttpClient.get(
        '${AppConfig.baseApi}/store/list?page=1&limit=50',
        timeout: const Duration(seconds: 15),
        context: context,
      );

      final responses = await Future.wait([storeFuture, allStoresFuture]);
      final storeResponse = responses[0];
      final allStoresResponse = responses[1];

      if (storeResponse.statusCode == 200 &&
          allStoresResponse.statusCode == 200) {
        final storeJson = json.decode(storeResponse.body);
        final allStoresJson = json.decode(allStoresResponse.body);

        bool storeSuccess = storeJson['success'] ?? false;
        bool allStoresSuccess = allStoresJson['success'] ?? false;

        if (storeSuccess && allStoresSuccess) {
           List<dynamic> fetchedStores = (allStoresJson['data'] as List<dynamic>?) ?? [];
           // Add null safety check when accessing store id
           int foundIndex = fetchedStores.indexWhere((s) {
             if (s == null || s is! Map) return false;
             final storeId = s['id'];
             return storeId != null && storeId == widget.storeId;
           });
           
           // Cart requires login. Avoid 401->logout redirect for guest browsing.
           if (_userId.isNotEmpty && _userId != '0') {
             // AWAITING THE CART FETCH HERE to ensure _cartQuantities is populated
             await _fetchCartQuantities();
           }

           if (mounted) {
             setState(() {
               store = storeJson['data'];
               allStores = fetchedStores;
               currentIndex = foundIndex;
               isLoading = false;
             });
              _resetAndLoadProducts();
             // Initialize size data for all products (after cart is loaded to use cart sizes)
           }
        } else {
           String errorMsg = '';
           if (!storeSuccess) errorMsg += 'Store API error. ';
           if (!allStoresSuccess) errorMsg += 'All Stores API error.';
           throw Exception(errorMsg.trim());
        }
      } else {
        String errorMsg = '';
        if (storeResponse.statusCode != 200) errorMsg += 'Store fetch failed: ${storeResponse.statusCode}. ';
        if (allStoresResponse.statusCode != 200) errorMsg += 'All Stores fetch failed: ${allStoresResponse.statusCode}.';
        throw Exception(errorMsg.trim());
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() { isLoading = false; });
        debugPrint("Timeout fetching store data: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timeout. Please check your internet connection and try again.')),
        );
      }
    } on SocketException catch (e) {
      if (mounted) {
        setState(() { isLoading = false; });
        debugPrint("No internet connection: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection. Please check your network.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { isLoading = false; });
        debugPrint("Error fetching store data: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading store details: ${e.toString()}')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _fetchProductsPage({required int page, int limit = 20}) async {
    final url =
        '${AppConfig.baseApi}/store/product/getAllProductById/${widget.storeId}?page=$page&limit=$limit';
    final response = await SecureHttpClient.get(
      url,
      timeout: const Duration(seconds: 15),
      context: context,
    );
    if (response.statusCode != 200) {
      throw Exception('Product fetch failed: ${response.statusCode}');
    }
    final Map<String, dynamic> data = json.decode(response.body);
    if (data['success'] != true) {
      throw Exception('Product API error');
    }
    return data;
  }

  void _resetAndLoadProducts() {
    products = [];
    _productsLoading = false;
    _productsHasMore = true;
    _productsPage = 1;
    _productsTotalCount = 0;
    if (mounted) setState(() {});
    _loadMoreProducts();
  }

  bool _isOnline(dynamic item) {
    if (item is! Map) return false;
    final paymentMode = (item['paymentMode'] ?? '').toString();
    return paymentMode.contains('2');
  }

  int _randKey(dynamic item) {
    if (item is! Map) return 0;
    final id = int.tryParse('${item['id'] ?? item['productId'] ?? ''}') ?? 0;
    final v = (id * 1103515245 + _shuffleSeed) & 0x7fffffff;
    return v;
  }

  void _sortOnlineFirstRandom() {
    products.sort((a, b) {
      final ao = _isOnline(a) ? 1 : 0;
      final bo = _isOnline(b) ? 1 : 0;
      if (ao != bo) return bo - ao;
      return _randKey(a).compareTo(_randKey(b));
    });
  }

  String _getProductName(dynamic item) {
    if (item is! Map) return "";
    final p = item["product"];
    if (p is Map) {
      return (p["name"] ?? p["productName"] ?? "").toString();
    }
    return (item["name"] ?? item["productName"] ?? "").toString();
  }

  Future<void> _loadMoreProducts() async {
    if (_productsLoading || !_productsHasMore) return;
    setState(() {
      _productsLoading = true;
    });
    try {
      final data = await _fetchProductsPage(page: _productsPage, limit: 20);
      final List<dynamic> newItems = List<dynamic>.from(data['data'] ?? const []);
      final int total = (data['count'] is int) ? data['count'] as int : int.tryParse('${data['count']}') ?? 0;

      setState(() {
        _productsTotalCount = total;
        products.addAll(newItems);
        _sortOnlineFirstRandom();
        _productsPage += 1;
        _productsHasMore = products.length < _productsTotalCount && newItems.isNotEmpty;
        _productsLoading = false;
      });
      _initializeSizeDataForProducts();
    } catch (e) {
      setState(() {
        _productsLoading = false;
      });
    }
  }

  void _navigateToPreviousStore() {
    if (currentIndex > 0 && currentIndex - 1 < allStores.length) {
      final previousStore = allStores[currentIndex - 1];
      if (previousStore != null && previousStore is Map) {
        final previousStoreId = previousStore['id'];
        if (previousStoreId != null && mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => StoreDetails(storeId: previousStoreId as int)));
        }
      }
    } else { debugPrint("Already at the first store."); }
  }

  void _navigateToNextStore() {
    if (currentIndex != -1 && currentIndex < allStores.length - 1) {
      final nextStore = allStores[currentIndex + 1];
      if (nextStore != null && nextStore is Map) {
        final nextStoreId = nextStore['id'];
        if (nextStoreId != null && mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => StoreDetails(storeId: nextStoreId as int)));
        }
      }
    } else { debugPrint("Already at the last store."); }
  }

  Future<void> _updateCart(int productId, int newQuantity, Map<String, dynamic> productData, {required bool isAdd}) async {
    if (!mounted || _cartLoadingIds.contains(productId)) return;

    setState(() { _cartLoadingIds.add(productId); });

    try {
      final responseData = await updateCart(
        productId: productId,
        newQuantity: newQuantity,
        productData: productData,
        isAdd: isAdd,
        userId: _userId,
        storeId: widget.storeId.toString(),
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

  // Initialize size data for all products
  void _initializeSizeDataForProducts() {
    for (var item in products) {
      if (item['product'] != null && item['product'] is Map) {
        final product = item['product'] as Map<String, dynamic>;
        final productId = product['id'] as int?;
        if (productId != null) {
          try {
            final sizeUnitSizeMapStr = product['sizeUnitSizeMap'];
            Map<String, dynamic>? sizeMap;
            
            if (sizeUnitSizeMapStr != null && sizeUnitSizeMapStr is String) {
              sizeMap = json.decode(sizeUnitSizeMapStr) as Map<String, dynamic>?;
            } else if (sizeUnitSizeMapStr is Map) {
              sizeMap = Map<String, dynamic>.from(sizeUnitSizeMapStr);
            }
            
            _sizeUnitSizeMaps[productId] = sizeMap;
            
            // Set default size (first available or from cart)
            if (sizeMap != null && sizeMap.isNotEmpty) {
              // Check cart for existing size (prioritize cart size)
              final cartSize = _cartSizes[productId] ?? product['size']?.toString();
              if (cartSize != null && sizeMap.containsKey(cartSize)) {
                _selectedSizes[productId] = cartSize;
              } else {
                _selectedSizes[productId] = sizeMap.keys.first;
              }
              _updatePriceAndStockForProduct(productId, product);
            } else {
              // Fallback to default product price and stock
              _currentPrices[productId] = double.tryParse(product['total']?.toString() ?? 
                                                          product['price']?.toString() ?? '0') ?? 0.0;
              _currentStocks[productId] = int.tryParse(product['unitSize']?.toString() ?? '0') ?? 0;
            }
          } catch (e) {
            debugPrint('Error initializing size data for product $productId: $e');
          }
        }
      }
    }
  }
  
  // Update price and stock based on selected size for a product
  void _updatePriceAndStockForProduct(int productId, Map<String, dynamic> product) {
    final selectedSize = _selectedSizes[productId];
    final sizeMap = _sizeUnitSizeMaps[productId];
    
    if (selectedSize != null && sizeMap != null) {
      final sizeData = sizeMap[selectedSize];
      if (sizeData is Map) {
        // Get discounted price (total or grandTotal)
        _currentPrices[productId] = double.tryParse(sizeData['total']?.toString() ?? 
                                                    sizeData['grandTotal']?.toString() ?? 
                                                    sizeData['price']?.toString() ?? 
                                                    product['total']?.toString() ?? 
                                                    product['price']?.toString() ?? '0') ?? 0.0;
        
        // Get original price (price field from sizeData or product)
        _originalPrices[productId] = double.tryParse(sizeData['price']?.toString() ?? 
                                                     product['price']?.toString() ?? 
                                                     product['total']?.toString() ?? '0') ?? 0.0;
        
        // Get discount percentage
        _currentDiscounts[productId] = double.tryParse(
                                                       sizeData['discount']?.toString() ?? 
                                                       '0') ?? 0.0;
        
        _currentStocks[productId] = int.tryParse(sizeData['unitSize']?.toString() ?? '0') ?? 0;
      }
    } else {
      // Fallback to default product price and stock
      final originalPrice = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
      final discountedPrice = double.tryParse(product['total']?.toString() ?? product['price']?.toString() ?? '0') ?? 0.0;
      
      _currentPrices[productId] = discountedPrice;
      _originalPrices[productId] = originalPrice;
      _currentDiscounts[productId] = double.tryParse(product['discount']?.toString() ?? '0') ?? 0.0;
      _currentStocks[productId] = int.tryParse(product['unitSize']?.toString() ?? '0') ?? 0;
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    // Check if user is logged in
    final isLoggedIn = await AuthHelper.checkAuthAndShowDialog(
      context,
      message: 'Please login to add items to your cart.',
    );
    
    if (!isLoggedIn) {
      return; // User chose not to login or dialog was dismissed
    }
    
    // Reload userId after potential login
    final prefs = await SharedPreferences.getInstance();
    final updatedUserId = prefs.getString('userId') ?? '0';
    if (updatedUserId == '0') {
      return; // Still not logged in
    }
    
    setState(() {
      _userId = updatedUserId;
    });
    
    final int? productIdRaw = product['id'] as int?;
    if (productIdRaw == null) {
       debugPrint("Error: Product ID is null in _addToCart");
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add item: Invalid product data.')));
       return;
    }
    final int productId = productIdRaw;
    final int currentQuantity = _cartQuantities[productId] ?? 0;
    
    // Stock validation
    final availableStock = _currentStocks[productId] ?? int.tryParse(product['unitSize']?.toString() ?? '0') ?? 0;
    
    if (currentQuantity >= availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only $availableStock items available in stock')),
      );
      return;
    }
    
    final int newQuantity = currentQuantity + 1;
    
    // Include size in product data
    final productWithSize = Map<String, dynamic>.from(product);
    final selectedSize = _selectedSizes[productId];
    if (selectedSize != null) {
      productWithSize['size'] = selectedSize;
      productWithSize['price'] = _currentPrices[productId] ?? double.tryParse(product['total']?.toString() ?? product['price']?.toString() ?? '0') ?? 0.0;
      productWithSize['total'] = _currentPrices[productId] ?? double.tryParse(product['total']?.toString() ?? product['price']?.toString() ?? '0') ?? 0.0;
    }

    await _updateCart(productId, newQuantity, productWithSize, isAdd: true);
  }

  Future<void> _incrementQuantity(int productId) async {
     final productWrapper = products.firstWhere((p) => (p['product'] as Map?)?['id'] == productId, orElse: () => null);
     final productData = productWrapper?['product'] as Map<String, dynamic>?;

     if(productData != null) {
       final int currentQuantity = _cartQuantities[productId] ?? 0;
       
       // Stock validation
       final availableStock = _currentStocks[productId] ?? int.tryParse(productData['unitSize']?.toString() ?? '0') ?? 0;
       
       if (currentQuantity >= availableStock) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Only $availableStock items available in stock')),
         );
         return;
       }
       
       final int newQuantity = currentQuantity + 1;
       
       // Include size in product data
       final productWithSize = Map<String, dynamic>.from(productData);
       final selectedSize = _selectedSizes[productId];
       if (selectedSize != null) {
         productWithSize['size'] = selectedSize;
         productWithSize['price'] = _currentPrices[productId] ?? double.tryParse(productData['total']?.toString() ?? productData['price']?.toString() ?? '0') ?? 0.0;
         productWithSize['total'] = _currentPrices[productId] ?? double.tryParse(productData['total']?.toString() ?? productData['price']?.toString() ?? '0') ?? 0.0;
       }
       
       await _updateCart(productId, newQuantity, productWithSize, isAdd: false);
     } else {
        debugPrint("Could not find product data to increment quantity for ID: $productId");
     }
  }

  Future<void> _decrementQuantity(int productId) async {
     final int currentQuantity = _cartQuantities[productId] ?? 0;
     if (currentQuantity <= 0) return;
     final int newQuantity = currentQuantity - 1;

     final productWrapper = products.firstWhere((p) => (p['product'] as Map?)?['id'] == productId, orElse: () => null);
     final productData = productWrapper?['product'] as Map<String, dynamic>?;
     
     if (productData == null) {
       debugPrint("Could not find product data to decrement quantity for ID: $productId");
       return;
     }
     
     // Include size in product data
     final productWithSize = Map<String, dynamic>.from(productData);
     final selectedSize = _selectedSizes[productId];
     if (selectedSize != null) {
       productWithSize['size'] = selectedSize;
       productWithSize['price'] = _currentPrices[productId] ?? double.tryParse(productData['total']?.toString() ?? productData['price']?.toString() ?? '0') ?? 0.0;
       productWithSize['total'] = _currentPrices[productId] ?? double.tryParse(productData['total']?.toString() ?? productData['price']?.toString() ?? '0') ?? 0.0;
     }
     
     await _updateCart(productId, newQuantity, productWithSize, isAdd: false);
  }

  Widget buildStoreHeader() {
    final String openTime = store?['openTime'] ?? 'N/A';
    final String closeTime = store?['closeTime'] ?? 'N/A';
    final String openCloseTime = (openTime != 'N/A' && closeTime != 'N/A') ? 'Open : $openTime AM - $closeTime PM' : 'Timings not available';
    final String? storePhone = store?['phone'];
    final String? storeWebsite = store?['website'];
    final String storeName = store?['storename'] ?? 'This Store';
    final String? location = store?['location'] ?? store?['storeaddress'];
    final String shareText = 'Check out $storeName! ${storeWebsite != null ? storeWebsite : ""}';
    final bool canGoBack = currentIndex > 0;
    final bool canGoForward = currentIndex != -1 && currentIndex < allStores.length - 1;

    return NavBarContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    store?['storeImage'] ?? 'https://via.placeholder.com/100x100.png?text=Store',
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.storefront, color: Colors.grey[400], size: 34),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        storeName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(children: [ const Icon(Icons.star, color: Colors.amber, size: 16), const SizedBox(width: 4), Text(store?['rating']?.toString() ?? "4.2", style: const TextStyle(color: Colors.black87, fontSize: 14))]),
                      const SizedBox(height: 4),
                      Text(openCloseTime, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      Text("Products : ${products.length}", style: const TextStyle(color: Colors.black87, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                GestureDetector( onTap: () { if (storePhone != null) launchWhatsApp(storePhone); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp number not available.'))); }, child: _buildCircleIcon(FontAwesomeIcons.whatsapp, Colors.green)),
                GestureDetector( onTap: () { if (storePhone != null) makePhoneCall(storePhone); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not available.'))); }, child: _buildCircleIcon(Icons.phone, Colors.blue)),
                GestureDetector( onTap: () { if (location != null && location.isNotEmpty) openMap(location); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available.'))); }, child: _buildCircleIcon(Icons.location_on, Colors.purple)),
                GestureDetector( onTap: () { launchWebsite(storeWebsite ?? '', store?['id'] ?? 0); }, child: _buildCircleIcon(Icons.language, Colors.red)),
                GestureDetector( onTap: () { shareContent(shareText, subject: 'Check out this store!'); }, child: _buildCircleIcon(Icons.share, Colors.teal)),
              ],
            ),
            const SizedBox(height: 12),
            NavBarContainer(
              child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _buildBottomButton(Icons.remove),
                  GestureDetector( onTap: canGoBack ? _navigateToPreviousStore : null, child: _buildBottomButton(Icons.arrow_back, color: canGoBack ? Colors.black87 : Colors.grey[400])),
                  GestureDetector( onTap: canGoForward ? _navigateToNextStore : null, child: _buildBottomButton(Icons.arrow_forward, color: canGoForward ? Colors.blue : Colors.grey[400])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildCircleIcon(IconData icon, Color color) {
  return Container(
    width: 42,
    height: 42,
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
    child: Icon(icon, color: color, size: 20),
  );
}

Widget _buildBottomButton(IconData icon, {Color? color}) {
 return Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]), child: Icon(icon, color: color ?? Colors.black87, size: 20));
}

Widget _buildQuantitySelector({ required int quantity, required VoidCallback onIncrement, required VoidCallback onDecrement}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
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

// Helper widget for payment check items
  Widget _buildCheckItem(bool isChecked, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 5),
         Icon(
          isChecked ? Icons.check_circle : Icons.cancel,
          color: isChecked ? Colors.green.shade600 : Colors.red.shade400,
          size: 15,
        ),
      ],
    );
  }
  
Widget buildProductCard(Map<String, dynamic> item, {bool compact: false}) {
    // --- Safe Access ---
    if (item['product'] == null || item['product'] is! Map) {
      return Padding( padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Error: Invalid product data', style: TextStyle(color: Colors.red[700])));
    }
    final product = item['product'] as Map<String, dynamic>;
    final int? productIdRaw = product['id'] as int?; // Product ID can be null
    if (productIdRaw == null) {
       return Padding( padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Error: Missing product ID', style: TextStyle(color: Colors.red[700])));
    }
    final int productId = productIdRaw;

    // Use ?? to provide defaults for potentially null/missing fields
    final bool available = product['isEnableEcommerce']?.toString() == '1';
    final bool isBooking = product['isBooking']?.toString() == '1';
    final String? photoUrl = product['photo'] as String?;
    final String productName = product['name']?.toString() ?? 'Unnamed Product';
    
    // --- START: Price Parsing ---
    // Get current price, discount, and stock based on selected size
    final double currentPrice = _currentPrices[productId] ?? double.tryParse(product['total']?.toString() ?? product['price']?.toString() ?? '0') ?? 0.0;
    final double originalPrice = _originalPrices[productId] ?? double.tryParse(product['price']?.toString() ?? product['total']?.toString() ?? '0') ?? 0.0;
    final double discountValue = _currentDiscounts[productId] ?? double.tryParse(product['discountPer']?.toString() ?? '0') ?? 0.0;
    final int currentStock = _currentStocks[productId] ?? int.tryParse(product['unitSize']?.toString() ?? '0') ?? 0;
    
    // Fallback values
    final double finalPrice = currentPrice;
    final String priceString = originalPrice.toStringAsFixed(0);
    final String totalString = currentPrice.toStringAsFixed(0);
    // --- END: Price Parsing ---

    final String unitSize = product['unitSize']?.toString() ?? '';
    final String stockQty = product['unitSize']?.toString() ?? '0';
    final String qty = product['qty']?.toString() ?? '0';
    final String paymentMode = (product['paymentMode'] ?? '').toString();
    final bool isPerOrder = paymentMode.contains('1');
    final bool isOnline = paymentMode.contains('2'); // Not in API example, but safe check
    final bool isCOD = paymentMode.contains('3');
    // Cart State: Reads the pre-loaded quantity or defaults to 0
    final int currentQuantity = _cartQuantities[productId] ?? 0;
    final bool isInCart = currentQuantity > 0;
    final bool isCartLoading = _cartLoadingIds.contains(productId);

    if (compact) {
      final bool showDiscount = discountValue > 0 && originalPrice > finalPrice;
      Widget miniFlag(String label, bool enabled) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: enabled ? successColor.withOpacity(0.12) : Colors.red.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: enabled ? successColor.withOpacity(0.35) : Colors.red.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                enabled ? Icons.check_circle : Icons.cancel,
                size: 12,
                color: enabled ? successColor : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: enabled ? successColor : Colors.red,
                ),
              ),
            ],
          ),
        );
      }
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final productWithStoreId = Map<String, dynamic>.from(product);
          if (!productWithStoreId.containsKey('storeId') &&
              !productWithStoreId.containsKey('store')) {
            productWithStoreId['storeId'] = widget.storeId;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  NewProductDetailsScreen(product: productWithStoreId),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 1.45,
                  child: Image.network(
                    photoUrl ??
                        'https://via.placeholder.com/300x200.png?text=Product',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey[400]),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      // In 2-column GridView, variable-height titles cause bottom actions to overflow.
                      // Keep actions visible by clamping title height.
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '₹$totalString',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (showDiscount)
                          Text(
                            '₹$priceString',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: available
                                ? successColor.withOpacity(0.12)
                                : Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            available ? 'Available' : 'Offline',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: available ? successColor : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isPerOrder) miniFlag('Per Order', true),
                        if (isOnline) miniFlag('Online', true),
                        if (isCOD) miniFlag('COD', true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (_selectedSizes[productId] ?? '').toString().isNotEmpty
                                ? 'Size: ${_selectedSizes[productId]}'
                                : (unitSize.isNotEmpty ? unitSize : ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Stock: $currentStock',
                          style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Divider(color: Colors.grey[200], height: 1),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              onPressed: (isBooking || available)
                                  ? () {
                                      final checkoutProduct = {
                                        'productId': productIdRaw,
                                        'name': productName,
                                        'price': (_currentPrices[productId] ?? finalPrice),
                                        'qty': 1,
                                        'storeId': widget.storeId,
                                        'photo': photoUrl,
                                        'isBooking': isBooking,
                                        if (_selectedSizes[productId] != null) 'size': _selectedSizes[productId],
                                      };
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CheckoutScreen(product: checkoutProduct),
                                        ),
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (isBooking || available) ? primaryColor : Colors.grey.shade300,
                                foregroundColor: (isBooking || available) ? Colors.white : Colors.black54,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isBooking ? 'Book' : (available ? 'Order' : 'Offline'),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 102,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: () {
                                  final productWithStoreId = Map<String, dynamic>.from(product);
                                  if (!productWithStoreId.containsKey('storeId') && !productWithStoreId.containsKey('store')) {
                                    productWithStoreId['storeId'] = widget.storeId;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NewProductDetailsScreen(product: productWithStoreId),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.black54, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                              ),
                              isCartLoading
                                  ? const SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: Padding(
                                        padding: EdgeInsets.all(6.0),
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : IconButton(
                                onPressed: isCartLoading
                                    ? null
                                    : (available && !isBooking)
                                        ? (isInCart
                                            ? () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (context) => CartScreen()),
                                                );
                                              }
                                            : () => _addToCart(product))
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => CartScreen()),
                                            );
                                          },
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      isInCart ? Icons.shopping_bag_outlined : Icons.add_shopping_cart,
                                      color: isInCart ? accentColor : primaryColor,
                                      size: 20,
                                    ),
                                    if (currentQuantity > 0)
                                      Positioned(
                                        top: -6,
                                        right: -8,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                          child: Text(
                                            currentQuantity.toString(),
                                            style: const TextStyle(color: Colors.white, fontSize: 8),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => CustomerOrderScreen()),
                                  );
                                },
                                icon: Icon(Icons.receipt_long, color: successColor, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                              ),
                            ],
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
      );
    }

    return Container( /* ... Card Decoration ... */
      margin: compact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [ BoxShadow( color: Colors.grey.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack( fit: StackFit.passthrough, children: [
              GestureDetector(
                onTap: () {
                  // Add storeId to product if not present (for NewProductDetailsScreen)
                  final productWithStoreId = Map<String, dynamic>.from(product);
                  if (!productWithStoreId.containsKey('storeId') && !productWithStoreId.containsKey('store')) {
                    productWithStoreId['storeId'] = widget.storeId;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewProductDetailsScreen(product: productWithStoreId),
                    ),
                  );
                },
                child: ClipRRect( /* ... Image ... */
                  borderRadius: const BorderRadius.only( topRight: Radius.circular(16), topLeft: Radius.circular(16)),
                  child: Image.network( photoUrl ?? 'https://via.placeholder.com/300x200.png?text=Product', height: 200, width: double.infinity, fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container( height: 160, width: double.infinity, decoration: BoxDecoration( color: Colors.grey[200], borderRadius: const BorderRadius.only( topRight: Radius.circular(16), topLeft: Radius.circular(16))), child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 50)),
                  ),
                ),
              ),
              if (discountValue > 0) Positioned( /* ... Discount Badge ... */ top: 10, left: 10, child: Container( decoration: BoxDecoration( color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text( "${discountValue.toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
              if (!available && !isBooking) Positioned( /* ... Not Available Badge ... */ bottom: 8, right: 8, child: Container( decoration: BoxDecoration( color: Colors.redAccent.withOpacity(0.9), borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: const Text( "Online Order Not Available", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)))),
              if (isBooking) Positioned( /* ... Not Available Badge ... */ bottom: 8, right: 8, child: Container( decoration: BoxDecoration( color: Colors.redAccent.withOpacity(0.9), borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: const Text( "Booking Only", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)))),
          ]),
          Padding( /* ... Product Details ... */
            padding: const EdgeInsets.all(12),
            child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(productName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row( /* ... Price and Stock ... */ crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text("₹${currentPrice.toStringAsFixed(0)}", style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold)),
                     const SizedBox(width: 8),
                    // Show original price with strikethrough if there's a discount
                    if (discountValue > 0 && originalPrice > currentPrice)
                      Text("₹${originalPrice.toStringAsFixed(0)}", style: TextStyle(color: Colors.grey[600], fontSize: 13, decoration: TextDecoration.lineThrough)),
                    const Spacer(),
                    Text( currentStock <= 0 && !isBooking ? "Coming soon" : isBooking ? "Booking Only" : "$currentStock Stocks", style: TextStyle( color: currentStock <= 0 ? Colors.orange[700] : Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),
                
                // Size Selection UI
                if (_sizeUnitSizeMaps[productId] != null && _sizeUnitSizeMaps[productId]!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Size:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sizeUnitSizeMaps[productId]!.keys.map((size) {
                      final sizeData = _sizeUnitSizeMaps[productId]![size];
                      final isSelected = _selectedSizes[productId] == size;
                      final unitSize = sizeData is Map 
                          ? sizeData['unitSize']?.toString() ?? ''
                          : '';
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSizes[productId] = size;
                            _updatePriceAndStockForProduct(productId, product);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? primaryColor : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            unitSize.isNotEmpty ? '$size: $unitSize' : size,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCheckItem(isPerOrder, 'Per Order'),
                    _buildCheckItem(isOnline, 'Online Payment'),
                    _buildCheckItem(isCOD, 'Cash On Delivery'),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isBooking || available)
                      ElevatedButton(
                        onPressed: () {
                          // --- ⭐️ START: MODIFICATION ---
                          // Create a 'cart-like' item map that CheckoutScreen understands
                          final checkoutProduct = {
                            'productId': productIdRaw,
                            'name': productName,
                            'price': (_currentPrices[productId] ?? finalPrice), // Use size-based price if available
                            'qty': 1, // Default quantity for "Buy Now"
                            'storeId': widget.storeId, // Pass the storeId
                            'photo': photoUrl, // Pass photo for summary
                            'isBooking': isBooking, // Pass booking status
                            if (_selectedSizes[productId] != null) 'size': _selectedSizes[productId],
                          };
                          // --- ⭐️ END: MODIFICATION ---
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutScreen(product: checkoutProduct),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isBooking ? const Text('Book Now') : const Text('Order Now'),
                      ),
                    if (available && !isBooking)
                      OutlinedButton.icon(
                        onPressed: isInCart ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => CartScreen()),
                          );
                        } : () => _addToCart(product),
                        icon: Icon(
                          isInCart ? Icons.check_circle_outline : Icons.add_shopping_cart,
                          size: 18,
                          color: isInCart ? Colors.green : primaryColor,
                        ),
                        label: Text(isInCart ? 'In Cart' : 'Add to Cart'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: (isInCart ? Colors.green : primaryColor).withOpacity(0.55),
                            width: 1.5,
                          ),
                          foregroundColor: isInCart ? Colors.green : primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        // Add storeId to product if not present (for NewProductDetailsScreen)
                        final productWithStoreId = Map<String, dynamic>.from(product);
                        if (!productWithStoreId.containsKey('storeId') && !productWithStoreId.containsKey('store')) {
                          productWithStoreId['storeId'] = widget.storeId;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewProductDetailsScreen(product: productWithStoreId),
                          ),
                        );
                      },
                      child: const Icon(Icons.remove_red_eye_outlined, color: Colors.black54),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
     return Container(
      decoration: gradientBackgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 48,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: brandHeaderGradient,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Store Details",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
            : store == null && !isLoading
              ? Center(
                  child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.error_outline, color: Colors.red[300], size: 60),
                      const SizedBox(height: 16),
                      const Text('Could not load store details.', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      ElevatedButton.icon( icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _fetchStoreData)
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchStoreData,
                  child: ListView(
                    controller: _productsScrollController,
                    padding: const EdgeInsets.only(top: 8),
                    children: [
                      buildStoreHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _productSearchController,
                            onChanged: (v) {
                              setState(() {
                                _productSearchQuery = v.trim().toLowerCase();
                              });
                            },
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: "Search products in this store...",
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.search, color: Colors.black54),
                              suffixIcon: _productSearchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _productSearchController.clear();
                                        setState(() {
                                          _productSearchQuery = "";
                                        });
                                      },
                                      icon: const Icon(Icons.close, color: Colors.black54),
                                    ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (products.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _productSearchQuery.isEmpty
                                ? products.length
                                : products.where((it) => _getProductName(it).toLowerCase().contains(_productSearchQuery)).length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              // Reduce extra blank space at bottom while keeping room for actions.
                              // NOTE: compact product cards have bottom actions; keep them tall enough to avoid overflow.
                              // Tighten card height now that actions are compact.
                              childAspectRatio: 0.56,
                            ),
                            itemBuilder: (context, index) {
                              final List<dynamic> visibleProducts = _productSearchQuery.isEmpty
                                  ? products
                                  : products.where((it) => _getProductName(it).toLowerCase().contains(_productSearchQuery)).toList();
                              if (index >= visibleProducts.length) return const SizedBox.shrink();
                              return buildProductCard(
                                visibleProducts[index],
                                compact: true,
                              );
                            },
                          ),
                        )
                      else if (!_productsLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                          child: Center(
                            child: Text(
                              "No products found for this store.",
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      if (products.isNotEmpty && _productSearchQuery.isNotEmpty)
                        Builder(
                          builder: (context) {
                            final visibleCount = products
                                .where((it) => _getProductName(it).toLowerCase().contains(_productSearchQuery))
                                .length;
                            if (visibleCount > 0) return const SizedBox.shrink();
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 26.0, horizontal: 20.0),
                              child: Center(
                                child: Text(
                                  "No matching products found.",
                                  style: TextStyle(fontSize: 15, color: Colors.black54),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                      if (_productsLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 22),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      const SizedBox(height: 80), // Bottom padding
                    ],
                  ),
                ),
      ),
    );
  }
}