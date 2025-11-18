import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart'; // <-- NEW: Import geolocator

// ASSUMED: Your Utility Functions
import 'package:nickname_portal/utilities/url_launcher_utils.dart';
import 'package:nickname_portal/views/main/store/store_details.dart';

// ASSUMED: Your Components/Constants
import '../../../components/loading.dart';
import '../../../constants/colors.dart';
import 'package:nickname_portal/components/nav_bar_container.dart';
import 'package:nickname_portal/components/gradient_background.dart';

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
  late Future<List<dynamic>> _categoriesFuture;
  
  Future<List<dynamic>>? _storesFuture;
  
  Set<int> _currentFilterIds = {};
  String? _currentSearchQuery;
  
  int? _currentPaymentMode; 
  
  // --- NEW: Location State ---
  Position? _position; 
  String? _locationError;

  // Computed property to format location for API
  String? get _currentLocationString {
    if (_position == null) return null;
    return '${_position!.latitude},${_position!.longitude}';
  }
  // ---------------------------
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchCategories();
    // Start fetching location immediately
    _determinePosition(); 
    
    // Initial store fetch will use null location, which is fine, 
    // it will be re-run after position is determined.
    _storesFuture = _fetchStoreList(categoryIds: null, searchQuery: null, paymentMode: null);
    
    _searchController.addListener(() {
      setState(() {});
    });
  }

  // --- NEW: Location Determination Function ---
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show a dialog to the user
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text('Allow location and get distance of near store'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Open Settings'),
                onPressed: () {
                  Geolocator.openLocationSettings();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
        setState(() {
          _locationError = 'Location services are disabled.';
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Location Permissions Denied'),
              content: const Text('Allow location and get distance of near store'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
          setState(() {
            _locationError = 'Location permissions are denied.';
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Location Permissions Permanently Denied'),
            content: const Text('Location permissions are permanently denied. Please enable them from app settings to get distance of near store.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Open App Settings'),
                onPressed: () {
                  Geolocator.openAppSettings();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
        setState(() {
          _locationError = 'Location permissions are permanently denied, we cannot request permissions.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      
      if (mounted) {
        setState(() {
          _position = position;
          _locationError = null;
          // Re-fetch stores with the newly acquired location
          _storesFuture = _fetchStoreList(
            categoryIds: _currentFilterIds, 
            searchQuery: _currentSearchQuery, 
            paymentMode: _currentPaymentMode,
          );
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching location: $e");
      }
      if (mounted) {
         setState(() {
          _locationError = 'Failed to get location: $e';
        });
      }
    }
  }
  // ---------------------------------------------
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    try {
      final filterData = Provider.of<CategoryFilterData>(context);

      final newFilterIds = filterData.selectedCategoryIds ?? <int>{};
      final newSearchQuery = filterData.searchQuery;
      final newPaymentMode = filterData.selectedPaymentMode; 

      bool filterChanged = !setEquals(_currentFilterIds, newFilterIds);
      bool searchChanged = newSearchQuery != _currentSearchQuery;
      bool paymentModeChanged = newPaymentMode != _currentPaymentMode; 

      if (filterChanged || searchChanged || paymentModeChanged) { 
        _currentFilterIds = newFilterIds; 
        _currentSearchQuery = newSearchQuery;
        _currentPaymentMode = newPaymentMode; 
        
        // --- MODIFIED: Location is now retrieved via _currentLocationString getter ---
        _storesFuture = _fetchStoreList(
          categoryIds: _currentFilterIds, 
          searchQuery: _currentSearchQuery,
          paymentMode: _currentPaymentMode, 
        );
        // ----------------------------------------------------------------------------
        
        setState(() {});
        
        if (filterChanged && newFilterIds.isNotEmpty) {
           _searchController.clear();
        }
        
        if (paymentModeChanged && newPaymentMode != null) {
          _searchController.clear();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Provider Error in didChangeDependencies: $e");
      }
    }
  }
  
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
  
  // --- MODIFIED: Removed currentLocation parameter, now uses _currentLocationString getter ---
  Future<List<dynamic>> _fetchStoreList({
    Set<int>? categoryIds, 
    String? searchQuery, 
    int? paymentMode,
  }) async {
    String url;
    final location = _currentLocationString; // Get the latest location from state

    if (categoryIds != null && categoryIds.isNotEmpty) {
      final idString = categoryIds.join(','); 
      url = 'https://nicknameinfo.net/api/store/filterByCategory?categoryIds=$idString';
    } else if (searchQuery != null && searchQuery.isNotEmpty) {
      url = 'https://nicknameinfo.net/api/store/getAllStoresByFilters?search=${Uri.encodeQueryComponent(searchQuery)}';
    } else if (paymentMode != null) {
      url = 'https://nicknameinfo.net/api/store/getAllStoresByFilters?paymentModes=$paymentMode';
    } else {
      url = 'https://nicknameinfo.net/api/store/list';
      
      // --- MODIFIED: Append location to the default list endpoint ---
      if (location != null && location.isNotEmpty) {
        url = '$url?currentLocation=${Uri.encodeQueryComponent(location)}'; 
      }
    }

    if (kDebugMode) {
      print('Fetching URL: $url');
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
          return data['data'] ?? [];
        } else {
          throw Exception('Failed to load stores: API error');
        }
      } else {
        throw Exception('Failed to load stores: HTTP error ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout. Please check your internet connection.');
    } on SocketException {
      throw Exception('No internet connection.');
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
      setState(() {
        _currentSearchQuery = trimmedValue.isNotEmpty ? trimmedValue : null;
        _storesFuture = _fetchStoreList(searchQuery: _currentSearchQuery);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const HomeFilterDrawer(),
      body: Container(
        decoration: gradientBackgroundDecoration,
        child: SafeArea(
          child: Column(
        children: [
          HomeTopBar(
            searchController: _searchController,
            onSearchSubmitted: _onSearchSubmitted,
          ),
          if (_locationError != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Location Error: $_locationError',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ) 
          else if (_position == null)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Fetching location...',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          const SizedBox(height: 15),
          CategoriesWidget(
            categoriesFuture: _categoriesFuture,
          ),
          const SizedBox(height: 15),
          Expanded(
            child: _buildContentCards(),
          ),
        ],
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

          return ListView(
            children: storeList.map((store) {
              final openTime = store['openTime'] ?? 'N/A';
              final closeTime = store['closeTime'] ?? 'N/A';
              final openCloseTime = (openTime != 'N/A' && closeTime != 'N/A')
                  ? '$openTime AM : $closeTime PM'
                  : 'N/A';
              final website = store['website'] as String?;
              final phone = store['phone'] as String?;
              final storeaddress = store['storeaddress'] as String?;
              
              // --- FIX: Ensure distance is a String ---
              final rawDistance = store['distance'];
              final distanceString = (rawDistance is double || rawDistance is int)
                  ? rawDistance.toStringAsFixed(1) // Format to one decimal place
                  : 'N/A';
              // --------------------------------------

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
                  distance: distanceString, // <-- Use the corrected string
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
    required String distance,
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
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => StoreDetails(
                          storeId: storeId,
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
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
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Text(
                            'Open : ',
                            style: TextStyle(fontSize: 12, color: Colors.black),
                          ),
                          Text(
                            openTime,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
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
                                    launchWebsite(website ?? '', storeId);
                                },
                                child: const Icon(Icons.language, size: 20, color: Colors.deepPurple),
                              ),
                              const SizedBox(width: 15),
                              GestureDetector(
                                onTap: () {
                                  if (location != 'N/A') { // Check against the default string
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
                Row(
                  children: [
                    const Text(
                      'Near By : ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                        '${distance} km', // <-- Now guaranteed to be a String
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
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