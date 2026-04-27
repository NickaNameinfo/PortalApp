import 'package:flutter/material.dart';
import 'package:nickname_portal/providers/cart.dart';
import 'package:nickname_portal/utilities/show_message.dart';
import 'package:provider/provider.dart';
import 'package:nickname_portal/routes/routes.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:nickname_portal/helpers/address_service.dart';
import 'package:nickname_portal/helpers/order_service.dart'; // We keep this for Address class
import 'package:nickname_portal/views/main/customer/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nickname_portal/helpers/secure_http_client.dart';

// --- New Imports Required for Payment Logic ---
// Conditional imports for Razorpay - use appropriate package based on platform
import 'package:nickname_portal/components/razorpay_stub.dart'
    if (dart.library.io) 'package:nickname_portal/components/razorpay_mobile.dart'
    if (dart.library.html) 'package:nickname_portal/components/razorpay_web_impl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nickname_portal/helpers/checkout_api_helper.dart'; // Our new helper
import 'package:nickname_portal/constants/colors.dart';
import 'package:nickname_portal/utilities/auth_helper.dart';
import 'package:nickname_portal/constants/app_config.dart';


// --- MOCK DEFINITIONS (from your code) ---
void showErrorMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('ERROR: $message'), backgroundColor: Colors.red),
  );
}

void showSuccessMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('SUCCESS: $message'), backgroundColor: Colors.green),
  );
}
// --------------------------------------------------------

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  const CheckoutScreen({super.key, this.product});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _nameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _pincodeController = TextEditingController();
  
  late String _userId = '';
  int _selectedPaymentOption = 2; // Default to Pre Order (matches web option "2")
  DateTime? _selectedDeliveryDate;
  List<Address> _addresses = [];
  Address? _selectedAddress;
  final AddressService _addressService = AddressService();
  List<dynamic> _cartItems = [];
  final Map<String, Map<String, dynamic>> _storesById = {};
  final Map<String, String> _shiprocketEtaByStoreId = {};
  bool _shiprocketEtaLoading = false;
  Timer? _shiprocketDebounce;
  int _shiprocketMetaToken = 0;
  
  // --- New State Variables for Payment Logic ---
  late Razorpay _razorpay;
  bool _isLoading = false;
  bool _hasCheckedAuth = false; // Flag to prevent multiple auth checks
  
  // To pass data to the Razorpay success callback
  Map<String, dynamic>? _pendingApiParams;
  Map<String, dynamic>? _pendingPaymentResult;

  double _cartTotal() {
    if (_cartItems.isEmpty) return 0.0;
    return _cartItems.fold(0.0, (sum, item) {
      final double price = (item['price'] is num)
          ? (item['price'] as num).toDouble()
          : (double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0);
      final int qty = (item['qty'] is num)
          ? (item['qty'] as num).toInt()
          : (int.tryParse(item['qty']?.toString() ?? '0') ?? 0);
      return sum + (price * qty);
    });
  }

  @override
  void initState() {
    super.initState();
    
    // Check if product data was passed directly
    if (widget.product != null) {
      // Set cart items with the single product
      _cartItems = [widget.product!];
    }
    
    // Initialize Razorpay first
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    
    // Check auth after a small delay to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasCheckedAuth) {
        _checkAuthAndLoad();
      }
    });
  }
  
  Future<void> _checkAuthAndLoad() async {
    if (_hasCheckedAuth) return; // Prevent multiple checks
    _hasCheckedAuth = true;
    
    // Check if user is logged in
    final isLoggedIn = await AuthHelper.isUserLoggedIn();
    
    if (!isLoggedIn && mounted) {
      // Show login dialog only once
      final shouldLogin = await AuthHelper.showLoginDialog(
        context,
        message: 'Please login to proceed with checkout.',
      );
      
      if (shouldLogin) {
        // User navigated to login screen, dialog is already dismissed
        // Don't do anything here, let the login screen handle navigation
        // When user comes back, we'll check auth again
        _hasCheckedAuth = false; // Reset flag so we can check again when screen resumes
      } else {
        // User cancelled, navigate back
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
    } else if (mounted) {
      _loadUserId();
    }
  }

  @override
  void dispose() {
    _shiprocketDebounce?.cancel();
    _nameController.dispose();
    _phoneNumberController.dispose();
    _districtController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _pincodeController.dispose();
    
    // --- Dispose Razorpay ---
    _razorpay.clear();
    super.dispose();
  }

  void _scheduleShiprocketRefresh() {
    _shiprocketDebounce?.cancel();
    _shiprocketDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      await _refreshShiprocketMeta();
    });
  }

  String _extractPincode(String? text) {
    final m = RegExp(r'\b(\d{6})\b').firstMatch(text ?? '');
    return m != null ? m.group(1)! : '';
  }

  List<int> _uniqueStoreIdsFromCart() {
    final ids = <int>[];
    for (final raw in _cartItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final sid = item['storeId'] ?? item['store_id'];
      final n = (sid is num) ? sid.toInt() : int.tryParse(sid?.toString() ?? '');
      if (n != null && n > 0) ids.add(n);
    }
    return ids.toSet().toList()..sort();
  }

  String _pickupPincodeForStoreRow(Map<String, dynamic> s) {
    final fromAddress = _extractPincode(
      '${s['storeaddress'] ?? ''} ${s['shopaddress'] ?? ''} ${s['owneraddress'] ?? ''} ${s['location'] ?? ''}',
    );
    if (fromAddress.isNotEmpty) return fromAddress;
    final z = s['areaZipcode'] ?? s['zipcode'] ?? (s['area'] is Map ? (s['area'] as Map)['zipcode'] : null);
    final zs = z?.toString().trim() ?? '';
    return zs;
  }

  String _deliveryPincodeForEta() {
    final fromSelected = _selectedAddress?.pincode?.trim();
    final fromField = _pincodeController.text.trim();
    final pin = (fromSelected != null && fromSelected.isNotEmpty) ? fromSelected : fromField;
    return pin;
  }

  int _codFlagForShiprocket() {
    // Match web BuyCard: COD is payment method "3"
    return _selectedPaymentOption == 3 ? 1 : 0;
  }

  String _formatEtaFromShiprocketPayload(dynamic rawOut) {
    final sr = rawOut is Map<String, dynamic> ? rawOut : null;
    if (sr == null) return 'Not available';

    final data = sr['data'];
    final inner = data is Map<String, dynamic> ? data : sr;

    final list = inner['available_courier_companies'] ??
        sr['available_courier_companies'] ??
        inner['available_courier_companies'];

    if (list is! List || list.isEmpty) return 'Not available';

    final withDays = list
        .map((c) {
          if (c is! Map) return null;
          final company = c['courier_name'] ?? c['courier_company_name'] ?? c['name'];
          final days = num.tryParse(c['estimated_delivery_days']?.toString() ?? '');
          final etd = c['etd'];
          if (days == null || !days.isFinite || days < 0) return null;
          return <String, dynamic>{
            'company': company?.toString(),
            'days': days.toInt(),
            'etd': etd,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    if (withDays.isNotEmpty) {
      var min = withDays.first;
      for (final x in withDays) {
        final d = x['days'] as int;
        if (d < (min['days'] as int)) min = x;
      }
      final days = min['days'] as int;
      final d = DateTime.now().add(Duration(days: days));
      final company = min['company']?.toString();
      final suffix = (company != null && company.isNotEmpty) ? ' • $company' : '';
      return '${d.day}/${d.month}/${d.year} ($days day(s))$suffix';
    }

    for (final c in list) {
      if (c is Map && c['etd'] != null && c['etd'].toString().trim().isNotEmpty) {
        return c['etd'].toString();
      }
    }
    return 'Not available';
  }

  Future<void> _loadStoresForCart(int metaToken) async {
    final ids = _uniqueStoreIdsFromCart();
    if (ids.isEmpty) {
      if (!mounted) return;
      setState(() {
        _storesById.clear();
      });
      return;
    }

    try {
      final response = await SecureHttpClient.post(
        '${AppConfig.baseApi}/store/public/by-ids',
        body: {'ids': ids},
        timeout: const Duration(seconds: 15),
        context: context,
      );
      if (!mounted || metaToken != _shiprocketMetaToken) return;

      if (response.statusCode != 200) {
        setState(() {
          _storesById.clear();
        });
        return;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['success'] != true) {
        setState(() {
          _storesById.clear();
        });
        return;
      }

      final rows = decoded['data'];
      final next = <String, Map<String, dynamic>>{};
      if (rows is List) {
        for (final r in rows) {
          if (r is Map) {
            final m = Map<String, dynamic>.from(r);
            final id = m['id'];
            if (id != null) next[id.toString()] = m;
          }
        }
      }

      setState(() {
        _storesById
          ..clear()
          ..addAll(next);
      });
    } catch (_) {
      if (!mounted || metaToken != _shiprocketMetaToken) return;
      setState(() {
        _storesById.clear();
      });
    }
  }

  Future<void> _refreshShiprocketEstimates(int metaToken) async {
    final delivery = _deliveryPincodeForEta().trim();
    if (!RegExp(r'^\d{6}$').hasMatch(delivery)) {
      if (!mounted) return;
      setState(() {
        _shiprocketEtaByStoreId.clear();
        _shiprocketEtaLoading = false;
      });
      return;
    }

    final storeIds = _uniqueStoreIdsFromCart();
    if (storeIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _shiprocketEtaByStoreId.clear();
        _shiprocketEtaLoading = false;
      });
      return;
    }

    if (!mounted || metaToken != _shiprocketMetaToken) return;
    setState(() {
      _shiprocketEtaLoading = true;
    });

    final next = <String, String>{};
    final cod = _codFlagForShiprocket();

    await Future.wait(storeIds.map((sid) async {
      final key = sid.toString();
      final storeRow = _storesById[key];
      if (storeRow == null) {
        next[key] = 'Checking store...';
        return;
      }

      final partner = (storeRow['deliveryPartner'] ?? '').toString().toLowerCase();
      if (partner != 'shiprocket') {
        next[key] = 'Local delivery';
        return;
      }

      final pickup = _pickupPincodeForStoreRow(storeRow);
      if (pickup.isEmpty) {
        next[key] = 'Pickup pincode missing in shop address';
        return;
      }

      try {
        final qs = Uri(queryParameters: {
          'pickup_postcode': pickup,
          'delivery_postcode': delivery,
          'cod': cod.toString(),
          'weight': '0.5',
        }).query;

        final response = await SecureHttpClient.get(
          '${AppConfig.baseApi}/shiprocket/courier/serviceability?$qs',
          timeout: const Duration(seconds: 15),
          context: context,
        );

        if (!mounted || metaToken != _shiprocketMetaToken) return;

        if (response.statusCode != 200) {
          next[key] = 'Not available';
          return;
        }

        final decoded = json.decode(response.body);
        if (decoded is! Map<String, dynamic>) {
          next[key] = 'Not available';
          return;
        }
        if (decoded['success'] != true) {
          next[key] = 'Not available';
          return;
        }

        final out = decoded['data'];
        next[key] = _formatEtaFromShiprocketPayload(out);
      } catch (_) {
        next[key] = 'Not available';
      }
    }));

    if (!mounted) return;

    // If a newer refresh started while we were in-flight, don't stomp loading/UI state.
    if (metaToken != _shiprocketMetaToken) return;

    setState(() {
      _shiprocketEtaByStoreId
        ..clear()
        ..addAll(next);
      _shiprocketEtaLoading = false;
    });
  }

  Future<void> _refreshShiprocketMeta() async {
    final token = ++_shiprocketMetaToken;
    await _loadStoresForCart(token);
    if (!mounted || token != _shiprocketMetaToken) return;
    await _refreshShiprocketEstimates(token);
  }

 
  Future<void> _loadUserId() async {
    setState(() { _isLoading = true; });
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = (prefs.getString('userId') ?? '0');
    });
    
    if (_userId != '0' && _userId.isNotEmpty) {
      await _fetchAddresses();
      // Only fetch cart items if no direct product was passed
      if (widget.product == null) {
        await _fetchCartItems();
      }
    } else {
      // User not logged in - show login dialog
      if (mounted) {
        final shouldLogin = await AuthHelper.showLoginDialog(
          context,
          message: 'Please login to proceed with checkout.',
        );
        if (shouldLogin) {
          // Wait for login and reload
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            final updatedPrefs = await SharedPreferences.getInstance();
            final updatedUserId = updatedPrefs.getString('userId') ?? '0';
            if (updatedUserId != '0' && updatedUserId.isNotEmpty) {
              setState(() {
                _userId = updatedUserId;
              });
              await _fetchAddresses();
              if (widget.product == null) {
                await _fetchCartItems();
              }
            }
          }
        } else {
          // User cancelled, navigate back
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    }
    setState(() { _isLoading = false; });
    if (mounted && _cartItems.isNotEmpty) {
      _scheduleShiprocketRefresh();
    }
  }
  
  Future<void> _fetchAddresses() async {
    try {
      final fetchedAddresses = await _addressService.fetchAddresses(_userId);
      setState(() {
        _addresses = fetchedAddresses;
        if (_addresses.isNotEmpty) {
          _selectedAddress = _addresses.first;
          _populateAddressFields(_selectedAddress!);
        }
      });
      if (mounted) {
        _scheduleShiprocketRefresh();
      }
    } catch (e) {
      print('Error fetching addresses: $e');
      showErrorMessage(context, 'Failed to load addresses.');
    }
  }

  void _populateAddressFields(Address address) {
    _nameController.text = address.fullname;
    _phoneNumberController.text = address.phone;
    _districtController.text = address.discrict ?? '';
    _addressLine1Controller.text = address.shipping;
    _addressLine2Controller.text = address.area;
    _cityController.text = address.city;
    _postalCodeController.text = address.states;
    _pincodeController.text = address.pincode ?? '';
  }

  Future<void> _addAddress() async {
    // Check if user is logged in
    final isLoggedIn = await AuthHelper.checkAuthAndShowDialog(
      context,
      message: 'Please login to add an address.',
    );
    
    if (!isLoggedIn) {
      return; // User chose not to login
    }
    
    // Reload userId after potential login
    final prefs = await SharedPreferences.getInstance();
    final updatedUserId = prefs.getString('userId') ?? '0';
    if (updatedUserId == '0' || updatedUserId.isEmpty) {
      return; // Still not logged in
    }
    
    setState(() {
      _userId = updatedUserId;
    });
    
    if (!_validateAddressForm()) {
      setState(() {}); // Update UI to show errors
      showErrorMessage(context, 'Please fill all required fields correctly.');
      return;
    }
    
    final newAddress = Address(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Temp ID
      fullname: _nameController.text.trim(),
      phone: _phoneNumberController.text.trim(),
      discrict: _districtController.text.trim(),
      city: _cityController.text.trim(),
      states: _postalCodeController.text.trim(),
      area: _addressLine2Controller.text.trim(),
      shipping: _addressLine1Controller.text.trim(),
      pincode: _pincodeController.text.trim(),
      orderId: _userId,
      custId: _userId,
    );

    try {
      setState(() { _isLoading = true; });
      await _addressService.createAddress(newAddress);
      await _fetchAddresses(); // Refresh list
      showSuccessMessage(context, 'Address added successfully!');
      _addressErrors.clear();
      setState(() {}); // Clear errors
    } catch (e) {
      print('Error adding address: $e');
      showErrorMessage(context, 'Failed to add address.');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _updateAddress() async {
    if (_selectedAddress == null) {
      showErrorMessage(context, 'Please select an address to update.');
      return;
    }
    
    if (!_validateAddressForm()) {
      setState(() {}); // Update UI to show errors
      showErrorMessage(context, 'Please fill all required fields correctly.');
      return;
    }

    final updatedAddress = Address(
      id: _selectedAddress!.id,
      fullname: _nameController.text.trim(),
      phone: _phoneNumberController.text.trim(),
      discrict: _districtController.text.trim(),
      city: _cityController.text.trim(),
      states: _postalCodeController.text.trim(),
      area: _addressLine2Controller.text.trim(),
      shipping: _addressLine1Controller.text.trim(),
      pincode: _pincodeController.text.trim(),
      orderId: _userId,
      custId: _userId,
    );

    try {
      setState(() { _isLoading = true; });
      await _addressService.updateAddress(updatedAddress);
      await _fetchAddresses(); // Refresh list
      showSuccessMessage(context, 'Address updated successfully!');
      _addressErrors.clear();
      setState(() {}); // Clear errors
    } catch (e) {
      print('Error updating address: $e');
      showErrorMessage(context, 'Failed to update address.');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // --- NEW PAYMENT HANDLERS ---

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print("Razorpay Success: ${response.paymentId}");
    final paymentId = response.paymentId;
    
    if (paymentId != null && _pendingApiParams != null && _pendingPaymentResult != null) {
      // Call the equivalent of 'afterPaymentSuccess'
      _afterPaymentSuccess(paymentId, _pendingApiParams!, _pendingPaymentResult!);
    } else {
      setState(() { _isLoading = false; });
      showErrorMessage(context, "Payment succeeded but local data was lost. Please contact support.");
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print("Razorpay Error: ${response.code} - ${response.message}");
    setState(() { _isLoading = false; });
    showErrorMessage(context, "Payment Failed: ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print("External Wallet: ${response.walletName}");
  }

  // --- REPLACED _placeOrder with _handlePlaceOrder ---
  // This is the implementation of the JavaScript 'handleAddOrder' logic
  
  // Address validation
  Map<String, String> _addressErrors = {};
  
  bool _validateAddressForm() {
    _addressErrors.clear();
    bool isValid = true;
    
    // Full Name validation
    if (_nameController.text.trim().isEmpty) {
      _addressErrors['fullname'] = 'Full name is required';
      isValid = false;
    } else if (_nameController.text.trim().length < 2) {
      _addressErrors['fullname'] = 'Full name must be at least 2 characters';
      isValid = false;
    } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(_nameController.text.trim())) {
      _addressErrors['fullname'] = 'Full name should contain only letters';
      isValid = false;
    }
    
    // Phone validation
    if (_phoneNumberController.text.trim().isEmpty) {
      _addressErrors['phone'] = 'Phone number is required';
      isValid = false;
    } else if (!RegExp(r'^\d{10}$').hasMatch(_phoneNumberController.text.trim())) {
      _addressErrors['phone'] = 'Phone number must be exactly 10 digits';
      isValid = false;
    }
    
    // District validation
    if (_districtController.text.trim().isEmpty) {
      _addressErrors['district'] = 'District is required';
      isValid = false;
    } else if (_districtController.text.trim().length < 2) {
      _addressErrors['district'] = 'District must be at least 2 characters';
      isValid = false;
    }
    
    // City validation
    if (_cityController.text.trim().isEmpty) {
      _addressErrors['city'] = 'City is required';
      isValid = false;
    } else if (_cityController.text.trim().length < 2) {
      _addressErrors['city'] = 'City must be at least 2 characters';
      isValid = false;
    }
    
    // State validation
    if (_postalCodeController.text.trim().isEmpty) {
      _addressErrors['states'] = 'State is required';
      isValid = false;
    } else if (_postalCodeController.text.trim().length < 2) {
      _addressErrors['states'] = 'State must be at least 2 characters';
      isValid = false;
    }

    // Pincode validation (required for delivery estimates)
    final pin = _pincodeController.text.trim();
    if (pin.isEmpty) {
      _addressErrors['pincode'] = 'Pincode is required';
      isValid = false;
    } else if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _addressErrors['pincode'] = 'Pincode must be 6 digits';
      isValid = false;
    }
    
    // Area validation
    if (_addressLine2Controller.text.trim().isEmpty) {
      _addressErrors['area'] = 'Area is required';
      isValid = false;
    } else if (_addressLine2Controller.text.trim().length < 2) {
      _addressErrors['area'] = 'Area must be at least 2 characters';
      isValid = false;
    }
    
    // Shipping address validation
    if (_addressLine1Controller.text.trim().isEmpty) {
      _addressErrors['shipping'] = 'Shipping address is required';
      isValid = false;
    } else if (_addressLine1Controller.text.trim().length < 5) {
      _addressErrors['shipping'] = 'Shipping address must be at least 5 characters';
      isValid = false;
    }
    
    return isValid;
  }
  
  Future<void> _handlePlaceOrder() async {
    // Check if user is logged in
    final isLoggedIn = await AuthHelper.checkAuthAndShowDialog(
      context,
      message: 'Please login to place an order.',
    );
    
    if (!isLoggedIn) {
      return; // User chose not to login
    }
    
    // Reload userId after potential login
    final prefs = await SharedPreferences.getInstance();
    final updatedUserId = prefs.getString('userId') ?? '0';
    if (updatedUserId == '0' || updatedUserId.isEmpty) {
      return; // Still not logged in
    }
    
    setState(() {
      _userId = updatedUserId;
    });
    
    // Cart validation
    if (_cartItems.isEmpty) {
      showErrorMessage(context, 'Your cart is empty.');
      return;
    }
    
    // Address validation
    if (_selectedAddress == null) {
      // Validate form fields
      if (!_validateAddressForm()) {
        showErrorMessage(context, 'Please fill all required address fields correctly.');
        setState(() {}); // Update UI to show errors
        return;
      }
    } else {
      // Validate selected address
      if (!_validateAddressForm()) {
        showErrorMessage(context, 'Please update address fields correctly.');
        setState(() {}); // Update UI to show errors
        return;
      }
    }
    
    // Check for date if payment option 4 is selected
    if (_selectedPaymentOption == 4 && _selectedDeliveryDate == null) {
      showErrorMessage(context, 'Please select a delivery date.');
      return;
    }
    
    // Stock validation for all cart items
    for (var item in _cartItems) {
      final int productId = (item['productId'] is num) ? (item['productId'] as num).toInt() : (int.tryParse(item['productId']?.toString() ?? '0') ?? 0);
      final int qty = (item['qty'] is num) ? (item['qty'] as num).toInt() : (int.tryParse(item['qty']?.toString() ?? '0') ?? 0);
      
      try {
        final productResponse = await SecureHttpClient.get(
          '${AppConfig.baseApi}/product/getProductById/$productId',
          timeout: const Duration(seconds: 10),
          context: context,
        );
        
        if (productResponse.statusCode == 200) {
          final productData = jsonDecode(productResponse.body);
          final int availableStock = int.tryParse(productData['data']?['unitSize']?.toString() ?? '0') ?? 0;
          
          if (qty > availableStock) {
            showErrorMessage(context, '${item['name'] ?? 'Product'} - Only $availableStock items available in stock');
            return;
          }
        }
      } catch (e) {
        debugPrint('Error checking stock for product $productId: $e');
        // Continue with order if stock check fails
      }
    }

    setState(() { _isLoading = true; });

    final double grandTotal = _cartItems.fold(0.0, (sum, item) {
       final double price = (item['price'] is num) ? (item['price'] as num).toDouble() : (double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0);
       final int qty = (item['qty'] is num) ? (item['qty'] as num).toInt() : (int.tryParse(item['qty']?.toString() ?? '0') ?? 0);
       return sum + (price * qty);
    });

    // 1. Create baseApiParams
    // We assume the Address object has a toMap() method for serialization
    // If not, you must manually create a Map from _selectedAddress fields.
    Map<String, dynamic> addressMap;
    try {
      // Use toJson() method instead of toMap()
      addressMap = _selectedAddress!.toJson(); 
    } catch (e) {
      // Manual fallback if toJson() doesn't exist
      addressMap = {
        "fullname": _selectedAddress!.fullname,
        "phone": _selectedAddress!.phone,
        "discrict": _selectedAddress!.discrict,
        "city": _selectedAddress!.city,
        "states": _selectedAddress!.states,
        "area": _selectedAddress!.area,
        "shipping": _selectedAddress!.shipping,
        "pincode": _selectedAddress!.pincode,
        "custId": _selectedAddress!.custId,
        "orderId": _selectedAddress!.orderId,
      };
    }

    final baseApiParams = {
      "custId": _userId,
      "paymentmethod": _selectedPaymentOption.toString(),
      "orderId": int.tryParse(_userId) ?? 0, // Using userId as per JS
      "grandTotal": grandTotal,
      "storeId": _cartItems.first['storeId'], // Assuming all items from same store
      "cutomerDeliveryDate": _selectedDeliveryDate?.toIso8601String() ?? '',
      "deliveryAddress": addressMap,
      "orderType": "Product",
    };

    // 2. Check payment method
    // 1 = Online (Razorpay full amount)
    // 2 = Pre Order (Razorpay 50% now)
    // 3 = COD (offline)
    // 4 = Future delivery (Razorpay full amount)
    if (_selectedPaymentOption == 1 || _selectedPaymentOption == 2 || _selectedPaymentOption == 4) {
      // --- ONLINE PAYMENT FLOW (Razorpay) ---
      try {
        final double amountToPayNow =
            _selectedPaymentOption == 2 ? (grandTotal * 0.5) : grandTotal;
        final paymentResult =
            await CheckoutApiHelper.createRazorpayOrder(amountToPayNow, _userId);

        if (paymentResult['success'] == true && paymentResult['data'] != null) {
          final paymentData = paymentResult['data'];
          
          _pendingApiParams = baseApiParams;
          _pendingPaymentResult = paymentData;

          final options = {
            'key': AppConfig.razorpayKey,
            'amount': paymentData['amount'],
            'currency': paymentData['currency'],
            'order_id': paymentData['id'],
            'name': 'Nickname Infotech',
            'description': _selectedPaymentOption == 2
                ? 'Pre Order (50% advance)'
                : (_selectedPaymentOption == 4 ? 'Future delivery (paid)' : 'For Subscriptions'),
            'theme': {'color': '#49a84c'}
          };
          
          _razorpay.open(options);
          // Loading remains true until callback

        } else {
          throw Exception(paymentResult['message'] ?? "Failed to create payment order.");
        }
      } catch (e) {
        setState(() { _isLoading = false; });
        showErrorMessage(context, "Payment Error: ${e.toString()}");
      }
    } else {
      // --- OFFLINE PAYMENT FLOW (COD, Pre-Order, Future) ---
      try {
        await _placeIndividualOrders(baseApiParams);
        _showSuccessAndClear();
      } catch (e) {
        setState(() { _isLoading = false; });
        showErrorMessage(context, "Order Failed: ${e.toString()}");
      }
    }
  }

  // Equivalent to 'afterPaymentSuccess' in JS
  Future<void> _afterPaymentSuccess(String paymentId, Map<String, dynamic> apiParams, Map<String, dynamic> paymentResult) async {
    try {
      // --- ⭐️ START: MODIFICATION ---
      // Removed `custId: _userId` as it's not in the CheckoutApiHelper.updatePaymentRecord definition
      final razorpayPaymentUpdate = await CheckoutApiHelper.updatePaymentRecord(
        orderCreationId: apiParams['orderId'].toString(),
        razorpayPaymentId: paymentId,
        razorpayOrderId: paymentResult['id'],
      );
      // --- ⭐️ END: MODIFICATION ---

      if (razorpayPaymentUpdate['success'] == true) {
        // 2. Iterate and create separate orders (as per JS logic)
        await _placeIndividualOrders(apiParams);
        _showSuccessAndClear();
        
      } else {
         throw Exception(razorpayPaymentUpdate['message'] ?? "Failed to update payment record.");
      }
    } catch (e) {
        setState(() { _isLoading = false; });
        showErrorMessage(context, "Post-Payment Error: ${e.toString()}");
    }
  }

  // This helper function creates individual orders, used by both online and offline flows
  Future<void> _updateProductUnitSize(int productId, int quantity, {String? size}) async {
    try {
      final productResponse = await SecureHttpClient.get(
        '${AppConfig.baseApi}/product/getProductById/$productId',
        timeout: const Duration(seconds: 15),
        context: context,
      );

      if (productResponse.statusCode == 200) {
        final productData = jsonDecode(productResponse.body);
        final product = productData['data'];
        
        // Check if product has sizeUnitSizeMap and size is provided
        if (size != null && size.isNotEmpty && product['sizeUnitSizeMap'] != null) {
          // Update size-specific unitSize
          try {
            Map<String, dynamic> sizeUnitSizeMap;
            if (product['sizeUnitSizeMap'] is String) {
              sizeUnitSizeMap = jsonDecode(product['sizeUnitSizeMap']) as Map<String, dynamic>;
            } else {
              sizeUnitSizeMap = Map<String, dynamic>.from(product['sizeUnitSizeMap']);
            }
            
            // Check if the size exists in the map (case-insensitive matching)
            String? matchingSizeKey;
            for (var key in sizeUnitSizeMap.keys) {
              if (key.toString().toLowerCase() == size.toLowerCase()) {
                matchingSizeKey = key.toString();
                break;
              }
            }
            
            if (matchingSizeKey != null) {
              final sizeData = sizeUnitSizeMap[matchingSizeKey];
              int currentSizeUnitSize = 0;
              
              if (sizeData is Map) {
                currentSizeUnitSize = int.tryParse(sizeData['unitSize']?.toString() ?? '0') ?? 0;
              } else if (sizeData is String) {
                currentSizeUnitSize = int.tryParse(sizeData) ?? 0;
              }
              
              if (currentSizeUnitSize > 0) {
                final newSizeUnitSize = currentSizeUnitSize - quantity;
                
                // Skip if new unit size is negative
                if (newSizeUnitSize < 0) {
                  print('⚠️ Size $size stock would be negative, skipping update');
                  return;
                }
                
                // Update the size-specific unitSize in the map
                if (sizeData is Map) {
                  // Create a new map with updated unitSize
                  final updatedSizeData = Map<String, dynamic>.from(sizeData);
                  updatedSizeData['unitSize'] = newSizeUnitSize.toString();
                  sizeUnitSizeMap[matchingSizeKey] = updatedSizeData;
                } else {
                  // If sizeData is not a Map, create a new structure
                  sizeUnitSizeMap[matchingSizeKey] = {
                    'unitSize': newSizeUnitSize.toString(),
                    'price': '',
                    'qty': '',
                    'discount': '',
                    'discountPer': '',
                    'total': '',
                    'grandTotal': '',
                  };
                }
                
                // Update the product with modified sizeUnitSizeMap
                final updateData = {
                  'id': productId,
                  'sizeUnitSizeMap': jsonEncode(sizeUnitSizeMap),
                };

                final response = await SecureHttpClient.post(
                  '${AppConfig.baseApi}/product/update',
                  body: updateData,
                  timeout: const Duration(seconds: 15),
                  context: context,
                );
                
                if (response.statusCode == 200) {
                  print('✅ Successfully updated product $productId size $size unitSize to $newSizeUnitSize');
                } else {
                  print('⚠️ Failed to update product $productId size $size unitSize. Status: ${response.statusCode}');
                }
                return; // Exit early since we updated size-specific stock
              }
            }
          } catch (e) {
            print('⚠️ Error parsing sizeUnitSizeMap for product $productId: $e');
            // Fall through to default flow
          }
        }
        
        // Default flow: Update main product unitSize (if no size or sizeUnitSizeMap doesn't exist)
        final currentUnitSize = int.tryParse(product['unitSize']?.toString() ?? '0') ?? 0;
        
        if (currentUnitSize <= 0) {
          return;
        }

        final newUnitSize = currentUnitSize - quantity;
        
        // Skip if new unit size is negative
        if (newUnitSize < 0) {
          return;
        }

        final updateData = {
          'id': productId,
          'unitSize': newUnitSize.toString(),
        };

        final response = await SecureHttpClient.post(
          '${AppConfig.baseApi}/product/update',
          body: updateData,
          timeout: const Duration(seconds: 15),
          context: context,
        ).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          print('✅ Successfully updated product $productId unit size to $newUnitSize');
        } else {
          print('⚠️ Failed to update product $productId unitSize. Status: ${response.statusCode}');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error updating product unitSize: $e');
      print('Stack trace: $stackTrace');
      // Don't throw error as order was successful
    }
  }

  Future<void> _placeIndividualOrders(Map<String, dynamic> baseApiParams) async {
    final List<Future<void>> orderPromises = [];
    
    // --- ⭐️ START: MODIFICATION ---
    // Check if this is a direct buy (widget.product is not null) or from the cart
    final bool isDirectBuy = widget.product != null;
    // --- ⭐️ END: MODIFICATION ---
        
    for (final item in _cartItems) {
      final double itemPrice = (item['price'] is num) ? (item['price'] as num).toDouble() : (double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0);
      final int itemQty = (item['qty'] is num) ? (item['qty'] as num).toInt() : (int.tryParse(item['qty']?.toString() ?? '0') ?? 0);
      final int productId = (item['productId'] is num) ? (item['productId'] as num).toInt() : (int.tryParse(item['productId']?.toString() ?? '0') ?? 0);
      final dynamic itemStoreId = item['storeId'] ?? item['store_id'] ?? baseApiParams['storeId'];


      final itemApiParams = {
        ...baseApiParams,
        "grandTotal": itemPrice * itemQty,
        "productIds": item['productId'],
        "qty": item['qty'],
        "storeId": itemStoreId,
        "orderType": (item["isBooking"] == true) ? "Service" : "Product"
      };
      
      // Include size if available
      if (item['size'] != null && item['size'].toString().isNotEmpty) {
        itemApiParams['size'] = item['size'].toString();
      }
      
      // Include weight if available
      if (item['weight'] != null && item['weight'].toString().isNotEmpty) {
        itemApiParams['weight'] = item['weight'].toString();
      }
      
      // Get size from item if available
      final String? itemSize = item['size']?.toString();
      
      orderPromises.add(
        CheckoutApiHelper.createOrder(itemApiParams).then((_) async {
          // Pass size to update function so it can update size-specific stock
          await _updateProductUnitSize(productId, itemQty, size: itemSize);
          
          if (!isDirectBuy) {
            return CheckoutApiHelper.deleteCartItem(_userId, item['productId']);
          } else {
            return Future.value(null);
          }
        }).catchError((error) {
          print('❌ Error processing order for Product ID $productId: $error');
          throw error;
        })
      );
    }
    
    
    await Future.wait(orderPromises);
  }

  void _showSuccessAndClear() {
    setState(() { 
      _isLoading = false; 
      _cartItems = [];
      _selectedAddress = null;
    });

    showSuccessMessage(context, 'Order placed successfully!');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check auth again when screen resumes (e.g., after login)
    if (mounted && _hasCheckedAuth) {
      // Re-check auth status when screen resumes
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          final isLoggedIn = await AuthHelper.isUserLoggedIn();
          if (isLoggedIn && (_userId == '0' || _userId.isEmpty)) {
            // User just logged in, reload data
            _hasCheckedAuth = false; // Reset to allow re-check
            _loadUserId();
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with Stack to show loading overlay
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FB),
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
          'Checkout',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBar: _buildCheckoutBottomBar(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDeliveryAddressSection(),
                const SizedBox(height: 20),
                _buildOrderSummarySection(),
                const SizedBox(height: 20),
                _buildPaymentOptionsSection(),
              ],
            ),
          ),
          
          // --- Loading Overlay ---
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                // Assuming you have a Loading widget
                // child: Loading(color: primaryColor, kSize: 30),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBottomBar() {
    final total = _cartTotal();
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: primaryColor.withOpacity(0.25)),
                  ),
                  child: const Text('Back'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _handlePlaceOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Confirm Order',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- All your _build... Widgets remain unchanged ---
  // --- They are perfectly fine ---

  Widget _buildDeliveryAddressSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.location_on, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Delivery Address',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_addresses.isNotEmpty)
              ..._addresses.map((address) {
                return RadioListTile<Address>(
                  title: Text(
                      '${address.fullname}, ${address.shipping}, ${address.city}'),
                  value: address,
                  groupValue: _selectedAddress,
                  onChanged: (Address? value) {
                    setState(() {
                      _selectedAddress = value;
                      if (value != null) {
                        _populateAddressFields(value);
                      }
                    });
                    _scheduleShiprocketRefresh();
                  },
                );
              }).toList()
            else
              const Text('No addresses found. Please add a new address.'),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              fieldKey: 'fullname',
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _phoneNumberController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              fieldKey: 'phone',
              keyboardType: TextInputType.phone,
              maxLength: 10,
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _districtController,
              label: 'District',
              icon: Icons.location_city_outlined,
              fieldKey: 'district',
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _addressLine1Controller,
              label: 'Shipping Address',
              icon: Icons.home_outlined,
              fieldKey: 'shipping',
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _addressLine2Controller,
              label: 'Area',
              icon: Icons.place_outlined,
              fieldKey: 'area',
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _cityController,
              label: 'City',
              icon: Icons.apartment_outlined,
              fieldKey: 'city',
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _postalCodeController,
              label: 'States',
              icon: Icons.map_outlined,
              fieldKey: 'states',
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _pincodeController,
              label: 'Pincode',
              icon: Icons.local_post_office_outlined,
              fieldKey: 'pincode',
              keyboardType: TextInputType.number,
              maxLength: 6,
              onValueChanged: (_) => _scheduleShiprocketRefresh(),
            ),
            const SizedBox(height: 20),
            // Show login message if user is not logged in
            if (_userId == '0' || _userId.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please login to add or update addresses',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: _addAddress,
                      label: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: _updateAddress,
                      label: const Text('Update Address', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? fieldKey,
    TextInputType? keyboardType,
    int? maxLength,
    ValueChanged<String>? onValueChanged,
  }) {
    final hasError = fieldKey != null && _addressErrors.containsKey(fieldKey);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            labelText: '$label${fieldKey != null ? ' *' : ''}',
            prefixIcon: Icon(icon, color: hasError ? Colors.red : primaryColor),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasError ? Colors.red : primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            errorText: hasError ? _addressErrors[fieldKey] : null,
            errorMaxLines: 2,
          ),
          onChanged: (value) {
            if (fieldKey != null && _addressErrors.containsKey(fieldKey)) {
              _addressErrors.remove(fieldKey);
              setState(() {});
            }
            onValueChanged?.call(value);
          },
        ),
      ],
    );
  }

  Widget _buildShiprocketDeliverySection() {
    final storeIds = _uniqueStoreIdsFromCart();
    if (storeIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final delivery = _deliveryPincodeForEta().trim();
    final hasValidDeliveryPin = RegExp(r'^\d{6}$').hasMatch(delivery);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.10),
            Colors.white,
          ],
        ),
        border: Border.all(color: primaryColor.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.local_shipping_outlined, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Delivery estimates (by store)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                if (_shiprocketEtaLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: primaryColor.withOpacity(0.18)),
                    ),
                    child: Text(
                      'ETA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Icon(Icons.pin_drop_outlined, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      !hasValidDeliveryPin
                          ? 'Enter a valid 6-digit delivery pincode to see Shiprocket ETAs.'
                          : 'Delivery pincode: $delivery',
                      style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...storeIds.map((sid) {
              final key = sid.toString();
              final storeRow = _storesById[key];
              final name = (storeRow?['storename'] ?? 'Store #$sid').toString();
              final partner = (storeRow?['deliveryPartner'] ?? '').toString().toLowerCase();
              final eta = _shiprocketEtaByStoreId[key];

              String line;
              if (!hasValidDeliveryPin) {
                line = '—';
              } else if (storeRow == null) {
                line = 'Checking store...';
              } else if (partner != 'shiprocket') {
                line = 'Local delivery';
              } else if (eta == null || eta.isEmpty) {
                line = _shiprocketEtaLoading ? 'Checking...' : '—';
              } else {
                line = eta;
              }

              final isLocal = storeRow != null && partner != 'shiprocket';
              final isShiprocket = storeRow != null && partner == 'shiprocket';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isShiprocket
                            ? primaryColor
                            : (isLocal ? Colors.orange[700] : Colors.grey[500]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (isShiprocket ? primaryColor : (isLocal ? Colors.orange : Colors.grey))
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isShiprocket ? 'Shiprocket' : (isLocal ? 'Local' : 'Pending'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isShiprocket ? primaryColor : (isLocal ? Colors.orange[800] : Colors.grey[800]),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  line,
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
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
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummarySection() {
    double total = 0.0;
    if(_cartItems.isNotEmpty) {
      total = _cartItems.fold(0.0, (sum, item) {
       final double price = (item['price'] is num) ? (item['price'] as num).toDouble() : (double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0);
       final int qty = (item['qty'] is num) ? (item['qty'] as num).toInt() : (int.tryParse(item['qty']?.toString() ?? '0') ?? 0);
       return sum + (price * qty);
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Order Summary',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_cartItems.isNotEmpty)
              ..._cartItems.map((item) {
                 final double price = (item['price'] is num) ? (item['price'] as num).toDouble() : (double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0);
                 final int qty = (item['qty'] is num) ? (item['qty'] as num).toInt() : (int.tryParse(item['qty']?.toString() ?? '0') ?? 0);
                 final String? size = item['size']?.toString();
                 final String? weight = item['weight']?.toString();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['name']} (x${item['qty']})'),
                                if (size != null && size.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.straighten, size: 12, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Size: $size',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (weight != null && weight.isNotEmpty) ...[
                                        const SizedBox(width: 12),
                                        Icon(Icons.scale, size: 12, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Weight: $weight',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text('Rs: ${(price * qty).toStringAsFixed(2)}'),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList()
            else
              const Text('Your cart is empty.'),
            if (_cartItems.isNotEmpty) _buildShiprocketDeliverySection(),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Products (${_cartItems.length} Items)'),
                Text('Rs: ${total.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 5),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Delivery Charge'),
                Text('Free'),
              ],
            ),
            const Divider(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOptionsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.payment, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Payment Options',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            RadioListTile<int>(
              title: const Text('Online payment'),
              value: 1,
              groupValue: _selectedPaymentOption,
              onChanged: (int? value) {
                setState(() {
                  _selectedPaymentOption = value!;
                });
                _scheduleShiprocketRefresh();
              },
            ),
            RadioListTile<int>(
              title: const Text('Pre Order'),
              value: 2,
              groupValue: _selectedPaymentOption,
              onChanged: (int? value) {
                setState(() {
                  _selectedPaymentOption = value!;
                });
                _scheduleShiprocketRefresh();
              },
            ),
            if (_selectedPaymentOption == 2) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaryColor.withOpacity(0.18)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.info_outline, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final total = _cartTotal();
                          final payNow = total * 0.5;
                          final remaining = total - payNow;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pre Order: Pay 50% now',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Pay now: ₹${payNow.toStringAsFixed(2)}  •  Remaining: ₹${remaining.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[900],
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your order will be confirmed after the advance payment. Remaining amount can be collected later.',
                                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // RadioListTile<int>(
            //   title: const Text('Cash on Delivery'),
            //   value: 3,
            //   groupValue: _selectedPaymentOption,
            //   onChanged: (int? value) {
            //     setState(() {
            //       _selectedPaymentOption = value!;
            //     });
            //     _scheduleShiprocketRefresh();
            //   },
            // ),
            RadioListTile<int>(
              title: const Text('Delivery in future'),
              value: 4,
              groupValue: _selectedPaymentOption,
              onChanged: (int? value) {
                setState(() {
                  _selectedPaymentOption = value!;
                });
                _scheduleShiprocketRefresh();
              },
            ),
            if (_selectedPaymentOption == 4) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.withOpacity(0.18)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_available, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Future delivery: Pay full amount now',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pay now: ₹${_cartTotal().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[900],
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select a delivery date below and complete payment to confirm your order.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_selectedPaymentOption == 4)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    'Select Delivery Date:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  ElevatedButton(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDeliveryDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != _selectedDeliveryDate) {
                        setState(() {
                          _selectedDeliveryDate = picked;
                        });
                      }
                    },
                    child: Text(
                      _selectedDeliveryDate == null
                          ? 'Choose Date'
                          : '${_selectedDeliveryDate!.day}/${_selectedDeliveryDate!.month}/${_selectedDeliveryDate!.year}',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // --- THIS IS THE KEY CHANGE ---
        // The button is now enabled and calls the new logic
        ElevatedButton(
          onPressed: _handlePlaceOrder, // Changed from null
          child: const Text('Confirm Order'),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomeScreen()));
          },
          child: const Text('Back To Shop'),
        ),
      ],
    );
  }

  Future<void> _fetchCartItems() async {
    final response = await SecureHttpClient.get(
      '${AppConfig.baseApi}/cart/list/$_userId',
      context: context,
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        setState(() {
          _cartItems = data['data'];
        });
      } else {
        setState(() {
          _cartItems = [];
        });
      }
      if (mounted) {
        _scheduleShiprocketRefresh();
      }
    } else {
      throw Exception('Failed to load cart items');
    }
  }
}