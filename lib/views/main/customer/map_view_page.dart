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


class MapViewPage extends StatefulWidget {
  static const routeName = '/map-view';
  const MapViewPage({super.key});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
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
      url = 'https://nicknameinfo.net/api/store/service/filterByCategory?categoryIds=$idString';
    } else if (searchQuery != null && searchQuery.isNotEmpty) {
      url = 'https://nicknameinfo.net/api/store/service/getAllStoresByFilters?search=${Uri.encodeQueryComponent(searchQuery)}';
    } else if (paymentMode != null) {
      url = 'https://nicknameinfo.net/api/store/service/getAllStoresByFilters?paymentModes=$paymentMode';
    } else {
      url = 'https://nicknameinfo.net/api/store/service/list';
      // --- MODIFIED: Append location to the default list endpoint ---
      if (location != null && location.isNotEmpty) {
        url = '$url?currentLocation=${Uri.encodeQueryComponent(location)}'; 
      }
    }

    if (kDebugMode) {
      print('Fetching URL: $url');
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => StoreDetails(storeId: storeId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[100],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: logoUrl.startsWith('http')
                            ? Image.network(
                                logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.store,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.store,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Name
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          // Rating and Timing Badges Row
                          Row(
                            children: [
                              // Rating Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.orange, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toString(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Timing Badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time, size: 14, color: Colors.green[700]),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          openTime,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Action Icons Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildActionIcon(
                                icon: Icons.call_outlined,
                                color: Colors.blue,
                                onTap: () {
                                  if (phone != null) {
                                    makePhoneCall(phone);
                                  }
                                },
                              ),
                              _buildActionIcon(
                                icon: Icons.language_outlined,
                                color: Colors.purple,
                                onTap: () {
                                  launchWebsite(website ?? '', storeId);
                                },
                              ),
                              _buildActionIcon(
                                icon: Icons.location_on_outlined,
                                color: Colors.red,
                                onTap: () {
                                  if (location != 'N/A') {
                                    openMap(location);
                                  }
                                },
                              ),
                              _buildActionIcon(
                                icon: Icons.arrow_forward_ios,
                                color: primaryColor,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => StoreDetails(storeId: storeId),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bottom Info Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            '$products Products',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (distance != 'N/A')
                        Row(
                          children: [
                            Icon(Icons.near_me_outlined, size: 16, color: primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'Near By : ${distance} km',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
          ),
        ),
      ),
    );
  }

  // Modern Action Icon Widget
  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: color,
        ),
      ),
    );
  }
}