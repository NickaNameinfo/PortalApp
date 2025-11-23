import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:nickname_portal/components/gradient_background.dart';
import 'package:nickname_portal/views/main/customer/new_product_details_screen.dart';
import '../../../constants/colors.dart';
import '../product/details.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerOrderScreen extends StatefulWidget {
  static const routeName = '/customer_orders';
  const CustomerOrderScreen({super.key});

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  Future<List<dynamic>>? _ordersFuture;
  late String _userId = '';
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserId(); // Load user ID when the screen initializes
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = (prefs.getString('userId') ?? '0'); // Default to "0" or handle as needed
      _ordersFuture = fetchOrders(); // Call fetchOrders after _userId is loaded
    });
  }

  Future<List<dynamic>> fetchOrders() async {
    final url = Uri.parse('https://nicknameinfo.net/api/order/list/$_userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData['success'] == true) {
        return jsonData['data'];
      }
    }
    return [];
  }
  
  List<dynamic> _filterOrders(List<dynamic> orders) {
    var filtered = orders;
    
    // Status filter
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty && _selectedStatus != 'All') {
      filtered = filtered.where((order) {
        final status = order['status']?.toString().toLowerCase() ?? '';
        return status == _selectedStatus!.toLowerCase();
      }).toList();
    }
    
    // Date filter
    if (_startDate != null) {
      filtered = filtered.where((order) {
        try {
          final orderDate = DateTime.parse(order['createdAt'] ?? order['deliverydate'] ?? '');
          return orderDate.isAfter(_startDate!.subtract(const Duration(days: 1))) ||
                 orderDate.isAtSameMomentAs(_startDate!);
        } catch (e) {
          return false;
        }
      }).toList();
    }
    
    if (_endDate != null) {
      filtered = filtered.where((order) {
        try {
          final orderDate = DateTime.parse(order['createdAt'] ?? order['deliverydate'] ?? '');
          return orderDate.isBefore(_endDate!.add(const Duration(days: 1))) ||
                 orderDate.isAtSameMomentAs(_endDate!);
        } catch (e) {
          return false;
        }
      }).toList();
    }
    
    // Search filter
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filtered = filtered.where((order) {
        return (order['id']?.toString() ?? '').contains(searchLower) ||
               (order['status']?.toString().toLowerCase() ?? '').contains(searchLower) ||
               (order['grandtotal']?.toString() ?? '').contains(searchLower);
      }).toList();
    }
    
    return filtered;
  }
  
  List<String> _getUniqueStatuses(List<dynamic> orders) {
    final statuses = <String>{'All'};
    for (var order in orders) {
      final status = order['status']?.toString();
      if (status != null && status.isNotEmpty) {
        statuses.add(status);
      }
    }
    return statuses.toList();
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
                final filteredOrders = _filterOrders(orders);
                final uniqueStatuses = _getUniqueStatuses(orders);

                return Column(
                  children: [
                    // Filter Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Search Bar
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search orders...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          // Status Filter
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedStatus ?? 'All',
                                  decoration: InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  items: uniqueStatuses.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Date Filters
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _startDate = picked;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 18),
                                  label: Text(_startDate == null 
                                      ? 'Start Date' 
                                      : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _endDate ?? DateTime.now(),
                                      firstDate: _startDate ?? DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _endDate = picked;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 18),
                                  label: Text(_endDate == null 
                                      ? 'End Date' 
                                      : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_startDate != null || _endDate != null || (_selectedStatus != null && _selectedStatus != 'All'))
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Showing ${filteredOrders.length} of ${orders.length} orders',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedStatus = null;
                                        _startDate = null;
                                        _endDate = null;
                                        _searchController.clear();
                                      });
                                    },
                                    child: const Text('Clear Filters'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Orders List
                    Expanded(
                      child: filteredOrders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/images/sad.png', width: 120),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No orders found',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _refreshOrders,
                              child: ListView.builder(
                                itemCount: filteredOrders.length,
                                itemBuilder: (context, index) {
                                  final order = filteredOrders[index];
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
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => NewProductDetailsScreen(product: prod),
                                              ),
                                            );
                                          },
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.white,
                                            backgroundImage: NetworkImage(prod['photo']),
                                          ),
                                          title: Text(
                                            prod['name'] ?? '',
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                          // subtitle: Text(
                                          //   'Qty: ${prod['qty']} • ₹${prod['price']}',
                                          // ),
                                          // trailing: const Icon(
                                          //   Icons.chevron_right,
                                          //   color: primaryColor,
                                          // ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }
}
