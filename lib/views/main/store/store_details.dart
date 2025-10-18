import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../constants/colors.dart';
import 'package:multivendor_shop/components/nav_bar_container.dart';
import 'package:multivendor_shop/components/gradient_background.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  Future<void> _fetchStoreData() async {
    try {
      final storeResponse = await http.get(Uri.parse(
          'https://nicknameinfo.net/api/store/list/${widget.storeId}'));
      final productResponse = await http.get(Uri.parse(
          'https://nicknameinfo.net/api/store/product/getAllProductById/${widget.storeId}'));

      if (storeResponse.statusCode == 200 &&
          productResponse.statusCode == 200) {
        final storeJson = json.decode(storeResponse.body);
        final productJson = json.decode(productResponse.body);

        setState(() {
          store = storeJson['data'];
          products = productJson['data'] ?? [];
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load store or products");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint("Error: $e");
    }
  }

Widget buildStoreHeader() {
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
                      'https://via.placeholder.com/80x80.png?text=Store',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store?['storename'] ?? 'Nickname',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: const [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "4.2",
                          style: TextStyle(color: Colors.black87, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Open : 9 AM - 9 PM",
                      style: const TextStyle(color: Colors.black87),
                    ),
                    Text(
                      "Products : 5",
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
              _buildCircleIcon(FontAwesomeIcons.whatsapp, Colors.green),
              _buildCircleIcon(Icons.phone, Colors.blue),
              _buildCircleIcon(Icons.location_on, Colors.purple),
              _buildCircleIcon(Icons.language, Colors.red),
              _buildCircleIcon(Icons.send, Colors.teal),
            ],
          ),

          const SizedBox(height: 16),

          // ---------- Bottom Navigation Buttons ----------
          NavBarContainer(
     child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomButton(Icons.remove),
              _buildBottomButton(Icons.arrow_back_ios),
              _buildBottomButton(Icons.arrow_forward_ios),
            ],
          ),
          ),
        ],
      ),
    ),
  );
}

// ---------- Helper Widget: Circular Colored Icons ----------
Widget _buildCircleIcon(IconData icon, Color color) {
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

// ---------- Helper Widget: Bottom Rounded Buttons ----------
Widget _buildBottomButton(IconData icon) {
  return Container(
    width: 46,
    height: 36,
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
    child: Icon(icon, color: Colors.black87, size: 20),
  );
}


  Widget buildProductCard(Map<String, dynamic> item) {
    final product = item['product'];
    final bool available = product['isEnableEcommerce'] == '1';
    final String labelText = available ? "Available" : "Online Order Not Available";
    final Color labelColor = available ? Colors.green : Colors.redAccent;

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
                product['photo'] ??
                    'https://via.placeholder.com/300x200.png?text=Product',
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
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
                      ? "${product['discountPer']} %"
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
                Text(product['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Rs : ${product['total']}",
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Stocks : ${product['qty']}",
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
    return Container(
      decoration: gradientBackgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Set Scaffold's background to transparent
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent, // Also set AppBar background to transparent
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Store Details",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator()) // Replace with your Loading widget
            : RefreshIndicator(
                onRefresh: _fetchStoreData,
                child: ListView(
                  children: [
                    buildStoreHeader(),
                    const SizedBox(height: 8),
                    ...products.map((p) => buildProductCard(p)).toList(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }
}
