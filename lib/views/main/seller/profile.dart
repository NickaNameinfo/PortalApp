import 'package:flutter/material.dart';
import 'package:multivendor_shop/components/loading.dart';
import 'package:multivendor_shop/constants/colors.dart';
import 'package:multivendor_shop/views/main/seller/dashboard_screens/orders.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/store.dart';
import '../../auth/account_type_selector.dart';
import 'dashboard_screens/manage_products.dart';
import 'edit_profile.dart';
import '../../../components/k_list_tile.dart';
import 'dashboard_screens/account_balance.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Removed DocumentSnapshot credential as all info now comes from store API
  // Removed unused Firebase dependencies
  
  Store? _store;
  var isLoading = true;
  String? _supplierId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  // --- Data Fetching Methods ---

  Future<void> _fetchStoreDetails() async {
    debugPrint('Attempting to fetch store details for supplier ID: $_supplierId');
    try {
      if (_supplierId == null || _supplierId?.isEmpty == true) {
        debugPrint('Supplier ID is null/empty. Cannot fetch store details.');
        return;
      }
      final response = await http.get(Uri.parse('https://nicknameinfo.net/api/store/list/$_supplierId'));
      
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          if (mounted) {
            setState(() {
              _store = Store.fromJson(decodedData['data']);
            });
          }
        } else {
          debugPrint('Store API returned success: false or missing data.');
        }
      } else {
        debugPrint('Store API failed with status: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching store details: $e');
    }
  }

  Future<void> _loadAllData() async {
    if (mounted) {
      setState(() => isLoading = true);
    }
    
    // 1. Load supplier ID from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? loadedSupplierId = prefs.getString('storeId');

    if (mounted) {
      setState(() {
        _supplierId = loadedSupplierId;
      });
    }

    // 2. Fetch Store Details (API) - This now provides the seller's profile details too.
    if (_supplierId != null && _supplierId?.isNotEmpty == true) {
      await _fetchStoreDetails();
    } else {
      debugPrint('Skipping _fetchStoreDetails because _supplierId is null or empty.');
    }

    // 3. Set final loading state
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // --- UI Action Handlers ---

  void showLogoutOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Image.asset(
              'assets/images/profile.png',
              width: 35,
              color: primaryColor,
            ),
            const Text(
              'Logout Account',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(
            color: primaryColor,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _logout(),
            child: const Text(
              'Yes',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() {
    // Navigate without Firebase sign-out
    Navigator.of(context).pushNamedAndRemoveUntil(
      AccountTypeSelector.routeName,
      (route) => false,
    );
  }

  void _editProfile() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const EditProfile(),
          ),
        )
        .then((_) => _loadAllData()); 
  }

  void _settings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App Settings functionality not implemented.')),
    );
  }

  void _changePassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EditProfile(
          editPasswordOnly: true,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    final dataLoaded = _store != null;
    
    // Safely retrieve data from _store (Owner/Seller Details)
    final fullName = _store?.ownername ?? 'Store Owner';
    // Use storeImage or a fallback if ownerImage is not provided in the model
    final imageUrl = _store?.storeImage ?? 'https://placehold.co/100x100/CCCCCC/000000?text=P'; 
    final storeName = _store?.storename ?? 'N/A';

    // Helper to safely read store owner details
    String getOwnerDetail(String key) {
      final value = _store?.toJson()[key];
      if (value == null || (value is String && value.isEmpty)) {
        return 'Not set yet';
      }
      return value.toString();
    }


    return isLoading
        ? const Center(
            child: Loading(
              color: primaryColor,
              kSize: 50,
            ),
          )
        : CustomScrollView(
            slivers: [
              SliverAppBar(
                elevation: 0,
                automaticallyImplyLeading: false,
                expandedHeight: 130,
                backgroundColor: primaryColor,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    return FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      title: AnimatedOpacity(
                        opacity: constraints.biggest.height <= 120 ? 1 : 0,
                        duration: const Duration(
                          milliseconds: 300,
                        ),
                        child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: primaryColor,
                                backgroundImage: NetworkImage(
                                  imageUrl,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ]),
                      ),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              Colors.black26,
                            ],
                            stops: [0.1, 1],
                            end: Alignment.topRight,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 65,
                              backgroundColor: primaryColor,
                              backgroundImage: NetworkImage(
                                imageUrl,
                              ),
                            ),
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_store != null)
                              Text(
                                storeName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Column(
                    children: [
                      // Container(
                      //   height: 60,
                      //   width: size.width / 0.9,
                      //   decoration: BoxDecoration(
                      //     color: Colors.white,
                      //     borderRadius: BorderRadius.circular(30),
                      //   ),
                      //   child: Padding(
                      //     padding: const EdgeInsets.all(8.0),
                      //     child: Row(
                      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //       children: [
                      //         ElevatedButton(
                      //           style: ElevatedButton.styleFrom(
                      //             padding: const EdgeInsets.symmetric(
                      //               horizontal: 20,
                      //               vertical: 10,
                      //             ),
                      //             backgroundColor: bWhite,
                      //             shape: const RoundedRectangleBorder(
                      //               borderRadius: BorderRadius.only(
                      //                 topLeft: Radius.circular(30),
                      //                 bottomLeft: Radius.circular(30),
                      //               ),
                      //             ),
                      //           ),
                      //           onPressed: () => Navigator.of(context)
                      //               .pushNamed(OrdersScreen.routeName),
                      //           child: const Text(
                      //             'Order',
                      //             style: TextStyle(
                      //               fontWeight: FontWeight.bold,
                      //               fontSize: 22,
                      //               color: primaryColor,
                      //             ),
                      //           ),
                      //         ),
                      //         // ElevatedButton(
                      //         //   style: ElevatedButton.styleFrom(
                      //         //     padding: const EdgeInsets.symmetric(
                      //         //       horizontal: 20,
                      //         //       vertical: 10,
                      //         //     ),
                      //         //     backgroundColor: primaryColor,
                      //         //     shape: RoundedRectangleBorder(
                      //         //       borderRadius: BorderRadius.circular(5),
                      //         //     ),
                      //         //   ),
                      //         //   onPressed: () => Navigator.of(context)
                      //         //       .pushNamed(AccountBalanceScreen.routeName), 
                      //         //   child: const Text(
                      //         //     'Account',
                      //         //     style: TextStyle(
                      //         //       fontWeight: FontWeight.bold,
                      //         //       fontSize: 22,
                      //         //       color: Colors.white,
                      //         //     ),
                      //         //   ),
                      //         // ),
                      //         ElevatedButton(
                      //           style: ElevatedButton.styleFrom(
                      //             padding: const EdgeInsets.symmetric(
                      //               horizontal: 20,
                      //               vertical: 10,
                      //             ),
                      //             backgroundColor: bWhite,
                      //             shape: const RoundedRectangleBorder(
                      //               borderRadius: BorderRadius.only(
                      //                 topRight: Radius.circular(30),
                      //                 bottomRight: Radius.circular(30),
                      //               ),
                      //             ),
                      //           ),
                      //           onPressed: () => Navigator.of(context)
                      //               .pushNamed(ManageProductsScreen.routeName),
                      //           child: const Text(
                      //             'Products',
                      //             style: TextStyle(
                      //               fontWeight: FontWeight.bold,
                      //               fontSize: 22,
                      //               color: primaryColor,
                      //             ),
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(height: 20),
                      Container(
                        height: size.height / 1.8, 
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            if (dataLoaded) ...[
                              // Owner/Seller Details (from Store API response)
                              KListTile(
                                title: 'Owner Name',
                                subtitle: getOwnerDetail('ownername'),
                                icon: Icons.person,
                              ),
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Divider(thickness: 1),
                              ),
                              KListTile(
                                title: 'Email Address',
                                subtitle: getOwnerDetail('email'),
                                icon: Icons.email,
                              ),
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Divider(thickness: 1),
                              ),
                              KListTile(
                                title: 'Phone Number',
                                subtitle: getOwnerDetail('phone'),
                                icon: Icons.phone,
                              ),
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Divider(thickness: 1),
                              ),
                              KListTile(
                                title: 'Owner Address',
                                subtitle: getOwnerDetail('owneraddress'),
                                icon: Icons.location_pin,
                              ),
                              
                              // Store Details
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Divider(thickness: 1),
                              ),
                              KListTile(
                                title: 'Store Name',
                                subtitle: _store!.storename,
                                icon: Icons.store,
                              ),
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Divider(thickness: 1),
                              ),
                              KListTile(
                                title: 'Store Address',
                                subtitle: _store!.storeaddress,
                                icon: Icons.location_city,
                              ),
                            ],
                            // Fallback if no user or store data is available
                            if (!dataLoaded && !isLoading)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: Text('Profile details not loaded. Check Supplier ID.')),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: size.height / 17,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            KListTile(
                              title: 'Logout',
                              icon: Icons.logout,
                              onTapHandler: showLogoutOptions,
                              showSubtitle: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          );
  }
}
