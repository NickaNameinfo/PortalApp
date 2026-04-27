import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../components/loading.dart';
import '../../../../constants/app_config.dart';
import '../../../../constants/colors.dart';
import 'package:nickname_portal/components/gradient_background.dart';
import '../../../../helpers/product_api_service.dart';
import '../../product/details.dart';
import 'edit_product.dart';
import 'scan_barcode_screen.dart';
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

  String _firstPhotoFromProductPhotos(dynamic productPhotos) {
    try {
      if (productPhotos is List && productPhotos.isNotEmpty) {
        final first = productPhotos.first;
        if (first is Map) {
          final v = first['imgUrl'] ?? first['url'] ?? first['imageUrl'];
          return v?.toString().trim() ?? '';
        }
        if (first is String) return first.trim();
      }
    } catch (_) {}
    return '';
  }

  String _resolveProductPhotoUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return "";
    final uri = Uri.tryParse(s);
    if (uri != null && uri.hasScheme) return s; // already absolute (http/https)
    final filename = s.split("/").where((p) => p.isNotEmpty).toList().last;
    return "${AppConfig.baseApi}/uploads/$filename";
  }

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
        elevation: 0,
        toolbarHeight: 48,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: brandHeaderGradient,
          ),
        ),
        title: const Text(
          'Manage Products',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScanBarcodeScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
            ),
            tooltip: 'Scan Barcode',
          ),
        ],
      ),
      body: Container(
        decoration: gradientBackgroundDecoration,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
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
                              'No products yet',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 110),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        var item = snapshot.data![index];
                        final product = item['product'] as Map<String, dynamic>?;
                        final photo = product?['photo']?.toString() ?? '';
                        final fallbackPhoto = _firstPhotoFromProductPhotos(product?['productphotos']);
                        final name = product?['name']?.toString() ?? 'Unnamed Product';
                        final price = product?['price']?.toString() ?? '0';
                        final photoUrl = _resolveProductPhotoUrl(photo.isNotEmpty ? photo : fallbackPhoto);
                        return GestureDetector(
                          onTap: () {
                            if (product != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => DetailsScreen(product: product),
                                ),
                              );
                            }
                          },
                          child: Dismissible(
                            onDismissed: (direction) => removeProduct(item['id'].toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              height: 92,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                color: Colors.red,
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 18),
                              child: const Icon(
                                Icons.delete_forever,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                            confirmDismiss: (direction) => showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Remove $name'),
                                content: Text(
                                  'Are you sure you want to remove $name from your products?',
                                ),
                                actions: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text(
                                      'Yes',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade300,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            key: ValueKey(item['id']),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                color: Colors.white.withOpacity(0.92),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.06),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 14,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      color: primaryColor.withOpacity(0.10),
                                      child: photoUrl.isNotEmpty
                                          ? Image.network(
                                              photoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.broken_image, color: primaryColor),
                                            )
                                          : const Icon(Icons.image, color: primaryColor),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'RS: $price',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black.withOpacity(0.55),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => EditProduct(productData: product),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.edit_note,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.category, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
