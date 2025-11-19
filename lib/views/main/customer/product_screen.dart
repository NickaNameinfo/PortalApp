import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart'; 
import 'package:flutter/foundation.dart'; 

import '../../../constants/colors.dart';
import '../../../components/loading.dart';
import 'product_details_screen.dart'; 
import 'package:nickname_portal/components/gradient_background.dart';
import 'package:nickname_portal/providers/category_filter_data.dart'; 

// Import the customer widgets file to get the HomeTopBar, CategoriesWidget,
// and HomeFilterDrawer
import 'package:nickname_portal/components/customer_home_widgets.dart';


class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Future<List<dynamic>> _productsFuture;
  
  // State variables to manage the filter widgets
  late Future<List<dynamic>> _categoriesFuture;
  final TextEditingController _searchController = TextEditingController();
  
  // State variables to track the *current* filters
  Set<int> _currentFilterIds = {};
  String? _currentSearchQuery;
  int? _currentPaymentMode; // <-- NEW

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
    
    // Start the first product fetch
    _productsFuture = _fetchProductsFromApi(
      categoryIds: _currentFilterIds,
      searchQuery: _currentSearchQuery,
      paymentMode: _currentPaymentMode, // <-- NEW
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
      
      // Re-fetch products with the new filters
      _productsFuture = _fetchProductsFromApi(
        categoryIds: _currentFilterIds,
        searchQuery: _currentSearchQuery,
        paymentMode: _currentPaymentMode, // <-- NEW
      );
      
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
    setState(() {
      _productsFuture = _fetchProductsFromApi(
        categoryIds: _currentFilterIds,
        searchQuery: _currentSearchQuery,
        paymentMode: _currentPaymentMode, // <-- NEW
      );
    });
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
      final response = await http.get(
        Uri.parse('https://nicknameinfo.net/api/category/getAllCategory')
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Category request timeout');
        },
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

  // --- MODIFIED ---
  // Updated to handle search, payment mode, category, or default states
  Future<List<dynamic>> _fetchProductsFromApi({
    Set<int>? categoryIds, 
    String? searchQuery,
    int? paymentMode, // <-- NEW
  }) async {
    String url;

    // --- MODIFIED ---
    // Priority 1: Search
    if (searchQuery != null && searchQuery.isNotEmpty) {
      url = 'https://nicknameinfo.net/api/product/gcatalogsearch/result?search=${Uri.encodeQueryComponent(searchQuery)}';
    }
    // Priority 2: Payment Mode
    else if (paymentMode != null) {
      url = 'https://nicknameinfo.net/api/product/gcatalogsearch/result?paymentModes=$paymentMode';
    }
    // Priority 3: Category
    else if (categoryIds != null && categoryIds.isNotEmpty) {
      final idString = categoryIds.join(',');
      url = 'https://nicknameinfo.net/api/product/getAllByCategory?categoryIds=$idString';
    } 
    // Priority 4: Default (All)
    else {
      url = 'https://nicknameinfo.net/api/product/getAllproductList';
    }
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          
          List<dynamic> responseData = data['data'] ?? [];
          if (responseData.isEmpty) {
            return []; // Return empty list if data is empty
          }

          // Check if the first item has a 'products' key (nested format)
          if (responseData[0] is Map && responseData[0].containsKey('products')) {
            // This is the nested format: List of sub-categories, each with a 'products' list
            List<dynamic> allProducts = [];
            for (var subCategory in responseData) {
              if (subCategory is Map && subCategory['products'] is List) {
                allProducts.addAll(subCategory['products'] as List<dynamic>);
              }
            }
            return allProducts;
          } else {
            // This is the old format: A flat list of products
            return responseData;
          }

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
                child: FutureBuilder<List<dynamic>>(
                  future: _productsFuture, 
                  builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Loading(
                          color: primaryColor,
                          kSize: 30,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('An error occurred: ${snapshot.error}'),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

                    // --- (GridView builder is unchanged) ---
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      itemCount: snapshot.data!.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.75,
                      ),
                      itemBuilder: (context, index) {
                        final product = snapshot.data![index];
                        return GestureDetector(
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
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(18),
                                        topRight: Radius.circular(18),
                                      ),
                                      child: Image.network(
                                        product['photo'] ?? 'https://via.placeholder.com/150',
                                        height: 150,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => 
                                          Container(
                                            height: 150,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(18),
                                                topRight: Radius.circular(18),
                                              ),
                                            ),
                                            child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 50)
                                          ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['name'] ?? 'N/A',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              if (product['discountPer'] != null)
                                                Text(
                                                  '₹${product['discountPer']}',
                                                  style: TextStyle(
                                                    decoration: TextDecoration.lineThrough,
                                                    color: Colors.grey[500],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              if (product['discountPer'] != null)
                                                const SizedBox(width: 6),
                                              Text(
                                                '₹${product['total']}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
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
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.red[400]!, Colors.red[600]!],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${product['discount'] ?? 0}% OFF',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
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