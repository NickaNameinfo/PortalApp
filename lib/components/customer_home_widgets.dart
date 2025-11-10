import 'package:flutter/material.dart';
import 'package:nickname_portal/constants/colors.dart';
import 'package:nickname_portal/components/loading.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 

// ASSUMED: These imports point to your other files
import 'package:nickname_portal/components/nav_bar_container.dart';
import 'package:nickname_portal/providers/category_filter_data.dart'; // The CategoryFilterData class

// --- NEW ---
// Import the new screen you just created.
// (You may need to adjust the path)
import 'package:nickname_portal/views/main/customer/product_screen.dart';
import 'package:nickname_portal/views/auth/account_type_selector.dart';
import 'package:nickname_portal/views/main/seller/dashboard_screens/orders.dart';
import 'package:nickname_portal/views/auth/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ... (ProfileButton, HomeTopBar remain unchanged) ...

class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});


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

  @override
  Widget build(BuildContext context) {
    // We wrap the original Container in a PopupMenuButton
    return PopupMenuButton<String>(
      // This offset pushes the popup down, away from the button
      offset: const Offset(0, 60), 
      // This styles the popup card to have rounded corners
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      elevation: 5,
      color: Colors.white,
      
      // This builder creates the list of items
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        _buildPopupMenuItem(
          icon: Icons.home_outlined,
          text: 'Orders',
          value: 'orders',
          // badgeCount: 5,
        ),
        // _buildPopupMenuItem(
        //   icon: Icons.home_outlined,
        //   text: 'Cart',
        //   value: 'cart',
        //   badgeCount: 2,
        // ),
        // _buildPopupMenuItem(
        //   icon: Icons.home_outlined,
        //   text: 'Profile',
        //   value: 'profile',
        // ),
        _buildPopupMenuItem(
          icon: Icons.home_outlined,
          text: 'Log Out',
          value: 'logout',
        ),
      ],

      // This is called when a user taps an item
      onSelected: (String value) {
        switch (value) {
          case 'orders':
            Navigator.pushNamed(context, OrdersScreen.routeName);
            break;
          case 'cart':
            Navigator.pushNamed(context, '/cart');
            break;
          // case 'profile':
          //   Navigator.pushNamed(context, '/profile');
          //   break;
          // case 'logout':
          //   _logout(context);
          //   break;
        }
      },

      // This is your original button UI. It now acts as the
      // 'child' that triggers the popup menu.
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.person, color: Colors.white),
      ),
    );
  }

  // Helper method to build the custom menu items from your screenshot
  PopupMenuItem<String> _buildPopupMenuItem({
    required IconData icon,
    required String text,
    required String value,
    int? badgeCount,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          // Icon from your screenshot
          Icon(icon, color: Colors.green.shade400),
          const SizedBox(width: 15),
          
          // Text
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black87)),
          ),
          
          // Badge (only shows if badgeCount is not null)
          if (badgeCount != null)
            Text(
              badgeCount.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
        ],
      ),
    );
  }
}

class HomeTopBar extends StatelessWidget {
  final TextEditingController searchController;
  final Function(String) onSearchSubmitted;

  const HomeTopBar({
    super.key,
    required this.searchController,
    required this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return NavBarContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const ProfileButton(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSearchSubmitted,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    icon: const Icon(Icons.search, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    // Use ValueListenableBuilder to automatically update the suffixIcon visibility
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: searchController,
                        builder: (context, value, child) {
                          if (value.text.isNotEmpty) {
                            return IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                searchController.clear();
                                onSearchSubmitted(''); // Triggers search with empty string
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                  ),
                ),
              ),
            ),
            
            GestureDetector(
              onTap: () {
                // This command finds the nearest Scaffold and opens its endDrawer
                Scaffold.of(context).openEndDrawer();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.tune, size: 20, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MODIFIED ---
// Added GestureDetector to the "Products" button
// class ButtonsGrid extends StatelessWidget {
//   const ButtonsGrid({super.key});
  
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             GridButton(Icons.store, 'Shop', isSelected: true),
//             const SizedBox(width: 15),
            
//             // --- THIS IS THE CHANGE ---
//             // Wrap the button in a GestureDetector to make it tappable
//             GestureDetector(
//               onTap: () => Navigator.of(context).push(
//                 MaterialPageRoute(builder: (context) => const ProductScreen())
//               ),
//               child: GridButton(Icons.local_shipping, 'Products')
//             ),
//             // --- END OF CHANGE ---
            
//             const SizedBox(width: 15),
//             GridButton(Icons.map, 'Vendor'),
//           ],
//         ),
//       ],
//     );
//   }
// }

// class GridButton extends StatelessWidget {
//   // ... (No changes here) ...
//   final IconData icon;
//   final String label;
//   final bool isSelected;
//   // ... build implementation ...
//   const GridButton(this.icon, this.label, {super.key, this.isSelected = false});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 100,
//       height: 70,
//       decoration: BoxDecoration(
//         color: isSelected ? const Color(0xFF6A5ACD) : Colors.white,
//         borderRadius: BorderRadius.circular(15),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.2),
//             spreadRadius: 2,
//             blurRadius: 5,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             icon,
//             color: isSelected ? Colors.white : const Color(0xFF6A5ACD), 
//           ),
//           const SizedBox(height: 5),
//           Text(
//             label,
//             style: TextStyle(
//               color: isSelected ? Colors.white : Colors.black,
//               fontSize: 12,
//               fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


class CategoryTab extends StatelessWidget {
  // ... (No changes here) ...
  final Map<String, dynamic> category;

  const CategoryTab({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<CategoryFilterData, Set<int>>(
      selector: (_, data) => data.selectedCategoryIds ?? <int>{},
      builder: (context, selectedFilterIds, child) {
        final categoryId = category['id'] as int?;
        
        final isSelected = selectedFilterIds.contains(categoryId); 
        
        final text = category['name'] as String? ?? 'N/A';

        return GestureDetector(
          onTap: () {
            Provider.of<CategoryFilterData>(context, listen: false).setCategory(categoryId);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF6A5ACD) : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: isSelected ? null : Border.all(color: Colors.grey.shade300),
              boxShadow: isSelected
                  ? const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))]
                  : null,
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class CategoriesWidget extends StatelessWidget {
  // ... (No changes here) ...
  final Future<List<dynamic>> categoriesFuture;

  const CategoriesWidget({
    super.key,
    required this.categoriesFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Loading(kSize: 30, color: Color(0xFF6A5ACD)));
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No categories available.'));
        }

        List<dynamic> apiCategories = snapshot.data!;

        List<dynamic> categories = [
          {'id': null, 'name': 'All'},
          ...apiCategories
        ];

        return SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index] as Map<String, dynamic>;
                return CategoryTab(
                  category: category,
                );
              },
            ),
          ),
        );
      },
    );
  }
}


class HomeFilterDrawer extends StatelessWidget {
  // ... (No changes here) ...
  const HomeFilterDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    const Color drawerBackgroundColor = Color(0xFFF2F0FF); 

    return Consumer<CategoryFilterData>(
      builder: (context, filterData, child) {
        
        final selectedPaymentMode = filterData.selectedPaymentMode;
        
        final selectedCategoryIds = filterData.selectedCategoryIds ?? <int>{};
        final isHospitalActive = selectedCategoryIds.contains(20);
        final isHotelActive = selectedCategoryIds.contains(21);
        
        return Drawer(
          backgroundColor: drawerBackgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nickname Infotech',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black54),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
        
                    _buildDrawerButton(
                      text: 'For Me',
                      onTap: () {},
                      comingSoon: true,
                    ),
                    const SizedBox(height: 10),
                    _buildDrawerButton(
                      text: 'Other For You',
                      onTap: () {},
                      comingSoon: true,
                    ),
                    const SizedBox(height: 10),
                    _buildDrawerButton(
                      text: 'Within 5Km',
                      onTap: () {},
                      comingSoon: true,
                    ),
                    const SizedBox(height: 20),
        
                    const CategoriesExpansionFilter(),
    
                    const SizedBox(height: 10),
        
                    _buildFilterOption(
                      text: 'Pre Booking', 
                      onTap: () {
                        filterData.setPaymentMode(selectedPaymentMode == 1 ? null : 1);
                      },
                      isActive: selectedPaymentMode == 1,
                    ),
                    const SizedBox(height: 10),
                    
                    _buildFilterOption(
                      text: 'Online Payment', 
                      onTap: () {
                        filterData.setPaymentMode(selectedPaymentMode == 2 ? null : 2);
                      },
                      isActive: selectedPaymentMode == 2,
                    ),
                    const SizedBox(height: 10),
                    
                    _buildFilterOption(
                      text: 'Cash on Delivery', 
                      onTap: () {
                        filterData.setPaymentMode(selectedPaymentMode == 3 ? null : 3);
                      },
                      isActive: selectedPaymentMode == 3,
                    ),
                    const SizedBox(height: 10),
                    
                    _buildFilterOption(text: 'Open Shop', onTap: () {}),
                    const SizedBox(height: 10),
                    
                    _buildFilterOption(
                      text: 'Hospitals', 
                      onTap: () {
                        filterData.setCategory(isHospitalActive ? null : 20);
                      },
                      isActive: isHospitalActive,
                    ),
                    const SizedBox(height: 10),

                    _buildFilterOption(
                      text: 'Hotels', 
                      onTap: () {
                        filterData.setCategory(isHotelActive ? null : 21);
                      },
                      isActive: isHotelActive,
                    ),
                    const SizedBox(height: 20), 
                  ],
                ),
              ),
              
              _buildFooter(),
            ],
          ),
        ),
        );
      }
    );
  }

  Widget _buildDrawerButton({
    required String text,
    required VoidCallback onTap,
    bool comingSoon = false,
    bool isActive = false,
    Widget? trailing,
  }) {
    // ... (No changes here) ...
    final Color bgColor = isActive 
      ? const Color(0xFF5C6BC0) // Active blue/purple
      : const Color(0xFFE6E6E6); // Disabled grey
      
    final Color fgColor = isActive 
      ? Colors.white 
      : Colors.black54;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: comingSoon ? null : onTap, // Disable tap if coming soon
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                text, 
                style: TextStyle(
                  color: fgColor, 
                  fontSize: 16, 
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500
                )
              ),
              if (comingSoon)
                const Text(
                  'coming soon', 
                  style: TextStyle(color: Colors.grey, fontSize: 12)
                )
              else if (trailing != null)
                trailing,
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilterOption({
    required String text,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    // ... (No changes here) ...
    return Material(
      color: isActive ? const Color(0xFF5C6BC0) : Colors.white, 
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            text, 
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black87, 
              fontSize: 16, 
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            )
          ),
        ),
      ),
    );
  }
  
  Widget _buildFooter() {
    // ... (No changes here) ...
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), // Add bottom padding for safety area
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'nic', 
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 16
                )
              )
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'nicknameportal', 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16
                )
              ),
              Text(
                'Your Details', 
                style: TextStyle(color: Colors.black54, fontSize: 14)
              ),
            ],
          )
        ],
      ),
    );
  }
}


class CategoriesExpansionFilter extends StatefulWidget {
  // ... (No changes here) ...
  const CategoriesExpansionFilter({super.key});

  @override
  State<CategoriesExpansionFilter> createState() => _CategoriesExpansionFilterState();
}

class _CategoriesExpansionFilterState extends State<CategoriesExpansionFilter> {
  
  late Future<List<dynamic>> _categoriesFuture;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchCategoriesFromApi();
  }

  Future<List<dynamic>> _fetchCategoriesFromApi() async {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryFilterData>(
      builder: (context, filterData, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ExpansionTile(
            backgroundColor: const Color(0xFF5C6BC0), 
            collapsedBackgroundColor: const Color(0xFF5C6BC0), 
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            
            trailing: Icon(
              _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              color: Colors.white,
            ),
            onExpansionChanged: (bool expanded) {
              setState(() {
                _isExpanded = expanded;
              });
            },
            
            title: const Text(
              'Categories',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold
              ),
            ),
            
            children: [
              FutureBuilder<List<dynamic>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: Colors.white),
                    ));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                    ));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No categories found', style: const TextStyle(color: Colors.white)),
                    ));
                  }

                  final categories = snapshot.data!;
                  
                  return Container(
                    color: const Color(0xFF5C6BC0), 
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.3,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index] as Map<String, dynamic>;
                        final int categoryId = category['id'];
                        final String categoryName = category['name'] ?? 'N/A';
                        
                        final bool isSelected = 
                            (filterData.selectedCategoryIds ?? <int>{})
                                .contains(categoryId);

                        return CheckboxListTile(
                          title: Text(categoryName, style: const TextStyle(color: Colors.white)),
                          value: isSelected,
                          onChanged: (bool? value) {
                            filterData.toggleCategory(categoryId);
                          },
                          activeColor: Colors.white, 
                          checkColor: const Color(0xFF5C6BC0),
                          
                          secondary: const Icon(Icons.circle, color: Color(0xFFFBC02D), size: 10), 
                          
                          controlAffinity: ListTileControlAffinity.trailing, 
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}