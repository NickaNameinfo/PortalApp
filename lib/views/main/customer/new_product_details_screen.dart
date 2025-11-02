import 'package:flutter/material.dart';
import 'package:multivendor_shop/constants/colors.dart';
import 'package:flutter/services.dart'; 

class NewProductDetailsScreen extends StatelessWidget {
  static const routeName = '/new_product_details_screen';
  final Map<String, dynamic> product;

  const NewProductDetailsScreen({super.key, required this.product});

  // Helper to safely access dynamic product fields
  String _safeGet(String key, String fallback) {
    // Accessing map safely and converting to String
    return product[key] is String ? product[key] : product[key]?.toString() ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    // Safely parse data based on the provided API response structure
    final double price = double.tryParse(_safeGet('price', '0')) ?? 0.0;
    // Calculate final price after discount (API: total = 44100)
    final double discountedPrice = double.tryParse(_safeGet('total', price.toString())) ?? price;
    final double discountPer = double.tryParse(_safeGet('discountPer', '0')) ?? 0.0;
    final int stockQty = int.tryParse(_safeGet('qty', '0')) ?? 0;
    
    // Check payment modes (API: paymentMode = "1,3")
    final String paymentMode = _safeGet('paymentMode', '');
    final bool isPerOrder = paymentMode.contains('1');
    final bool isOnline = paymentMode.contains('2'); // Not in API example, but safe check
    final bool isCOD = paymentMode.contains('3');

    // Tab view height estimation
    const double tabViewHeight = 300; 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Use DefaultTabController for the tabbed interface at the bottom
      body: DefaultTabController(
        length: 2, // Description and Customization
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Product Image & Main Info Card (Full Width) ---
              Padding(
                padding: const EdgeInsets.all(16.0), 
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _safeGet('photo', 'https://placehold.co/600x400/5E5E5E/FFFFFF/png?text=No+Image'),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 180,
                              color: Colors.grey.shade200,
                              child: const Center(child: Text('Image Failed to Load')),
                            ),
                          ),
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
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // Discounted Price
                                Text(
                                  '₹${discountedPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Original Price
                                Text(
                                  '₹${price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                            // Stock Indicator
                            Text(
                              stockQty > 0 ? '$stockQty Stocks Available' : 'Out of Stock',
                              style: TextStyle(
                                fontSize: 16,
                                color: stockQty > 0 ? Colors.green.shade600 : Colors.red.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

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
                        
                        // --- Quantity & Cart Button ---
                        // Row(
                        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //   children: [
                        //     // Quantity Controls
                        //     Row(
                        //       children: [
                        //         Container(
                        //           decoration: BoxDecoration(
                        //             color: Colors.grey.shade200,
                        //             borderRadius: BorderRadius.circular(20),
                        //           ),
                        //           child: Row(
                        //             children: [
                        //               IconButton(
                        //                 icon: const Icon(Icons.remove, color: primaryColor),
                        //                 onPressed: () {}, 
                        //               ),
                        //               const Text(
                        //                 '1', 
                        //                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        //               ),
                        //               IconButton(
                        //                 icon: const Icon(Icons.add, color: primaryColor),
                        //                 onPressed: () {}, 
                        //               ),
                        //             ],
                        //           ),
                        //         ),
                        //       ],
                        //     ),

                        //     // View Cart Button
                        //     ElevatedButton.icon(
                        //       onPressed: () {}, 
                        //       icon: const Icon(Icons.shopping_cart, color: Colors.white),
                        //       label: const Text(
                        //         'View Cart',
                        //         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        //       ),
                        //       style: ElevatedButton.styleFrom(
                        //         backgroundColor: primaryColor,
                        //         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        //         shape: RoundedRectangleBorder(
                        //           borderRadius: BorderRadius.circular(10),
                        //         ),
                        //       ),
                        //     ),
                        //   ],
                        // ),
                        
                        // const SizedBox(height: 20),

                        // // --- Action Icons ---
                        // Row(
                        //   mainAxisAlignment: MainAxisAlignment.spaceAround,
                        //   children: [
                        //     _buildIconButton(Icons.location_on, Colors.blue, () {}),
                        //     _buildIconButton(Icons.share, Colors.green, () {}),
                        //     _buildIconButton(Icons.language, Colors.orange, () {}),
                        //     _buildIconButton(Icons.favorite, Colors.red, () {}),
                        //   ],
                        // ),
                      ],
                    ),
                  ),
              ),
              ),
              const SizedBox(height: 20),

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
                          Tab(text: 'Customization'),
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
                          _buildDescriptionCard(_safeGet('desc', 'No detailed description available.')),

                          // Tab 2: Customization Card
                          _buildCustomizationCard(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                    
                    // Place Order Button (Full Width)
                    SizedBox(
                      width: double.infinity,
                      child: 
                      Column(
                        children: [
                          Text(
                            "We are currently collaborating with stores and will enable ordering soon.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                                        onPressed: null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text(
                                          'Place Order',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold
                                          ),
                                        ),
                                      ),
                        ],
                      ),
        
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
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
              'Product Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor
              ),
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
}