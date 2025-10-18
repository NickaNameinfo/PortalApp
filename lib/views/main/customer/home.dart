import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; 

// ASSUMED: Your Utility Functions
import 'package:multivendor_shop/utilities/url_launcher_utils.dart';
import 'package:multivendor_shop/views/main/store/store_details.dart';

// ASSUMED: Your Components/Constants
import '../../../components/loading.dart';
import '../../../constants/colors.dart'; 
import 'package:multivendor_shop/components/nav_bar_container.dart';
import 'package:multivendor_shop/components/gradient_background.dart';

// Import the refactored common widgets
import '../../../components/customer_home_widgets.dart'; 
// Import the extracted Provider class
import '../../../providers/category_filter_data.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // FIX: Use List<dynamic>. This is the most flexible type and is compatible
  // with the explicit casting in _fetchCategories and the CategoriesWidget.
  late Future<List<dynamic>> _categoriesFuture;
  
  Future<List<dynamic>>? _storesFuture;
  
  int? _currentFilterId; 
  String? _currentSearchQuery;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize the future
    _categoriesFuture = _fetchCategories();
    _storesFuture = _fetchStoreList(categoryId: null, searchQuery: null);
    
    _searchController.addListener(() {
      setState(() {}); 
    }); 
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    try {
      final filterData = Provider.of<CategoryFilterData>(context, listen: false);
      final newFilterId = filterData.selectedCategoryId;
      final newSearchQuery = filterData.searchQuery;

      bool filterChanged = newFilterId != _currentFilterId;
      bool searchChanged = newSearchQuery != _currentSearchQuery;

      if (filterChanged || searchChanged) {
        _currentFilterId = newFilterId;
        _currentSearchQuery = newSearchQuery;
        
        _storesFuture = _fetchStoreList(
          categoryId: _currentFilterId, 
          searchQuery: _currentSearchQuery,
        );
        setState(() {});
        
        if (filterChanged && newFilterId != null) {
          _searchController.clear();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Provider Error in didChangeDependencies: $e");
      }
    }
  }
  
  // FIX: This is the corrected and singular definition for fetching categories.
  // It returns List<dynamic> but ensures the elements inside are Map<String, dynamic>.
  Future<List<dynamic>> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('https://nicknameinfo.net/api/category/getAllCategory'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          // Returning List.from() is safer than using type casting (as List<Map<String, dynamic>>)
          // in the return signature, but the widget code must handle the elements as Map.
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
  
  Future<List<dynamic>> _fetchStoreList({int? categoryId, String? searchQuery}) async {
    String url;
    if (categoryId != null) {
      url = 'https://nicknameinfo.net/api/store/filterByCategory?categoryIds=$categoryId';
    } else if (searchQuery != null && searchQuery.isNotEmpty) {
      url = 'https://nicknameinfo.net/api/store/getAllStoresByFilters?search=${Uri.encodeQueryComponent(searchQuery)}'; 
    } else {
      url = 'https://nicknameinfo.net/api/store/list';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'] ?? [];
      } else {
        throw Exception('Failed to load stores: API error');
      }
    } else {
      throw Exception('Failed to load stores: HTTP error ${response.statusCode}');
    }
  }


  void _onSearchSubmitted(String value) {
    final trimmedValue = value.trim();

    try {
      Provider.of<CategoryFilterData>(context, listen: false).setSearchQuery(
        trimmedValue.isNotEmpty ? trimmedValue : null
      );
    } catch (e) {
      if (kDebugMode) {
        print("Provider not found for search: $e");
      }
      // Fallback: If provider is missing
      setState(() {
        _currentSearchQuery = trimmedValue.isNotEmpty ? trimmedValue : null;
        _storesFuture = _fetchStoreList(searchQuery: _currentSearchQuery);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: gradientBackgroundDecoration, 
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                HomeTopBar(
                  searchController: _searchController,
                  onSearchSubmitted: _onSearchSubmitted,
                ),
                const SizedBox(height: 10),
                const ButtonsGrid(),
                const SizedBox(height: 15),
                CategoriesWidget(
                  categoriesFuture: _categoriesFuture,
                ),
                const SizedBox(height: 15),
                _buildContentCards(),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentCards() {
    return NavBarContainer(
      child: FutureBuilder<List<dynamic>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No stores available.'),
            ));
          }

          final List<dynamic> storeList = snapshot.data!;

          return Column(
            children: storeList.map((store) {
              final openTime = store['openTime'] ?? 'N/A';
              final closeTime = store['closeTime'] ?? 'N/A';
              final openCloseTime = (openTime != 'N/A' && closeTime != 'N/A')
                  ? '$openTime AM : $closeTime PM'
                  : 'N/A';
              final website = store['website'] as String?;
              final phone = store['phone'] as String?;
              final storeaddress = store['storeaddress'] as String?;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: _buildInfoCard(
                  title: store['storename'] ?? 'N/A',
                  logoUrl: store['storeImage'] ?? 'https://via.placeholder.com/150',
                  products: store['totalProducts'] ?? 0,
                  openTime: openCloseTime,
                  rating: 4.3, // Static rating
                  website: website,
                  phone: phone,
                  storeaddress: storeaddress,
                  storeId: store['id'],
                  location: store['location'] ?? 'N/A',
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String logoUrl,
    required int products,
    required String openTime,
    required double rating,
    required String? website,
    required String? phone,
    required String? storeaddress,
    required int storeId,
    required String location,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.white,
                        ),
                        child: logoUrl.startsWith('http')
                          ? Image.network(
                              logoUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.error, size: 120),
                            )
                          : Image.asset('assets/placeholder.png', fit: BoxFit.contain),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Text(
                            'Open : ',
                            style: TextStyle(fontSize: 14, color: Colors.black),
                          ),
                          Text(
                            openTime,
                            style: const TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 16),
                          const SizedBox(width: 5),
                          Text(rating.toString(), style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (phone != null) {
                                    // Assumed utility function
                                    makePhoneCall(phone);
                                  }
                                },
                                child: const Icon(Icons.call, size: 20, color: Colors.deepPurple),
                              ),
                              const SizedBox(width: 15),
                              GestureDetector(
                                onTap: () {
                                  if (website != null) {
                                    // Assumed utility function
                                    launchWebsite(website);
                                  }
                                },
                                child: const Icon(Icons.language, size: 20, color: Colors.deepPurple),
                              ),
                              const SizedBox(width: 15),
                              GestureDetector(
                                onTap: () {
                                  if (location != null) {
                                    // Assumed utility function
                                    openMap(location);
                                  }
                                },
                                child: const Icon(Icons.location_on, size: 20, color: Colors.deepPurple),
                              ),
                            ],
                          ),
                          GestureDetector(
                                onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => StoreDetails(
                                storeId:  storeId
                              ),
                            ),
                          ),
                                child: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.deepPurple),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Products : $products',
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
                const Row(
                  children: [
                    Text(
                      'Near By : ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Coming soon',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}