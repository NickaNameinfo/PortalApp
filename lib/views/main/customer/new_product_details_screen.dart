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
import 'package:nickname_portal/utilities/auth_helper.dart';
import 'package:nickname_portal/constants/app_config.dart';
import 'package:nickname_portal/helpers/secure_http_client.dart';

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
  final Map<int, String?> _cartSizes = {}; // Store size from cart for each product
  final Set<int> _cartLoadingIds = {};
  late String _userId = ''; // Initialize with an empty string
  
  // Size selection state
  String? _selectedSize;
  String? _selectedWeight;
  double _currentPrice = 0.0;
  int _currentStock = 0;
  double _currentDiscount = 0.0;
  double _originalPrice = 0.0;
  Map<String, dynamic>? _sizeUnitSizeMap;
  
  // Feedback state
  final TextEditingController _feedbackController = TextEditingController();
  int _feedbackRating = 0;
  bool _isSubmittingFeedback = false;

  // Product photos state
  int _selectedImageIndex = 0;
  List<String> _allProductPhotos = [];

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
    _initializeProductPhotos();
  }
  
  // Initialize product photos (main + sub photos)
  void _initializeProductPhotos() {
    final List<String> photos = [];
    
    // Add main photo first
    final mainPhoto = _safeGet('photo', '');
    if (mainPhoto.isNotEmpty && mainPhoto != 'https://placehold.co/600x400/5E5E5E/FFFFFF/png?text=No+Image') {
      photos.add(mainPhoto);
    }
    
    // Add sub photos from productphotos array
    try {
      final productphotos = widget.product['productphotos'];
      if (productphotos != null) {
        if (productphotos is List) {
          for (var photo in productphotos) {
            String? imgUrl;
            if (photo is Map) {
              imgUrl = photo['imgUrl']?.toString() ?? photo['url']?.toString();
            } else if (photo is String) {
              imgUrl = photo;
            }
            if (imgUrl != null && imgUrl.isNotEmpty) {
              photos.add(imgUrl);
            }
          }
        } else if (productphotos is String) {
          // Try to parse as JSON string
          try {
            final parsed = json.decode(productphotos) as List;
            for (var photo in parsed) {
              String? imgUrl;
              if (photo is Map) {
                imgUrl = photo['imgUrl']?.toString() ?? photo['url']?.toString();
              } else if (photo is String) {
                imgUrl = photo;
              }
              if (imgUrl != null && imgUrl.isNotEmpty) {
                photos.add(imgUrl);
              }
            }
          } catch (e) {
            // If parsing fails, ignore
          }
        }
      }
    } catch (e) {
      // If any error occurs, just use main photo
    }
    
    setState(() {
      _allProductPhotos = photos;
      _selectedImageIndex = 0;
    });
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  // Load user ID from shared preferences
  Future<void> _loadUserId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('userId');
    setState(() {
      _userId = userId ?? '0'; // Set to '0' if null for guest users
    });
    
    // Initialize size data immediately (doesn't depend on cart)
    _initializeSizeData();
    
    // Load store data (and cart if user is logged in)
    _fetchStoreData();
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
        
        // Update UI by calling setState
        if (mounted) {
          setState(() {
            // State is already updated above, this triggers rebuild
          });
        }
      } else {
        // No size map available, set fallback values
        if (mounted) {
          setState(() {
            _updatePriceAndStock();
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing size data: $e');
      // Even on error, try to set fallback values
      if (mounted) {
        setState(() {
          _updatePriceAndStock();
        });
      }
    }
  }
  
  // Update price and stock based on selected size
  void _updatePriceAndStock() {
    if (_selectedSize != null && _sizeUnitSizeMap != null) {
      final sizeData = _sizeUnitSizeMap![_selectedSize];
      if (sizeData is Map) {
        // Get discounted price (total or grandTotal)
        _currentPrice = double.tryParse(sizeData['total']?.toString() ?? 
                                        sizeData['grandTotal']?.toString() ?? 
                                        sizeData['price']?.toString() ?? 
                                        widget.product['total']?.toString() ?? 
                                        widget.product['price']?.toString() ?? '0') ?? 0.0;
        
        // Get original price (price field from sizeData or product)
        _originalPrice = double.tryParse(sizeData['price']?.toString() ?? 
                                         widget.product['price']?.toString() ?? 
                                         widget.product['total']?.toString() ?? '0') ?? 0.0;
        
        // Get discount percentage
        _currentDiscount = double.tryParse(sizeData['discount']?.toString() ?? 
                                           '0') ?? 0.0;
        
        _currentStock = int.tryParse(sizeData['unitSize']?.toString() ?? '0') ?? 0;
      }
    } else {
      // Fallback to default product price and stock
      _originalPrice = double.tryParse(widget.product['price']?.toString() ?? '0') ?? 0.0;
      _currentPrice = double.tryParse(widget.product['total']?.toString() ?? 
                                     widget.product['price']?.toString() ?? '0') ?? 0.0;
      _currentDiscount = double.tryParse(widget.product['discount']?.toString() ?? '0') ?? 0.0;
      _currentStock = int.tryParse(widget.product['unitSize']?.toString() ?? '0') ?? 0;
    }
  }
int? storeId;
  // Fetch store and product data
  Future<void> _fetchStoreData() async {
    if (!isLoading) {
      setState(() {
        isLoading = true;
      });
    }
    try {
      // Safely get store ID - handle both nested store object and direct storeId
      
      if (widget.product['store'] != null && widget.product['store'] is Map) {
        storeId = widget.product['store']['id'] as int?;
      } else if (widget.product['storeId'] != null) {
        storeId = widget.product['storeId'] is int 
            ? widget.product['storeId'] as int
            : int.tryParse(widget.product['storeId'].toString());
      }
      
      if (storeId == null) {
        throw Exception('Store ID not found in product data');
      }
      
      final storeFuture = SecureHttpClient.get(
        '${AppConfig.baseApi}/store/list/$storeId',
        context: context,
      );
      final productFuture = SecureHttpClient.get(
        '${AppConfig.baseApi}/store/product/getAllProductById/$storeId',
        context: context,
      );
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
    // Skip cart loading for guest users
    if (_userId == null || _userId == '0' || _userId.isEmpty) {
      // Still initialize size data even without cart
      if (mounted) {
        _initializeSizeData();
      }
      return;
    }
    
    try {
      final response = await fetchCartItems(_userId);
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] is List) {
          final List<dynamic> cartItems = responseData['data'];
          if (mounted) {
            setState(() {
              _cartQuantities.clear();
              _cartSizes.clear();
              for (var item in cartItems) {
                final productId = item['productId'] as int?;
                final quantity = item['qty'] as int?;
                final size = item['size']?.toString();
                if (productId != null && quantity != null) {
                  _cartQuantities[productId] = quantity;
                  if (size != null && size.isNotEmpty) {
                    _cartSizes[productId] = size;
                  }
                }
              }
            });
            // Re-initialize size data after cart is loaded to use cart size
            _initializeSizeData();
          }
        } else {
          // Even if cart API fails, initialize size data
          if (mounted) {
            _initializeSizeData();
          }
        }
      } else {
        // Even if cart API fails, initialize size data
        if (mounted) {
          _initializeSizeData();
        }
      }
    } catch (e) {
      print('Error loading cart data: $e');
      // Even if cart loading fails, initialize size data
      if (mounted) {
        _initializeSizeData();
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> productData) async {
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
    
    final productId = productData['id'] as int;
    final currentQuantity = _cartQuantities[productId] ?? 0;
    
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
    
    final newQuantity = currentQuantity + 1;
    
    // Include size and weight in product data
    final productWithSize = Map<String, dynamic>.from(productData);
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
    final currentQuantity = _cartQuantities[productId] ?? 0;
    
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
    
    final newQuantity = currentQuantity + 1;
    
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
    final currentQuantity = _cartQuantities[productId] ?? 0;
    if (currentQuantity <= 0) return;
    
    final newQuantity = currentQuantity - 1;
    
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

  // Show full-screen image viewer
  void _showFullScreenImage(BuildContext context, String imageUrl, {int initialIndex = 0}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) => _FullScreenImageViewer(
          imageUrl: imageUrl,
          allImages: _allProductPhotos,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  // Store header widget
  Widget buildStoreHeader() {
    final String openTime = store?['openTime'] ?? 'N/A';
    final String closeTime = store?['closeTime'] ?? 'N/A';
    final String openCloseTime = (openTime != 'N/A' && closeTime != 'N/A') ? '$openTime : $closeTime' : 'Timings not available';
    final String? storePhone = store?['phone'];
    final String? storeWebsite = store?['website'];
    final String storeName = store?['storename'] ?? 'This Store';
    final String? location = store?['location'] ?? store?['storeaddress'];
    final double rating = double.tryParse(store?['rating']?.toString() ?? '4.2') ?? 4.2;
    final String distance = store?['distance']?.toString() ?? 'N/A';

    return Container(
      margin: const EdgeInsets.all(16.0),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (storeId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoreDetails(storeId: storeId!),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Store ID not available')),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[100],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          store?['storeImage'] ?? 'https://via.placeholder.com/100x100.png?text=Store',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.store,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Store Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Name
                          Text(
                            storeName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Rating and Timing Row
                          Row(
                            children: [
                              // Rating Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.orange, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Timing Badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time, size: 14, color: Colors.green[700]),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          openCloseTime,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Action Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Call Button
                    _buildActionButton(
                      icon: Icons.call_outlined,
                      color: Colors.blue,
                      onTap: () {
                        if (storePhone != null) {
                          makePhoneCall(storePhone);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Phone number not available.')),
                          );
                        }
                      },
                    ),
                    // Website Button
                    _buildActionButton(
                      icon: Icons.language_outlined,
                      color: Colors.purple,
                      onTap: () {
                        launchWebsite(storeWebsite ?? '', storeId ?? 0);
                      },
                    ),
                    // Location Button
                    _buildActionButton(
                      icon: Icons.location_on_outlined,
                      color: Colors.red,
                      onTap: () {
                        if (location != null && location.isNotEmpty) {
                          openMap(location);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Location not available.')),
                          );
                        }
                      },
                    ),
                    // More Info Button
                    _buildActionButton(
                      icon: Icons.arrow_forward_ios,
                      color: primaryColor,
                      onTap: () {
                        if (storeId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoreDetails(storeId: storeId!),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Store ID not available')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bottom Info Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Products Count
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            '${products.length} Products',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      // Distance
                      if (distance != 'N/A')
                        Row(
                          children: [
                            Icon(Icons.near_me_outlined, size: 16, color: primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'Near By : ${distance} km',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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

  // Helper method to build action button
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 22,
        ),
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

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while data is being fetched
    if (isLoading) {
      return Scaffold(
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
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Safely parse data based on the provided API response structure
    final double price = double.tryParse(_safeGet('price', '0')) ?? 0.0;
    // Calculate final price after discount (API: total = 44100)
    final double discountedPrice = double.tryParse(_safeGet('total', price.toString())) ?? price;
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
      // Use DefaultTabController for the tabbed interface at the bottom
      body: DefaultTabController(
        length: 2, // Description and FeedBack (Customization is commented out)
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Product Image & Main Info Card (Full Width) ---
              Padding(
                padding: const EdgeInsets.all(16.0), 
                child: Container(
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
                        // Product Image with Thumbnails
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Image
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_allProductPhotos.isNotEmpty) {
                                    _showFullScreenImage(
                                      context,
                                      _allProductPhotos[_selectedImageIndex],
                                      initialIndex: _selectedImageIndex,
                                    );
                                  } else {
                                    _showFullScreenImage(
                                      context,
                                      _safeGet('photo', 'https://placehold.co/600x400/5E5E5E/FFFFFF/png?text=No+Image'),
                                    );
                                  }
                                },
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  color: Colors.grey.shade100,
                                    height: 200,
                                    width: double.infinity,
                                        child: _allProductPhotos.isNotEmpty
                                            ? Image.network(
                                                _allProductPhotos[_selectedImageIndex],
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  height: 200,
                                                  color: Colors.grey.shade200,
                                                  child: const Center(child: Text('Image Failed to Load')),
                                                ),
                                              )
                                            : Image.network(
                                                _safeGet('photo', 'https://placehold.co/600x400/5E5E5E/FFFFFF/png?text=No+Image'),
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 200,
                                      color: Colors.grey.shade200,
                                      child: const Center(child: Text('Image Failed to Load')),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in,
                                    color: Colors.white,
                                    size: 18,
                                        ),
                                      ),
                                    ),
                                    // Photo count badge
                                    if (_allProductPhotos.length > 1)
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${_selectedImageIndex + 1}/${_allProductPhotos.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                              ),
                            ),
                            // Thumbnail Gallery (if multiple photos)
                            if (_allProductPhotos.length > 1) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 60,
                                child: Column(
                                  children: [
                                    ...List.generate(
                                      _allProductPhotos.length > 4 ? 4 : _allProductPhotos.length,
                                      (index) => GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedImageIndex = index;
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: _selectedImageIndex == index
                                                  ? primaryColor
                                                  : Colors.grey.shade300,
                                              width: _selectedImageIndex == index ? 2 : 1,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(5),
                                            child: Image.network(
                                              _allProductPhotos[index],
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                width: 60,
                                                height: 60,
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.broken_image, size: 20),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Show "+X more" indicator if more than 4 photos
                                    if (_allProductPhotos.length > 4)
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(6),
                                          color: Colors.grey.shade100,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '+${_allProductPhotos.length - 4}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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
                        
                        // Discount Badge (if applicable)
                        if (_currentDiscount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    '${_currentDiscount.toStringAsFixed(0)}% OFF',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // Discounted Price (dynamic based on size)
                                Text(
                                  '₹${(_currentPrice > 0 ? _currentPrice : discountedPrice).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Original Price (show if there's a discount)
                                if (_currentDiscount > 0 && _originalPrice > _currentPrice)
                                  Text(
                                    '₹${_originalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                              ],
                            ),
                            // Stock Indicator (dynamic based on size)
                            Text(
                              isBooking ? 'Booking Only' : ((_currentStock > 0 || stockQty > 0) ? '$_currentStock Stocks' : 'Out of Stock'),
                              style: TextStyle(
                                fontSize: 16,
                                color: isBooking ? Colors.orange.shade600 : ((_currentStock > 0 || stockQty > 0) ? Colors.green.shade600 : Colors.red.shade600),
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
                        
                        // Size Selection UI
                        if (_sizeUnitSizeMap != null && _sizeUnitSizeMap!.isNotEmpty) ...[
                          const SizedBox(height: 20),
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
                                                    ? () async {
                                                        // Check if user is logged in
                                                        final isLoggedIn = await AuthHelper.checkAuthAndShowDialog(
                                                          context,
                                                          message: 'Please login to place an order.',
                                                        );
                                                        
                                                        if (!isLoggedIn) {
                                                          return; // User chose not to login
                                                        }
                                                        
                                                        // Create a 'cart-like' item map that CheckoutScreen understands
                                                        final checkoutProduct = {
                                                          'productId': widget.product['id'] ?? '',
                                                          'name': _safeGet('name', 'Product Name'),
                                                          'price': (_currentPrice > 0 ? _currentPrice : discountedPrice).toString(),
                                                          'qty': 1, // Default quantity for "Buy Now"
                                                          'storeId': widget.product['storeId'] ?? '',
                                                          'photo': _safeGet('photo', ''),
                                                          'isBooking': isBooking, // Pass booking status
                                                          'total': (_currentPrice > 0 ? _currentPrice : discountedPrice).toString(),
                                                          if (_selectedSize != null) 'size': _selectedSize,
                                                          if (_selectedWeight != null) 'weight': _selectedWeight,
                                                        };

                                                        if (mounted) {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) => CheckoutScreen(
                                                                product: checkoutProduct,
                                                              ),
                                                            ),
                                                          );
                                                        }
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
    return Container(
      margin: const EdgeInsets.all(16),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.description, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Product Description',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
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

  // Submit feedback function
  Future<void> _submitFeedback() async {
    // Check if user is logged in and show login dialog if not
    final isLoggedIn = await AuthHelper.checkAuthAndShowDialog(
      context,
      message: 'Please login to submit feedback.',
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

    // Validate feedback
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback')),
      );
      return;
    }

    if (_feedbackRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() {
      _isSubmittingFeedback = true;
    });

    try {
      final product = widget.product;
      final productId = product['id'] as int?;
      final storeId = product['storeId'] as int? ?? 
                     (product['store'] is Map ? (product['store']['id'] as int?) : null);
      
      // Determine vendorId or storeId based on product type
      int? vendorId;
      int? finalStoreId;
      
      if (product['createdType'] == 'Vendor') {
        vendorId = product['createdId'] as int?;
      } else {
        finalStoreId = storeId ?? product['createdId'] as int?;
      }

      final feedbackData = {
        'customerId': _userId,
        'productId': productId,
        'vendorId': vendorId,
        'storeId': finalStoreId,
        'feedBack': _feedbackController.text.trim(),
        'rating': _feedbackRating,
        'customizedMessage': _feedbackController.text.trim(),
      };

      final response = await SecureHttpClient.post(
        '${AppConfig.baseApi}/productFeedback/create',
        body: feedbackData,
        context: context,
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Feedback submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            // Clear form
            _feedbackController.clear();
            setState(() {
              _feedbackRating = 0;
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['msg'] ?? 'Failed to submit feedback'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit feedback. Status: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingFeedback = false;
        });
      }
    }
  }

  // Build star rating widget
  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return GestureDetector(
          onTap: () {
            setState(() {
              _feedbackRating = starValue;
            });
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              starValue <= _feedbackRating ? Icons.star : Icons.star_border,
              color: starValue <= _feedbackRating ? Colors.amber : Colors.grey,
              size: 32,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFeedBackCard() {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.feedback, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Give Feedback',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Rating Section
            const Text(
              'Rating:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            _buildStarRating(),
            if (_feedbackRating > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Selected: $_feedbackRating star${_feedbackRating != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Feedback Text Field
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter your feedback',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSubmittingFeedback || 
                           _feedbackController.text.trim().isEmpty || 
                           _feedbackRating == 0)
                    ? null
                    : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_feedbackController.text.trim().isNotEmpty && 
                                   _feedbackRating > 0)
                      ? primaryColor
                      : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSubmittingFeedback
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-screen image viewer widget
class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final List<String>? allImages;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.imageUrl,
    this.allImages,
    this.initialIndex = 0,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      // Reset zoom with animation
      _transformationController.value = Matrix4.identity();
    } else {
      // Zoom in to 2.5x for better clarity
      final position = _doubleTapDetails!.localPosition;
      final double scale = 2.5;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
        ..scale(scale);
    }
  }
  
  List<String> get _images {
    if (widget.allImages != null && widget.allImages!.isNotEmpty) {
      return widget.allImages!;
    }
    return [widget.imageUrl];
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final hasMultipleImages = images.length > 1;
    
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        top: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image viewer with PageView for multiple images
            hasMultipleImages
                ? PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        _transformationController.value = Matrix4.identity();
                      });
                    },
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onDoubleTapDown: _handleDoubleTapDown,
                        onDoubleTap: _handleDoubleTap,
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 0.5,
                          maxScale: 5.0,
                          panEnabled: true,
                          scaleEnabled: true,
                          child: Container(
                            color: Colors.black,
                            child: Center(
                              child: Image.network(
                                images[index],
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Loading image...',
                                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.white, size: 48),
                                      SizedBox(height: 16),
                                      Text(
                                        'Failed to load image',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : GestureDetector(
              onDoubleTapDown: _handleDoubleTapDown,
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 5.0,
                panEnabled: true,
                scaleEnabled: true,
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading image...',
                                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 48),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ),
            ),
            // Image counter (if multiple images)
            if (hasMultipleImages)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Instructions
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Pinch to zoom • Double tap to zoom in/out',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}