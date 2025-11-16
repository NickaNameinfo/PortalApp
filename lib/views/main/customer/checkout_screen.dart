import 'package:flutter/material.dart';
import 'package:nickname_portal/providers/cart.dart';
import 'package:nickname_portal/utilities/show_message.dart';
import 'package:provider/provider.dart';
import 'package:nickname_portal/routes/routes.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:nickname_portal/helpers/address_service.dart';
import 'package:nickname_portal/helpers/order_service.dart'; // We keep this for Address class
import 'package:nickname_portal/views/main/customer/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- New Imports Required for Payment Logic ---
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:nickname_portal/helpers/checkout_api_helper.dart'; // Our new helper
// Assuming you have a loading component
// import 'package:nickname_portal/components/loading.dart'; 
// import 'package:nickname_portal/constants/colors.dart';


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
  
  late String _userId = '';
  int _selectedPaymentOption = 2; // Default to COD
  DateTime? _selectedDeliveryDate;
  List<Address> _addresses = [];
  Address? _selectedAddress;
  final AddressService _addressService = AddressService();
  List<dynamic> _cartItems = [];
  
  // --- New State Variables for Payment Logic ---
  late Razorpay _razorpay;
  bool _isLoading = false;
  
  // To pass data to the Razorpay success callback
  Map<String, dynamic>? _pendingApiParams;
  Map<String, dynamic>? _pendingPaymentResult;


  @override
  void initState() {
    super.initState();
    
    // Check if product data was passed directly
    if (widget.product != null) {
      // Set cart items with the single product
      _cartItems = [widget.product!];
    }
    
    _loadUserId();
    
    // --- Initialize Razorpay ---
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    _districtController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    
    // --- Dispose Razorpay ---
    _razorpay.clear();
    super.dispose();
  }

 
  Future<void> _loadUserId() async {
    setState(() { _isLoading = true; });
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = (prefs.getString('userId') ?? '0');
    });
    
    if (_userId != '0') {
      await _fetchAddresses();
      // Only fetch cart items if no direct product was passed
      if (widget.product == null) {
        await _fetchCartItems();
      }
    } else {
      showErrorMessage(context, "User not logged in.");
    }
    setState(() { _isLoading = false; });
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
  }

  Future<void> _addAddress() async {
    final newAddress = Address(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Temp ID
      fullname: _nameController.text,
      phone: _phoneNumberController.text,
      discrict: _districtController.text,
      city: _cityController.text,
      states: _postalCodeController.text,
      area: _addressLine2Controller.text,
      shipping: _addressLine1Controller.text,
      orderId: _userId,
      cusId: _userId,
    );

    try {
      setState(() { _isLoading = true; });
      await _addressService.createAddress(newAddress);
      await _fetchAddresses(); // Refresh list
      showSuccessMessage(context, 'Address added successfully!');
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

    final updatedAddress = Address(
      id: _selectedAddress!.id,
      fullname: _nameController.text,
      phone: _phoneNumberController.text,
      discrict: _districtController.text,
      city: _cityController.text,
      states: _postalCodeController.text,
      area: _addressLine2Controller.text,
      shipping: _addressLine1Controller.text,
      orderId: _userId,
      cusId: _userId,
    );

    try {
      setState(() { _isLoading = true; });
      await _addressService.updateAddress(updatedAddress);
      await _fetchAddresses(); // Refresh list
      showSuccessMessage(context, 'Address updated successfully!');
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
  
  Future<void> _handlePlaceOrder() async {
    if (_selectedAddress == null) {
      showErrorMessage(context, 'Please select or add a delivery address.');
      return;
    }
    if (_cartItems.isEmpty) {
      showErrorMessage(context, 'Your cart is empty.');
      return;
    }
    
    // Check for date if payment option 4 is selected
    if (_selectedPaymentOption == 4 && _selectedDeliveryDate == null) {
      showErrorMessage(context, 'Please select a delivery date.');
      return;
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
        "cusId": _selectedAddress!.cusId,
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
    // Based on your new UI: 1 = Online, 2/3/4 = Offline
    if (_selectedPaymentOption == 1 || _selectedPaymentOption == 3 || _selectedPaymentOption == 4) {
      // --- ONLINE PAYMENT FLOW (Razorpay) ---
      try {
        final paymentResult = await CheckoutApiHelper.createRazorpayOrder(grandTotal, _userId);

        if (paymentResult['success'] == true && paymentResult['data'] != null) {
          final paymentData = paymentResult['data'];
          
          _pendingApiParams = baseApiParams;
          _pendingPaymentResult = paymentData;

          final options = {
            'key': 'rzp_live_RgPc8rKEOZbHgf', // Your Razorpay Key
            'amount': paymentData['amount'],
            'currency': paymentData['currency'],
            'order_id': paymentData['id'],
            'name': 'Nickname Infotech',
            'description': 'For Subscriptions',
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
  Future<void> _placeIndividualOrders(Map<String, dynamic> baseApiParams) async {
    final List<Future<void>> orderPromises = [];
    
    // --- ⭐️ START: MODIFICATION ---
    // Check if this is a direct buy (widget.product is not null) or from the cart
    final bool isDirectBuy = widget.product != null;
    // --- ⭐️ END: MODIFICATION ---
    
    for (final item in _cartItems) {
      final double itemPrice = (item['price'] is num) ? (item['price'] as num).toDouble() : (double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0);
      final int itemQty = (item['qty'] is num) ? (item['qty'] as num).toInt() : (int.tryParse(item['qty']?.toString() ?? '0') ?? 0);

      final itemApiParams = {
        ...baseApiParams,
        "grandTotal": itemPrice * itemQty,
        "productIds": item['productId'],
        "qty": item['qty'],
        "orderType": item["isBooking"] ? "Service" : "Product"
      };
      
      orderPromises.add(
        CheckoutApiHelper.createOrder(itemApiParams).then((_) {
          // --- ⭐️ START: MODIFICATION ---
          // ONLY delete from cart if it was NOT a direct buy
          if (!isDirectBuy) {
            return CheckoutApiHelper.deleteCartItem(_userId, item['productId']);
          } else {
            // If it's a direct buy, do nothing with the cart
            return Future.value(null);
          }
          // --- ⭐️ END: MODIFICATION ---
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
  Widget build(BuildContext context) {
    // Wrap with Stack to show loading overlay
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDeliveryAddressSection(),
                const SizedBox(height: 20),
                _buildOrderSummarySection(),
                const SizedBox(height: 20),
                _buildPaymentOptionsSection(),
                const SizedBox(height: 20),
                _buildActionButtons(),
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

  // --- All your _build... Widgets remain unchanged ---
  // --- They are perfectly fine ---

  Widget _buildDeliveryAddressSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  },
                );
              }).toList()
            else
              const Text('No addresses found. Please add a new address.'),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneNumberController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _districtController,
              decoration: const InputDecoration(labelText: 'District'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressLine1Controller,
              decoration: const InputDecoration(labelText: 'Shipping Address'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressLine2Controller,
              decoration: const InputDecoration(labelText: 'Area'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _postalCodeController,
              decoration: const InputDecoration(labelText: 'States'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: _addAddress,
                  child: const Text('Add Address'),
                ),
                ElevatedButton(
                  onPressed: _updateAddress,
                  child: const Text('Update Address'),
                ),
              ],
            ),
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

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_cartItems.isNotEmpty)
              ..._cartItems.map((item) {
                 final double price = (item['price'] is num) ? (item['price'] as num).toDouble() : (double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0);
                 final int qty = (item['qty'] is num) ? (item['qty'] as num).toInt() : (int.tryParse(item['qty']?.toString() ?? '0') ?? 0);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item['name']} (x${item['qty']})'),
                      Text('Rs: ${(price * qty).toStringAsFixed(2)}'),
                    ],
                  ),
                );
              }).toList()
            else
              const Text('Your cart is empty.'),
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
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Rs. ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOptionsSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            RadioListTile<int>(
              title: const Text('Online payment'),
              value: 1,
              groupValue: _selectedPaymentOption,
              onChanged: (int? value) {
                setState(() {
                  _selectedPaymentOption = value!;
                });
              },
            ),
            RadioListTile<int>(
              title: const Text('Cash on Delivery'),
              value: 2,
              groupValue: _selectedPaymentOption,
              onChanged: (int? value) {
                setState(() {
                  _selectedPaymentOption = value!;
                });
              },
            ),
            RadioListTile<int>(
              title: const Text('Pre Order'),
              value: 3,
              groupValue: _selectedPaymentOption,
              onChanged: (int? value) {
                setState(() {
                  _selectedPaymentOption = value!;
                });
              },
            ),
            RadioListTile<int>(
              title: const Text('Delivery in future'),
              value: 4,
              groupValue: _selectedPaymentOption,
              onChanged: (int? value) {
                setState(() {
                  _selectedPaymentOption = value!;
                });
              },
            ),
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
    final response = await http.get(Uri.parse('https://nicknameinfo.net/api/cart/list/$_userId'));
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
    } else {
      throw Exception('Failed to load cart items');
    }
  }
}