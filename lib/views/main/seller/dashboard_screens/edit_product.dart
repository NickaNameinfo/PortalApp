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
import 'package:shared_preferences/shared_preferences.dart'; // Added for SharedPreferences
import '../../../../utilities/categories_list.dart'; // Still needed for legacy/default values
import 'package:path/path.dart' as path;
import 'package:nickname_portal/constants/colors.dart';
import 'package:nickname_portal/models/subscription_model.dart'; // Import SubscriptionPlan
import 'package:nickname_portal/helpers/subscription_service.dart'; // Import SubscriptionService
import 'dart:typed_data';

// New: Enum for Product Status
enum ProductStatus { active, inactive }

// New: Enum for Payment Type
enum PaymentType { perOrder, onlinePayment, cashOnDelivery }

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

  List<dynamic> productImages = [];
  List<String> imageDownloadLinks = [];
  final ImagePicker _picker = ImagePicker();

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
  
  // Payment Mode states
  bool isPerOrderEnabled = false;
  bool isOnlinePaymentEnabled = false;
  bool isCashOnDeliveryEnabled = false;

  var isLoading = false;
  var isImagePicked = false; 

  List<dynamic> _categories = []; // Main Category List
  List<dynamic> _subcategories = []; // Subcategory List for selected category
  List<dynamic> _childCategories = []; // Child Category List for selected subcategory
  bool _isCategoryLoading = true; 

  String? _customerId;
  late Future<SubscriptionPlan?> _plan1SubscriptionFuture;
  late Future<SubscriptionPlan?> _plan2SubscriptionFuture;

  Future<void> _loadCustomerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final loadedCustomerId = prefs.getString('storeId');
    
    if (mounted) {
      setState(() {
        _customerId = loadedCustomerId; 
        if (_customerId != null) {
          // Fetch subscriptions for Plan1 and Plan2 keys
          _plan1SubscriptionFuture = SubscriptionService.getSubscriptionDetails(_customerId!, "Plan1");
          _plan2SubscriptionFuture = SubscriptionService.getSubscriptionDetails(_customerId!, "Plan2");
        } else {
          // Handle case where customerId is missing
          final errorFuture = Future<SubscriptionPlan?>.error('Customer ID not found.');
          _plan1SubscriptionFuture = errorFuture;
          _plan2SubscriptionFuture = errorFuture;
        }
      });
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
    _descriptionController.text = '';
    _brandController.text = '';
    
    _loadSupplierId();
    _loadCustomerId(); // Call _loadCustomerId here
    _fetchSubscriptionDetails();
    _fetchCategories().then((_) {
      // Initialize product data only after categories are fetched
      _initProductData();
    });
    
    _priceController.addListener(_calculateTotals);
    _discountController.addListener(_calculateTotals);
    _discountPriceController.addListener(_calculateTotals);
    debugPrint('productImages on init: $productImages');
    debugPrint('isImagePicked on init: $isImagePicked');
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
      final response = await http.get(Uri.parse('https://nicknameinfo.net/api/category/getAllCategory'));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true) {
          if (mounted) {
            setState(() {
              _categories = decodedData['data'] ?? [];
              _isCategoryLoading = false;
            });
          }
        } else {
           debugPrint('API failed to return categories: ${decodedData['message']}');
          if (mounted) setState(() => _isCategoryLoading = false);
        }
      } else {
        debugPrint('Failed to fetch categories: ${response.statusCode}');
        if (mounted) setState(() => _isCategoryLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) setState(() => _isCategoryLoading = false);
    }
  }

  Future<void> _fetchSubscriptionDetails() async {
    // TODO: Implement subscription details fetching logic
    debugPrint('Fetching subscription details...');
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
    final productData = widget.productData;
    if (productData != null) {
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
          productImages = List<dynamic>.from(productData['productphotos'] ?? []);
          isEcommerceEnabled = (productData['isEnableEcommerce'] == "1");
          isCustomizeEnabled = (productData['isEnableCustomize'] == 1);
          if (productImages.isNotEmpty) {
            isImagePicked = true;
          }

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
        });
      }
    }
  }

  @override
  void dispose() {
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
    _priceController.removeListener(_calculateTotals);
    _discountController.removeListener(_calculateTotals);
    _discountPriceController.removeListener(_calculateTotals);
    super.dispose();
  }
  
  void _calculateTotals() {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final discountPer = double.tryParse(_discountController.text.trim()) ?? 0; 
    final discountAmount = double.tryParse(_discountPriceController.text.trim()) ?? 0; 
    
    double finalPrice;

    if (discountPer > 0) {
      final discount = (price * discountPer) / 100;
      finalPrice = price - discount;
    } else if (discountAmount > 0) {
      finalPrice = price - discountAmount;
    } else {
      finalPrice = price;
    }

    if (mounted) {
      setState(() {
        if (finalPrice >= 0) {
          _totalController.text = finalPrice.toStringAsFixed(2);
          _grandTotalController.text = finalPrice.toStringAsFixed(2);
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

  // for selecting photo (existing logic)
  Future _selectPhoto() async {
    List<XFile>? pickedImages;
    pickedImages = await _picker.pickMultiImage(
      maxWidth: 600,
      maxHeight: 600,
    );
    if (pickedImages == null || pickedImages.isEmpty) {
      return;
    }

    List<XFile> validImages = [];
    for (XFile image in pickedImages) {
      final fileSize = await image.length(); // Get file size in bytes
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
        productImages = validImages.cast<dynamic>();
        isImagePicked = validImages.isNotEmpty;
        currentImage = 0; 
        imageDownloadLinks = []; 
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
        hintText: hint,
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
            case Field.price:
              return 'Price is not valid';
            case Field.quantity:
              return 'Quantity is not valid';
            case Field.description:
              return 'Description is not valid';
            case Field.unit:
              return 'Unit cannot be empty';
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

  Future<String?> _uploadFile(XFile image) async {
    final uri = Uri.parse('https://nicknameinfo.net/api/auth/upload-file');
    final request = http.MultipartRequest('POST', uri);
    request.fields['storeName'] = _supplierId ?? 'unknown_store';
    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: image.name,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
    }

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await http.Response.fromStream(response);
        final decodedData = json.decode(responseData.body);
        // FIX: The API response structure for file upload might use 'url' or 'fileUrl'
        // Let's assume the API returns 'fileUrl' based on common patterns.
        if (decodedData['success'] == true && decodedData['fileUrl'] != null) {
          return decodedData['fileUrl'];
        } else {
          debugPrint('File upload API returned success: false or missing URL.');
          return null;
        }
      } else {
        debugPrint('File upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
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
      // --- Image upload logic ---
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
      
      // --- API Call to update product ---
     
      final String apiUrl = isUpdating
          ? 'https://nicknameinfo.net/api/product/update'
          : 'https://nicknameinfo.net/api/product/add';

      // Payment mode processing: Convert boolean states back to API string format ("1,3")
      String paymentModeString = '';
      if (isPerOrderEnabled) paymentModeString += '1,';
      if (isOnlinePaymentEnabled) paymentModeString += '2,';
      if (isCashOnDeliveryEnabled) paymentModeString += '3,';
      if (paymentModeString.endsWith(',')) {
        paymentModeString = paymentModeString.substring(0, paymentModeString.length - 1);
      }
      
      // Safely parse numerical values or default to 0.0 or 0
      final price = _priceController.text.isEmpty ? 0.0 : double.tryParse(_priceController.text) ?? 0.0;
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
        "unitSize": _unitController.text,
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
        if (isUpdating) "createdAt": widget.productData!['createdAt'],
        "updatedAt": DateTime.now().toIso8601String(),
        "photo": imageDownloadLinks.isNotEmpty ? imageDownloadLinks.first : null, 
        "productphotos": imageDownloadLinks, 
        "grand_total": grandTotal,
      };

      debugPrint('Request Body: $requestBody');

      final http.Response response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Call the second API to associate product with store (only needed on ADD, or if store association logic is always run)
          if (!isUpdating) {
            final productId = responseData['data']['id']; // Assuming the product ID is returned in this structure
            final storeProductAddUrl = Uri.parse('https://nicknameinfo.net/api/store/product-add');
            final storeProductAddPayload = {
              "supplierId": _supplierId,
              "productId": productId,
              "unitSize": _unitController.text,
              "buyerPrice": price,
            };
            
            final storeProductAddResponse = await http.post(
              storeProductAddUrl,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(storeProductAddPayload),
            );

            if (storeProductAddResponse.statusCode == 200) {
              showSnackBar('Product added and associated with store successfully!');
              if (mounted) Navigator.pop(context, true); 
            } else {
              debugPrint('Error associating product with store: ${storeProductAddResponse.body}');
              showSnackBar('Product added, but error associating with store: ${storeProductAddResponse.statusCode}');
              if (mounted) Navigator.pop(context, true); // Still pop even on partial failure
            }
          } else {
            // For updating, just show success and pop
            showSnackBar('Product updated successfully!');
            Navigator.pop(context, true);
            if (mounted) Navigator.pop(context, true);
          }
        } else {
          showSnackBar('Failed to save product: ${responseData['message']}');
        }
      } else {
        debugPrint('Error saving product: ${response.body}');
        showSnackBar('Error saving product: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error saving product: $e');
      showSnackBar('Error saving product: ${e.toString()}');
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

  // New: Widget for Subscription Toggle
  Widget _buildSubscriptionToggle(bool isChecked, String label, Function(bool?) onChanged, {SubscriptionPlan? subscriptionPlan, required bool initialEnabledState}) {
    final bool isEnabled = (subscriptionPlan?.subscriptionCount ?? 0) > 0;
    final bool wasInitiallyEnabledInEditMode = widget.productData != null && initialEnabledState;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5, // Reduce opacity when disabled
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: isChecked,
            onChanged: (isEnabled && !wasInitiallyEnabledInEditMode) ? onChanged : null,
            activeColor: primaryColor,
          ),
          Text(
            isEnabled ? label : 'Get subscription and enable the option',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isEnabled ? Colors.black : Colors.grey,
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
        backgroundColor: primaryColor,
        title: Text(
          'Editing $productTitle', // Use the safely accessed title
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _saveProduct(),
            icon: const Icon(
              Icons.save,
              color: Colors.white,
            ),
          )
        ],
      ),
      body: isLoading
          ? const Loading(color: primaryColor, kSize: 50)
          : SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 18.0,
                left: 18,
                right: 18,
              ),
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
                                      child: isImagePicked && productImages[currentImage] is XFile
                                          ? kIsWeb
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
                                                )
                                          : Image.network(
                                              productImages[currentImage].toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Image.asset(
                                                'assets/images/holder.png',
                                                color: primaryColor,
                                              ),
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
                          final isNetworkImage = productImages[index] is String;
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
                                  image: isNetworkImage
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            productImages[index],
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : DecorationImage(
                                          // FIX: Use Image.network path for web, Image.file for others
                                          image: kIsWeb
                                            ? NetworkImage((productImages[index] as XFile).path) as ImageProvider
                                            : FileImage(
                                                File((productImages[index] as XFile).path),
                                              ),
                                          fit: BoxFit.cover,
                                        ),
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
                        planFuture: _plan1SubscriptionFuture,
                        onTap: () {
                          // Handle tap for Plan1
                          print('Ecommerce Subscription tapped');
                        },
                      ),
                      _SubscriptionPill(
                        color: Colors.pink,
                        title: 'Total Customize Subscription',
                        planFuture: _plan2SubscriptionFuture,
                        onTap: () {
                          // Handle tap for Plan2
                          print('Customize Subscription tapped');
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
                                  : _buildCategoryDropdown<dynamic>(
                                      type: DropDownType.category,
                                      list: _categories,
                                      currentValue: selectedCategoryId,
                                      label: 'Select Category',
                                      onChanged: (newId) {
                                        if (mounted) {
                                          setState(() {
                                            selectedCategoryId = newId;
                                            _updateSubcategoryList(newId);
                                            // Reset sub/child IDs when main category changes
                                            selectedSubCategoryId = null; 
                                            selectedChildCategoryId = null;
                                          });
                                        }
                                      },
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
                                'Mobile',
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
                                '10',
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
                                'Mobile test product',
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
                                '45000',
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
                                'Samsung',
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


                        // Row 5: Quantity & Discount (%)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              flex: 1,
                              child: kTextField(
                                _quantityController,
                                '1',
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
                                '2',
                                'Discont(%) *',
                                Field.discount,
                                1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Row 6: Discount Price & Total
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              flex: 1,
                              child: kTextField(
                                _discountPriceController,
                                '900',
                                'Discount Price *',
                                Field.discountPer,
                                1,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Flexible(
                              flex: 1,
                              child: kTextField(
                                _totalController,
                                '44100',
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
                                '44100',
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
                                  const Text('No file selected', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
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
                                  _buildPaymentCheckbox(PaymentType.cashOnDelivery, isCashOnDeliveryEnabled, 'Cash on Delivery'),
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
                                  FutureBuilder<SubscriptionPlan?>(
                                    future: _plan1SubscriptionFuture,
                                    builder: (context, snapshot) {
                                      SubscriptionPlan? plan;
                                      if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                        plan = snapshot.data;
                                      }
                                      return _buildSubscriptionToggle(
                                        isEcommerceEnabled,
                                        'Enable Ecommerce',
                                        (newValue) {
                                          if (mounted) {
                                            setState(() {
                                              isEcommerceEnabled = newValue ?? false;
                                            });
                                          }
                                        },
                                        subscriptionPlan: plan,
                                        initialEnabledState: widget.productData?['isEnableEcommerce'] == "1",
                                      );
                                    },
                                  ),
                                  FutureBuilder<SubscriptionPlan?>(
                                    future: _plan2SubscriptionFuture,
                                    builder: (context, snapshot) {
                                      SubscriptionPlan? plan;
                                      if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                        plan = snapshot.data;
                                      }
                                      return _buildSubscriptionToggle(
                                        isCustomizeEnabled,
                                        'Enable Customize',
                                        (newValue) {
                                          if (mounted) {
                                            setState(() {
                                              isCustomizeEnabled = newValue ?? false;
                                            });
                                          }
                                        },
                                        subscriptionPlan: plan,
                                        initialEnabledState: widget.productData?['isEnableCustomize'] == 1,
                                      );
                                    },
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
    );
  }
}

// Helper Widget to display the subscription pills/banners at the top
class _SubscriptionPill extends StatelessWidget {
  final Color color;
  final String title;
  final Future<SubscriptionPlan?> planFuture;
  final VoidCallback onTap;

  const _SubscriptionPill({
    required this.color,
    required this.title,
    required this.planFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FutureBuilder<SubscriptionPlan?>(
        future: planFuture,
        builder: (context, snapshot) {
          String total = 'N/A';
          String used = 'N/A';
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            total = snapshot.data!.subscriptionCount.toString();
            used = (snapshot.data!.subscriptionCount - snapshot.data!.freeCount).toString();
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
