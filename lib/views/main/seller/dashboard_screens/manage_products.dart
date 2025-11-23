import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../components/loading.dart';
import '../../../../constants/colors.dart';
import '../../../../helpers/product_api_service.dart';
import '../../product/details.dart';
import 'edit_product.dart';
import '../category.dart';
class ManageProductsScreen extends StatefulWidget {
  static const routeName = '/manage_products';

  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  String? _supplierId;
  Future<List<dynamic>>? _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadSupplierIdAndFetchProducts();
  }

  Future<void> _loadSupplierIdAndFetchProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _supplierId = prefs.getString('storeId'); // Assuming userId is the supplierId
      if (_supplierId != null) {
        _productsFuture = ProductApiService.getAllProductsBySupplierId(_supplierId!);
      }
    });
  }

  // remove product (this will need to be updated to use the API later)
  void removeProduct(String id) {
    // Implement API call to remove product
    setState(() {
      _productsFuture = ProductApiService.getAllProductsBySupplierId(_supplierId!); // Refresh products after deletion
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: litePrimary,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.grey,
        statusBarBrightness: Brightness.dark,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Manage Products',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10.0,
            vertical: 5,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height / 1.2,
            child: _productsFuture == null
                ? const Center(child: Text('No supplier ID found'))
                : FutureBuilder<List<dynamic>>(
                    future: _productsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Loading(
                            color: primaryColor,
                            kSize: 30,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('An error occurred: ${snapshot.error}'),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/sad.png',
                                width: 150,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'No data available!',
                                style: TextStyle(
                                  color: primaryColor,
                                ),
                              )
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          var item = snapshot.data![index];
                          return GestureDetector(
                            onTap: () {
                              if (item['product'] != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => DetailsScreen(product: item['product']),
                                  ),
                                );
                              }
                            },
                            child: Dismissible(
                              onDismissed: (direction) => removeProduct(item['id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                height: 115,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.red,
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete_forever,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              confirmDismiss: (direction) => showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Remove ${item['product']?['name']?.toString() ?? 'Product'}'),
                                  content: Text(
                                    'Are you sure you want to remove ${item['product']?['name']?.toString() ?? 'this product'} from your products?',
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
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
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              key: ValueKey(item['id']),
                              child: Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.only(
                                    left: 10,
                                    right: 10,
                                    top: 5,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: primaryColor,
                                    radius: 35,
                                    backgroundImage: item['product']?['photo'] != null && item['product']['photo'].toString().isNotEmpty
                                        ? NetworkImage(item['product']['photo'].toString())
                                        : null,
                                    child: item['product']?['photo'] == null || item['product']['photo'].toString().isEmpty
                                        ? const Icon(Icons.image, color: Colors.white)
                                        : null,
                                  ),
                                  title: Text(
                                    item['product']?['name']?.toString() ?? 'Unnamed Product',
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text('RS: ${item['product']?['price']?.toString() ?? '0'}'),
                                  trailing: IconButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => EditProduct(productData: item['product']),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.edit_note,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "addProduct",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProduct(productData: null),
                ),
              ).then((value) {
                if (value == true) {
                  _loadSupplierIdAndFetchProducts(); // Refresh products after adding a new one
                }
              });
            },
            backgroundColor: primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "addCategory",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryScreen(),
                ),
              );
            },
            backgroundColor: primaryColor,
            child: const Icon(Icons.category, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
