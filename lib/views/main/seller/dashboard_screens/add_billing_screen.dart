import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../models/billing_model.dart';
import '../../../../helpers/billing_service.dart';

class AddBillingScreen extends StatefulWidget {
  const AddBillingScreen({Key? key}) : super(key: key);

  @override
  State<AddBillingScreen> createState() => _AddBillingScreenState();
}

class _AddBillingScreenState extends State<AddBillingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _taxController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  List<BillingProduct> _selectedProducts = [];
  Map<String, dynamic>? _selectedProduct;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _storeId;
  
  // Size management for selected product
  String? _selectedSize;
  Map<String, Map<String, dynamic>>? _sizeUnitSizeMap; // Store sizeUnitSizeMap for current product
  final List<String> _availableSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL', 'XXXXL'];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadStoreId();
    await _fetchProducts();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Try both 'storeId' and 'storeid' keys
    String? storeId = prefs.getString('storeId') ?? prefs.getInt('storeid')?.toString();
    setState(() {
      _storeId = storeId;
    });
    print('Store ID loaded: $_storeId'); // Debug log
  }

  Future<void> _fetchProducts() async {
    print('_fetchProducts called with storeId: $_storeId'); // Debug log
    
    if (_storeId == null || _storeId!.isEmpty) {
      print('Store ID is null or empty'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store ID not found. Please login again.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = 'https://nicknameinfo.net/api/store/product/admin/getAllProductById/$_storeId';
      print('Fetching products from: $url'); // Debug log
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      print('Response status code: ${response.statusCode}'); // Debug log
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final productsList = List<Map<String, dynamic>>.from(data['data'] ?? []);
        print('Products loaded: ${productsList.length} items'); // Debug log
        setState(() {
          _products = productsList;
        });
      } else {
        print('Failed response body: ${response.body}'); // Debug log
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addProduct() {
    if (_selectedProduct == null) return;

    final product = _selectedProduct!['product'];
    final productId = _selectedProduct!['productId'];
    if (product == null) return;

    // Check if already added (considering size if applicable)
    final isDuplicate = _selectedProducts.any((p) {
      if (p.id == _selectedProduct!['id']) {
        // If product has sizes, check if same size is already added
        if (_selectedSize != null && _selectedSize!.isNotEmpty) {
          return p.size == _selectedSize;
        }
        // If no size, check if product without size is already added
        return p.size == null || p.size!.isEmpty;
      }
      return false;
    });

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_selectedSize != null && _selectedSize!.isNotEmpty
            ? 'Product with size $_selectedSize already added to the bill'
            : 'Product already added to the bill')),
      );
      return;
    }

    // Get price and unitSize based on size selection
    double price = 0.0;
    int unitSize = 0;

    // Check if product has sizeUnitSizeMap and size is selected
    if (_selectedSize != null && _selectedSize!.isNotEmpty && _sizeUnitSizeMap != null && _sizeUnitSizeMap!.isNotEmpty) {
      // Use size-specific price and unitSize
      final sizeData = _sizeUnitSizeMap![_selectedSize];
      if (sizeData != null) {
        price = double.tryParse(sizeData['price']?.toString() ?? '0') ?? 0.0;
        unitSize = int.tryParse(sizeData['unitSize']?.toString() ?? '0') ?? 0;
      }
    }

    // Fallback to default price/unitSize if size-specific not available
    if (price == 0.0) {
      price = double.tryParse(_selectedProduct!['price']?.toString() ?? '0') ??
          double.tryParse(product['total']?.toString() ?? '0') ??
          double.tryParse(product['price']?.toString() ?? '0') ??
          0.0;
    }
    if (unitSize == 0) {
      unitSize = int.tryParse(product['unitSize']?.toString() ?? '0') ?? 0;
    }

    final newProduct = BillingProduct(
      id: _selectedProduct!['id'],
      productId: product['id'],
      name: product['name'],
      productName: product['name'],
      photo: product['photo'],
      price: price,
      quantity: 1,
      total: price,
      unitSize: unitSize,
      size: _selectedSize,
    );

    setState(() {
      _selectedProducts.add(newProduct);
      _selectedProduct = null;
      _selectedSize = null;
      _sizeUnitSizeMap = null;
    });
  }

  void _removeProduct(int index) {
    setState(() {
      _selectedProducts.removeAt(index);
    });
  }

  void _updateQuantity(int index, int quantity) {
    if (quantity < 1) return;
    
    final product = _selectedProducts[index];
    
    // Check stock availability
    if (product.unitSize != null && quantity > product.unitSize!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product.size != null && product.size!.isNotEmpty
                ? 'Only ${product.unitSize} items available in stock for size ${product.size}!'
                : 'Only ${product.unitSize} items available in stock!'
          ),
        ),
      );
      return;
    }
    
    setState(() {
      _selectedProducts[index] = product.copyWith(
        quantity: quantity,
        total: product.price * quantity,
      );
    });
  }

  void _updatePrice(int index, double price) {
    if (price < 0) return;
    setState(() {
      final product = _selectedProducts[index];
      _selectedProducts[index] = product.copyWith(
        price: price,
        total: price * product.quantity,
      );
    });
  }

  double _calculateSubtotal() {
    return _selectedProducts.fold(0, (sum, product) => sum + product.total);
  }

  double _calculateTotal() {
    final subtotal = _calculateSubtotal();
    final discount = double.tryParse(_discountController.text) ?? 0;
    final tax = double.tryParse(_taxController.text) ?? 0;
    return subtotal - discount + tax;
  }

  Future<void> _updateProductUnitSizes() async {
    try {
      for (final product in _selectedProducts) {
        if (product.productId == null) continue;

        // Fetch current product data
        final productResponse = await http.get(
          Uri.parse('https://nicknameinfo.net/api/product/getProductById/${product.productId}'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 15));

        if (productResponse.statusCode != 200) {
          print('Failed to fetch product ${product.productId}');
          continue;
        }

        final productData = jsonDecode(productResponse.body);
        final productInfo = productData['data'];

        if (productInfo == null) continue;

        // Check if product has sizeUnitSizeMap and size is provided
        if (product.size != null && product.size!.isNotEmpty && productInfo['sizeUnitSizeMap'] != null) {
          // Update size-specific unitSize
          try {
            Map<String, dynamic> sizeUnitSizeMap;
            if (productInfo['sizeUnitSizeMap'] is String) {
              sizeUnitSizeMap = Map<String, dynamic>.from(jsonDecode(productInfo['sizeUnitSizeMap']));
            } else {
              sizeUnitSizeMap = Map<String, dynamic>.from(productInfo['sizeUnitSizeMap']);
            }

            // Find matching size key (case-insensitive)
            String? matchingSizeKey;
            for (var key in sizeUnitSizeMap.keys) {
              if (key.toString().toLowerCase() == product.size!.toLowerCase()) {
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
                final newSizeUnitSize = currentSizeUnitSize - product.quantity;

                if (newSizeUnitSize < 0) {
                  print('Warning: Product ${product.name} size ${product.size} has insufficient stock');
                  continue;
                }

                // Update the size-specific unitSize in the map
                if (sizeData is Map) {
                  final updatedSizeData = Map<String, dynamic>.from(sizeData);
                  updatedSizeData['unitSize'] = newSizeUnitSize.toString();
                  sizeUnitSizeMap[matchingSizeKey] = updatedSizeData;
                } else {
                  sizeUnitSizeMap[matchingSizeKey] = {
                    'unitSize': newSizeUnitSize.toString(),
                    'price': '',
                    'qty': '',
                    'discount': '',
                    'discountPer': '',
                    'total': '',
                    'grandTotal': '',
                    'name': product.name,
                  };
                }

                // Update the product with modified sizeUnitSizeMap
                final updateData = {
                  'id': product.productId,
                  'sizeUnitSizeMap': jsonEncode(sizeUnitSizeMap),
                };

                final response = await http.post(
                  Uri.parse('https://nicknameinfo.net/api/product/update'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(updateData),
                ).timeout(const Duration(seconds: 15));

                if (response.statusCode == 200) {
                  print('✅ Successfully updated product ${product.productId} size ${product.size} unitSize to $newSizeUnitSize');
                } else {
                  print('⚠️ Failed to update product ${product.productId} size ${product.size} unitSize. Status: ${response.statusCode}');
                }
                continue; // Skip default flow
              }
            }
          } catch (e) {
            print('⚠️ Error parsing sizeUnitSizeMap for product ${product.productId}: $e');
            // Fall through to default flow
          }
        }

        // Default flow: Update main product unitSize (if no size or sizeUnitSizeMap doesn't exist)
        if (product.unitSize == null) continue;

        final newUnitSize = product.unitSize! - product.quantity;

        if (newUnitSize < 0) {
          print('Warning: Product ${product.name} has insufficient stock');
          continue;
        }

        final updateData = {
          'id': product.productId,
          'unitSize': newUnitSize.toString(),
        };

        final response = await http.post(
          Uri.parse('https://nicknameinfo.net/api/product/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updateData),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          print('✅ Successfully updated product ${product.productId} unit size to $newUnitSize');
        } else {
          print('⚠️ Failed to update product ${product.productId} unitSize. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('❌ Error updating product unit sizes: $e');
      // Don't throw error as billing was successful
    }
  }

  Future<void> _submitBill() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final billData = BillingModel(
        customerName: _customerNameController.text,
        customerEmail: _customerEmailController.text,
        customerPhone: _customerPhoneController.text,
        products: _selectedProducts,
        subtotal: _calculateSubtotal(),
        discount: double.tryParse(_discountController.text) ?? 0,
        tax: double.tryParse(_taxController.text) ?? 0,
        total: _calculateTotal(),
        notes: _notesController.text,
      );

      final billJson = billData.toJson();
      billJson['storeId'] = _storeId;

      await BillingService.addBill(billJson);

      // Update product unit sizes after successful billing
      await _updateProductUnitSizes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill created successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create bill: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Bill'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Selection Card
                    _buildProductSelectionCard(),
                    const SizedBox(height: 16),

                    // Customer Information Card
                    _buildCustomerInfoCard(),
                    const SizedBox(height: 16),

                    // Bill Summary Card
                    _buildBillSummaryCard(),
                    const SizedBox(height: 16),

                    // Notes Card
                    _buildNotesCard(),
                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitBill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Create Bill',
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProductSelectionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Products',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedProduct,
                    decoration: InputDecoration(
                      labelText: 'Search and Select Product',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: _products.map((storeProduct) {
                      final product = storeProduct['product'];
                      if (product == null) return null;

                      // Get price with proper fallback
                      final displayPrice = double.tryParse(storeProduct['price']?.toString() ?? '0') ?? 
                                         double.tryParse(product['total']?.toString() ?? '0') ?? 
                                         double.tryParse(product['price']?.toString() ?? '0') ?? 
                                         0.0;

                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: storeProduct,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product['name'] ?? 'Unknown Product',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '₹${displayPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).whereType<DropdownMenuItem<Map<String, dynamic>>>().toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedProduct = value;
                        _selectedSize = null;
                        _sizeUnitSizeMap = null;
                        
                        // Parse sizeUnitSizeMap if product has it
                        if (value != null) {
                          final product = value['product'];
                          if (product != null && product['sizeUnitSizeMap'] != null) {
                            try {
                              Map<String, dynamic> parsedMap;
                              if (product['sizeUnitSizeMap'] is String) {
                                parsedMap = Map<String, dynamic>.from(jsonDecode(product['sizeUnitSizeMap']));
                              } else {
                                parsedMap = Map<String, dynamic>.from(product['sizeUnitSizeMap']);
                              }
                              
                              // Convert to Map<String, Map<String, dynamic>>
                              _sizeUnitSizeMap = parsedMap.map((key, value) {
                                if (value is Map) {
                                  return MapEntry(key, Map<String, dynamic>.from(value));
                                } else {
                                  // If value is not a Map, create a default structure
                                  return MapEntry(key, {
                                    'unitSize': value?.toString() ?? '0',
                                    'qty': value?.toString() ?? '0',
                                    'price': '0',
                                    'discount': '0',
                                    'discountPer': '0',
                                    'total': '0',
                                    'grandTotal': '0',
                                  });
                                }
                              });
                              
                              // Set default size to first available if map exists
                              if (_sizeUnitSizeMap != null && _sizeUnitSizeMap!.isNotEmpty) {
                                _selectedSize = _sizeUnitSizeMap!.keys.first;
                              }
                            } catch (e) {
                              print('Error parsing sizeUnitSizeMap: $e');
                              _sizeUnitSizeMap = null;
                            }
                          }
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedProduct != null ? _addProduct : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            // Size Selection (if product has sizes)
            if (_selectedProduct != null && _sizeUnitSizeMap != null && _sizeUnitSizeMap!.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSize,
                decoration: InputDecoration(
                  labelText: 'Select Size',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: _sizeUnitSizeMap!.keys.map((size) {
                  final sizeData = _sizeUnitSizeMap![size];
                  final price = double.tryParse(sizeData?['price']?.toString() ?? '0') ?? 0.0;
                  final unitSize = int.tryParse(sizeData?['unitSize']?.toString() ?? '0') ?? 0;
                  
                  return DropdownMenuItem<String>(
                    value: size,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          size,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                        Text(
                          '₹${price.toStringAsFixed(2)} | Stock: $unitSize',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedSize = value);
                },
              ),
            ],
            if (_selectedProducts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Selected Products (${_selectedProducts.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildSelectedProductsTable(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedProductsTable() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _selectedProducts.length,
      itemBuilder: (context, index) {
        final product = _selectedProducts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Product Info Row
                Row(
                  children: [
                    // Product Image
                    if (product.photo != null && product.photo!.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            product.photo!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[100],
                              child: Icon(Icons.image, size: 30, color: Colors.grey[400]),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    // Product Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name ?? product.productName ?? 'Unknown Product',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Item #${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (product.size != null && product.size!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Size: ${product.size}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Delete Button
                    IconButton(
                      onPressed: () => _removeProduct(index),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                // Price, Quantity, Total Row
                Row(
                  children: [
                    // Price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: Key('price_$index'),
                            initialValue: product.price.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              prefixText: '₹',
                              prefixStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onChanged: (value) {
                              _updatePrice(index, double.tryParse(value) ?? 0);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Quantity
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (product.quantity > 1) {
                                      _updateQuantity(index, product.quantity - 1);
                                    }
                                  },
                                  icon: const Icon(Icons.remove),
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 48,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    product.quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _updateQuantity(index, product.quantity + 1);
                                  },
                                  icon: const Icon(Icons.add),
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 48,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Total
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text(
                              '₹${product.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerNameController,
              decoration: InputDecoration(
                labelText: 'Customer Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Customer name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerEmailController,
              decoration: InputDecoration(
                labelText: 'Customer Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerPhoneController,
              decoration: InputDecoration(
                labelText: 'Customer Phone',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bill Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:', style: TextStyle(fontSize: 16)),
                Text(
                  '₹${_calculateSubtotal().toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _discountController,
              decoration: InputDecoration(
                labelText: 'Discount',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.discount),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _taxController,
              decoration: InputDecoration(
                labelText: 'Tax',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.receipt),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${_calculateTotal().toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Add any additional notes...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}

