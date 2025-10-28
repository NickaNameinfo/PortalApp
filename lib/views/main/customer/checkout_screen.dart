import 'package:flutter/material.dart';
import 'package:multivendor_shop/providers/cart.dart';
import 'package:multivendor_shop/utilities/show_message.dart';
import 'package:provider/provider.dart';
import 'package:multivendor_shop/routes/routes.dart';
import 'package:http/http.dart' as http; // Import http package
import 'dart:convert'; // Import for json.decode
// *** FIX: Import the Address class from its definitive location ***
import 'package:multivendor_shop/helpers/address_service.dart';
import 'package:multivendor_shop/helpers/order_service.dart';
import 'package:multivendor_shop/views/main/customer/home.dart';


// --- MOCK DEFINITIONS FOR UTILITY FUNCTIONS (Kept to resolve previous errors) ---
// These functions are assumed to be defined in 'package:multivendor_shop/utilities/show_message.dart'
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

// *** REMOVED: The duplicate definition of the 'Address' class was here ***


class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

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

  int _selectedPaymentOption = 1;
  DateTime? _selectedDeliveryDate;
  // Now uses the Address class imported from address_service.dart
  List<Address> _addresses = []; 
  Address? _selectedAddress;
  final AddressService _addressService = AddressService();
  List<dynamic> _cartItems = []; // New state variable to store cart items

  // Placeholder for userId, replace with actual user ID from authentication
  final String userId = '48'; 

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
    _fetchCartItems(); // Fetch cart items when the screen initializes
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
    super.dispose();
  }

  Future<void> _fetchAddresses() async {
    try {
      // Replace with actual user ID
      final fetchedAddresses = await _addressService.fetchAddresses('48'); 
      print(fetchedAddresses);
      setState(() {
        // *** LINE 94 FIX: Assignment now works because both types are the same imported Address ***
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
    // We must now create the Address object using the constructor provided
    // by the Address class imported from address_service.dart.
    // Assuming the constructor signature is the same.
    final newAddress = Address(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID
      fullname: _nameController.text,
      phone: _phoneNumberController.text,
      discrict: _districtController.text,
      city: _cityController.text,
      states: _postalCodeController.text,
      area: _addressLine2Controller.text,
      shipping: _addressLine1Controller.text,
      orderId: '48',
      cusId: '48',
    );

    try {
      // *** LINE 130 FIX: Argument type is now the correct imported Address type ***
      await _addressService.createAddress(newAddress); 
      _fetchAddresses();
      showSuccessMessage(context, 'Address added successfully!');
      
    } catch (e) {
      print('Error adding address: $e');
      showErrorMessage(context, 'Failed to add address.');
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
      orderId: '48',
      cusId: '48',
    );

    try {
      // *** LINE 160 FIX: Argument type is now the correct imported Address type ***
      await _addressService.updateAddress(updatedAddress);
      _fetchAddresses();
      showSuccessMessage(context, 'Address updated successfully!');
      
    } catch (e) {
      print('Error updating address: $e');
      showErrorMessage(context, 'Failed to update address.');
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      showErrorMessage(context, 'Please select a delivery address.');
      return;
    }

    if (_cartItems.isEmpty) {
      showErrorMessage(context, 'Your cart is empty.');
      return;
    }

    try {
      // Place order using OrderService
      final orderResponse = await OrderService.placeOrder(
        customerId: int.parse(userId),
        paymentMethod: 3, // Update with actual payment method
        orderId: int.parse(userId), // Update with actual order ID logic
        grandTotal: _cartItems.fold(0.0, (sum, item) => sum + (item['price'] as double) * (item['qty'] as double)),
        productIds: _cartItems.map((item) => item['productId'] as int).toList(),
        quantities: _cartItems.map((item) => item['qty'] as int).toList(),
      );

      // Delete cart items after successful order
      for (var item in _cartItems) {
        await OrderService.deleteCartItem(
          userId: userId,
          productId: item['productId'] as int,
        );
      }

      showSuccessMessage(context, 'Order placed successfully!');
      _cartItems = [];
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomeScreen()));
    } catch (e) {
      print('Error placing order: $e');
      showErrorMessage(context, 'Failed to place order.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: SingleChildScrollView(
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
    );
  }

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
    // final cartData = Provider.of<CartData>(context);
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
            // Display fetched cart items
            if (_cartItems.isNotEmpty)
              ..._cartItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item['name']} (x${item['qty']})'),
                      Text('Rs: ${(item['price'] * item['qty']).toStringAsFixed(2)}'),
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
                Text('Rs: ${_cartItems.fold<double>(0.0, (double sum, item) => sum + (item['price'] as double) * (item['qty'] as double)).toStringAsFixed(2)}'),
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
                  'Rs. ${_cartItems.fold<double>(0.0, (double sum, item) => sum + (item['price'] as double) * (item['qty'] as double)).toStringAsFixed(2)}',
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
        ElevatedButton(
          onPressed: _placeOrder,
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
    final response = await http.get(Uri.parse('https://nicknameinfo.net/api/cart/list/$userId'));
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