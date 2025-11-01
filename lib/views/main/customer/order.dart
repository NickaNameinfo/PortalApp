import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:multivendor_shop/components/gradient_background.dart';
import 'package:multivendor_shop/views/main/customer/new_product_details_screen.dart';
import '../../../constants/colors.dart';
import '../product/details.dart';

class CustomerOrderScreen extends StatefulWidget {
  static const routeName = '/customer_orders';

  const CustomerOrderScreen({super.key});

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  Future<List<dynamic>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = fetchOrders(); // ✅ Initialize safely
  }

  Future<List<dynamic>> fetchOrders() async {
    final url = Uri.parse('https://nicknameinfo.net/api/order/list/48');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData['success'] == true) {
        return jsonData['data'];
      }
    }
    return [];
  }

  void _navigateToDetails(Map<String, dynamic> product) {
    Navigator.of(context).push( 
      MaterialPageRoute(
        builder: (context) => DetailsScreen(product: product),
      ),
    );
  }

  void _showProductNotFoundSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Product not found!'),
      ),
    );
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = fetchOrders();
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
          'Orders',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshOrders, // ✅ Manual refresh button
          ),
        ],
      ),
      body: Container(
        decoration: gradientBackgroundDecoration,
        child: _ordersFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<dynamic>>(
                future: _ordersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/sad.png', width: 120),
                        const SizedBox(height: 10),
                        const Text(
                          'No orders to display',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshOrders, // ✅ Pull-to-refresh support
                  child: 
                  ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final orderDate = intl.DateFormat.yMMMEd().format(
                        DateTime.parse(order['createdAt']),
                      );
                      final products = order['products'] as List<dynamic>;

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        child: ExpansionTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: primaryColor,
                            ),
                          ),
                          title: Text(
                            'Order #${order['id']} - ${order['status']}',
                            style: const TextStyle(color: Colors.black),
                          ),
                          subtitle: Text(
                            '₹${order['grandtotal']}  •  $orderDate',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          iconColor: primaryColor,
                          children: products.map((prod) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.white,
                                backgroundImage: NetworkImage(prod['photo']),
                              ),
                              title: Text(
                                prod['name'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                              subtitle: Text(
                                'Qty: ${prod['qty']} • ₹${prod['price']}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.chevron_right,
                                  color: primaryColor,
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => NewProductDetailsScreen(product: prod),
                                    ),
                                  );  
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
    );
  }
}
