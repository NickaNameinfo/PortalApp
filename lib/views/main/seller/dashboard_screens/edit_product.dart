import 'dart:async';
import 'dart:convert'; // Added for JSON encoding/decoding
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // Added for making HTTP requests
import 'package:nickname_portal/components/loading.dart';
import 'package:nickname_portal/helpers/category_service.dart'; // Added for CategoryService
import 'package:nickname_portal/helpers/secure_http_client.dart'; // Secure HTTP client with authentication
import 'package:nickname_portal/helpers/file_validation.dart'; // File validation utilities
import 'package:nickname_portal/components/gradient_background.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added for SharedPreferences
import '../../../../utilities/categories_list.dart'; // Still needed for legacy/default values
import 'package:path/path.dart' as path;
import 'package:nickname_portal/constants/colors.dart';
import 'package:nickname_portal/constants/app_config.dart';
import 'package:nickname_portal/models/subscription_model.dart'; // Import SubscriptionPlan
import 'dart:typed_data';
import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../add_category_screen.dart';

// New: Enum for Product Status
enum ProductStatus { active, inactive }

// New: Enum for Payment Type
enum PaymentType { perOrder, onlinePayment, cashOnDelivery }

// New: Enum for Service Type
enum ServiceType { product, service }

class EditProduct extends StatefulWidget {
  static const routeName = '/edit_product';
  // Use nullable Map<String, dynamic>? to safely represent optional product data
  final Map<String, dynamic>? productData;

  const EditProduct({
    super.key,
    this.productData,
  });

  @override
  State<EditProduct> createState() => _EditProductState();
}

// for fields
enum Field {
  title,
  price,
  quantity,
  description,
  unit, // New field
  discountPer, // New field for Discount Price
  discount, // New field for Discount (%)
}

enum DropDownType { category, subCategory, status, childCategory } // Added childCategory

class _EditProductState extends State<EditProduct> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _unitController = TextEditingController(); // New Controller
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _discountController = TextEditingController(); // New Controller for Discount (%)
  final _discountPriceController = TextEditingController(); // New Controller for Discount Price
  final _totalController = TextEditingController(); // New Controller for Total
  final _grandTotalController = TextEditingController(); // New Controller for Grand Total
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController(); // Added brand controller

  List<dynamic> productImages = []; // Main product image
  List<String> imageDownloadLinks = []; // Main image URLs
  List<XFile> subImages = []; // New sub-images to upload
  List<String> existingSubImages = []; // Existing sub-image URLs from API
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _fullProductData; // Full product data fetched by ID (includes all photos)

  var isInit = true;
  var currentImage = 0;
  String? _supplierId; 
  
  // Stored as String IDs (which is how the API accepts them)
  String? selectedCategoryId; 
  String? selectedSubCategoryId; 
  String? selectedChildCategoryId; 

  var currentStatus = ProductStatus.active; 
  var isEcommerceEnabled = false; 
  var isCustomizeEnabled = false; 
  var isBookingEnabled = false; // For Book Service subscription (Plan3)
  var currentServiceType = ServiceType.product; // Default to product
  
  // Payment Mode states
  bool isPerOrderEnabled = false;
  bool isOnlinePaymentEnabled = false;
  bool isCashOnDeliveryEnabled = false;
  
  // Size Management states
  bool enableSizeManagement = false;
  Map<String, Map<String, dynamic>> sizeUnitSizeMap = {}; // Map<size, {unitSize, qty, price, discount, discountPer, total, grandTotal}>
  List<Map<String, dynamic>> sizeEntries = []; // List of size entries for display
  String? selectedSize; // Currently selected size (nullable to avoid dropdown errors)
  final List<String> availableSizes = ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', '4XL', '5XL', '6XL', '7XL', '8XL', '9XL', '10XL'];
  
  // Helper to normalize size (case-insensitive matching)
  String? _normalizeSize(String? size) {
    if (size == null || size.isEmpty) return null;
    final upperSize = size.toUpperCase();
    return availableSizes.firstWhere(
      (s) => s.toUpperCase() == upperSize,
      orElse: () => availableSizes.first, // Default to first if not found
    );
  }
  
  // Controllers for size management
  final _sizeUnitSizeController = TextEditingController();
  final _sizePriceController = TextEditingController();
  final _sizeDiscountController = TextEditingController();
  final _sizeQuantityController = TextEditingController();

  var isLoading = false;
  var isImagePicked = false; 

  List<dynamic> _categories = []; // Main Category List
  List<dynamic> _subcategories = []; // Subcategory List for selected category
  List<dynamic> _childCategories = []; // Child Category List for selected subcategory
  bool _isCategoryLoading = true; 
  final TextEditingController _categorySearchController = TextEditingController();

  String? _customerId;
  SubscriptionPlan? _plan1Subscription;
  SubscriptionPlan? _plan2Subscription;
  SubscriptionPlan? _plan3Subscription;
  bool _isLoadingSubscriptions = true;
  
  // Product counts for "Used" calculation
  int _ecommerceUsedCount = 0;
  int _customizeUsedCount = 0;
  int _bookingUsedCount = 0;

  Future<void> _loadCustomerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final loadedCustomerId = prefs.getString('storeId');
    
    if (mounted) {
      setState(() {
        _customerId = loadedCustomerId; 
      });
      
      if (_customerId != null) {
        await _fetchUserSubscriptions();
        await _fetchProductCounts();
      } else {
        if (mounted) {
          setState(() {
            _plan1Subscription = null;
            _plan2Subscription = null;
            _plan3Subscription = null;
            _isLoadingSubscriptions = false;
          });
        }
      }
    }
  }

  /// Fetches user subscriptions from the API endpoint: auth/user/{userId}
  /// 
  /// API Response Structure:
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "id": 119,
  ///     "subscriptions": [
  ///       {
  ///         "id": 137,
  ///         "subscriptionType": "Plan1" | "Plan2" | "Plan3",
  ///         "subscriptionPlan": "PL1_005",
  ///         "subscriptionPrice": "10016.00",
  ///         "customerId": 55,
  ///         "status": "1",
  ///         "subscriptionCount": 200,
  ///         "freeCount": 0
  ///       }
  ///     ]
  ///   }
  /// }
  Future<void> _fetchUserSubscriptions() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId == null || userId.isEmpty || userId == '0') {
        if (mounted) {
          setState(() {
            _plan1Subscription = null;
            _plan2Subscription = null;
            _plan3Subscription = null;
            _isLoadingSubscriptions = false;
          });
        }
        return;
      }

      // Fetch user data with subscriptions from api/auth/user/{userId}
      final url = '${AppConfig.baseApi}/auth/user/$userId';
      debugPrint('Fetching user subscriptions from: $url');
      final response = await SecureHttpClient.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('User data response: ${data['success']}');
        
        if (data['success'] == true && data['data'] != null) {
          final userData = data['data'];
          final subscriptions = userData['subscriptions'] as List<dynamic>?;
          debugPrint('Found ${subscriptions?.length ?? 0} subscriptions');
          
          SubscriptionPlan? plan1;
          SubscriptionPlan? plan2;
          SubscriptionPlan? plan3;
          
          if (subscriptions != null && subscriptions.isNotEmpty) {
            // Find Plan1 subscription (Ecommerce)
            final plan1List = subscriptions.where(
              (sub) => sub['subscriptionType'] == 'Plan1' && sub['status'] == '1',
            ).toList();
            if (plan1List.isNotEmpty) {
              plan1 = SubscriptionPlan.mergedFromList(plan1List);
              debugPrint('Plan1 subscription found: ${plan1?.subscriptionPlan} with total count: ${plan1?.subscriptionCount}');
            }
            
            // Find Plan2 subscription (Customize)
            final plan2List = subscriptions.where(
              (sub) => sub['subscriptionType'] == 'Plan2' && sub['status'] == '1',
            ).toList();
            if (plan2List.isNotEmpty) {
              plan2 = SubscriptionPlan.mergedFromList(plan2List);
              debugPrint('Plan2 subscription found: ${plan2?.subscriptionPlan} with total count: ${plan2?.subscriptionCount}');
            }
            
            // Find Plan3 subscription (Booking)
            final plan3List = subscriptions.where(
              (sub) => sub['subscriptionType'] == 'Plan3' && sub['status'] == '1',
            ).toList();
            if (plan3List.isNotEmpty) {
              plan3 = SubscriptionPlan.mergedFromList(plan3List);
              debugPrint('Plan3 subscription found: ${plan3?.subscriptionPlan} with total count: ${plan3?.subscriptionCount}');
            }
          } else {
            debugPrint('No subscriptions found in user data');
          }
          
          if (mounted) {
            setState(() {
              _plan1Subscription = plan1;
              _plan2Subscription = plan2;
              _plan3Subscription = plan3;
              _isLoadingSubscriptions = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _plan1Subscription = null;
              _plan2Subscription = null;
              _plan3Subscription = null;
              _isLoadingSubscriptions = false;
            });
          }
        }
      } else {
        debugPrint('Failed to fetch user data. Status code: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _plan1Subscription = null;
            _plan2Subscription = null;
            _plan3Subscription = null;
            _isLoadingSubscriptions = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user subscriptions: $e');
      if (mounted) {
        setState(() {
          _plan1Subscription = null;
          _plan2Subscription = null;
          _plan3Subscription = null;
          _isLoadingSubscriptions = false;
        });
      }
    }
  }

  /// Fetches product counts to calculate "Used" subscription counts
  /// Counts products with isEnableEcommerce, isEnableCustomize, and isBooking enabled
  Future<void> _fetchProductCounts() async {
    try {
      if (_customerId == null || _customerId!.isEmpty) {
        return;
      }

      // Fetch products from store
      final url = '${AppConfig.baseApi}/store/product/admin/getAllProductById/$_customerId';
      final response = await SecureHttpClient.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final products = data['data'] as List<dynamic>?;

        if (products != null) {
          int ecommerceCount = 0;
          int customizeCount = 0;
          int bookingCount = 0;

          for (var product in products) {
            // Check if product has the subscription features enabled
            if (product['product'] != null) {
              final productData = product['product'] as Map<String, dynamic>;
              
              // Count Ecommerce (Plan1)
              if (productData['isEnableEcommerce']?.toString() == '1') {
                ecommerceCount++;
              }
              
              // Count Customize (Plan2)
              if (productData['isEnableCustomize']?.toString() == '1' || 
                  productData['isEnableCustomize'] == 1) {
                customizeCount++;
              }
              
              // Count Booking (Plan3)
              if (productData['isBooking']?.toString() == '1' || 
                  productData['isBooking'] == 1) {
                bookingCount++;
              }
            }
          }

          if (mounted) {
            setState(() {
              _ecommerceUsedCount = ecommerceCount;
              _customizeUsedCount = customizeCount;
              _bookingUsedCount = bookingCount;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching product counts: $e');
      // Set counts to 0 on error
      if (mounted) {
        setState(() {
          _ecommerceUsedCount = 0;
          _customizeUsedCount = 0;
          _bookingUsedCount = 0;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty strings to prevent null issues if _initProductData fails
    _titleController.text = '';
    _unitController.text = '';
    _priceController.text = '';
    _quantityController.text = '';
    _discountController.text = '';
    _discountPriceController.text = '';
    _totalController.text = '';
    _grandTotalController.text = '';
    _sizeUnitSizeController.text = '';
    _sizePriceController.text = '';
    _sizeDiscountController.text = '';
    _sizeQuantityController.text = '';
    _descriptionController.text = '';
    _brandController.text = '';
    
    // Initialize selectedSize to first available size
    if (selectedSize == null && availableSizes.isNotEmpty) {
      selectedSize = availableSizes.first;
    }
    
    _loadSupplierId();
    _loadCustomerId(); // Call _loadCustomerId here
    _fetchCategories().then((_) {
      // If editing, fetch full product details to get all photos
      if (widget.productData != null && widget.productData!['id'] != null) {
        _fetchFullProductDetails(widget.productData!['id']).then((_) {
          // Initialize product data only after categories and full product details are fetched
          _initProductData();
        });
      } else {
        // Initialize product data only after categories are fetched
        _initProductData();
      }
    });
    
    _priceController.addListener(_calculateTotals);
    _quantityController.addListener(_calculateTotals);
    _discountController.addListener(_calculateTotals);
    // _discountPriceController not listened - discount price is auto-calculated from discount %
    debugPrint('productImages on init: $productImages');
    debugPrint('isImagePicked on init: $isImagePicked');
  }

  String _categoryNameById(String? id) {
    if (id == null) return '';
    final match = _categories.where((c) => c is Map && c['id']?.toString() == id).toList();
    if (match.isEmpty) return '';
    final m = match.first as Map;
    return (m['name'] ?? '').toString();
  }

  Future<void> _openCategoryPicker() async {
    if (_isCategoryLoading) return;
    _categorySearchController.text = '';
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String q = '';
        return StatefulBuilder(
          builder: (context, setSheet) {
            final list = _categories
                .whereType<Map<String, dynamic>>()
                .where((c) => (c['name'] ?? '').toString().toLowerCase().contains(q))
                .toList();
            return Container(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Select category",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop(null);
                          await Navigator.of(this.context).push(
                            MaterialPageRoute(builder: (_) => const AddCategoryScreen()),
                          );
                          await _fetchCategories();
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.add, size: 18, color: primaryColor),
                        label: const Text(
                          "New",
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _categorySearchController,
                    onChanged: (v) => setSheet(() => q = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        final id = c['id']?.toString();
                        final name = (c['name'] ?? '').toString();
                        final isSel = id != null && id == selectedCategoryId;
                        return ListTile(
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                          trailing: isSel ? const Icon(Icons.check_circle, color: successColor) : null,
                          onTap: () => Navigator.of(context).pop(id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        selectedCategoryId = selected;
        _updateSubcategoryList(selectedCategoryId);
        selectedSubCategoryId = null;
        selectedChildCategoryId = null;
      });
    }
  }

  Future<void> _loadSupplierId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _supplierId = prefs.getString('storeId');
      });
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final url = '${AppConfig.baseApi}/category/getAllCategory';
      final response = await SecureHttpClient.get(
        url,
        timeout: const Duration(seconds: 15),
        context: context,
      );
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true) {
          if (mounted) {
            setState(() {
              final raw = decodedData['data'];
              _categories = raw is List ? raw : [];
              _isCategoryLoading = false;
            });
          }
        } else {
           debugPrint('API failed to return categories: ${decodedData['message']}');
          if (mounted) setState(() => _isCategoryLoading = false);
        }
      } else {
        debugPrint('Failed to fetch categories: ${response.statusCode} body=${response.body}');
        if (mounted) setState(() => _isCategoryLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) setState(() => _isCategoryLoading = false);
    }
  }

  // Fetch full product details by ID to get all productphotos
  Future<void> _fetchFullProductDetails(int productId) async {
    try {
      debugPrint('Fetching full product details for product ID: $productId');
      final response = await SecureHttpClient.get(
        '${AppConfig.baseApi}/product/getProductById/$productId',
        timeout: const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          final fullProductData = decodedData['data'];
          debugPrint('Full product data fetched. productphotos count: ${fullProductData['productphotos'] is List ? (fullProductData['productphotos'] as List).length : 'not a list'}');
          
          // Update widget.productData with the full product data (including all photos)
          // We'll merge the full product data into the existing productData
          if (mounted && widget.productData != null) {
            // Create a new map with merged data, prioritizing full product data
            final updatedProductData = Map<String, dynamic>.from(widget.productData!);
            updatedProductData.addAll(fullProductData);
            
            // Use a workaround: store in a state variable since we can't modify widget.productData
            // We'll use this in _initProductData
            _fullProductData = updatedProductData;
            debugPrint('Full product data stored. Ready to initialize.');
          }
        } else {
          debugPrint('Failed to fetch full product details: ${decodedData['message']}');
        }
      } else {
        debugPrint('Failed to fetch full product details: Status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching full product details: $e');
      // Continue with existing productData if fetch fails
    }
  }


  // Find the subcategory list for the currently selected category ID
  void _updateSubcategoryList(String? categoryId) {
    if (categoryId == null) return;
    
    // Find the category map by ID
    final category = _categories.firstWhere(
      (cat) => cat['id']?.toString() == categoryId,
      orElse: () => null,
    );

    if (category != null) {
      if (mounted) {
        setState(() {
          _subcategories = category['subcategories'] ?? [];
          // If the previously selected subcategory ID is not found in the new list, reset it
          if (!_subcategories.any((sub) => sub['id']?.toString() == selectedSubCategoryId)) {
            selectedSubCategoryId = null;
            selectedChildCategoryId = null;
            _childCategories = [];
          } else {
            // Re-populate child categories if the subcategory remains selected
            _updateChildCategoryList(selectedSubCategoryId);
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _subcategories = [];
          selectedSubCategoryId = null;
          selectedChildCategoryId = null;
          _childCategories = [];
        });
      }
    }
  }

  // Find the child category list for the currently selected subcategory ID
  void _updateChildCategoryList(String? subcategoryId) {
    if (subcategoryId == null) return;

    final subcategory = _subcategories.firstWhere(
      (sub) => sub['id']?.toString() == subcategoryId,
      orElse: () => null,
    );

    if (subcategory != null) {
      if (mounted) {
        setState(() {
          // Assuming child categories are nested here if they exist
          _childCategories = subcategory['childcategories'] ?? []; 
          // Reset selected child category if the old one is no longer valid
          if (!_childCategories.any((child) => child['id']?.toString() == selectedChildCategoryId)) {
            selectedChildCategoryId = null;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _childCategories = [];
          selectedChildCategoryId = null;
        });
      }
    }
  }

  void _initProductData() {
    // Use full product data if available (has all photos), otherwise use widget.productData
    final productData = _fullProductData ?? widget.productData;
    if (productData != null) {
      debugPrint('=== _initProductData called ===');
      debugPrint('Using ${_fullProductData != null ? "full product data" : "widget.productData"}');
      debugPrint('productData keys: ${productData.keys.toList()}');
      
      _titleController.text = productData['name'] ?? '';
      _descriptionController.text = productData['sortDesc'] ?? '';
      _priceController.text = productData['price']?.toString() ?? '';
      _quantityController.text = productData['qty']?.toString() ?? '';
      _discountController.text = productData['discount']?.toString() ?? '';
      _discountPriceController.text = productData['discountPer']?.toString() ?? '';
      _totalController.text = productData['total']?.toString() ?? '';
      _grandTotalController.text = productData['grand_total']?.toString() ?? '';
      _unitController.text = productData['unitSize'] ?? '';
      _brandController.text = productData['brand'] ?? '';

      // Set state variables only if mounted to avoid crash
      if (mounted) {
        setState(() {
          currentStatus = (productData['status'] == "1") ? ProductStatus.active : ProductStatus.inactive;
          
          // Handle main product image
          final mainPhoto = productData['photo'];
          if (mainPhoto != null && mainPhoto.toString().isNotEmpty) {
            productImages = [mainPhoto];
            isImagePicked = true;
          } else {
            productImages = [];
            isImagePicked = false;
          }
          
          // Handle sub-images (productphotos) - extract URLs from JSON maps
          existingSubImages = [];
          try {
            // Check both direct access and nested 'product' structure
            dynamic productphotos = productData['productphotos'];
            debugPrint('Direct productphotos access: ${productphotos != null ? (productphotos is List ? 'List with ${productphotos.length} items' : productphotos.runtimeType) : 'null'}');
            
            if (productphotos == null && productData['product'] != null) {
              // Try nested structure
              productphotos = productData['product']['productphotos'];
              debugPrint('Nested productphotos access: ${productphotos != null ? (productphotos is List ? 'List with ${productphotos.length} items' : productphotos.runtimeType) : 'null'}');
            }
            
            if (productphotos != null) {
              if (productphotos is List) {
                debugPrint('✅ Processing ${productphotos.length} product photos...');
                for (int i = 0; i < productphotos.length; i++) {
                  final photo = productphotos[i];
                  String? imgUrl;
                  if (photo is Map) {
                    // Handle JSON map with imgUrl property
                    imgUrl = photo['imgUrl']?.toString() ?? photo['url']?.toString();
                    debugPrint('  [${i + 1}/${productphotos.length}] Extracted imgUrl from Map: $imgUrl');
                  } else if (photo is String) {
                    imgUrl = photo;
                    debugPrint('  [${i + 1}/${productphotos.length}] Extracted imgUrl from String: $imgUrl');
                  } else {
                    debugPrint('  [${i + 1}/${productphotos.length}] Unknown photo type: ${photo.runtimeType}');
                  }
                  if (imgUrl != null && imgUrl.isNotEmpty) {
                    existingSubImages.add(imgUrl);
                    debugPrint('  ✅ Added to existingSubImages. Total count: ${existingSubImages.length}');
                  } else {
                    debugPrint('  ❌ Skipped photo (no valid URL): $photo');
                  }
                }
                debugPrint('🎯 Final existingSubImages count: ${existingSubImages.length}');
              } else if (productphotos is String) {
                // Try to parse as JSON string
                try {
                  final parsed = jsonDecode(productphotos) as List;
                  debugPrint('Parsed JSON string, found ${parsed.length} photos');
                  for (var photo in parsed) {
                    String? imgUrl;
                    if (photo is Map) {
                      imgUrl = photo['imgUrl']?.toString() ?? photo['url']?.toString();
                    } else if (photo is String) {
                      imgUrl = photo;
                    }
                    if (imgUrl != null && imgUrl.isNotEmpty) {
                      existingSubImages.add(imgUrl);
                    }
                  }
                } catch (e) {
                  debugPrint('Error parsing productphotos JSON string: $e');
                }
              } else {
                debugPrint('❌ productphotos is neither List nor String: ${productphotos.runtimeType}');
              }
            } else {
              debugPrint('❌ No productphotos found in productData');
              debugPrint('Available keys in productData: ${productData.keys.toList()}');
            }
          } catch (e, stackTrace) {
            debugPrint('❌ Error extracting productphotos: $e');
            debugPrint('Stack trace: $stackTrace');
          }
          
          isEcommerceEnabled = (productData['isEnableEcommerce'] == "1");
          isCustomizeEnabled = (productData['isEnableCustomize'] == 1);
          isBookingEnabled = (productData['isBooking'] == "1");
          
          // Service Type
          final String? serviceType = productData['serviceType']?.toString();
          currentServiceType = (serviceType == "Service") ? ServiceType.service : ServiceType.product;

          // Category IDs (stored as strings)
          selectedCategoryId = productData['categoryId']?.toString();
          selectedSubCategoryId = productData['subCategoryId']?.toString();
          selectedChildCategoryId = productData['childCategoryId']?.toString();
        
          // Populate subcategories based on initial category ID
          // Must call this after _categories list is populated in _fetchCategories
          if (!_isCategoryLoading) {
            _updateSubcategoryList(selectedCategoryId);
            _updateChildCategoryList(selectedSubCategoryId);
          }

          // Payment modes
          final String paymentMode = productData['paymentMode'] ?? '';
          isPerOrderEnabled = paymentMode.contains('1');
          isOnlinePaymentEnabled = paymentMode.contains('2');
          isCashOnDeliveryEnabled = paymentMode.contains('3');
          
          // Size Management
          if (productData['sizeUnitSizeMap'] != null) {
            try {
              Map<String, dynamic> parsedMap;
              if (productData['sizeUnitSizeMap'] is String) {
                parsedMap = Map<String, dynamic>.from(jsonDecode(productData['sizeUnitSizeMap']));
              } else {
                parsedMap = Map<String, dynamic>.from(productData['sizeUnitSizeMap']);
              }
              
              if (parsedMap.isNotEmpty) {
                enableSizeManagement = true;
                sizeUnitSizeMap = {};
                sizeEntries = [];
                
                parsedMap.forEach((size, data) {
                  // Normalize size to match availableSizes (case-insensitive)
                  final normalizedSize = _normalizeSize(size);
                  if (normalizedSize == null) return; // Skip invalid sizes
                  
                  Map<String, dynamic> sizeData;
                  if (data is Map) {
                    sizeData = Map<String, dynamic>.from(data);
                  } else {
                    sizeData = {
                      'unitSize': data?.toString() ?? '0',
                      'qty': data?.toString() ?? '0',
                      'price': '0',
                      'discount': '0',
                      'discountPer': '0',
                      'total': '0',
                      'grandTotal': '0',
                    };
                  }
                  
                  // Calculate missing values with null safety
                  final price = double.tryParse(sizeData['price']?.toString() ?? '0') ?? 0.0;
                  final discount = double.tryParse(sizeData['discount']?.toString() ?? '0') ?? 0.0;
                  final discountAmount = (price * discount) / 100;
                  final discountedPrice = price - discountAmount;
                  final qty = double.tryParse(sizeData['qty']?.toString() ?? sizeData['unitSize']?.toString() ?? '0') ?? 0.0;
                  final total = discountedPrice * qty;
                  
                  sizeData['price'] = price.toString();
                  sizeData['discount'] = discount.toString();
                  sizeData['discountPer'] = discountAmount.toStringAsFixed(2);
                  sizeData['total'] = total.toStringAsFixed(2);
                  sizeData['grandTotal'] = total.toStringAsFixed(2);
                  sizeData['qty'] = qty.toString();
                  sizeData['unitSize'] = sizeData['unitSize']?.toString() ?? qty.toString();
                  
                  sizeUnitSizeMap[normalizedSize] = sizeData;
                  sizeEntries.add({
                    'size': normalizedSize,
                    'id': normalizedSize, // Use normalized size as ID
                    ...sizeData,
                  });
                });
                
                // Set initial selectedSize to first available size if not set
                if (selectedSize == null || !availableSizes.contains(selectedSize)) {
                  selectedSize = availableSizes.isNotEmpty ? availableSizes.first : null;
                }
              }
            } catch (e) {
              debugPrint('Error parsing sizeUnitSizeMap: $e');
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _categorySearchController.dispose();
    _titleController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _discountController.dispose();
    _discountPriceController.dispose();
    _totalController.dispose();
    _grandTotalController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _sizeUnitSizeController.dispose();
    _sizePriceController.dispose();
    _sizeDiscountController.dispose();
    _sizeQuantityController.dispose();
    _priceController.removeListener(_calculateTotals);
    _quantityController.removeListener(_calculateTotals);
    _discountController.removeListener(_calculateTotals);
    super.dispose();
  }
  
  void _calculateTotals() {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 1;
    final discountPer = double.tryParse(_discountController.text.trim()) ?? 0;

    // Auto-calculate discount price from price and discount %
    double discountAmount = 0;
    if (discountPer > 0) {
      discountAmount = (price * discountPer) / 100;
    }
    final priceAfterDiscount = price - discountAmount;
    final total = priceAfterDiscount * quantity;

    if (mounted) {
      setState(() {
        _discountPriceController.text = discountAmount.toStringAsFixed(2);
        if (total >= 0) {
          _totalController.text = total.toStringAsFixed(2);
          _grandTotalController.text = total.toStringAsFixed(2);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    if (mounted) {
       setState(() {
        isInit = false;
      });
    }
    super.didChangeDependencies();
  }

  // for selecting main photo (existing logic)
  Future _selectPhoto() async {
    final XFile? pickedImage = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (pickedImage == null) {
      return;
    }

    final fileSize = await pickedImage.length();
    if (fileSize > 500 * 1024) { // 500 KB
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image is larger than 500KB and will not be uploaded.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        productImages = [pickedImage];
        isImagePicked = true;
        currentImage = 0;
        imageDownloadLinks = [];
      });
    }
  }

  // for selecting sub-images (product photos)
  Future _selectSubImages() async {
    // Limit ONLY new uploads (existing images can be more).
    const maxNewUploads = 3;
    final currentNew = subImages.length;
    
    if (currentNew >= maxNewUploads) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum $maxNewUploads new product photos allowed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final List<XFile>? pickedImages = await _picker.pickMultiImage(
      maxWidth: 600,
      maxHeight: 600,
    );
    if (pickedImages == null || pickedImages.isEmpty) {
      return;
    }

    // Calculate how many new images can be added
    final remainingSlots = maxNewUploads - currentNew;
    final imagesToAdd = pickedImages.take(remainingSlots).toList();
    
    if (pickedImages.length > remainingSlots) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can only add $remainingSlots more image(s). Maximum $maxNewUploads new uploads allowed.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    List<XFile> validImages = [];
    for (XFile image in imagesToAdd) {
      final fileSize = await image.length();
      if (fileSize <= 500 * 1024) { // 500 KB
        validImages.add(image);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image ${image.name} is larger than 500KB and will not be uploaded.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        subImages.addAll(validImages);
      });
    }
  }

  // New generic dropdown builder for categories, subcategories, and status
  Widget _buildCategoryDropdown<T>({
    required DropDownType type,
    required List<T> list,
    required String? currentValue,
    required String label,
    required Function(String?) onChanged,
  }) {
    // Convert dynamic list to DropdownMenuItem list
    List<DropdownMenuItem<String>> items = [];
    String displayValue = currentValue ?? '';

    if (list.isNotEmpty) {
      for (var item in list) {
        String id;
        String name;

        if (type == DropDownType.status) {
          // Status list is List<String>
          id = item.toString();
          name = item.toString();
        } else {
          // Category/Subcategory list is List<Map<String, dynamic>>
          // Safe cast to Map
          final itemMap = item as Map<String, dynamic>; 
          id = itemMap['id']?.toString() ?? '';
          name = itemMap['name'] ?? itemMap['sub_name'] ?? '';
        }

        if (name.isNotEmpty) {
          items.add(DropdownMenuItem(
            value: id,
            child: Text(name),
          ));
        }

        // Determine the display name for the initial value
        if (id == currentValue) {
          displayValue = name;
        }
      }
    }
    
    // Set default initial value if none is selected, but only if the list is not empty
    String? initialValue;

    if (currentValue != null && items.any((item) => item.value == currentValue)) {
        initialValue = currentValue;
    } else if (items.isNotEmpty) {
        // If current value is null or invalid, use the first item in the list
        initialValue = items.first.value; 
    }
    
    // If we are showing sub/child category, allow null initial value if the list is empty
    if ((type == DropDownType.subCategory || type == DropDownType.childCategory) && list.isEmpty) {
        initialValue = null;
    }


    return Expanded(
      child: DropdownButtonFormField<String>( 
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: primaryColor),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            width: 2,
            color: primaryColor,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            width: 1,
            color: Colors.grey,
          ),
        ),
      ),
      value: initialValue,
      borderRadius: BorderRadius.circular(20),
      items: items,
      onChanged: onChanged,
      // Ensure dropdown is disabled if the list is empty (e.g. no subcategories loaded)
      disabledHint: Text('No $label available'),
    ),
    );
  }

  // custom textfield for all form fields
  Widget kTextField(
    TextEditingController controller,
    String hint,
    String label,
    Field field,
    int maxLines, {
    bool readOnly = false, 
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly, 
      keyboardType: field == Field.price || field == Field.quantity || field == Field.unit || field == Field.discount || field == Field.discountPer
          ? const TextInputType.numberWithOptions(decimal: true) 
          : TextInputType.text,
      inputFormatters: field == Field.price || field == Field.quantity || field == Field.discount || field == Field.discountPer
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), 
            ]
          : null,
      textInputAction: field == Field.description
          ? TextInputAction.done
          : TextInputAction.next,
      autofocus: field == Field.title ? true : false,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: primaryColor),
        // No placeholders: rely on label + actual controller text
        hintText: null,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            width: 2,
            color: primaryColor,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            width: 1,
            color: Colors.grey,
          ),
        ),
      ),
      validator: (value) {
        // Validation logic for all fields
        if (!readOnly && (value == null || value.isEmpty)) {
          switch (field) {
            case Field.title:
              return 'Title can not be empty';
            case Field.quantity:
              return 'Quantity is not valid';
            case Field.description:
              return 'Description is not valid';
            case Field.discountPer:
            case Field.discount:
              if (value!.isNotEmpty && double.tryParse(value) == null) {
                return 'Must be a number';
              }
              return null;
          }
        }
        return null;
      },
    );
  }

  // snackbar for error message (existing logic)
  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        action: SnackBarAction(
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          label: 'Dismiss',
          textColor: Colors.white,
        ),
      ),
    );
  }

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        action: SnackBarAction(
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          label: 'Dismiss',
          textColor: Colors.white,
        ),
      ),
    );
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  String _extractBackendMessageFromBody(String body) {
    final obj = _tryDecodeJsonObject(body);
    if (obj == null) return body.trim();
    final msg = obj['message'] ?? obj['msg'] ?? obj['error'];
    if (msg != null && msg.toString().trim().isNotEmpty) return msg.toString().trim();
    final errs = obj['errors'];
    if (errs is List && errs.isNotEmpty) {
      final s = errs.map((e) => e?.toString().trim()).where((e) => e != null && e!.isNotEmpty).toList();
      if (s.isNotEmpty) return s.join('\n');
    }
    return body.trim();
  }

  String _httpErrorMessage(http.Response response, {String fallback = 'Request failed'}) {
    final status = response.statusCode;
    final body = response.body;
    final backendMsg = _extractBackendMessageFromBody(body);
    if (backendMsg.isNotEmpty && backendMsg != body.trim()) return backendMsg;
    if (backendMsg.isNotEmpty && backendMsg.length <= 180) return backendMsg;
    if (status == 401) return 'Authentication failed. Please login again.';
    if (status == 413) return 'File too large. Please choose a smaller image.';
    if (status >= 500) return 'Server error. Please try again.';
    return '$fallback (HTTP $status)';
  }

  Future<String?> _uploadFile(XFile image) async {
    try {
      // Validate file before upload
      final validationError = await FileValidation.validateXFile(image);
      if (validationError != null) {
        if (mounted) {
          showErrorSnackBar(validationError);
        }
        return null;
      }

      // Prepare file for upload
      http.MultipartFile multipartFile;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: image.name,
        );
      } else {
        multipartFile = await http.MultipartFile.fromPath('file', image.path);
      }
      
      final response = await SecureHttpClient.postFormData(
        '${AppConfig.baseApi}/auth/upload-file',
        fields: {
          'storeName': _supplierId ?? 'unknown_store',
        },
        files: [multipartFile],
      );
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        // FIX: The API response structure for file upload might use 'url' or 'fileUrl'
        // Let's assume the API returns 'fileUrl' based on common patterns.
        if (decodedData['success'] == true && decodedData['fileUrl'] != null) {
          return decodedData['fileUrl'];
        } else {
          debugPrint('File upload API returned success: false or missing URL.');
          if (mounted) {
            showErrorSnackBar(_extractBackendMessageFromBody(response.body).isNotEmpty
                ? _extractBackendMessageFromBody(response.body)
                : 'Upload failed. Please try again.');
          }
          return null;
        }
      } else {
        debugPrint('File upload failed with status: ${response.statusCode}');
        if (mounted) {
          showErrorSnackBar(_httpErrorMessage(response, fallback: 'Upload failed'));
        }
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      if (mounted) {
        showErrorSnackBar('Upload error: ${e.toString()}');
      }
      return null;
    }
  }

  // Renamed to _saveProduct to reflect create/update logic
  Future<void> _saveProduct() async {
    var valid = _formKey.currentState!.validate();
     final bool isUpdating = widget.productData != null;
    if (!valid) {
      showSnackBar('Fill all fields completely!');
      return;
    }
    
    if (productImages.isEmpty && !isUpdating) {
      showSnackBar('Product image can not be empty!');
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      // --- Main Image upload logic ---
      List<String> uploadedImageUrls = [];
      for (var image in productImages) {
        if (image is XFile) {
          // Upload new image
          final String? imageUrl = await _uploadFile(image);
          if (imageUrl != null) {
            uploadedImageUrls.add(imageUrl);
          }
        } else if (image is String) {
          // Existing image URL
          uploadedImageUrls.add(image);
        }
      }
      imageDownloadLinks = uploadedImageUrls;
      
      // --- Sub-images upload logic (before product save) ---
      List<String> uploadedSubImageUrls = [];
      
      // Keep existing sub-images if editing (only if they haven't been removed)
      if (isUpdating && existingSubImages.isNotEmpty) {
        uploadedSubImageUrls.addAll(existingSubImages);
      }
      
      // Upload new sub-images
      if (subImages.isNotEmpty) {
        debugPrint('Starting upload of ${subImages.length} sub-images...');
        for (var subImage in subImages) {
          try {
            final String? imageUrl = await _uploadFile(subImage);
            if (imageUrl != null) {
              debugPrint('Sub-image uploaded successfully: $imageUrl');
              uploadedSubImageUrls.add(imageUrl);
            } else {
              debugPrint('Failed to upload sub-image: ${subImage.name}');
            }
          } catch (error) {
            debugPrint('Error uploading sub-image ${subImage.name}: $error');
            // Continue with other uploads even if one fails
          }
        }
      }
      
      debugPrint('Final uploadedSubImageUrls: $uploadedSubImageUrls');
      
      // --- API Call to update product ---
     
      final String apiUrl = isUpdating
          ? '${AppConfig.baseApi}/product/update'
          : '${AppConfig.baseApi}/product/add';

      // Payment mode processing: Convert boolean states back to API string format ("1,3")
      String paymentModeString = '';
      if (isPerOrderEnabled) paymentModeString += '1,';
      if (isOnlinePaymentEnabled) paymentModeString += '2,';
      if (isCashOnDeliveryEnabled) paymentModeString += '3,';
      if (paymentModeString.endsWith(',')) {
        paymentModeString = paymentModeString.substring(0, paymentModeString.length - 1);
      }
      
      // Calculate unitSize and default price based on size management
      String unitSizeForSize;
      String defaultPrice;
      
      if (enableSizeManagement && sizeEntries.isNotEmpty) {
        // Calculate total unitSize from all size entries
        double totalUnitSize = 0.0;
        for (var entry in sizeEntries) {
          totalUnitSize += double.tryParse(entry['unitSize']?.toString() ?? '0') ?? 0.0;
        }
        unitSizeForSize = totalUnitSize > 0 ? totalUnitSize.toString() : _unitController.text;
        defaultPrice = sizeEntries[0]['price']?.toString() ?? _priceController.text;
      } else {
        unitSizeForSize = _unitController.text;
        defaultPrice = _priceController.text;
      }
      
      // Safely parse numerical values or default to 0.0 or 0
      final price = defaultPrice.isEmpty ? 0.0 : double.tryParse(defaultPrice) ?? 0.0;
      final qty = _quantityController.text.isEmpty ? 0 : int.tryParse(_quantityController.text) ?? 0;
      final discountPer = _discountPriceController.text.isEmpty ? 0.0 : double.tryParse(_discountPriceController.text) ?? 0.0;
      final discount = _discountController.text.isEmpty ? 0.0 : double.tryParse(_discountController.text) ?? 0.0;
      final total = _totalController.text.isEmpty ? 0.0 : double.tryParse(_totalController.text) ?? 0.0;
      final grandTotal = _grandTotalController.text.isEmpty ? 0.0 : double.tryParse(_grandTotalController.text) ?? 0.0;
      
      final Map<String, dynamic> requestBody = {
        if (isUpdating) "id": widget.productData!['id'],
        "categoryId": selectedCategoryId,
        "subCategoryId": '3',
        "childCategoryId": '3',
        "name": _titleController.text,
        "slug": isUpdating ? widget.productData!['slug'] : _titleController.text.toLowerCase().replaceAll(RegExp(r'\s+'), '-'), 
        "brand": _brandController.text, 
        "unitSize": unitSizeForSize,
        "status": currentStatus == ProductStatus.active ? "1" : "0",
        "buyerPrice": isUpdating ? widget.productData!['buyerPrice'] : null, 
        "price": price,
        "qty": qty,
        "discountPer": discountPer,
        "discount": discount,
        "total": total,
        "sortDesc": _descriptionController.text,
        "desc": _descriptionController.text, // Full description
        "paymentMode": paymentModeString, 
        "createdId": _supplierId, 
        "createdType": "Store", 
        "isEnableEcommerce": isEcommerceEnabled ? "1" : "0", 
        "isEnableCustomize": isCustomizeEnabled ? "1" : "0",
        "isBooking": isBookingEnabled ? "1" : "0",
        "serviceType": currentServiceType == ServiceType.product ? "Product" : "Service", 
        if (isUpdating) "createdAt": widget.productData!['createdAt'],
        "updatedAt": DateTime.now().toIso8601String(),
        "photo": imageDownloadLinks.isNotEmpty ? imageDownloadLinks.first : null, 
        "grand_total": grandTotal,
        "sizeUnitSizeMap": enableSizeManagement ? jsonEncode(sizeUnitSizeMap) : "", // Store size map as JSON string
        // Persist sub-images back to backend so removals/additions are saved.
        // Backend provides `productphotos` as a list of { imgUrl }, so keep the same shape.
        "productphotos": uploadedSubImageUrls.map((u) => {"imgUrl": u}).toList(),
      };

      debugPrint('Request Body: $requestBody');

      final response = await SecureHttpClient.post(
        apiUrl,
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Call the second API to associate product with store (only needed on ADD, or if store association logic is always run)
          if (!isUpdating) {
            final productId = responseData['data']['id']; // Assuming the product ID is returned in this structure
            
            // Verify token exists before making the API call
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('token');
            final storeId = prefs.getString('storeId');
            
            debugPrint('[EditProduct] Store product-add - Token exists: ${token != null && token.isNotEmpty}');
            debugPrint('[EditProduct] Store product-add - StoreId: $storeId');
            debugPrint('[EditProduct] Store product-add - ProductId: $productId');
            debugPrint('[EditProduct] Store product-add - SupplierId: $_supplierId');
            
            if (token == null || token.isEmpty) {
              debugPrint('[EditProduct] ⚠️ No token found for store product-add API call');
              showSnackBar('Product added, but authentication token missing. Please login again.');
              if (mounted) Navigator.pop(context, true);
              return;
            }
            
            final storeProductAddPayload = {
              "supplierId": _supplierId,
              "productId": productId,
              "unitSize": unitSizeForSize,
              "buyerPrice": price,
            };
            
            debugPrint('[EditProduct] Calling store/product-add with payload: $storeProductAddPayload');
            
            try {
              final storeProductAddResponse = await SecureHttpClient.post(
                '${AppConfig.baseApi}/store/product-add',
                body: storeProductAddPayload,
                context: context, // Pass context for 401 handling
                timeout: const Duration(seconds: 15),
              );

              debugPrint('[EditProduct] Store product-add response status: ${storeProductAddResponse.statusCode}');
              debugPrint('[EditProduct] Store product-add response body: ${storeProductAddResponse.body}');

              if (storeProductAddResponse.statusCode == 200) {
                final responseData = json.decode(storeProductAddResponse.body);
                if (responseData['success'] == true) {
                  // Upload product photos using the /upload-photos endpoint (after product is created and associated)
                  if (productId != null && uploadedSubImageUrls.isNotEmpty) {
                    try {
                      final uploadPhotosResponse = await SecureHttpClient.post(
                        '${AppConfig.baseApi}/product/upload-photos',
                        body: {
                          'productId': productId.toString(),
                          'productPhotos': jsonEncode(uploadedSubImageUrls), // Send as JSON string array
                        },
                      );
                      
                      if (uploadPhotosResponse.statusCode == 200) {
                        final photoResponseData = json.decode(uploadPhotosResponse.body);
                        debugPrint('Product photos uploaded successfully: $photoResponseData');
                      } else {
                        debugPrint('Failed to upload sub-images: ${uploadPhotosResponse.statusCode}');
                        // Don't block success message if photo upload fails
                      }
                    } catch (e) {
                      debugPrint('Error uploading product photos: $e');
                      // Don't block success message if photo upload fails
                    }
                  }
                  
                  showSnackBar('Product added and associated with store successfully!');
                  if (mounted) Navigator.pop(context, true);
                } else {
                  debugPrint('[EditProduct] Store product-add API returned success=false: ${responseData['message']}');
                  showSnackBar('Product added, but store association failed: ${responseData['message'] ?? "Unknown error"}');
                  if (mounted) Navigator.pop(context, true);
                }
              } else if (storeProductAddResponse.statusCode == 401) {
                debugPrint('[EditProduct] ⚠️ 401 Unauthorized - Token may be invalid or expired');
                showSnackBar('Product added, but authentication failed. Please login again.');
                if (mounted) Navigator.pop(context, true);
              } else {
                final errorBody = storeProductAddResponse.body;
                debugPrint('[EditProduct] Error associating product with store: Status ${storeProductAddResponse.statusCode}, Body: $errorBody');
                showSnackBar('Product added, but error associating with store: ${storeProductAddResponse.statusCode}');
                if (mounted) Navigator.pop(context, true);
              }
            } catch (e) {
              debugPrint('[EditProduct] Exception during store product-add: $e');
              showSnackBar('Product added, but error associating with store: ${e.toString()}');
              if (mounted) Navigator.pop(context, true);
            }
          } else {
            // For updating, upload product photos and then show success
            final updatedProductId = responseData['data']?['id'] ?? widget.productData!['id'];
            
            // Always sync product photos on update (even empty) so deletes persist.
            if (updatedProductId != null) {
              try {
                final uploadPhotosResponse = await SecureHttpClient.post(
                  '${AppConfig.baseApi}/product/upload-photos',
                  body: {
                    'productId': updatedProductId.toString(),
                    'productPhotos': jsonEncode(uploadedSubImageUrls), // Send as JSON string array
                  },
                );
                
                if (uploadPhotosResponse.statusCode == 200) {
                  final photoResponseData = json.decode(uploadPhotosResponse.body);
                  debugPrint('Product photos uploaded successfully: $photoResponseData');
                } else {
                  debugPrint('Failed to upload sub-images: ${uploadPhotosResponse.statusCode}');
                  // Don't block success message if photo upload fails
                }
              } catch (e) {
                debugPrint('Error uploading product photos: $e');
                // Don't block success message if photo upload fails
              }
            }
            
            showSnackBar('Product updated successfully!');
            if (mounted) Navigator.pop(context, true);
          }
        } else {
          showErrorSnackBar(
            'Failed to save product: ${responseData['message'] ?? responseData['msg'] ?? 'Unknown error'}',
          );
        }
      } else {
        debugPrint('Error saving product: ${response.body}');
        showErrorSnackBar(_httpErrorMessage(response, fallback: 'Error saving product'));
      }
    } catch (e) {
      debugPrint('Error saving product: $e');
      showErrorSnackBar('Error saving product: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // New: Widget for Payment Type Checkbox
  Widget _buildPaymentCheckbox(PaymentType type, bool isChecked, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: isChecked,
          onChanged: (bool? newValue) {
            if (mounted) {
              setState(() {
                switch (type) {
                  case PaymentType.perOrder:
                    isPerOrderEnabled = newValue ?? false;
                    break;
                  case PaymentType.onlinePayment:
                    isOnlinePaymentEnabled = newValue ?? false;
                    break;
                  case PaymentType.cashOnDelivery:
                    isCashOnDeliveryEnabled = newValue ?? false;
                    break;
                }
              });
            }
          },
          activeColor: primaryColor,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Size Management Helper Functions
  void _addOrUpdateSizeEntry() {
    if (selectedSize == null || selectedSize!.isEmpty || _sizeUnitSizeController.text.isEmpty || _sizePriceController.text.isEmpty || _sizeQuantityController.text.isEmpty) {
      showSnackBar('Please fill all required fields (Size, Unit Size, Price, Quantity)');
      return;
    }
    
    final unitSize = _sizeUnitSizeController.text;
    final price = double.tryParse(_sizePriceController.text) ?? 0.0;
    final discount = double.tryParse(_sizeDiscountController.text) ?? 0.0;
    final quantity = double.tryParse(_sizeQuantityController.text) ?? 0.0;
    final discountAmount = (price * discount) / 100;
    final discountedPrice = price - discountAmount;
    final qty = quantity > 0 ? quantity : (double.tryParse(unitSize) ?? 0.0);
    final total = discountedPrice * qty;
    
    final sizeData = {
      'unitSize': unitSize,
      'qty': qty.toString(),
      'quantity': quantity.toString(),
      'price': price.toString(),
      'discount': discount.toString(),
      'discountPer': discountAmount.toStringAsFixed(2),
      'total': total.toStringAsFixed(2),
      'grandTotal': total.toStringAsFixed(2),
    };
    
    setState(() {
      // Check if size already exists
      final existingIndex = sizeEntries.indexWhere((e) => e['size']?.toString() == selectedSize);
      
      if (existingIndex >= 0) {
        // Update existing entry
        sizeEntries[existingIndex] = {
          'size': selectedSize!,
          'id': selectedSize!,
          ...sizeData,
        };
      } else {
        // Add new entry
        sizeEntries.add({
          'size': selectedSize!,
          'id': selectedSize!,
          ...sizeData,
        });
      }
      
      // Update map
      sizeUnitSizeMap[selectedSize!] = sizeData;
      
      // Clear input fields
      _sizeUnitSizeController.clear();
      _sizePriceController.clear();
      _sizeDiscountController.clear();
      _sizeQuantityController.clear();
    });
  }
  
  void _deleteSizeEntry(String? size) {
    if (size == null || size.isEmpty) return;
    setState(() {
      sizeEntries.removeWhere((e) => e['size']?.toString() == size);
      sizeUnitSizeMap.remove(size);
    });
  }
  
  void _editSizeEntry(Map<String, dynamic> entry) {
    final entrySize = entry['size']?.toString();
    final normalizedSize = _normalizeSize(entrySize);
    
    setState(() {
      selectedSize = normalizedSize ?? availableSizes.first;
      _sizeUnitSizeController.text = entry['unitSize']?.toString() ?? '';
      _sizePriceController.text = entry['price']?.toString() ?? '';
      _sizeDiscountController.text = entry['discount']?.toString() ?? '';
      _sizeQuantityController.text = entry['quantity']?.toString() ?? entry['qty']?.toString() ?? '';
    });
  }

Future<void> _printBarcode(int count) async {
  if (widget.productData == null) {
    showSnackBar('Product data not available');
    return;
  }

  if (count <= 0) {
    showSnackBar('Count must be greater than 0');
    return;
  }

  if (mounted) setState(() => isLoading = true);

  try {
    final productId = widget.productData!['id']?.toString() ?? '';
    final productName = _titleController.text.isNotEmpty 
        ? _titleController.text 
        : (widget.productData!['name'] ?? 'Product');
    final productColor = widget.productData!['color']?.toString() ?? 
        widget.productData!['colour']?.toString() ?? 'N/A';
    
    // Get store name
    String storeName = 'STORE';
    try {
      if (_supplierId != null && _supplierId!.isNotEmpty) {
        final storeResponse = await SecureHttpClient.get(
          '${AppConfig.baseApi}/store/list/$_supplierId',
          timeout: const Duration(seconds: 5),
        );
        if (storeResponse.statusCode == 200) {
          final storeData = json.decode(storeResponse.body);
          if (storeData['success'] == true && storeData['data'] != null) {
            storeName = storeData['data']['storename']?.toString() ?? 
                       storeData['data']['storeName']?.toString() ?? 'STORE';
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching store name: $e');
      // Continue with default store name
    }
    
    final List<Map<String, dynamic>> labelsToGenerate = [];
    final useSizeEntries = enableSizeManagement && sizeEntries.isNotEmpty;
    
    if (useSizeEntries) {
      for (var entry in sizeEntries) {
        final unitSizeCount = int.tryParse(entry['unitSize']?.toString() ?? '1') ?? 1;
        final totalPerSize = count * unitSizeCount;
        for (int j = 0; j < totalPerSize; j++) {
          labelsToGenerate.add({
            'size': entry['size']?.toString().toUpperCase() ?? 'N/A',
            'price': entry['price']?.toString() ?? '0',
            'productId': productId,
          });
        }
      }
    } else {
      for (int i = 0; i < count; i++) {
        labelsToGenerate.add({
          'size': (widget.productData!['size']?.toString() ?? 'N/A').toUpperCase(),
          'price': _priceController.text.isNotEmpty 
              ? _priceController.text 
              : (widget.productData!['price']?.toString() ?? '0'),
          'productId': productId,
        });
      }
    }

    // Pre-generate all barcode SVG strings BEFORE building PDF (this prevents hanging)
    final barcode = Barcode.code128();
    final Map<String, String> barcodeSvgCache = {};
    
    debugPrint('Pre-generating ${labelsToGenerate.length} barcode SVGs...');
    for (var label in labelsToGenerate) {
      final productIdStr = label['productId'].toString();
      if (!barcodeSvgCache.containsKey(productIdStr)) {
        try {
          final barcodeSvg = barcode.toSvg(
            productIdStr,
            width: 180,
            height: 60,
            drawText: false,
          );
          barcodeSvgCache[productIdStr] = barcodeSvg;
        } catch (e) {
          debugPrint('Error generating barcode SVG for $productIdStr: $e');
          barcodeSvgCache[productIdStr] = '<svg></svg>';
        }
      }
    }
    debugPrint('Barcode SVGs pre-generated successfully');

    final pdf = pw.Document();

    // Define Dimensions for a clean grid (Approx 3 labels per row on A4)
    const double labelWidth = 60.0; 
    const double labelHeight = 40.0; 

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return [
            pw.Wrap(
              spacing: 5, 
              runSpacing: 5,
              children: labelsToGenerate.map((label) {
                final String pid = label['productId'];
                final barcodeSvg = barcodeSvgCache[pid] ?? '<svg></svg>';
                return pw.Container(
                  width: labelWidth * PdfPageFormat.mm,
                  height: labelHeight * PdfPageFormat.mm,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                  ),
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(productName, 
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                              maxLines: 1, overflow: pw.TextOverflow.clip
                            ),
                          ),
                          pw.Text(
                            storeName.length > 8 ? '${storeName.substring(0, 8)}...' : storeName,
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      pw.Text(pid, style: const pw.TextStyle(fontSize: 7)),
                      pw.Spacer(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          // Left side vertical ID
                          pw.Transform.rotate(
                            angle: 1.5708 * 3, // -90 degrees
                            child: pw.Text(pid.length > 4 ? pid.substring(pid.length - 4) : pid, 
                                style: const pw.TextStyle(fontSize: 6)),
                          ),
                          pw.SizedBox(width: 2),
                          pw.Column(
                            children: [
                              pw.SizedBox(
                                height: 18 * PdfPageFormat.mm,
                                width: 35 * PdfPageFormat.mm,
                                child: _buildBarcodeFromSvg(barcodeSvg, 35 * PdfPageFormat.mm, 18 * PdfPageFormat.mm),
                              ),
                              pw.Text(pid, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          pw.SizedBox(width: 2),
                          // Right side vertical ID
                          pw.Transform.rotate(
                            angle: 1.5708, // 90 degrees
                            child: pw.Text(pid.padLeft(8, '0'), style: const pw.TextStyle(fontSize: 6)),
                          ),
                        ],
                      ),
                      pw.Spacer(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _footerItem('M.R.P. ₹', label['price'].toString()),
                          _footerItem('COLOUR', productColor),
                          _footerItem('SIZE', label['size'].toString()),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  } catch (e) {
    debugPrint('Error: $e');
    showSnackBar('Printing failed: $e');
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}

// Helper function to draw barcode from SVG
pw.Widget _buildBarcodeFromSvg(String svgString, double width, double height) {
  try {
    // First try using SvgImage directly
    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.SvgImage(
        svg: svgString,
        fit: pw.BoxFit.contain,
      ),
    );
  } catch (e) {
    debugPrint('SvgImage failed, trying manual parsing: $e');
  }
  
  // Fallback: Parse SVG and draw manually
  try {
    // Extract all rect elements from SVG - try different quote patterns
    RegExp? rectPattern;
    Iterable<RegExpMatch> matches = [];
    
    // Try pattern with double quotes
    rectPattern = RegExp(r'<rect[^>]*x\s*=\s*"([0-9.]+)"[^>]*y\s*=\s*"([0-9.]+)"[^>]*width\s*=\s*"([0-9.]+)"[^>]*height\s*=\s*"([0-9.]+)"', caseSensitive: false);
    matches = rectPattern.allMatches(svgString);
    
    // If no matches, try single quotes
    if (matches.isEmpty) {
      rectPattern = RegExp(r"<rect[^>]*x\s*=\s*'([0-9.]+)'[^>]*y\s*=\s*'([0-9.]+)'[^>]*width\s*=\s*'([0-9.]+)'[^>]*height\s*=\s*'([0-9.]+)'", caseSensitive: false);
      matches = rectPattern.allMatches(svgString);
    }
    
    // If still no matches, try without quotes
    if (matches.isEmpty) {
      rectPattern = RegExp(r'<rect[^>]*x\s*=\s*([0-9.]+)[^>]*y\s*=\s*([0-9.]+)[^>]*width\s*=\s*([0-9.]+)[^>]*height\s*=\s*([0-9.]+)', caseSensitive: false);
      matches = rectPattern.allMatches(svgString);
    }
    
    final bars = <Map<String, double>>[];
    for (final match in matches) {
      final x = double.tryParse(match.group(1) ?? '0') ?? 0.0;
      final y = double.tryParse(match.group(2) ?? '0') ?? 0.0;
      final barWidth = double.tryParse(match.group(3) ?? '0') ?? 0.0;
      final barHeight = double.tryParse(match.group(4) ?? '0') ?? 0.0;
      
      if (barWidth > 0 && barHeight > 0) {
        bars.add({
          'x': x,
          'y': y,
          'width': barWidth,
          'height': barHeight,
        });
      }
    }
    
    debugPrint('Found ${bars.length} bars in SVG');
    
    if (bars.isEmpty) {
      debugPrint('SVG content: ${svgString.substring(0, svgString.length > 200 ? 200 : svgString.length)}');
      return pw.Center(
        child: pw.Text(
          'Barcode',
          style: pw.TextStyle(fontSize: 10),
        ),
      );
    }
    
    // Get SVG viewBox to calculate scaling - try different quote patterns
    RegExpMatch? viewBoxMatch;
    
    // Try double quotes
    final viewBoxPattern1 = RegExp(r'viewBox\s*=\s*"([^"]+)"', caseSensitive: false);
    viewBoxMatch = viewBoxPattern1.firstMatch(svgString);
    
    // If no match, try single quotes
    if (viewBoxMatch == null) {
      final viewBoxPattern2 = RegExp(r"viewBox\s*=\s*'([^']+)'", caseSensitive: false);
      viewBoxMatch = viewBoxPattern2.firstMatch(svgString);
    }
    
    double scaleX = 1.0;
    double scaleY = 1.0;
    
    if (viewBoxMatch != null) {
      final viewBoxValues = viewBoxMatch.group(1)!.split(RegExp(r'[\s,]+'));
      if (viewBoxValues.length >= 4) {
        final vbWidth = double.tryParse(viewBoxValues[2]) ?? width;
        final vbHeight = double.tryParse(viewBoxValues[3]) ?? height;
        scaleX = width / vbWidth;
        scaleY = height / vbHeight;
      }
    }
    
    // Use CustomPaint to draw the barcode
    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.CustomPaint(
        size: PdfPoint(width, height),
        painter: (PdfGraphics canvas, PdfPoint size) {
          canvas.setColor(PdfColors.black);
          for (final bar in bars) {
            final x = bar['x']! * scaleX;
            final y = bar['y']! * scaleY;
            final barWidth = bar['width']! * scaleX;
            final barHeight = bar['height']! * scaleY;
            canvas.drawRect(x, y, barWidth, barHeight);
            canvas.fillPath();
          }
        },
      ),
    );
  } catch (e) {
    debugPrint('Error parsing SVG barcode: $e');
    return pw.Center(
      child: pw.Text(
        'Barcode Error',
        style: pw.TextStyle(fontSize: 10),
      ),
    );
  }
}

// Helper for Footer items
pw.Widget _footerItem(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
      pw.Text(value, style: const pw.TextStyle(fontSize: 7)),
    ],
  );
}
  
  void _showPrintBarcodeDialog() {
    final countController = TextEditingController(text: '1');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print Barcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countController,
              decoration: const InputDecoration(
                labelText: 'Count',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final count = int.tryParse(countController.text) ?? 1;
              Navigator.pop(context);
              _printBarcode(count);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Print', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Subscription toggle: enabled only when total count > 0.
  // Restrict turning ON so that used count cannot exceed total (only allow enable when usedCount < totalCount).
  Widget _buildSubscriptionToggle(bool isChecked, String label, Function(bool?) onChanged, {SubscriptionPlan? subscriptionPlan, required bool initialEnabledState, int usedCount = 0}) {
    final int totalCount = subscriptionPlan?.subscriptionCount ?? 0;
    final bool hasSubscription = totalCount > 0;
    final bool hasQuotaLeft = usedCount < totalCount;
    // Allow turning ON only when there is quota (used < total)
    final bool canTurnOn = hasSubscription && hasQuotaLeft;

    return Opacity(
      opacity: hasSubscription ? 1.0 : 0.5,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: isChecked,
            onChanged: hasSubscription
                ? (bool? newValue) {
                    if (newValue == true && !hasQuotaLeft) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Subscription limit reached ($totalCount). You cannot enable more products.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                      return;
                    }
                    onChanged(newValue);
                  }
                : null,
            activeColor: primaryColor,
          ),
          Flexible(
            child: Text(
              hasSubscription ? label : 'Get subscription',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: hasSubscription ? Colors.black : Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: litePrimary, 
      statusBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ));
    
    final List<String> statusList = ['Active', 'Inactive'];
    final productTitle = widget.productData?['name'] ?? 'New Product'; // Safe access for title

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 48,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: brandHeaderGradient,
          ),
        ),
        title: Text(
          'Editing $productTitle', // Use the safely accessed title
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (widget.productData != null)
            IconButton(
              onPressed: () => _showPrintBarcodeDialog(),
              icon: const Icon(
                Icons.print,
                color: Colors.white,
              ),
              tooltip: 'Print Barcode',
            ),
          IconButton(
            onPressed: () => _saveProduct(),
            icon: const Icon(
              Icons.save,
              color: Colors.white,
            ),
          )
        ],
      ),
      body: Container(
        decoration: gradientBackgroundDecoration,
        child: isLoading
            ? const Center(child: Loading(color: primaryColor, kSize: 50))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  
                  // Image/Avatar Section
                  Center(
                    child: Stack(
                      alignment: Alignment.center, 
                      children: [
                        CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.white,
                          child: Center(
                            child: productImages.isEmpty
                                ? Image.asset(
                                    'assets/images/holder.png', 
                                    color: primaryColor,
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(80), 
                                    child: SizedBox(
                                      width: 160,
                                      height: 160,
                                      child: productImages.isNotEmpty && currentImage < productImages.length
                                          ? (productImages[currentImage] is XFile
                                              ? (kIsWeb
                                                  // Web uses XFile path as network URL
                                                  ? Image.network(
                                                      (productImages[currentImage] as XFile).path,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => Image.asset(
                                                        'assets/images/holder.png',
                                                        color: primaryColor,
                                                      ),
                                                    )
                                                  : Image.file(
                                                      // Mobile/Desktop uses File
                                                      File((productImages[currentImage] as XFile).path),
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => Image.asset(
                                                        'assets/images/holder.png',
                                                        color: primaryColor,
                                                      ),
                                                    ))
                                              : Image.network(
                                                  productImages[currentImage].toString(),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => Image.asset(
                                                    'assets/images/holder.png',
                                                    color: primaryColor,
                                                  ),
                                                ))
                                          : Image.asset(
                                              'assets/images/holder.png',
                                              color: primaryColor,
                                            ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: () => _selectPhoto(),
                            child: const CircleAvatar(
                              backgroundColor: litePrimary,
                              child: Icon(
                                Icons.photo,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        productImages.isEmpty
                            ? const SizedBox.shrink()
                            : Positioned(
                                bottom: 10,
                                left: 10,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    productImages = [];
                                    imageDownloadLinks = [];
                                    isImagePicked = false;
                                    currentImage = 0;
                                  }),
                                  child: const CircleAvatar(
                                    backgroundColor: litePrimary,
                                    child: Icon(
                                      Icons.delete_forever,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Thumbnail selector (Only if more than one image exists)
                  if (productImages.length > 1) 
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: productImages.length,
                        itemBuilder: (context, index) {
                          final image = productImages[index];
                          final isNetworkImage = image is String;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () => setState(() {
                                currentImage = index;
                              }),
                              child: Container(
                                height: 60,
                                width: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  border: currentImage == index
                                    ? Border.all(color: primaryColor, width: 3)
                                    : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: isNetworkImage
                                      ? Image.network(
                                          image.toString(),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.broken_image, size: 30),
                                          ),
                                        )
                                      : (kIsWeb
                                          ? Image.network(
                                              (image as XFile).path,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.broken_image, size: 30),
                                              ),
                                            )
                                          : Image.file(
                                              File((image as XFile).path),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.broken_image, size: 30),
                                              ),
                                            )),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  
                  const SizedBox(height: 25),
                  
                  // --- TOP SUBSCRIPTION BANNERS ---
                  Wrap(
                    spacing: 8.0, 
                    runSpacing: 8.0, 
                    alignment: WrapAlignment.center,
                    children: [ // Removed const here to fix compilation error
                      _SubscriptionPill(
                        color: Colors.blue,
                        title: 'Total Ecommerce Subscription',
                        subscriptionPlan: _plan1Subscription,
                        isLoading: _isLoadingSubscriptions,
                        usedCount: _ecommerceUsedCount,
                        onTap: () {
                          // Handle tap for Plan1
                          print('Ecommerce Subscription tapped');
                        },
                      ),
                      _SubscriptionPill(
                        color: Colors.pink,
                        title: 'Total Customize Subscription',
                        subscriptionPlan: _plan2Subscription,
                        isLoading: _isLoadingSubscriptions,
                        usedCount: _customizeUsedCount,
                        onTap: () {
                          // Handle tap for Plan2
                          print('Customize Subscription tapped');
                        },
                      ),
                      _SubscriptionPill(
                        color: Colors.green,
                        title: 'Total Book Service Subscription',
                        subscriptionPlan: _plan3Subscription,
                        isLoading: _isLoadingSubscriptions,
                        usedCount: _bookingUsedCount,
                        onTap: () {
                          // Handle tap for Plan3
                          print('Book Service Subscription tapped');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  
                  // --- MAIN FORM FIELDS ---
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Row 1: Category & Status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              flex: 1,
                                child: _isCategoryLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: _openCategoryPicker,
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText: 'Select Category',
                                            labelStyle: const TextStyle(color: primaryColor),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(20),
                                              borderSide: const BorderSide(width: 2, color: primaryColor),
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(20),
                                              borderSide: const BorderSide(width: 1, color: Colors.grey),
                                            ),
                                            suffixIcon: IconButton(
                                              icon: const Icon(Icons.search, color: primaryColor),
                                              onPressed: _openCategoryPicker,
                                            ),
                                          ),
                                          child: Text(
                                            _categoryNameById(selectedCategoryId).isEmpty
                                                ? "Tap to choose"
                                                : _categoryNameById(selectedCategoryId),
                                            style: TextStyle(
                                              color: _categoryNameById(selectedCategoryId).isEmpty
                                                  ? Colors.black45
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                            ),
                            const SizedBox(width: 15),
                            Flexible(
                              flex: 1,
                              child: _buildCategoryDropdown<String>(
                                type: DropDownType.status,
                                list: statusList,
                                currentValue: currentStatus == ProductStatus.active ? 'Active' : 'Inactive',
                                label: 'Status *',
                                onChanged: (newValue) {
                                  if (mounted) {
                                    setState(() {
                                      currentStatus = newValue == 'Active' ? ProductStatus.active : ProductStatus.inactive;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Row 2: Subcategory & Child Category
                        // Row(
                        //   crossAxisAlignment: CrossAxisAlignment.start,
                        //   children: [
                        //     Flexible(
                        //       flex: 1,
                        //       child: _buildCategoryDropdown<dynamic>(
                        //         type: DropDownType.subCategory,
                        //         list: _subcategories,
                        //         currentValue: selectedSubCategoryId,
                        //         label: 'Select Sub Category',
                        //         onChanged: (newId) {
                        //           if (mounted) {
                        //             setState(() {
                        //               selectedSubCategoryId = newId;
                        //               _updateChildCategoryList(newId);
                        //               // Reset child category ID when subcategory changes
                        //               selectedChildCategoryId = null;
                        //             });
                        //           }
                        //         },
                        //       ),
                        //     ),
                        //     const SizedBox(width: 15),
                        //     Flexible(
                        //       flex: 1,
                        //       child: _buildCategoryDropdown<dynamic>(
                        //         type: DropDownType.childCategory,
                        //         list: _childCategories,
                        //         currentValue: selectedChildCategoryId,
                        //         label: 'Select Child Category',
                        //         onChanged: (newId) {
                        //           if (mounted) {
                        //             setState(() {
                        //               selectedChildCategoryId = newId;
                        //             });
                        //           }
                        //         },
                        //       ),
                        //     ),
                        //   ],
                        // ),
                        const SizedBox(height: 20),

                        // Row 3: Name & Unit
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              flex: 1,
                              child: kTextField(
                                _titleController,
                                '',
                                'Name *',
                                Field.title,
                                1,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Flexible(
                              flex: 1,
                              child: kTextField(
                                _unitController,
                                '',
                                'Unit *',
                                Field.unit,
                                1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Row 4: Sort Description & Price
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              flex: 1,
                              child: kTextField(
                                _descriptionController,
                                '',
                                'Sort Description *',
                                Field.description,
                                1,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Flexible(
                              flex: 1,
                              child: kTextField(
                                _priceController,
                                '',
                                'Price *',
                                Field.price,
                                1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // New Row for Brand (Inserted here based on typical product form flow)
                        Row(
                          children: [
                            Flexible(
                              flex: 1,
                              child: kTextField(
                                _brandController,
                                '',
                                'Brand',
                                Field.title,
                                1,
                              ),
                            ),
                            const SizedBox(width: 15),
                            // Placeholder to maintain spacing/alignment
                            Flexible(flex: 1, child: Container()), 
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Show regular fields only if size management is disabled
                        if (!enableSizeManagement) ...[
                          // Row 5: Quantity & Discount (%)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                flex: 1,
                                child: kTextField(
                                  _quantityController,
                                  '',
                                  'Quantity *',
                                  Field.quantity,
                                  1,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Flexible(
                                flex: 1,
                                child: kTextField(
                                  _discountController,
                                  '',
                                  'Discont(%) *',
                                  Field.discount,
                                  1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Row 6: Discount Price (auto-calculated) & Total
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                flex: 1,
                                child: kTextField(
                                  _discountPriceController,
                                  '',
                                  'Discount Price *',
                                  Field.discountPer,
                                  1,
                                  readOnly: true, // Auto-calculated from Price and Discount(%)
                                ),
                              ),
                              const SizedBox(width: 15),
                              Flexible(
                                flex: 1,
                                child: kTextField(
                                  _totalController,
                                  '',
                                  'Total',
                                  Field.price, 
                                  1,
                                  readOnly: true, 
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Row 7: Grand Total & Image Upload Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              flex: 1,
                              child: kTextField(
                                _grandTotalController,
                                '',
                                'Grant total',
                                Field.price, 
                                1,
                                readOnly: true, 
                              ),
                            ),
                            const SizedBox(width: 15),
                            Flexible(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _selectPhoto(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade200,
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(color: Colors.grey.shade400)
                                      ),
                                    ),
                                    child: const Text('Choose File', style: TextStyle(color: Colors.black)),
                                  ),
                                  const SizedBox(height: 5),
                                  if (productImages.isNotEmpty && productImages[0] is XFile) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: kIsWeb
                                          ? Image.network(
                                              (productImages[0] as XFile).path,
                                              height: 120,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const SizedBox(
                                                height: 120,
                                                child: Center(child: Text('Failed to load image')),
                                              ),
                                            )
                                          : Image.file(
                                              File((productImages[0] as XFile).path),
                                              height: 120,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    const SizedBox(height: 3),
                                  ] else if (imageDownloadLinks.isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageDownloadLinks[0],
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox(
                                          height: 120,
                                          child: Center(child: Text('Failed to load image')),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                  ] else
                                    const Text('No file selected', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 3),
                                  const Text('Max image upload size: 500KB', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ] else ...[
                          // Image Upload Button when size management is enabled
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _selectPhoto(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade200,
                                        minimumSize: const Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          side: BorderSide(color: Colors.grey.shade400)
                                        ),
                                      ),
                                      child: const Text('Choose Main Image', style: TextStyle(color: Colors.black)),
                                    ),
                                    const SizedBox(height: 5),
                                    if (productImages.isNotEmpty && productImages[0] is XFile) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: kIsWeb
                                            ? Image.network(
                                                (productImages[0] as XFile).path,
                                                height: 120,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const SizedBox(
                                                  height: 120,
                                                  child: Center(child: Text('Failed to load image')),
                                                ),
                                              )
                                            : Image.file(
                                                File((productImages[0] as XFile).path),
                                                height: 120,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                      const SizedBox(height: 3),
                                    ] else if (imageDownloadLinks.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageDownloadLinks[0],
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const SizedBox(
                                            height: 120,
                                            child: Center(child: Text('Failed to load image')),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                    ] else
                                      const Text('No file selected', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 3),
                                    const Text('Max image upload size: 500KB', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        // Sub Images (Product Photos) Section
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Product Photos',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  Text(
                                    '${existingSubImages.length + subImages.length} (new uploads: ${subImages.length}/3)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: subImages.length > 3 ? Colors.red : primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: subImages.length >= 3
                                    ? null 
                                    : _selectSubImages,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: subImages.length >= 3
                                      ? Colors.grey.shade300 
                                      : primaryColor,
                                  minimumSize: const Size(double.infinity, 45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  '+ Add Product Photos',
                                  style: TextStyle(
                                    color: subImages.length >= 3
                                        ? Colors.grey.shade600 
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (subImages.length >= 3)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Maximum 3 product photos allowed for new uploads',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              if (existingSubImages.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Note: You can keep existing photos, and add up to 3 new photos per edit.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              
                              // Display Existing Sub Images
                              if (existingSubImages.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Existing Images:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: existingSubImages.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final imageUrl = entry.value;
                                    return Stack(
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(7),
                                            child: Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.broken_image, size: 30),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                existingSubImages.removeAt(index);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ],
                              
                              // Display New Sub Images
                              if (subImages.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Selected Images (will be uploaded on save):',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: subImages.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final image = entry.value;
                                    return Stack(
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(7),
                                            child: kIsWeb
                                                ? Image.network(
                                                    image.path,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => Container(
                                                      color: Colors.grey.shade200,
                                                      child: const Icon(Icons.broken_image, size: 30),
                                                    ),
                                                  )
                                                : Image.file(
                                                    File(image.path),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => Container(
                                                      color: Colors.grey.shade200,
                                                      child: const Icon(Icons.broken_image, size: 30),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              borderRadius: const BorderRadius.only(
                                                bottomLeft: Radius.circular(7),
                                                bottomRight: Radius.circular(7),
                                              ),
                                            ),
                                            child: FutureBuilder<int>(
                                              future: image.length(),
                                              builder: (context, snapshot) {
                                                if (snapshot.hasData) {
                                                  final sizeKB = (snapshot.data! / 1024).toStringAsFixed(1);
                                                  return Text(
                                                    '$sizeKB KB',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                    ),
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                subImages.removeAt(index);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Row 7.5: Service Type Selection
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'What would you like to offer?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    currentServiceType = ServiceType.product;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: currentServiceType == ServiceType.product 
                                        ? primaryColor.withOpacity(0.1) 
                                        : Colors.white,
                                    border: Border.all(
                                      color: currentServiceType == ServiceType.product 
                                          ? primaryColor 
                                          : Colors.grey.shade300,
                                      width: currentServiceType == ServiceType.product ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<ServiceType>(
                                        value: ServiceType.product,
                                        groupValue: currentServiceType,
                                        activeColor: primaryColor,
                                        onChanged: (ServiceType? value) {
                                          setState(() {
                                            currentServiceType = value ?? ServiceType.product;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Online selling product',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Sell physical or digital products directly through your online platform',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    currentServiceType = ServiceType.service;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: currentServiceType == ServiceType.service 
                                        ? primaryColor.withOpacity(0.1) 
                                        : Colors.white,
                                    border: Border.all(
                                      color: currentServiceType == ServiceType.service 
                                          ? primaryColor 
                                          : Colors.grey.shade300,
                                      width: currentServiceType == ServiceType.service ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<ServiceType>(
                                        value: ServiceType.service,
                                        groupValue: currentServiceType,
                                        activeColor: primaryColor,
                                        onChanged: (ServiceType? value) {
                                          setState(() {
                                            currentServiceType = value ?? ServiceType.product;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Providing service',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Offer a range of services, such as consulting, training, or support',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Size Management Section
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: enableSizeManagement,
                                    onChanged: (bool? newValue) {
                                      setState(() {
                                        enableSizeManagement = newValue ?? false;
                                        if (!enableSizeManagement) {
                                          // Clear size entries when disabled
                                          sizeEntries.clear();
                                          sizeUnitSizeMap.clear();
                                          _sizeUnitSizeController.clear();
                                          _sizePriceController.clear();
                                          _sizeDiscountController.clear();
                                          _sizeQuantityController.clear();
                                          selectedSize = availableSizes.isNotEmpty ? availableSizes.first : null;
                                        } else {
                                          // Initialize selectedSize when enabling
                                          if (selectedSize == null || !availableSizes.contains(selectedSize)) {
                                            selectedSize = availableSizes.isNotEmpty ? availableSizes.first : null;
                                          }
                                        }
                                      });
                                    },
                                    activeColor: primaryColor,
                                  ),
                                  const Text(
                                    'Enable Multiple Size Management',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              
                              if (enableSizeManagement) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline, color: primaryColor, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Size, Unit Size & Price Management',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Size Selection and Input Fields - Improved Layout
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Size Selection
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: DropdownButtonFormField<String>(
                                        decoration: InputDecoration(
                                          labelText: 'Select Size *',
                                          labelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              width: 2,
                                              color: primaryColor,
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              width: 1,
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        ),
                                        value: selectedSize != null && availableSizes.contains(selectedSize) 
                                            ? selectedSize 
                                            : (availableSizes.isNotEmpty ? availableSizes.first : null),
                                        items: availableSizes.map((size) {
                                          return DropdownMenuItem<String>(
                                            value: size,
                                            child: Text(
                                              size,
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            selectedSize = newValue ?? (availableSizes.isNotEmpty ? availableSizes.first : null);
                                          });
                                        },
                                        isExpanded: true,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Row 2: Unit Size and Price
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: kTextField(
                                              _sizeUnitSizeController,
                                              '10',
                                              'Unit Size *',
                                              Field.unit,
                                              1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: kTextField(
                                              _sizePriceController,
                                              '1000',
                                              'Price (₹) *',
                                              Field.price,
                                              1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Row 3: Quantity and Discount
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: kTextField(
                                              _sizeQuantityController,
                                              '1',
                                              'Quantity *',
                                              Field.quantity,
                                              1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: kTextField(
                                              _sizeDiscountController,
                                              '5',
                                              'Discount (%)',
                                              Field.discount,
                                              1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Row 4: Add Button
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: _addOrUpdateSizeEntry,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                            ),
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Add/Update',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
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
                                
                                // Size Entries Table
                                if (sizeEntries.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Size Entries (${sizeEntries.length})',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DataTable(
                                        headingRowColor: MaterialStateProperty.all(primaryColor),
                                        headingTextStyle: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        dataRowMinHeight: 50,
                                        dataRowMaxHeight: 60,
                                        columns: const [
                                          DataColumn(label: Text('Size')),
                                          DataColumn(label: Text('Unit Size')),
                                          DataColumn(label: Text('Qty')),
                                          DataColumn(label: Text('Price (₹)')),
                                          DataColumn(label: Text('Discount %')),
                                          DataColumn(label: Text('Discount Amt')),
                                          DataColumn(label: Text('Total (₹)')),
                                          DataColumn(label: Text('Actions')),
                                        ],
                                      rows: sizeEntries.map((entry) {
                                        final entrySize = entry['size']?.toString() ?? '';
                                        final price = double.tryParse(entry['price']?.toString() ?? '0') ?? 0.0;
                                        final discount = double.tryParse(entry['discount']?.toString() ?? '0') ?? 0.0;
                                        final discountAmount = (price * discount) / 100;
                                        final total = double.tryParse(entry['total']?.toString() ?? '0') ?? 0.0;
                                        
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: primaryColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  entrySize,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(
                                              entry['unitSize']?.toString() ?? '0',
                                              style: const TextStyle(fontSize: 14),
                                            )),
                                            DataCell(Text(
                                              entry['qty']?.toString() ?? '0',
                                              style: const TextStyle(fontSize: 14),
                                            )),
                                            DataCell(Text(
                                              '₹${price.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            )),
                                            DataCell(Text(
                                              '${discount.toStringAsFixed(2)}%',
                                              style: const TextStyle(fontSize: 14),
                                            )),
                                            DataCell(Text(
                                              '₹${discountAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(fontSize: 14),
                                            )),
                                            DataCell(Text(
                                              '₹${total.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            )),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: primaryColor, size: 20),
                                                    onPressed: () => _editSizeEntry(entry),
                                                    tooltip: 'Edit',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                    onPressed: () => _deleteSizeEntry(entrySize),
                                                    tooltip: 'Delete',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Row 8: Payment Type & Subscriptions
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Payment Type
                            Flexible(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Payment Type',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  _buildPaymentCheckbox(PaymentType.perOrder, isPerOrderEnabled, 'Per Order'),
                                  _buildPaymentCheckbox(PaymentType.onlinePayment, isOnlinePaymentEnabled, 'Online Payment'),
                                  // _buildPaymentCheckbox(PaymentType.cashOnDelivery, isCashOnDeliveryEnabled, 'Cash'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            // Subscriptions
                            Flexible(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Subscriptions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  _buildSubscriptionToggle(
                                    isEcommerceEnabled,
                                    'Enable Ecommerce',
                                    (newValue) {
                                      if (mounted) {
                                        setState(() {
                                          isEcommerceEnabled = newValue ?? false;
                                        });
                                      }
                                    },
                                    subscriptionPlan: _plan1Subscription,
                                    initialEnabledState: widget.productData?['isEnableEcommerce'] == "1",
                                    usedCount: _ecommerceUsedCount,
                                  ),
                                  _buildSubscriptionToggle(
                                    isCustomizeEnabled,
                                    'Enable Customize',
                                    (newValue) {
                                      if (mounted) {
                                        setState(() {
                                          isCustomizeEnabled = newValue ?? false;
                                        });
                                      }
                                    },
                                    subscriptionPlan: _plan2Subscription,
                                    initialEnabledState: widget.productData?['isEnableCustomize'] == 1,
                                    usedCount: _customizeUsedCount,
                                  ),
                                  _buildSubscriptionToggle(
                                    isBookingEnabled,
                                    'Enable Booking',
                                    (newValue) {
                                      if (mounted) {
                                        setState(() {
                                          isBookingEnabled = newValue ?? false;
                                        });
                                      }
                                    },
                                    subscriptionPlan: _plan3Subscription,
                                    initialEnabledState: widget.productData?['isBooking'] == "1",
                                    usedCount: _bookingUsedCount,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "Save",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.save, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper Widget to display the subscription pills/banners at the top
class _SubscriptionPill extends StatelessWidget {
  final Color color;
  final String title;
  final SubscriptionPlan? subscriptionPlan;
  final bool isLoading;
  final int usedCount;
  final VoidCallback onTap;

  _SubscriptionPill({
    required this.color,
    required this.title,
    required this.subscriptionPlan,
    required this.isLoading,
    required this.usedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Builder(
        builder: (context) {
          String total = '0';
          String used = '0';
          if (isLoading) {
            total = '...';
            used = '...';
          } else if (subscriptionPlan != null) {
            total = subscriptionPlan!.subscriptionCount.toString();
            used = usedCount.toString();
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total: $total | Used: $used',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
