import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart'; 
import 'package:flutter/foundation.dart';
import '../../../helpers/secure_http_client.dart'; 

import '../../../constants/colors.dart';
import '../../../constants/app_config.dart';
import '../../../components/loading.dart';
import 'product_details_screen.dart'; 
import 'package:nickname_portal/components/gradient_background.dart';
import 'package:nickname_portal/providers/category_filter_data.dart'; 
import 'cart.dart';
import 'order.dart';
import 'checkout_screen.dart';
import '../../../helpers/cart_api_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import the customer widgets file to get the HomeTopBar, CategoriesWidget,
// and HomeFilterDrawer
import 'package:nickname_portal/components/customer_home_widgets.dart';


class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ScrollController _productsScrollController = ScrollController();
  final List<dynamic> _products = [];
  bool _productsLoading = false;
  bool _productsHasMore = true;
  int _productsPage = 1;
  int _productsTotalCount = 0;
  String? _productsError;
  final int _shuffleSeed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  
  // State variables to manage the filter widgets
  late Future<List<dynamic>> _categoriesFuture;
  final TextEditingController _searchController = TextEditingController();
  
  // State variables to track the *current* filters
  Set<int> _currentFilterIds = {};
  String? _currentSearchQuery;
  int? _currentPaymentMode; // <-- NEW

  // --- Cart state (online products) ---
  String _userId = '';
  final Map<int, int> _cartQuantities = {};
  final Set<int> _cartLoadingIds = {};

  @override
  void initState() {
    super.initState();
    
    _categoriesFuture = _fetchCategories(); 
    
    // Get initial state from provider
    final provider = Provider.of<CategoryFilterData>(context, listen: false);
    _currentFilterIds = provider.selectedCategoryIds ?? <int>{};
    _currentSearchQuery = provider.searchQuery;
    _currentPaymentMode = provider.selectedPaymentMode; // <-- NEW
    
    // Set initial text for the search controller if it exists
    if (_currentSearchQuery != null) {
      _searchController.text = _currentSearchQuery!;
    }
    
    _resetAndLoadProducts();
    _loadUserIdAndCart();

    _productsScrollController.addListener(() {
      if (!_productsHasMore || _productsLoading) return;
      final pos = _productsScrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 350) {
        _loadMoreProducts();
      }
    });
  }

  Future<void> _loadUserIdAndCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('userId') ?? '';
      if (!mounted) return;
      setState(() => _userId = uid);
      if (uid.isEmpty || uid == '0') return;
      await _fetchCartQuantities();
    } catch (_) {}
  }

  Future<void> _fetchCartQuantities() async {
    if (_userId.isEmpty || _userId == '0') return;
    try {
      final resp = await fetchCartItems(_userId).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return;
      final body = jsonDecode(resp.body);
      final list = (body['data'] is List) ? body['data'] as List : <dynamic>[];
      final next = <int, int>{};
      for (final it in list) {
        final pid = int.tryParse(it['productId']?.toString() ?? '') ?? 0;
        final qty = int.tryParse(it['qty']?.toString() ?? '') ?? 0;
        if (pid > 0 && qty > 0) next[pid] = qty;
      }
      if (!mounted) return;
      setState(() {
        _cartQuantities
          ..clear()
          ..addAll(next);
      });
    } catch (_) {}
  }

  Future<void> _updateCartQty({
    required Map<String, dynamic> product,
    required int productId,
    required int newQty,
    required bool isAdd,
  }) async {
    if (_userId.isEmpty || _userId == '0') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to add items to cart')),
        );
      }
      return;
    }
    if (_cartLoadingIds.contains(productId)) return;
    setState(() => _cartLoadingIds.add(productId));
    try {
      await updateCart(
        productId: productId,
        newQuantity: newQty,
        productData: product,
        isAdd: isAdd,
        userId: _userId,
        storeId: (product['storeId'] ?? product['createdId'] ?? '').toString(),
      );
      if (!mounted) return;
      setState(() {
        if (newQty <= 0) _cartQuantities.remove(productId);
        else _cartQuantities[productId] = newQty;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update cart')),
        );
      }
    } finally {
      if (mounted) setState(() => _cartLoadingIds.remove(productId));
    }
  }

  Widget _qtyStepper({
    required int quantity,
    required VoidCallback onInc,
    required VoidCallback onDec,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.30), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: quantity > 0 ? onDec : null,
            child: Container(
              width: 36,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.remove,
                  size: 18,
                  color: quantity > 0 ? primaryColor : Colors.grey.shade400),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              quantity.toString(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          InkWell(
            onTap: onInc,
            child: Container(
              width: 36,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, size: 18, color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _productsScrollController.dispose();
    super.dispose();
  }

  // Helper method to get product photo count
  int _getProductPhotoCount(Map<String, dynamic> product) {
    int count = 0;
    
    // Count main photo
    if (product['photo'] != null && product['photo'].toString().isNotEmpty) {
      count = 1;
    }
    
    // Count sub photos from productphotos array
    try {
      final productphotos = product['productphotos'];
      if (productphotos != null) {
        if (productphotos is List) {
          count += productphotos.length;
        } else if (productphotos is String) {
          try {
            final parsed = json.decode(productphotos) as List;
            count += parsed.length;
          } catch (e) {
            // If parsing fails, ignore
          }
        }
      }
    } catch (e) {
      // If any error occurs, just return main photo count
    }
    
    return count;
  }

  Widget _buildMiniFlag(String label, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? successColor.withOpacity(0.12)
            : Colors.red.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: enabled
              ? successColor.withOpacity(0.35)
              : Colors.red.withOpacity(0.25),
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
          const SizedBox(width: 5),
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

  Widget _buildCompactProductCard(Map<String, dynamic> product) {
    final String? photoUrl = product['photo'] as String?;
    final String name = product['name']?.toString() ?? 'N/A';
    final String paymentMode = (product['paymentMode'] ?? '').toString();
    final bool isPerOrder = paymentMode.contains('1');
    final bool isOnline = paymentMode.contains('2');
    final bool isCOD = paymentMode.contains('3');
    final bool available = product['isEnableEcommerce']?.toString() == '1';
    final bool isBooking = product['isBooking']?.toString() == '1';
    final int productId = int.tryParse(product['id']?.toString() ?? '0') ?? 0;
    final int currentQty = _cartQuantities[productId] ?? 0;
    final bool isCartLoading = _cartLoadingIds.contains(productId);

    final double price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;
    final double total = double.tryParse(product['total']?.toString() ?? '0') ?? price;
    final double discountPer =
        double.tryParse(product['discountPer']?.toString() ?? '0') ?? 0;
    final bool showDiscount = discountPer > 0 && price > total;

    final int stock =
        int.tryParse(product['unitSize']?.toString() ?? '0') ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: AspectRatio(
                aspectRatio: 1.45,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        photoUrl ?? 'https://via.placeholder.com/300x200.png?text=Product',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[100],
                          child: Icon(Icons.image_not_supported,
                              color: Colors.grey[400], size: 46),
                        ),
                      ),
                    ),
                    if (_getProductPhotoCount(product) > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_getProductPhotoCount(product)} photos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '₹${total.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (showDiscount)
                              Text(
                                '₹${price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: available
                                    ? successColor.withOpacity(0.14)
                                    : Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                available ? 'Available' : 'Offline',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: available ? successColor : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isPerOrder) _buildMiniFlag('Per Order', true),
                            if (isOnline) _buildMiniFlag('Online', true),
                            if (isCOD) _buildMiniFlag('COD', true),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Stock: $stock',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            if (product['discount'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${product['discount'] ?? 0}% OFF',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const SizedBox(height: 6),
                        Divider(color: Colors.grey[200], height: 1),
                        const SizedBox(height: 6),
                        if (available && !isBooking && productId > 0) ...[
                          SizedBox(
                            height: 40,
                            child: isCartLoading
                                ? const SizedBox(
                                    height: 30,
                                    width: 30,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : currentQty > 0
                                    ? _qtyStepper(
                                        quantity: currentQty,
                                        onInc: () => _updateCartQty(
                                          product: product,
                                          productId: productId,
                                          newQty: currentQty + 1,
                                          isAdd: true,
                                        ),
                                        onDec: () => _updateCartQty(
                                          product: product,
                                          productId: productId,
                                          newQty: currentQty - 1,
                                          isAdd: false,
                                        ),
                                      )
                                    : SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _updateCartQty(
                                            product: product,
                                            productId: productId,
                                            newQty: 1,
                                            isAdd: true,
                                          ),
                                          icon: const Icon(Icons.add_shopping_cart,
                                              color: Colors.white, size: 18),
                                          label: const Text(
                                            'Add to Cart',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                      ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: ElevatedButton(
                            onPressed: (isBooking || available)
                                ? () {
                                    final checkoutProduct = {
                                      'productId': product['id'],
                                      'name': name,
                                      'price': total,
                                      'qty': 1,
                                      'storeId': product['storeId'],
                                      'photo': photoUrl,
                                      'isBooking': isBooking,
                                    };
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CheckoutScreen(product: checkoutProduct),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (isBooking || available)
                                  ? primaryColor
                                  : Colors.grey.shade300,
                              foregroundColor: (isBooking || available)
                                  ? Colors.white
                                  : Colors.black54,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isBooking ? 'Book Now' : (available ? 'Order Now' : 'Offline'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ProductDetailsScreen(product: product),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.remove_red_eye_outlined,
                                  color: Colors.black54, size: 22),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => CartScreen()),
                                );
                              },
                              icon: Icon(Icons.shopping_bag_outlined,
                                  color: accentColor, size: 22),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => CustomerOrderScreen()),
                                );
                              },
                              icon: Icon(Icons.receipt_long,
                                  color: successColor, size: 22),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Listen for changes in *all* relevant filters
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Listen for provider changes
    final filterData = Provider.of<CategoryFilterData>(context);
    final newFilterIds = filterData.selectedCategoryIds ?? <int>{};
    final newSearchQuery = filterData.searchQuery;
    final newPaymentMode = filterData.selectedPaymentMode; // <-- NEW

    // Check for changes in all filters
    bool categoryChanged = !setEquals(_currentFilterIds, newFilterIds);
    bool searchChanged = newSearchQuery != _currentSearchQuery;
    bool paymentModeChanged = newPaymentMode != _currentPaymentMode; // <-- NEW

    if (categoryChanged || searchChanged || paymentModeChanged) { // <-- MODIFIED
      
      // Update our internal state
      _currentFilterIds = newFilterIds;
      _currentSearchQuery = newSearchQuery;
      _currentPaymentMode = newPaymentMode; // <-- NEW
      
      _resetAndLoadProducts();
      
      // Sync the search bar text with the provider state
      if ((categoryChanged && newFilterIds.isNotEmpty) || (paymentModeChanged && newPaymentMode != null)) {
        // If a category or payment mode was selected, clear the search bar
        _searchController.clear();
      } else if (searchChanged && newSearchQuery != _searchController.text) {
         // If search changed (incl. being cleared), update the text field
         _searchController.text = newSearchQuery ?? '';
      }
      
      setState(() {}); 
    }
  }

  // Refresh using the *current* filters
  void _refreshProducts() {
    _resetAndLoadProducts();
  }
  
  // This now triggers the provider, which updates the state
  void _onSearchSubmitted(String value) {
    final trimmedValue = value.trim();
    // This will trigger didChangeDependencies
    Provider.of<CategoryFilterData>(context, listen: false).setSearchQuery(
      trimmedValue.isNotEmpty ? trimmedValue : null
    );
  }

  // This function is for the CategoriesWidget
  Future<List<dynamic>> _fetchCategories() async {
    try {
      final response = await SecureHttpClient.get(
        '${AppConfig.baseApi}/category/getAllCategory',
        timeout: const Duration(seconds: 10),
        context: context,
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return List.from(data['data'] ?? []);
        } else {
          throw Exception('Failed to load categories: API error');
        }
      } else {
        throw Exception('Failed to load categories: HTTP error ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout. Please check your internet connection.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchProductsPage({
    Set<int>? categoryIds,
    String? searchQuery,
    int? paymentMode,
    required int page,
    int limit = 20,
  }) async {
    String url;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      url =
          '${AppConfig.baseApi}/product/gcatalogsearch/result?flat=1&search=${Uri.encodeQueryComponent(searchQuery)}&page=$page&limit=$limit';
    } else if (paymentMode != null) {
      url =
          '${AppConfig.baseApi}/product/gcatalogsearch/result?flat=1&paymentModes=$paymentMode&page=$page&limit=$limit';
    } else if (categoryIds != null && categoryIds.isNotEmpty) {
      final idString = categoryIds.join(',');
      url =
          '${AppConfig.baseApi}/product/getAllByCategory?categoryIds=$idString&page=$page&limit=$limit';
    } else {
      url = '${AppConfig.baseApi}/product/getAllproductList?page=$page&limit=$limit';
    }

    try {
      final response = await SecureHttpClient.get(
        url,
        timeout: const Duration(seconds: 15),
        context: context,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception('API returned an error');
        }
      } else {
        throw Exception('Failed to load products');
      }
    } on TimeoutException {
      throw Exception('Request timeout. Please check your internet connection.');
    } on SocketException {
      throw Exception('No internet connection.');
    }
  }

  void _resetAndLoadProducts() {
    _products.clear();
    _productsError = null;
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
    final id = int.tryParse('${item['id'] ?? ''}') ?? 0;
    // Simple deterministic hash: stable within session (seed), random-ish across ids.
    final v = (id * 1103515245 + _shuffleSeed) & 0x7fffffff;
    return v;
  }

  void _sortOnlineFirstRandom() {
    _products.sort((a, b) {
      final ao = _isOnline(a) ? 1 : 0;
      final bo = _isOnline(b) ? 1 : 0;
      if (ao != bo) return bo - ao; // online first
      return _randKey(a).compareTo(_randKey(b)); // random within group
    });
  }

  Future<void> _loadMoreProducts() async {
    if (_productsLoading || !_productsHasMore) return;
    setState(() {
      _productsLoading = true;
      _productsError = null;
    });
    try {
      final data = await _fetchProductsPage(
        categoryIds: _currentFilterIds,
        searchQuery: _currentSearchQuery,
        paymentMode: _currentPaymentMode,
        page: _productsPage,
        limit: 20,
      );
      final List<dynamic> newItems = List<dynamic>.from(data['data'] ?? const []);
      final int total = (data['count'] is int) ? data['count'] as int : int.tryParse('${data['count']}') ?? 0;

      setState(() {
        _productsTotalCount = total;
        _products.addAll(newItems);
        _sortOnlineFirstRandom();
        _productsPage += 1;
        _productsHasMore = _products.length < _productsTotalCount && newItems.isNotEmpty;
        _productsLoading = false;
      });
    } catch (e) {
      setState(() {
        _productsError = e.toString();
        _productsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      
      // Add the drawer to the Scaffold
      endDrawer: const HomeFilterDrawer(),
      
      body: Container(
        decoration: gradientBackgroundDecoration,
        // Add SafeArea to avoid the status bar
        child: SafeArea( 
          child: Column(
            children: [
              
              // Filter widgets
              HomeTopBar(
                searchController: _searchController,
                onSearchSubmitted: _onSearchSubmitted,
              ),
              const SizedBox(height: 10),
              CategoriesWidget(
                categoriesFuture: _categoriesFuture,
              ),
              const SizedBox(height: 15),
              
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_productsError != null && _products.isEmpty) {
                      return Center(child: Text('An error occurred: $_productsError'));
                    }
                    if (_productsLoading && _products.isEmpty) {
                      return const Center(
                        child: Loading(
                          color: primaryColor,
                          kSize: 30,
                        ),
                      );
                    }
                    if (_products.isEmpty) {
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
                                Icons.inventory_2_outlined,
                                size: 80,
                                color: primaryColor.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No products available',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      controller: _productsScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      itemCount: _products.length + (_productsHasMore ? 1 : 0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        // Compact cards have 2 CTAs + icon row; keep items tall enough to avoid overflow.
                        childAspectRatio: 0.38,
                      ),
                      itemBuilder: (context, index) {
                        if (index >= _products.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 20),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final product = _products[index];
                        if (product is Map<String, dynamic>) {
                          return _buildCompactProductCard(product);
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}