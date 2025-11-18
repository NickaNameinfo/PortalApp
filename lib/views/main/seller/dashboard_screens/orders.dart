import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../constants/colors.dart'; // Ensure this path is correct for your project

class OrdersScreen extends StatefulWidget {
  static const routeName = '/orders';
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late String _userId = '';
  List<dynamic> _orders = [];
  bool _isLoading = true;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = (prefs.getString('userId') ?? '0');
      if (_userId != '0') {
        _fetchOrders();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // --- 1. Fetch Orders API ---
  Future<void> _fetchOrders() async {
    // Using the specific store ID endpoint provided in your example
    // Ideally, this 57 should be dynamic based on the logged-in user's store
    final url = Uri.parse('https://nicknameinfo.net/api/order/store/list/57'); 
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];
          
          double tempTotal = 0;
          for (var item in data) {
            double price = double.tryParse(item['grandtotal'].toString()) ?? 0.0;
            tempTotal += price;
          }

          setState(() {
            _orders = data;
            _totalAmount = tempTotal;
            _isLoading = false;
          });
        } else {
          setState(() { _isLoading = false; });
        }
      } else {
        debugPrint('Failed to load orders: ${response.statusCode}');
        setState(() { _isLoading = false; });
      }
    } catch (error) {
      debugPrint('Error fetching orders: $error');
      setState(() { _isLoading = false; });
    }
  }

  // --- 2. Update Order API ---
  Future<void> _updateOrderStatus(int orderId, String status, DateTime? date) async {
    final url = Uri.parse('https://nicknameinfo.net/api/order/status/update');
    
    // Format date to YYYY-MM-DD
    String formattedDate = date != null 
        ? intl.DateFormat('yyyy-MM-dd').format(date) 
        : intl.DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: primaryColor)),
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "id": orderId,
          "status": status,
          "deliverydate": formattedDate,
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        // Check API success logic (adjust if your API returns 'success': true differently)
        if (result['success'] == true || response.statusCode == 200) { 
          Navigator.of(context).pop(); // Close the Edit Form Dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order updated successfully!'), backgroundColor: Colors.green),
          );
          _fetchOrders(); // Refresh the list
        } else {
          throw Exception(result['message'] ?? 'Update failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading if error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // --- 3. Update Dialog UI ---
  void _showUpdateDialog(Map<String, dynamic> order) {
    final int orderId = order['id'];
    // Default to existing status or 'processing'
    String currentStatus = (order['status'] ?? 'processing').toString().toLowerCase();
    // Default to existing date or today
    DateTime selectedDate = order['deliverydate'] != null 
        ? DateTime.parse(order['deliverydate']) 
        : DateTime.now();
    
    final dateController = TextEditingController(
      text: intl.DateFormat('yyyy-MM-dd').format(selectedDate)
    );

    // Status options
    final List<String> statuses = ['processing', 'shipping', 'delivered', 'cancelled'];
    
    // Safety check: if api status isn't in list, default to first
    if (!statuses.contains(currentStatus)) currentStatus = statuses[0];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Update Order $orderId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date Picker
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Delivery Date *',
                      suffixIcon: const Icon(Icons.calendar_month, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        setStateDialog(() {
                          selectedDate = pickedDate;
                          dateController.text = intl.DateFormat('yyyy-MM-dd').format(selectedDate);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  // Status Dropdown
                  DropdownButtonFormField<String>(
                    value: currentStatus,
                    decoration: InputDecoration(
                      labelText: 'Status *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: statuses.map((String status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setStateDialog(() {
                        currentStatus = newValue!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent, // Or primaryColor
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    _updateOrderStatus(orderId, currentStatus, selectedDate);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper: Build Data Row for DataTable
  DataRow buildDataRow(String field, dynamic detail) {
    return DataRow(
      cells: [
        DataCell(Text(field, style: const TextStyle(color: Colors.grey))),
        DataCell(
          SizedBox(
            width: 160,
            child: Text(
              detail.toString(),
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        )
      ],
    );
  }

  // Helper: Get Product Image
  String _getProductImage(Map<String, dynamic> order) {
    if (order['products'] != null && (order['products'] as List).isNotEmpty) {
      String? photo = order['products'][0]['photo'];
      if (photo != null && photo.isNotEmpty) return photo.trim();
    }
    return 'https://via.placeholder.com/150';
  }

  // Helper: Get Product Name
  String _getProductName(Map<String, dynamic> order) {
    if (order['products'] != null && (order['products'] as List).isNotEmpty) {
      return order['products'][0]['name'] ?? 'Unknown Product';
    }
    return 'Unknown Product';
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
       SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: litePrimary, 
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'My Orders',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _orders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 10),
                      Text(
                        'No orders to display',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final item = _orders[index];
                    final user = item['user'] ?? {};
                    
                    String formattedDate = 'N/A';
                    if (item['createdAt'] != null) {
                      try {
                        formattedDate = intl.DateFormat.yMMMEd().format(DateTime.parse(item['createdAt']));
                      } catch (_) {}
                    }

                    Color statusColor = Colors.grey;
                    String status = (item['status'] ?? 'pending').toString().toLowerCase();
                    if (status == 'processing') statusColor = Colors.orange;
                    else if (status == 'delivered') statusColor = Colors.green;
                    else if (status == 'cancelled') statusColor = Colors.red;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      elevation: 2,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          backgroundImage: NetworkImage(_getProductImage(item)),
                          onBackgroundImageError: (_, __) {},
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _getProductName(item),
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // --- EDIT BUTTON ---
                            IconButton(
                              icon: const Icon(Icons.edit_square, color: primaryColor, size: 20),
                              onPressed: () {
                                _showUpdateDialog(item);
                              },
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total: \₹${item['grandtotal']}', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                                Text('Qty: ${item['qty']}', style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: statusColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        iconColor: primaryColor,
                        children: [
                          DataTable(
                            headingRowHeight: 0,
                            columns: const [DataColumn(label: Text('')), DataColumn(label: Text(''))],
                            rows: [
                              buildDataRow('Order ID', '#${item['id']}'),
                              buildDataRow('Order Date', formattedDate),
                              buildDataRow('Customer', user['firstName'] ?? 'N/A'),
                              buildDataRow('Contact', user['phone'] ?? 'N/A'),
                              buildDataRow('Address', item['deliveryAddress'] ?? 'N/A'),
                              if (item['deliverydate'] != null)
                                buildDataRow('Delivery Date', item['deliverydate']),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
      bottomSheet: _orders.isNotEmpty
          ? Container(
              color: Colors.white,
              padding: const EdgeInsets.all(15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
                  Text('\₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: primaryColor)),
                ],
              ),
            )
          : null,
    );
  }
}