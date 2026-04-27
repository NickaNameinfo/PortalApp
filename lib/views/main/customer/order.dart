import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'package:nickname_portal/components/gradient_background.dart';
import 'package:nickname_portal/views/main/customer/new_product_details_screen.dart';
import '../../../constants/colors.dart';
import '../product/details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/app_config.dart';
import '../../../helpers/secure_http_client.dart';

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
  final Map<String, String> _storePhoneById = {};
  final Set<String> _storePhoneRequested = {};

  String _normalizePhone(String raw) {
    final s = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    return s;
  }

  Future<void> _callStore(String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return;
    final uri = Uri.parse('tel:$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _formatShortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Color _statusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s.contains('cancel')) return Colors.red;
    if (s.contains('deliver')) return Colors.green;
    if (s.contains('process')) return Colors.blue;
    if (s.contains('ship')) return Colors.purple;
    if (s.contains('pending')) return Colors.orange;
    return Colors.grey;
  }

  Widget _pill({
    required Widget child,
    required VoidCallback? onTap,
    Color? bg,
    Color? border,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border ?? Colors.black.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          child: child,
        ),
      ),
    );
  }

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
    final response = await SecureHttpClient.get(
      '${AppConfig.baseApi}/order/list/$_userId',
      context: context,
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData['success'] == true) {
        return jsonData['data'];
      }
    }
    return [];
  }

  int? _parseStoreId(dynamic order) {
    if (order is! Map) return null;
    final m = Map<String, dynamic>.from(order);
    final sid = m['storeId'] ?? m['store_id'] ?? m['storeID'];
    final n = (sid is num) ? sid.toInt() : int.tryParse(sid?.toString() ?? '');
    return (n != null && n > 0) ? n : null;
  }

  Future<void> _prefetchStorePhones(List<dynamic> orders) async {
    final ids = <int>[];
    for (final o in orders) {
      final sid = _parseStoreId(o);
      if (sid == null) continue;
      if (_storePhoneRequested.contains(sid.toString())) continue;
      ids.add(sid);
    }
    final uniq = ids.toSet().toList();
    if (uniq.isEmpty) return;

    // mark requested up-front to avoid duplicate calls
    for (final id in uniq) {
      _storePhoneRequested.add(id.toString());
    }

    try {
      final response = await SecureHttpClient.post(
        '${AppConfig.baseApi}/store/public/by-ids',
        body: {'ids': uniq},
        timeout: const Duration(seconds: 15),
        context: context,
      );
      if (response.statusCode != 200) return;
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['success'] != true) return;
      final rows = decoded['data'];
      if (rows is! List) return;

      bool changed = false;
      for (final r in rows) {
        if (r is! Map) continue;
        final m = Map<String, dynamic>.from(r);
        final id = m['id'];
        if (id == null) continue;
        final phone = (m['phone'] ?? '').toString().trim();
        if (phone.isEmpty) continue;
        _storePhoneById[id.toString()] = phone;
        changed = true;
      }
      if (changed && mounted) setState(() {});
    } catch (_) {
      // ignore store-phone prefetch errors (orders still render)
    }
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
        elevation: 0,
        backgroundColor: primaryColor,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.82),
              ],
            ),
          ),
        ),
        title: const Text(
          'Orders',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
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
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _prefetchStorePhones(filteredOrders);
                });

                return Column(
                  children: [
                    // Filter Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
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
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primaryColor.withOpacity(0.6), width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          // Status Filter
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 170, maxWidth: 220),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedStatus ?? 'All',
                                  decoration: InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  items: uniqueStatuses.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        status,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value;
                                    });
                                  },
                                ),
                              ),
                              _pill(
                                onTap: () async {
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
                                bg: primaryColor.withOpacity(0.08),
                                border: primaryColor.withOpacity(0.18),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Text(_startDate == null ? 'Start Date' : _formatShortDate(_startDate!)),
                                  ],
                                ),
                              ),
                              _pill(
                                onTap: () async {
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
                                bg: primaryColor.withOpacity(0.08),
                                border: primaryColor.withOpacity(0.18),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Text(_endDate == null ? 'End Date' : _formatShortDate(_endDate!)),
                                  ],
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
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                                itemCount: filteredOrders.length,
                                itemBuilder: (context, index) {
                                  final order = filteredOrders[index];
                                  final orderDate = intl.DateFormat.yMMMEd().format(
                                    DateTime.parse(order['createdAt']),
                                  );
                                  final products = order['products'] as List<dynamic>;

                                  final status = (order['status'] ?? '').toString();
                                  final statusColor = _statusColor(status);
                                  final total = (order['grandtotal'] ?? order['grandTotal'] ?? '').toString();
                                  final storeId = _parseStoreId(order);
                                  final storePhone = storeId != null ? _storePhoneById[storeId.toString()] : null;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 18,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent,
                                        splashColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                      ),
                                      child: ExpansionTile(
                                        tilePadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                                        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                        iconColor: primaryColor,
                                        collapsedIconColor: primaryColor,
                                        leading: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(0.10),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(Icons.shopping_bag_outlined, color: primaryColor),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Order #${order['id']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.10),
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(color: statusColor.withOpacity(0.22)),
                                              ),
                                              child: Text(
                                                status.isEmpty ? '—' : status,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    '₹$total',
                                                    style: TextStyle(
                                                      color: Colors.grey[900],
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      orderDate,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (storePhone != null && storePhone.trim().isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                InkWell(
                                                  onTap: () => _callStore(storePhone),
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.call_outlined, size: 16, color: primaryColor),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            'Store: $storePhone',
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              color: primaryColor,
                                                              fontWeight: FontWeight.w800,
                                                              fontSize: 12,
                                                              decoration: TextDecoration.underline,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        children: products.map((prod) {
                                          final photo = (prod['photo'] ?? '').toString();
                                          final name = (prod['name'] ?? '').toString();
                                          return Container(
                                            margin: const EdgeInsets.only(top: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF7F8FC),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: Colors.black.withOpacity(0.06)),
                                            ),
                                            child: ListTile(
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) => NewProductDetailsScreen(product: prod),
                                                  ),
                                                );
                                              },
                                              leading: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Container(
                                                  width: 44,
                                                  height: 44,
                                                  color: Colors.white,
                                                  child: photo.isNotEmpty
                                                      ? Image.network(photo, fit: BoxFit.cover)
                                                      : const Icon(Icons.image_not_supported_outlined),
                                                ),
                                              ),
                                              title: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                              ),
                                              trailing: const Icon(Icons.chevron_right, color: primaryColor),
                                            ),
                                          );
                                        }).toList(),
                                      ),
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
