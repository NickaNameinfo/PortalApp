import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:multivendor_shop/components/loading.dart';
import 'package:multivendor_shop/constants/colors.dart';
import 'package:multivendor_shop/views/auth/account_type_selector.dart';
import 'package:multivendor_shop/views/main/customer/edit_profile.dart';
import 'package:multivendor_shop/components/k_list_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}


class _ProfileScreenState extends State<ProfileScreen> {
  // Use a hardcoded ID for demonstration; in a real app, this would come from a user session
  late String _userId = ''; // Initialize with an empty string
  Map<String, dynamic>? credential;
  var isLoading = true;
  var isInit = true;

 @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = (prefs.getString('userId') ?? '0'); // Default to "0" or handle as needed
      _fetchUserDetails(); // Call _fetchUserDetails after _userId is loaded
    });
  }

  // fetch user credentials
  Future<void> _fetchUserDetails() async {
    try {
      final response = await http.get(Uri.parse('https://nicknameinfo.net/api/auth/user/$_userId'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            credential = data['data'];
            isLoading = false;
          });
        } else {
          // Handle API-specific errors
          print('API error: ${data['errors']}');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        // Handle HTTP status code errors
        print('Failed to load user data. Status code: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      // Handle network or parsing errors
      print('An unexpected error occurred: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

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
    // Navigate to the account type selector screen and remove all other routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AccountTypeSelector()),
      (Route<dynamic> route) => false,
    );
  }

  void _editProfile() {
    Navigator.of(context)
        .pushNamed(EditProfile.routeName)
        .then(
          (value) => setState(
            () {
              _fetchUserDetails(); // Refresh data after returning from EditProfile
            },
          ),
        );
  }

  void _settings() {
    // TODO: Implement settings navigation
  }

  void _changePassword() {
    Navigator.of(context).pushNamed(
      EditProfile.routeName,
      arguments: true,
    );
  }
  
  // This method is no longer needed as the fetch is handled in initState()
  // and the call to refresh is made in the .then() of _editProfile().
  // @override
  // void didChangeDependencies() {
  //   if (isInit) {
  //     isInit = false;
  //     _fetchUserDetails();
  //   }
  //   super.didChangeDependencies();
  // }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return isLoading
        ? const Center(
            child: Loading(
              color: primaryColor,
              kSize: 50,
            ),
          )
        : CustomScrollView(
            slivers: [
              // SliverAppBar(
              //   elevation: 0,
              //   automaticallyImplyLeading: false,
              //   expandedHeight: 130,
              //   backgroundColor: primaryColor,
              //   flexibleSpace: LayoutBuilder(
              //     builder: (context, constraints) {
              //       return FlexibleSpaceBar(
              //         titlePadding: const EdgeInsets.symmetric(
              //           horizontal: 18,
              //           vertical: 10,
              //         ),
              //         title: AnimatedOpacity(
              //           opacity: constraints.biggest.height <= 120 ? 1 : 0,
              //           duration: const Duration(
              //             milliseconds: 300,
              //           ),
              //           child: Wrap(
              //               crossAxisAlignment: WrapCrossAlignment.center,
              //               children: [
              //                 const CircleAvatar(
              //                   radius: 20,
              //                   backgroundColor: primaryColor,
              //                   backgroundImage: NetworkImage(
              //                     // Placeholder image as the API response doesn't contain a user image
              //                     'https://via.placeholder.com/150',
              //                   ),
              //                 ),
              //                 const SizedBox(width: 10),
              //                 Text(
              //                   credential?['firstName'] ?? 'N/A',
              //                   style: const TextStyle(
              //                     fontSize: 12,
              //                     color: Colors.white,
              //                     fontWeight: FontWeight.w600,
              //                   ),
              //                 ),
              //               ]),
              //         ),
              //         background: Container(
              //           decoration: const BoxDecoration(
              //             gradient: LinearGradient(
              //               colors: [
              //                 primaryColor,
              //                 Colors.black26,
              //               ],
              //               stops: [0.1, 1],
              //               end: Alignment.topRight,
              //             ),
              //           ),
              //           child: Column(
              //             mainAxisAlignment: MainAxisAlignment.center,
              //             children: [
              //               const CircleAvatar(
              //                 radius: 65,
              //                 backgroundColor: primaryColor,
              //                 backgroundImage: NetworkImage(
              //                   // Placeholder image as the API response doesn't contain a user image
              //                   'https://via.placeholder.com/150',
              //                 ),
              //               ),
              //               Text(
              //                 credential?['firstName'] ?? 'N/A',
              //                 style: const TextStyle(
              //                   fontSize: 18,
              //                   color: Colors.white,
              //                   fontWeight: FontWeight.w600,
              //                 ),
              //               ),
              //             ],
              //           ),
              //         ),
              //       );
              //     },
              //   ),
              // ),
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
                      //           onPressed: () {},
                      //           child: const Text(
                      //             'Orders',
                      //             style: TextStyle(
                      //               fontWeight: FontWeight.bold,
                      //               fontSize: 22,
                      //               color: primaryColor,
                      //             ),
                      //           ),
                      //         ),
                      //         ElevatedButton(
                      //           style: ElevatedButton.styleFrom(
                      //             padding: const EdgeInsets.symmetric(
                      //               horizontal: 20,
                      //               vertical: 10,
                      //             ),
                      //             backgroundColor: primaryColor,
                      //             shape: RoundedRectangleBorder(
                      //               borderRadius: BorderRadius.circular(5),
                      //             ),
                      //           ),
                      //           onPressed: () {},
                      //           child: const Text(
                      //             'Wishlist',
                      //             style: TextStyle(
                      //               fontWeight: FontWeight.bold,
                      //               fontSize: 22,
                      //               color: Colors.white,
                      //             ),
                      //           ),
                      //         ),
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
                      //           onPressed: () {},
                      //           child: const Text(
                      //             'Cart',
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
                        height: size.height / 4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            KListTile(
                              title: 'Email Address',
                              subtitle: credential?['email'] ?? 'N/A',
                              icon: Icons.email,
                            ),
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Divider(thickness: 1),
                            ),
                            KListTile(
                              title: 'Phone Number',
                              subtitle: credential?['phone'] ?? 'Not set yet',
                              icon: Icons.phone,
                            ),
                            // const Padding(
                            //   padding: EdgeInsets.all(8.0),
                            //   child: Divider(thickness: 1),
                            // ),
                            // KListTile(
                            //   title: 'Delivery Address',
                            //   subtitle: credential?['address'] ?? 'Not set yet',
                            //   icon: Icons.location_pin,
                            // ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: size.height / 15,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            // KListTile(
                            //   title: 'Edit Profile',
                            //   icon: Icons.edit_note,
                            //   onTapHandler: _editProfile,
                            //   showSubtitle: false,
                            // ),
                            // const Padding(
                            //   padding: EdgeInsets.all(8.0),
                            //   child: Divider(thickness: 1),
                            // ),
                            // KListTile(
                            //   title: 'Change Password',
                            //   icon: Icons.key,
                            //   onTapHandler: _changePassword,
                            //   showSubtitle: false,
                            // ),
                            // const Padding(
                            //   padding: EdgeInsets.all(8.0),
                            //   child: Divider(thickness: 1),
                            // ),
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