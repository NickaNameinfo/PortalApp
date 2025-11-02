import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../models/category.dart';
import '../categories/children.dart';
import '../categories/men.dart';
import '../categories/other.dart';
import '../categories/sneakers.dart';
import '../categories/women.dart';
import 'package:nickname_portal/views/main/seller/add_category_screen.dart';
import 'package:nickname_portal/models/category_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('https://nicknameinfo.net/api/category/getAllCategory'));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true && decodedData['data'] != null) {
          setState(() {
            _categories = (decodedData['data'] as List)
                .map((e) => Category.fromJson(e))
                .toList();
            _isLoading = false;
          });
        } else {
          debugPrint('Category API returned success: false or missing data.');
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        debugPrint('Category API failed with status: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Categories',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => AddCategoryScreen())).then((_) => _fetchCategories());
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return CategoryItem(
                  category: category,
                );
              },
            ),
    );
  }
}

class CategoryItem extends StatelessWidget {
  final Category category;

  const CategoryItem({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // const Icon(Icons.category, size: 40.0),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // if (category.subcategories.isNotEmpty)
                  //   Text(
                  //     'Subcategories: ${category.subcategories.length}',
                  //     style: const TextStyle(
                  //       fontSize: 14,
                  //       color: Colors.grey,
                  //     ),
                  //   ),
                ],
              ),
            ),
            // const Icon(Icons.arrow_forward_ios, size: 16.0, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
