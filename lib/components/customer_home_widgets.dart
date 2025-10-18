import 'package:flutter/material.dart';
// Note: multivemdor_shop/models/category.dart is not used since we use Map<String, dynamic>
// import 'package:multivendor_shop/models/category.dart'; 
import 'package:multivendor_shop/constants/colors.dart'; 
import 'package:multivendor_shop/components/loading.dart'; 
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

// ASSUMED: These imports point to your other files
import 'package:multivendor_shop/components/nav_bar_container.dart';
import 'package:multivendor_shop/providers/category_filter_data.dart'; // The CategoryFilterData class


// --- Top Bar Widgets (Omitted for brevity, assumed correct) ---

class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});
  // ... build implementation ...
  @override
  Widget build(BuildContext context) {
    return Container(
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

  // ... build implementation (omitted) ...
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
            Container(
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
          ],
        ),
      ),
    );
  }
}

class ButtonsGrid extends StatelessWidget {
  const ButtonsGrid({super.key});
  // ... build implementation ...
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GridButton(Icons.store, 'Shop', isSelected: true),
            const SizedBox(width: 15),
            GridButton(Icons.local_shipping, 'Products'),
            const SizedBox(width: 15),
            GridButton(Icons.map, 'Vendor'),
          ],
        ),
      ],
    );
  }
}

class GridButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  // ... build implementation ...
  const GridButton(this.icon, this.label, {super.key, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 70,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF6A5ACD) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : const Color(0xFF6A5ACD), 
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryTab extends StatelessWidget {
  final Map<String, dynamic> category;

  const CategoryTab({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    // Selector rebuilds only when selectedCategoryId changes
    return Selector<CategoryFilterData, int?>(
      selector: (_, data) => data.selectedCategoryId,
      builder: (context, selectedFilterId, child) {
        final categoryId = category['id'] as int?;
        final isSelected = selectedFilterId == categoryId;
        final text = category['name'] as String? ?? 'N/A';

        return GestureDetector(
          onTap: () {
            // Use Provider.of with listen: false to dispatch the event
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
  // FIX: Change type back to List<dynamic> for simpler consumption in the common widget
  // The home.dart file is responsible for correctly returning the data.
  final Future<List<dynamic>> categoriesFuture; 

  const CategoriesWidget({
    super.key,
    required this.categoriesFuture,
  });

  @override
  Widget build(BuildContext context) {
    // FIX: Match the FutureBuilder type parameter to the expected future type.
    return FutureBuilder<List<dynamic>>( // Changed to List<dynamic>
      future: categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Loading(kSize: 30, color: Color(0xFF6A5ACD))); 
        } else if (snapshot.hasError) {
          // This will show the error message.
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No categories available.'));
        }

        // Data is now List<dynamic>, where each element is Map<String, dynamic>
        List<dynamic> apiCategories = snapshot.data!;

        // Prepend the "All" category at the list start
        // FIX: Ensure 'categories' is List<dynamic> for successful spread operation.
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
                // Now we cast the individual element before passing it to CategoryTab
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