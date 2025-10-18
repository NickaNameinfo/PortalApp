import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:multivendor_shop/components/gradient_background.dart';
import 'package:multivendor_shop/components/nav_bar_container.dart';
import 'package:multivendor_shop/utilities/url_launcher_utils.dart'; // Import the utils file

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

  // --- NEW ---
  // State variables for navigation
  List<dynamic> allStores = []; // To hold the full list of stores
  int currentIndex = -1; // Index of the current store in the list

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  Future<void> _fetchStoreData() async {
    if (!isLoading) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      // Create futures without awaiting
      final storeFuture = http.get(Uri.parse(
          'https://nicknameinfo.net/api/store/list/${widget.storeId}'));
      final productFuture = http.get(Uri.parse(
          'https://nicknameinfo.net/api/store/product/getAllProductById/${widget.storeId}'));
      // --- NEW ---
      // Fetch the full store list in parallel
      final allStoresFuture = http.get(Uri.parse(
          'https://nicknameinfo.net/api/store/list'));


      // Run in parallel
      final responses = await Future.wait([
        storeFuture,
        productFuture,
        allStoresFuture, // <-- Add the new future here
      ]);

      final storeResponse = responses[0];
      final productResponse = responses[1];
      final allStoresResponse = responses[2]; // <-- Get the response

      // Check status codes
      if (storeResponse.statusCode == 200 &&
          productResponse.statusCode == 200 &&
          allStoresResponse.statusCode == 200 // <-- Check the new response
          ) {
        final storeJson = json.decode(storeResponse.body);
        final productJson = json.decode(productResponse.body);
        final allStoresJson = json.decode(allStoresResponse.body); // <-- Decode

        // Check API success flags
        bool storeSuccess = storeJson['success'] ?? false;
        bool productSuccess = productJson['success'] ?? false;
        bool allStoresSuccess = allStoresJson['success'] ?? false; // <-- Check

        if (storeSuccess && productSuccess && allStoresSuccess) { // <-- Check all
           // --- NEW ---
           // Find the index of the current store
           List<dynamic> fetchedStores = (allStoresJson['data'] as List<dynamic>?) ?? [];
           int foundIndex = fetchedStores.indexWhere((s) => s['id'] == widget.storeId);

           setState(() {
             store = storeJson['data'];
             products = (productJson['data'] as List<dynamic>?) ?? [];
             allStores = fetchedStores; // <-- Store the full list
             currentIndex = foundIndex; // <-- Store the index
             isLoading = false;
           });
        } else {
           // Handle API errors
           String errorMsg = '';
           if (!storeSuccess) errorMsg += 'Store API error. ';
           if (!productSuccess) errorMsg += 'Product API error. ';
           if (!allStoresSuccess) errorMsg += 'All Stores API error.'; // <-- Add error
           throw Exception(errorMsg.trim());
        }
      } else {
        // Handle HTTP errors
        String errorMsg = '';
        if (storeResponse.statusCode != 200) {
           errorMsg += 'Store fetch failed: ${storeResponse.statusCode}. ';
        }
        if (productResponse.statusCode != 200) {
           errorMsg += 'Product fetch failed: ${productResponse.statusCode}.';
        }
         if (allStoresResponse.statusCode != 200) { // <-- Add error
           errorMsg += 'All Stores fetch failed: ${allStoresResponse.statusCode}.';
        }
        throw Exception(errorMsg.trim());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      debugPrint("Error fetching store data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Error loading store details: ${e.toString()}'))
      );
    }
  }

  // --- NEW ---
  // Navigation Functions
  void _navigateToPreviousStore() {
    if (currentIndex > 0) { // Check if not the first store
      final previousStoreId = allStores[currentIndex - 1]['id'];
      if (previousStoreId != null) {
        // Replace current screen with the new one
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StoreDetails(storeId: previousStoreId),
          ),
        );
      }
    } else {
       debugPrint("Already at the first store.");
       // Optionally navigate home or show a message
       // Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _navigateToNextStore() {
    if (currentIndex != -1 && currentIndex < allStores.length - 1) { // Check if not the last store
      final nextStoreId = allStores[currentIndex + 1]['id'];
      if (nextStoreId != null) {
        // Replace current screen with the new one
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StoreDetails(storeId: nextStoreId),
          ),
        );
      }
    } else {
      debugPrint("Already at the last store.");
      // Optionally navigate home or show a message
      // Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }


Widget buildStoreHeader() {
  final String openTime = store?['openTime'] ?? 'N/A';
  final String closeTime = store?['closeTime'] ?? 'N/A';
  final String openCloseTime = (openTime != 'N/A' && closeTime != 'N/A')
      ? 'Open : $openTime - $closeTime'
      : 'Timings not available';

  // Get data for onTap functions
  final String? storePhone = store?['phone'];
  final String? storeWebsite = store?['website'];
  final String storeName = store?['storename'] ?? 'This Store';
  final String? location = store?['location'] ?? store?['storeaddress'];
  final String shareText = 'Check out $storeName! ${storeWebsite != null ? storeWebsite : ""}';

  // --- NEW ---
  // Determine if navigation buttons should be enabled
  final bool canGoBack = currentIndex > 0;
  final bool canGoForward = currentIndex != -1 && currentIndex < allStores.length - 1;


  return NavBarContainer(
     child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---------- Top Row (Logo + Details) ----------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  store?['storeImage'] ??
                      'https://via.placeholder.com/100x100.png?text=Store',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Icon(Icons.storefront, color: Colors.grey[400], size: 40)
                    ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          store?['rating']?.toString() ?? "4.2",
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      openCloseTime,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    Text(
                      "Products : ${products?.length ?? 0}",
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ---------- Middle Row (Colored Circular Buttons) ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () {
                  if (storePhone != null) {
                    launchWhatsApp(storePhone);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('WhatsApp number not available.'))
                    );
                  }
                },
                child: _buildCircleIcon(FontAwesomeIcons.whatsapp, Colors.green),
              ),
              GestureDetector(
                onTap: () {
                  if (storePhone != null) {
                    makePhoneCall(storePhone);
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Phone number not available.'))
                    );
                  }
                },
                child: _buildCircleIcon(Icons.phone, Colors.blue),
              ),
              GestureDetector(
                onTap: () {
                   if (location != null && location.isNotEmpty) {
                     openMap(location);
                   } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Location not available.'))
                      );
                   }
                },
                child: _buildCircleIcon(Icons.location_on, Colors.purple),
              ),
              GestureDetector(
                 onTap: () {
                   if (storeWebsite != null && storeWebsite.isNotEmpty) {
                     launchWebsite(storeWebsite);
                   } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Website not available.'))
                      );
                   }
                 },
                child: _buildCircleIcon(Icons.language, Colors.red),
              ),
              GestureDetector(
                onTap: () {
                  shareContent(shareText, subject: 'Check out this store!');
                },
                child: _buildCircleIcon(Icons.share, Colors.teal),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ---------- Bottom Navigation Buttons ----------
          NavBarContainer(
             child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBottomButton(Icons.remove), // Keep this as is if it has other functionality
                // --- MODIFIED ---
                // Add GestureDetector and disable logic
                GestureDetector(
                  onTap: canGoBack ? _navigateToPreviousStore : null, // Disable onTap if can't go back
                  child: _buildBottomButton(
                    Icons.arrow_back,
                    // Change color if disabled
                    color: canGoBack ? Colors.black87 : Colors.grey[400],
                  ),
                ),
                GestureDetector(
                  onTap: canGoForward ? _navigateToNextStore : null, // Disable onTap if can't go forward
                  child: _buildBottomButton(
                    Icons.arrow_forward,
                    // Change color if disabled
                    color: canGoForward ? Colors.blue : Colors.grey[400], // Match next icon color
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCircleIcon(IconData icon, Color color) {
  // ... (unchanged) ...
   return Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.3),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

// --- MODIFIED ---
// Add optional color parameter for disabled state
Widget _buildBottomButton(IconData icon, {Color? color}) {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(
      icon,
      // Use provided color or default
      color: color ?? Colors.black87,
      size: 20
    ),
  );
}


  Widget buildProductCard(Map<String, dynamic> item) {
    // ... (This function is unchanged) ...
    if (item['product'] == null || item['product'] is! Map) {
      return Container(
        padding: const EdgeInsets.all(8.0),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: Colors.red[100],
        child: const Text('Error: Invalid product data format'),
      );
    }
    final product = item['product'] as Map<String, dynamic>;

    final bool available = product['isEnableEcommerce']?.toString() == '1';
    final String labelText = available ? "Available" : "Online Order Not Available";
    final Color labelColor = available ? Colors.green : Colors.redAccent;
    final String? photoUrl = product['photo'] as String?;
    final String productName = product['name']?.toString() ?? 'Unnamed Product';
    final String totalPrice = product['total']?.toString() ?? 'N/A';
    final String stockQty = product['qty']?.toString() ?? 'N/A';
    final String discount = product['discountPer']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                topLeft: Radius.circular(16),
              ),
              child: Image.network(
                photoUrl ??
                    'https://via.placeholder.com/300x200.png?text=Product',
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        topLeft: Radius.circular(16),
                      ),
                    ),
                    child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 50)
                  ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: available ? Colors.black87 : Colors.redAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  available
                      ? "$discount %"
                      : labelText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Rs : $totalPrice",
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Stocks : $stockQty",
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text("Per order"),
                const Text("Online payment"),
                const Text("Cash on delivery"),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Icon(Icons.favorite_border, color: Colors.red),
                    Icon(Icons.remove_red_eye_outlined, color: Colors.black54),
                    Icon(Icons.chat_bubble_outline, color: Colors.purple),
                    Icon(Icons.shopping_cart_outlined, color: Colors.green),
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
    // ... (This function is largely unchanged, but uses the updated buildStoreHeader) ...
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
            : products.isEmpty && store == null && !isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[300], size: 60),
                      const SizedBox(height: 16),
                      const Text(
                        'Could not load store details.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: _fetchStoreData,
                      )
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchStoreData,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8),
                    children: [
                      if (store != null)
                         buildStoreHeader(), // This now includes the nav buttons
                      const SizedBox(height: 8),
                      if (products.isNotEmpty)
                        ...products.map((p) => buildProductCard(p)).toList()
                      else if (!isLoading)
                         const Padding(
                           padding: EdgeInsets.all(20.0),
                           child: Center(child: Text("No products found for this store.")),
                         ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      ),
    );
  }
}