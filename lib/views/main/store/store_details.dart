import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:nickname_portal/components/gradient_background.dart';
import 'package:nickname_portal/components/nav_bar_container.dart';
import 'package:nickname_portal/utilities/url_launcher_utils.dart'; // Import the utils file
import 'package:nickname_portal/helpers/cart_api_helper.dart';
import 'package:nickname_portal/views/main/customer/new_product_details_screen.dart';
import 'package:nickname_portal/views/main/customer/cart.dart';
import 'package:nickname_portal/views/main/customer/order.dart';

// Assuming constants/colors.dart defines primaryColor or similar
// import '../../../constants/colors.dart';

class StoreDetails extends StatefulWidget {
  final int storeId;
  const StoreDetails({super.key, required this.storeId});

  @override
  State<StoreDetails> createState() => _StoreDetailsState();
}

class _StoreDetailsState extends State<StoreDetails> {
  Map<String, dynamic>? store;
  List<dynamic> products = [];
  bool isLoading = true;
  List<dynamic> allStores = [];
  int currentIndex = -1;

  // State for Cart
  Map<int, int> _cartQuantities = {}; 
  Set<int> _cartLoadingIds = {};
  late String _userId = ''; // Initialize with an empty string
  // The cart API endpoint for listing is 'https://nicknameinfo.net/api/cart/list/$_userId'

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId') ?? '0'; // Default to "0" or handle as needed
      _fetchStoreData(); // Call _fetchStoreData after _userId is loaded
    });
  }

  // NEW: Function to fetch existing cart quantities for the user
  Future<void> _fetchCartQuantities() async {
    final url = Uri.parse('https://nicknameinfo.net/api/cart/list/$_userId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] is List) {
          final List<dynamic> cartItems = responseData['data'];
          final Map<int, int> fetchedQuantities = {};

          for (var item in cartItems) {
            final int? productId = item['productId'] as int?;
            final int? quantity = item['qty'] as int?;

            if (productId != null && quantity != null && quantity > 0) {
              fetchedQuantities[productId] = quantity;
            }
          }

          if (mounted) {
            // Update the cart quantities state
            setState(() {
              _cartQuantities = fetchedQuantities;
            });
          }
        } else {
          debugPrint("Cart list API returned success: false or invalid data structure.");
        }
      } else {
        debugPrint("Failed to fetch cart list. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching cart quantities: $e");
    }
  }

  Future<void> _fetchStoreData() async {
    if (!isLoading) {
      setState(() {
        isLoading = true;
      });
    }
    try {
      final storeFuture = http.get(Uri.parse(
          'https://nicknameinfo.net/api/store/list/${widget.storeId}'));
      final productFuture = http.get(Uri.parse(
          'https://nicknameinfo.net/api/store/product/getAllProductById/${widget.storeId}'));
      final allStoresFuture = http.get(Uri.parse(
          'https://nicknameinfo.net/api/store/list'));

      final responses = await Future.wait([storeFuture, productFuture, allStoresFuture]);
      final storeResponse = responses[0];
      final productResponse = responses[1];
      final allStoresResponse = responses[2];

      if (storeResponse.statusCode == 200 &&
          productResponse.statusCode == 200 &&
          allStoresResponse.statusCode == 200) {
        final storeJson = json.decode(storeResponse.body);
        final productJson = json.decode(productResponse.body);
        final allStoresJson = json.decode(allStoresResponse.body);

        bool storeSuccess = storeJson['success'] ?? false;
        bool productSuccess = productJson['success'] ?? false;
        bool allStoresSuccess = allStoresJson['success'] ?? false;

        if (storeSuccess && productSuccess && allStoresSuccess) {
           List<dynamic> fetchedStores = (allStoresJson['data'] as List<dynamic>?) ?? [];
           int foundIndex = fetchedStores.indexWhere((s) => s['id'] == widget.storeId);
           
           // AWAITING THE CART FETCH HERE to ensure _cartQuantities is populated
           await _fetchCartQuantities();

           if (mounted) {
             setState(() {
               store = storeJson['data'];
               products = (productJson['data'] as List<dynamic>?) ?? [];
               allStores = fetchedStores;
               currentIndex = foundIndex;
               isLoading = false;
             });
           }
        } else {
           String errorMsg = '';
           if (!storeSuccess) errorMsg += 'Store API error. ';
           if (!productSuccess) errorMsg += 'Product API error. ';
           if (!allStoresSuccess) errorMsg += 'All Stores API error.';
           throw Exception(errorMsg.trim());
        }
      } else {
        String errorMsg = '';
        if (storeResponse.statusCode != 200) errorMsg += 'Store fetch failed: ${storeResponse.statusCode}. ';
        if (productResponse.statusCode != 200) errorMsg += 'Product fetch failed: ${productResponse.statusCode}.';
        if (allStoresResponse.statusCode != 200) errorMsg += 'All Stores fetch failed: ${allStoresResponse.statusCode}.';
        throw Exception(errorMsg.trim());
      }
    } catch (e) {
      if (mounted) {
        setState(() { isLoading = false; });
        debugPrint("Error fetching store data: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading store details: ${e.toString()}')));
      }
    }
  }

  void _navigateToPreviousStore() {
    if (currentIndex > 0) {
      final previousStoreId = allStores[currentIndex - 1]['id'];
      if (previousStoreId != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => StoreDetails(storeId: previousStoreId as int)));
      }
    } else { debugPrint("Already at the first store."); }
  }

  void _navigateToNextStore() {
    if (currentIndex != -1 && currentIndex < allStores.length - 1) {
      final nextStoreId = allStores[currentIndex + 1]['id'];
      if (nextStoreId != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => StoreDetails(storeId: nextStoreId as int)));
      }
    } else { debugPrint("Already at the last store."); }
  }

  Future<void> _updateCart(int productId, int newQuantity, Map<String, dynamic> productData, {required bool isAdd}) async {
    if (!mounted || _cartLoadingIds.contains(productId)) return;

    setState(() { _cartLoadingIds.add(productId); });

    try {
      final responseData = await updateCart(
        productId: productId,
        newQuantity: newQuantity,
        productData: productData,
        isAdd: isAdd,
        userId: _userId,
        storeId: widget.storeId.toString(),
      );

      if (!mounted) return;

      if (responseData['success'] == true) {
        setState(() {
          if (newQuantity == 0) {
            _cartQuantities.remove(productId);
          } else {
            _cartQuantities[productId] = newQuantity;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${productData['name'] ?? 'Item'} quantity updated to $newQuantity')),
        );
      } else {
        throw Exception(responseData['message'] ?? 'Failed to update cart.');
      }
    } catch (e) {
      debugPrint("Error updating cart: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update cart: ${e.toString()}')));
      }
    } finally {
      if (mounted) { setState(() { _cartLoadingIds.remove(productId); }); }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final int? productIdRaw = product['id'] as int?;
    if (productIdRaw == null) {
       debugPrint("Error: Product ID is null in _addToCart");
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add item: Invalid product data.')));
       return;
    }
    final int productId = productIdRaw;
    final int currentQuantity = _cartQuantities[productId] ?? 0;
    final int newQuantity = currentQuantity + 1;

    await _updateCart(productId, newQuantity, product, isAdd: true);
  }

  Future<void> _incrementQuantity(int productId) async {
     final productWrapper = products.firstWhere((p) => (p['product'] as Map?)?['id'] == productId, orElse: () => null);
     final productData = productWrapper?['product'] as Map<String, dynamic>?;

     if(productData != null) {
       final int currentQuantity = _cartQuantities[productId] ?? 0;
       final int newQuantity = currentQuantity + 1;
       await _updateCart(productId, newQuantity, productData, isAdd: false);
     } else {
        debugPrint("Could not find product data to increment quantity for ID: $productId");
     }
  }

  Future<void> _decrementQuantity(int productId) async {
     final int currentQuantity = _cartQuantities[productId] ?? 0;
     if (currentQuantity <= 0) return;
     final int newQuantity = currentQuantity - 1;

     final productWrapper = products.firstWhere((p) => (p['product'] as Map?)?['id'] == productId, orElse: () => null);
     final productData = productWrapper?['product'] as Map<String, dynamic>?;
     
     if (productData == null) {
       debugPrint("Could not find product data to decrement quantity for ID: $productId");
       return;
     }
     await _updateCart(productId, newQuantity, productData, isAdd: false);
  }

  Widget buildStoreHeader() {
    final String openTime = store?['openTime'] ?? 'N/A';
    final String closeTime = store?['closeTime'] ?? 'N/A';
    final String openCloseTime = (openTime != 'N/A' && closeTime != 'N/A') ? 'Open : $openTime - $closeTime' : 'Timings not available';
    final String? storePhone = store?['phone'];
    final String? storeWebsite = store?['website'];
    final String storeName = store?['storename'] ?? 'This Store';
    final String? location = store?['location'] ?? store?['storeaddress'];
    final String shareText = 'Check out $storeName! ${storeWebsite != null ? storeWebsite : ""}';
    final bool canGoBack = currentIndex > 0;
    final bool canGoForward = currentIndex != -1 && currentIndex < allStores.length - 1;

    return NavBarContainer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network( store?['storeImage'] ?? 'https://via.placeholder.com/100x100.png?text=Store', width: 100, height: 100, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Icon(Icons.storefront, color: Colors.grey[400], size: 40)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(storeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [ const Icon(Icons.star, color: Colors.amber, size: 16), const SizedBox(width: 4), Text(store?['rating']?.toString() ?? "4.2", style: const TextStyle(color: Colors.black87, fontSize: 14))]),
                      const SizedBox(height: 4),
                      Text(openCloseTime, style: const TextStyle(color: Colors.black87)),
                      Text("Products : ${products.length}", style: const TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                GestureDetector( onTap: () { if (storePhone != null) launchWhatsApp(storePhone); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp number not available.'))); }, child: _buildCircleIcon(FontAwesomeIcons.whatsapp, Colors.green)),
                GestureDetector( onTap: () { if (storePhone != null) makePhoneCall(storePhone); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not available.'))); }, child: _buildCircleIcon(Icons.phone, Colors.blue)),
                GestureDetector( onTap: () { if (location != null && location.isNotEmpty) openMap(location); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available.'))); }, child: _buildCircleIcon(Icons.location_on, Colors.purple)),
                GestureDetector( onTap: () { if (storeWebsite != null && storeWebsite.isNotEmpty) launchWebsite(storeWebsite); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Website not available.'))); }, child: _buildCircleIcon(Icons.language, Colors.red)),
                GestureDetector( onTap: () { shareContent(shareText, subject: 'Check out this store!'); }, child: _buildCircleIcon(Icons.share, Colors.teal)),
              ],
            ),
            const SizedBox(height: 16),
            NavBarContainer(
              child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _buildBottomButton(Icons.remove),
                  GestureDetector( onTap: canGoBack ? _navigateToPreviousStore : null, child: _buildBottomButton(Icons.arrow_back, color: canGoBack ? Colors.black87 : Colors.grey[400])),
                  GestureDetector( onTap: canGoForward ? _navigateToNextStore : null, child: _buildBottomButton(Icons.arrow_forward, color: canGoForward ? Colors.blue : Colors.grey[400])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildCircleIcon(IconData icon, Color color) {
  return Container(width: 42, height: 42, decoration: BoxDecoration( color: color.withOpacity(0.15), shape: BoxShape.circle, boxShadow: [BoxShadow( color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]), child: Icon(icon, color: color, size: 20));
}

Widget _buildBottomButton(IconData icon, {Color? color}) {
 return Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]), child: Icon(icon, color: color ?? Colors.black87, size: 20));
}

Widget _buildQuantitySelector({ required int quantity, required VoidCallback onIncrement, required VoidCallback onDecrement}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow( color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))], border: Border.all(color: Colors.grey.shade300, width: 1)),
    child: Row( mainAxisSize: MainAxisSize.min, children: [
        GestureDetector( onTap: onDecrement, child: Icon( Icons.remove, size: 20, color: quantity > 0 ? Colors.black54 : Colors.grey[300])),
        const SizedBox(width: 10),
        Text(quantity.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        GestureDetector( onTap: onIncrement, child: const Icon(Icons.add, size: 20, color: Colors.black54)),
      ],
    ),
  );
}

Widget buildProductCard(Map<String, dynamic> item) {
    // --- Safe Access ---
    if (item['product'] == null || item['product'] is! Map) {
      return Padding( padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Error: Invalid product data', style: TextStyle(color: Colors.red[700])));
    }
    final product = item['product'] as Map<String, dynamic>;
    final int? productIdRaw = product['id'] as int?; // Product ID can be null
    if (productIdRaw == null) {
       return Padding( padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Error: Missing product ID', style: TextStyle(color: Colors.red[700])));
    }
    final int productId = productIdRaw;

    // Use ?? to provide defaults for potentially null/missing fields
    final bool available = product['isEnableEcommerce']?.toString() == '1';
    final String? photoUrl = product['photo'] as String?;
    final String productName = product['name']?.toString() ?? 'Unnamed Product';
    final String priceString = product['price']?.toString() ?? 'N/A';
    final String totalString = product['total']?.toString() ?? 'N/A';
    final String unitSize = product['unitSize']?.toString() ?? '';
    final String stockQty = product['qty']?.toString() ?? '0';
    final String priceDisplay = unitSize.isNotEmpty ? "$totalString ($stockQty)" : totalString;
    final String discount = product['discountPer']?.toString() ?? '0';
    final double discountValue = double.tryParse(discount) ?? 0.0;

    // Cart State: Reads the pre-loaded quantity or defaults to 0
    final int currentQuantity = _cartQuantities[productId] ?? 0;
    final bool isInCart = currentQuantity > 0;
    final bool isCartLoading = _cartLoadingIds.contains(productId);

    return Container( /* ... Card Decoration ... */
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [ BoxShadow( color: Colors.grey.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack( fit: StackFit.passthrough, children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewProductDetailsScreen(product: product),
                    ),
                  );
                },
                child: ClipRRect( /* ... Image ... */
                  borderRadius: const BorderRadius.only( topRight: Radius.circular(16), topLeft: Radius.circular(16)),
                  child: Image.network( photoUrl ?? 'https://via.placeholder.com/300x200.png?text=Product', height: 160, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container( height: 160, width: double.infinity, decoration: BoxDecoration( color: Colors.grey[200], borderRadius: const BorderRadius.only( topRight: Radius.circular(16), topLeft: Radius.circular(16))), child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 50)),
                  ),
                ),
              ),
              if (discountValue > 0) Positioned( /* ... Discount Badge ... */ top: 10, left: 10, child: Container( decoration: BoxDecoration( color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text( "$discount %", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
              if (!available) Positioned( /* ... Not Available Badge ... */ bottom: 8, right: 8, child: Container( decoration: BoxDecoration( color: Colors.redAccent.withOpacity(0.9), borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: const Text( "Online Order Not Available", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)))),
          ]),
          Padding( /* ... Product Details ... */
            padding: const EdgeInsets.all(12),
            child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row( /* ... Price and Stock ... */ crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text("Rs : $priceDisplay", style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
                     const SizedBox(width: 8),
                    if (priceString != totalString) Text("Rs : $discount", style: TextStyle(color: Colors.grey[600], fontSize: 13, decoration: TextDecoration.lineThrough)),
                    const Spacer(),
                    Text( int.tryParse(stockQty) == null || int.parse(stockQty) <= 0 ? "Coming soon" : "$stockQty Stocks", style: TextStyle( color: int.tryParse(stockQty) == null || int.parse(stockQty) <= 0 ? Colors.orange[700] : Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row( /* ... Payment/Order Info & Quantity/Add Button ... */ mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                     Column( crossAxisAlignment: CrossAxisAlignment.start, children: const [ Text("Per order", style: TextStyle(fontSize: 12, color: Colors.black54)), Text("Online payment", style: TextStyle(fontSize: 12, color: Colors.black54)), Text("Cash on delivery", style: TextStyle(fontSize: 12, color: Colors.black54))]),
                     if(available)
                        isCartLoading
                          ? const SizedBox( height: 30, width: 30, child: Padding( padding: EdgeInsets.all(4.0), child: CircularProgressIndicator(strokeWidth: 2)))
                          : isInCart
                              ? _buildQuantitySelector( quantity: currentQuantity, onIncrement: () => _incrementQuantity(productId), onDecrement: () => _decrementQuantity(productId))
                              : GestureDetector( onTap: () => _addToCart(product), child: const Icon(Icons.add_shopping_cart, color: Colors.green, size: 28))
                  ]
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CartScreen(),
                          ),
                        );
                      },
                     child: Icon(
                        Icons.favorite_border,
                        color: Colors.pink[300] ?? Colors.pink, // <-- Fix applied here
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewProductDetailsScreen(product: product),
                          ),
                        );
                      },
                      child: const Icon(Icons.remove_red_eye_outlined, color: Colors.black54),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CartScreen(),
                          ),
                        );
                      },
                      child : Stack(
                       clipBehavior: Clip.none,
                       children: [
                         const Icon(Icons.shopping_bag_outlined, color: Colors.purple),
                         // Only show the badge if quantity > 0
                         if (currentQuantity > 0)
                           Positioned(
                             top: -4,
                             right: -6,
                             child: Container(
                               padding: const EdgeInsets.all(3),
                               decoration: const BoxDecoration(
                                 color: Colors.red,
                                 shape: BoxShape.circle,
                               ),
                               constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                               child: Text(
                                 currentQuantity.toString(), // Use the variable
                                 style: const TextStyle(color: Colors.white, fontSize: 8),
                                 textAlign: TextAlign.center,
                               ),
                             ),
                           ),
                       ],
                     ),
                    ),
                   GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerOrderScreen(),
                          ),
                        );
                      },
                      child: const Icon(Icons.receipt_long, color: Colors.green),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
     return Container(
      decoration: gradientBackgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Store Details",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
            : store == null && !isLoading
              ? Center(
                  child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.error_outline, color: Colors.red[300], size: 60),
                      const SizedBox(height: 16),
                      const Text('Could not load store details.', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      ElevatedButton.icon( icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _fetchStoreData)
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchStoreData,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8),
                    children: [
                      buildStoreHeader(),
                      const SizedBox(height: 8),
                      if (products.isNotEmpty)
                        ...products.map((p) => buildProductCard(p)).toList()
                      else
                         const Padding(
                           padding: EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                           child: Center(
                               child: Text("No products found for this store.", style: TextStyle(fontSize: 16, color: Colors.black54), textAlign: TextAlign.center)),
                         ),
                      const SizedBox(height: 80), // Bottom padding
                    ],
                  ),
                ),
      ),
    );
  }
}