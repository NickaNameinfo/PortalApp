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
import 'package:nickname_portal/views/auth/auth.dart';
import 'package:nickname_portal/views/main/customer/customer_bottom_nav.dart';
import '../../../helpers/secure_http_client.dart';

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
  bool _isLoggedIn = false;
  bool _isFetching = false; // Flag to prevent concurrent API calls

 @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh login status and fetch data when screen becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshProfileData();
      }
    });
  }

  // Method to refresh profile data when screen becomes visible
  Future<void> _refreshProfileData() async {
    // Prevent concurrent calls
    if (_isFetching) {
      debugPrint('Already fetching profile data, skipping refresh...');
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '0';
    final userRole = prefs.getString('userRole');
    
    debugPrint('_refreshProfileData - userId: $userId, userRole: $userRole');
    
    // Check if user is logged in - if userId exists and is not '0', consider logged in
    bool isLoggedIn = false;
    if (userId.isNotEmpty && userId != '0') {
      isLoggedIn = true;
    }
    
    debugPrint('_refreshProfileData - isLoggedIn: $isLoggedIn');
    
    if (mounted) {
      // Update state
      setState(() {
        _userId = userId;
        _isLoggedIn = isLoggedIn;
      });
      
      // Always fetch user details if userId is valid (refresh data when coming to profile)
      // This ensures data is fresh every time user navigates to profile screen
      if (userId != '0' && userId.isNotEmpty) {
        debugPrint('Refreshing profile data for userId: $userId');
        await _fetchUserDetails();
      } else {
        debugPrint('Not refreshing - userId is invalid: $userId');
        setState(() {
          credential = null;
          isLoading = false;
        });
      }
    }
  }

  // Quick method to check and update login status without full reload
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '0';
    final userRole = prefs.getString('userRole');
    
    bool isLoggedIn = false;
    if (userId.isNotEmpty && 
        userId != '0' &&
        userRole != null &&
        (userRole == '1' || userRole == '2')) {
      isLoggedIn = true;
    }
    
    if (mounted) {
      // Update state if login status changed
      if (_isLoggedIn != isLoggedIn || _userId != userId) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _userId = userId;
        });
      }
      
      // If logged in and we don't have user data, fetch it
      if (isLoggedIn && credential == null && userId != '0' && !_isFetching) {
        await _fetchUserDetails();
      } else if (!isLoggedIn) {
        setState(() {
          credential = null;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '0';
    final userRole = prefs.getString('userRole');
    
    debugPrint('_loadUserId - userId: $userId, userRole: $userRole');
    
    // Check if user is logged in - if userId exists and is not '0', consider logged in
    // Role check is less strict - we'll fetch data if userId is valid
    bool isLoggedIn = false;
    if (userId.isNotEmpty && userId != '0') {
      // If role is specified, check it, otherwise just check userId
      if (userRole == null || userRole == '1' || userRole == '2') {
        isLoggedIn = true;
      } else {
        debugPrint('User role is $userRole, but still attempting to fetch profile data');
        // Still try to fetch if userId is valid
        isLoggedIn = true;
      }
    }
    
    debugPrint('_loadUserId - isLoggedIn: $isLoggedIn');
    
    if (mounted) {
      setState(() {
        _userId = userId;
        _isLoggedIn = isLoggedIn;
      });
      
      // Fetch user details if userId is valid (not '0' and not empty)
      if (userId != '0' && userId.isNotEmpty) {
        debugPrint('Calling _fetchUserDetails from _loadUserId');
        await _fetchUserDetails();
      } else {
        debugPrint('Not fetching user details - userId is invalid: $userId');
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // fetch user credentials
  Future<void> _fetchUserDetails() async {
    if (_userId.isEmpty || _userId == '0') {
      debugPrint('Cannot fetch user details: userId is empty or 0');
      if (mounted) {
        setState(() {
          isLoading = false;
          _isFetching = false;
        });
      }
      return;
    }
    
    // Prevent concurrent API calls
    if (_isFetching) {
      debugPrint('Already fetching user details, skipping...');
      return;
    }
    
    debugPrint('Fetching user details for userId: $_userId');
    
    if (mounted) {
      setState(() {
        isLoading = true;
        _isFetching = true;
      });
    }
    
    try {
      final url = 'https://nicknameinfo.net/api/auth/user/$_userId';
      debugPrint('API URL: $url');
      
      final response = await SecureHttpClient.get(
        url,
        timeout: const Duration(seconds: 15),
        context: context,
      );
      
      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('API Response Data: $data');
        
        if (data['success'] == true && data['data'] != null) {
          debugPrint('User details fetched successfully');
          debugPrint('Credential data: ${data['data']}');
          if (mounted) {
            setState(() {
              credential = data['data'];
              isLoading = false;
              _isFetching = false;
            });
            debugPrint('State updated with credential - firstName: ${credential?['firstName']}, email: ${credential?['email']}, phone: ${credential?['phone']}');
          }
        } else {
          // Handle API-specific errors
          debugPrint('API error - success: ${data['success']}, errors: ${data['errors']}');
          if (mounted) {
            setState(() {
              isLoading = false;
              _isFetching = false;
            });
          }
        }
      } else {
        // Handle HTTP status code errors
        debugPrint('Failed to load user data. Status code: ${response.statusCode}');
        if (mounted) {
          setState(() {
            isLoading = false;
            _isFetching = false;
          });
        }
      }
    } on TimeoutException {
      debugPrint('Request timeout while fetching user details');
      if (mounted) {
        setState(() {
          isLoading = false;
          _isFetching = false;
        });
      }
    } on SocketException {
      debugPrint('No internet connection');
      if (mounted) {
        setState(() {
          isLoading = false;
          _isFetching = false;
        });
      }
    } catch (e) {
      // Handle network or parsing errors
      debugPrint('An unexpected error occurred: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          _isFetching = false;
        });
      }
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
  // 3. Navigate to customer home screen and remove all other routes
  Navigator.of(context).pushNamedAndRemoveUntil(
    CustomerBottomNav.routeName,
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

  void _navigateToLogin() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AccountTypeSelector(),
      ),
    );
    
    // After login, reload data if user comes back to this screen
    if (mounted) {
      await _loadUserId();
    }
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
    // Ensure API is called when screen is visible and user is logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isLoggedIn && _userId != '0' && _userId.isNotEmpty && !_isFetching) {
        // Refresh data when screen becomes visible (for bottom nav scenarios)
        if (credential == null || isLoading) {
          _refreshProfileData();
        }
      }
    });
    
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
                                  icon: _isLoggedIn ? Icons.logout : Icons.login,
                                  iconColor: _isLoggedIn ? Colors.red : Colors.green,
                                  title: _isLoggedIn ? 'Logout' : 'Login',
                                  onTap: _isLoggedIn ? showLogoutOptions : _navigateToLogin,
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