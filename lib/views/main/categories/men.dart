import 'package:flutter/material.dart';
import 'package:nickname_portal/helpers/category_service.dart';
import '../../../utilities/category_gridview.dart';

class MenCategories extends StatefulWidget {
  const MenCategories({super.key});

  @override
  State<MenCategories> createState() => _MenCategoriesState();
}

class _MenCategoriesState extends State<MenCategories> {
  List<String> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final fetchedCategories = await CategoryService.getAllCategories();
      setState(() {
        categories = fetchedCategories
            .where((category) => category['name'] == 'Men')
            .expand((category) =>
                (category['subcategories'] as List<dynamic>).map((sub) => sub['sub_name'] as String))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      // Handle error, e.g., show a snackbar
      setState(() {
        isLoading = false;
      });
      print('Error fetching categories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    var imageLocation = 'assets/images/sub_categories/men/';
    var category = 'Men';

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 10.0),
          child: Text(
            'Categories for men',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 10),
        isLoading
            ? const CircularProgressIndicator() // Show loading indicator
            : SizedBox(
                height: size.height * 0.73,
                child: CategoryGridView(
                  categories: categories,
                  category: category,
                  imageLocation: imageLocation,
                ),
              ),
      ],
    );
  }
}
