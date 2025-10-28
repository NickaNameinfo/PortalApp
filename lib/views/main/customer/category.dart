import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart'; 
import 'package:flutter/foundation.dart'; 

import '../../../constants/colors.dart';
import '../../../components/loading.dart';
import 'product_details_screen.dart'; 
import 'package:multivendor_shop/components/gradient_background.dart';
import 'package:multivendor_shop/providers/category_filter_data.dart'; 

// --- NEW ---
// Import the customer widgets file to get the HomeTopBar, CategoriesWidget,
// and HomeFilterDrawer
import 'package:multivendor_shop/components/customer_home_widgets.dart';


class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Future<List<dynamic>> _productsFuture;
  
  // --- NEW ---
  // Add state variables from HomeScreen to manage the new filter widgets
  late Future<List<dynamic>> _categoriesFuture;
  final TextEditingController _searchController = TextEditingController();
  Set<int> _currentFilterIds = {};
  
  // We don't need _currentSearchQuery or _currentPaymentMode
  // because the product API only filters by category.

  @override
  void initState() {
    super.initState();
    
    // --- NEW ---
    // Fetch categories for the CategoriesWidget
    _categoriesFuture = _fetchCategories(); 
    
    // Get the *initial* category filter state
    final initialFilters = Provider.of<CategoryFilterData>(context, listen: false).selectedCategoryIds ?? <int>{};
    _currentFilterIds = initialFilters;
    
    // Start the first product fetch
    _productsFuture = _fetchProductsFromApi(categoryIds: _currentFilterIds);
  }

  // --- NEW ---
  // Listen for changes in the provider
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Listen for provider changes
    final filterData = Provider.of<CategoryFilterData>(context);
    final newFilterIds = filterData.selectedCategoryIds ?? <int>{};

    // Compare with the *last* filters we fetched for
    if (!setEquals(_currentFilterIds, newFilterIds)) {
      
      // Filters have changed! Update our state and re-fetch
      _currentFilterIds = newFilterIds;
      _productsFuture = _fetchProductsFromApi(categoryIds: _currentFilterIds);
      
      // Tell the FutureBuilder to rebuild with the new future
      setState(() {}); 
    }
  }

  // --- MODIFIED ---
  // Refresh using the *current* category filters
  void _refreshProducts() {
    setState(() {
      _productsFuture = _fetchProductsFromApi(categoryIds: _currentFilterIds);
    });
  }
  
  // --- NEW ---
  // This function is for the HomeTopBar's search field
  void _onSearchSubmitted(String value) {
    final trimmedValue = value.trim();
    // This will clear category filters and trigger a re-fetch
    Provider.of<CategoryFilterData>(context, listen: false).setSearchQuery(
      trimmedValue.isNotEmpty ? trimmedValue : null
    );
  }

  // --- NEW ---
  // This function is for the CategoriesWidget
  Future<List<dynamic>> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('https://nicknameinfo.net/api/category/getAllCategory'));
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
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // --- MODIFIED ---
  // Renamed from _getAllProducts and updated to accept filters
  Future<List<dynamic>> _fetchProductsFromApi({Set<int>? categoryIds}) async {
    String url;

    // Build the URL based on whether filters are active or not
    if (categoryIds != null && categoryIds.isNotEmpty) {
      final idString = categoryIds.join(',');
      url = 'https://nicknameinfo.net/api/product/getAllByCategory?categoryIds=$idString';
    } else {
      url = 'https://nicknameinfo.net/api/product/getAllproductList';
    }
    
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception('API returned an error');
      }
    } else {
      throw Exception('Failed to load products');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      
      // --- MODIFIED ---
      // Add the drawer to the Scaffold
      endDrawer: const HomeFilterDrawer(),
      
      // --- REMOVED ---
      // The old AppBar is gone
      // appBar: AppBar(...),
      
      body: Container(
        decoration: gradientBackgroundDecoration,
        // --- NEW ---
        // Add SafeArea to avoid the status bar
        child: SafeArea( 
          child: Column(
            children: [
              
              // --- NEW ---
              // Add the filter widgets from your home screen
              HomeTopBar(
                searchController: _searchController,
                onSearchSubmitted: _onSearchSubmitted,
              ),
              const SizedBox(height: 10),
              CategoriesWidget(
                categoriesFuture: _categoriesFuture,
              ),
              const SizedBox(height: 15),
              // --- END OF NEW WIDGETS ---
              
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  // --- MODIFIED ---
                  // Use the renamed state variable
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
                            Image.asset(
                              'assets/images/sad.png',
                              width: 150,
                              errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.sentiment_dissatisfied, size: 100, color: Colors.grey),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No products available!',
                              style: TextStyle(
                                color: primaryColor,
                              ),
                            )
                          ],
                        ),
                      );
                    }

                    // --- (Rest of the GridView is unchanged) ---
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
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(15.0),
                                        topRight: Radius.circular(15.0),
                                      ),
                                      child: Image.network(
                                        product['photo'] ?? 'https://via.placeholder.com/150',
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => 
                                          Container(
                                            height: 120, 
                                            color: Colors.grey[200], 
                                            child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 50)
                                          ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['name'] ?? 'N/A',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            'RS ${product['discount']}',
                                            style: const TextStyle(
                                              decoration: TextDecoration.lineThrough,
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'RS ${product['total']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'RS ${product['discount'] ?? 0} %',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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