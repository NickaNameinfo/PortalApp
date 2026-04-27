import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../constants/colors.dart';
import '../../../../constants/app_config.dart';
import '../../../../components/loading.dart';
import 'edit_product.dart';
import '../../../../helpers/secure_http_client.dart';

class ScanBarcodeScreen extends StatefulWidget {
  static const routeName = '/scan_barcode';

  const ScanBarcodeScreen({super.key});

  @override
  State<ScanBarcodeScreen> createState() => _ScanBarcodeScreenState();
}

class _ScanBarcodeScreenState extends State<ScanBarcodeScreen> {
  final TextEditingController _productIdController = TextEditingController();
  Map<String, dynamic>? _productData;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _fetchProductDetails(String productId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _productData = null;
    });

    try {
      final response = await SecureHttpClient.get(
        '${AppConfig.baseApi}/product/getProductById/$productId',
        timeout: const Duration(seconds: 15),
        context: context,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _productData = data['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Product not found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load product: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _handleSearch() {
    final productId = _productIdController.text.trim();
    if (productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a product ID')),
      );
      return;
    }
    _fetchProductDetails(productId);
  }

  void _clearSearch() {
    setState(() {
      _productIdController.clear();
      _productData = null;
      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _productIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Scan Barcode',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter Product ID',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _productIdController,
                            decoration: InputDecoration(
                              hintText: 'Scan or enter product ID',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _handleSearch(),
                            autofocus: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _handleSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Search'),
                        ),
                        if (_productData != null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _clearSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tip: Scan the barcode with your mobile device and enter the product ID here, or type the product ID manually.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Loading State
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Loading(color: primaryColor, kSize: 40),
                ),
              ),

            // Error State
            if (_errorMessage != null && !_isLoading)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Product Details
            if (_productData != null && !_isLoading) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_productData!['photo'] != null)
                        Center(
                          child: Image.network(
                            _productData!['photo'].toString(),
                            height: 200,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image, size: 100),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _buildDetailRow('Product Name', _productData!['name']?.toString() ?? 'N/A'),
                      _buildDetailRow('Description', _productData!['sortDesc']?.toString() ?? 'N/A'),
                      if (_productData!['brand'] != null && _productData!['brand'].toString().isNotEmpty)
                        _buildDetailRow('Brand', _productData!['brand']?.toString() ?? 'N/A'),
                      _buildDetailRow('Price', '₹${_productData!['price']?.toString() ?? '0'}'),
                      if (_productData!['discount'] != null && _productData!['discount'].toString().isNotEmpty)
                        _buildDetailRow('Discount', '${_productData!['discount']}%'),
                      if (_productData!['discountPer'] != null && _productData!['discountPer'].toString().isNotEmpty)
                        _buildDetailRow('Discount Amount', '₹${_productData!['discountPer']}'),
                      if (_productData!['total'] != null && double.tryParse(_productData!['total'].toString()) != null && double.parse(_productData!['total'].toString()) > 0)
                        _buildDetailRow('Total', '₹${_productData!['total']}'),
                      if (_productData!['grandTotal'] != null && _productData!['grandTotal'].toString().isNotEmpty)
                        _buildDetailRow('Grand Total', '₹${_productData!['grandTotal']}'),
                      _buildDetailRow('Quantity', _productData!['qty']?.toString() ?? '0'),
                      _buildDetailRow('Unit Size', _productData!['unitSize']?.toString() ?? 'N/A'),
                      if (_productData!['size'] != null && _productData!['size'].toString().isNotEmpty)
                        _buildDetailRow('Size', _productData!['size']?.toString() ?? 'N/A'),
                      if (_productData!['weight'] != null && _productData!['weight'].toString().isNotEmpty)
                        _buildDetailRow('Weight', _productData!['weight']?.toString() ?? 'N/A'),
                      _buildDetailRow(
                        'Status',
                        _productData!['status'] == '1' || _productData!['status'] == 1 ? 'Active' : 'Inactive',
                      ),
                      if (_productData!['paymentMode'] != null && _productData!['paymentMode'].toString().isNotEmpty)
                        _buildDetailRow('Payment Mode', _formatPaymentMode(_productData!['paymentMode'].toString())),
                      if (_productData!['serviceType'] != null)
                        _buildDetailRow('Service Type', _productData!['serviceType']?.toString() ?? 'N/A'),
                      _buildDetailRow('Ecommerce', _productData!['isEnableEcommerce'] == '1' ? 'Enabled' : 'Disabled'),
                      _buildDetailRow('Customize', _productData!['isEnableCustomize'] == 1 || _productData!['isEnableCustomize'] == '1' ? 'Enabled' : 'Disabled'),
                      _buildDetailRow('Booking', _productData!['isBooking'] == '1' || _productData!['isBooking'] == 1 ? 'Enabled' : 'Disabled'),
                      if (_productData!['sizeUnitSizeMap'] != null && _productData!['sizeUnitSizeMap'].toString().isNotEmpty)
                        _buildSizeMapSection(_productData!['sizeUnitSizeMap'].toString()),
                      _buildDetailRow('Product ID', _productData!['id']?.toString() ?? 'N/A'),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProduct(productData: _productData),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Edit Product',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPaymentMode(String paymentMode) {
    final modes = paymentMode.split(',');
    final List<String> modeNames = [];
    for (var mode in modes) {
      switch (mode.trim()) {
        case '1':
          modeNames.add('Per Order');
          break;
        case '2':
          modeNames.add('Online Payment');
          break;
        case '3':
          modeNames.add('Cash on Delivery');
          break;
        default:
          modeNames.add('Unknown');
      }
    }
    return modeNames.join(', ');
  }

  Widget _buildSizeMapSection(String sizeUnitSizeMapJson) {
    try {
      final sizeMap = json.decode(sizeUnitSizeMapJson) as Map<String, dynamic>;
      if (sizeMap.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Size Management:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...sizeMap.entries.map((entry) {
              final size = entry.key.toUpperCase();
              final data = entry.value as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Size: $size',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildDetailRow('Unit Size', data['unitSize']?.toString() ?? 'N/A'),
                    _buildDetailRow('Quantity', data['qty']?.toString() ?? 'N/A'),
                    _buildDetailRow('Price', '₹${data['price']?.toString() ?? '0'}'),
                    if (data['discount'] != null && data['discount'].toString().isNotEmpty)
                      _buildDetailRow('Discount', '${data['discount']}%'),
                    if (data['discountPer'] != null && data['discountPer'].toString().isNotEmpty)
                      _buildDetailRow('Discount Amt', '₹${data['discountPer']}'),
                    if (data['total'] != null && data['total'].toString().isNotEmpty)
                      _buildDetailRow('Total', '₹${data['total']}'),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      );
    } catch (e) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Text(
          'Size Map: Error parsing data',
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
      );
    }
  }
}
