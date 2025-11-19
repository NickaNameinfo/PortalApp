import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:nickname_portal/components/loading.dart';
import 'package:nickname_portal/constants/colors.dart';
import 'package:nickname_portal/views/auth/account_type_selector.dart';
import 'package:nickname_portal/views/main/customer/edit_profile.dart';
import 'package:nickname_portal/components/k_list_tile.dart';
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
      final response = await http.get(
        Uri.parse('https://nicknameinfo.net/api/auth/user/$_userId')
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timeout');
        },
      );

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
    } on TimeoutException {
      print('Request timeout while fetching user details');
      setState(() {
        isLoading = false;
      });
    } on SocketException {
      print('No internet connection');
      setState(() {
        isLoading = false;
      });
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
            onPressed: () => _logout(context),
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

void _logout(BuildContext context) async {
  // 1. Clear saved user data
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  // 3. Navigate and remove all other routes
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

  // Modern Card Widget
  Widget _buildModernCard({required Widget child}) {
    return Container(
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
      child: child,
    );
  }

  // Modern Info Tile Widget
  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modern Action Tile Widget
  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  // Modern Divider Widget
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey[200],
      ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: Loading(
                color: primaryColor,
                kSize: 50,
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryColor.withOpacity(0.1),
                    Colors.white,
                  ],
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  // Profile Header Section
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor,
                            primaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          // Profile Avatar
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // User Name
                          Text(
                            credential?['firstName'] ?? 'User',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // User Email
                          Text(
                            credential?['email'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Content Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contact Information Card
                          _buildModernCard(
                            child: Column(
                              children: [
                                _buildInfoTile(
                                  icon: Icons.email_outlined,
                                  iconColor: Colors.blue,
                                  title: 'Email Address',
                                  subtitle: credential?['email'] ?? 'N/A',
                                ),
                                _buildDivider(),
                                _buildInfoTile(
                                  icon: Icons.phone_outlined,
                                  iconColor: Colors.green,
                                  title: 'Phone Number',
                                  subtitle: credential?['phone'] ?? 'Not set yet',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Support Information Card
                          _buildModernCard(
                            child: Column(
                              children: [
                                _buildInfoTile(
                                  icon: Icons.support_agent_outlined,
                                  iconColor: Colors.orange,
                                  title: 'Support Email',
                                  subtitle: 'bussiness@nicknameinfotech.com',
                                ),
                                _buildDivider(),
                                _buildInfoTile(
                                  icon: Icons.phone_outlined,
                                  iconColor: Colors.purple,
                                  title: 'Support Phone',
                                  subtitle: '+91 88078 34582',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Actions Card
                          _buildModernCard(
                            child: Column(
                              children: [
                                // _buildActionTile(
                                //   icon: Icons.edit_outlined,
                                //   iconColor: primaryColor,
                                //   title: 'Edit Profile',
                                //   onTap: _editProfile,
                                // ),
                                // _buildDivider(),
                                // _buildActionTile(
                                //   icon: Icons.lock_outline,
                                //   iconColor: Colors.amber,
                                //   title: 'Change Password',
                                //   onTap: _changePassword,
                                // ),
                                _buildDivider(),
                                _buildActionTile(
                                  icon: Icons.logout,
                                  iconColor: Colors.red,
                                  title: 'Logout',
                                  onTap: showLogoutOptions,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}