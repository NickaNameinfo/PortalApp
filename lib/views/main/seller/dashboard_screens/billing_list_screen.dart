import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../helpers/billing_service.dart';
import '../../../../models/billing_model.dart';
import 'add_billing_screen.dart';
import 'view_billing_screen.dart';

class BillingListScreen extends StatefulWidget {
  const BillingListScreen({Key? key}) : super(key: key);

  @override
  State<BillingListScreen> createState() => _BillingListScreenState();
}

class _BillingListScreenState extends State<BillingListScreen> {
  List<BillingModel> _bills = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _storeId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadStoreId();
    _fetchBills();
  }

  Future<void> _loadStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storeId = prefs.getString('storeId') ?? prefs.getInt('storeid')?.toString();
    });
  }

  Future<void> _fetchBills() async {
    if (_storeId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final data = await BillingService.getAllBills(_storeId!);
      setState(() {
        _bills = data.map((bill) => BillingModel.fromJson(bill)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bills: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<BillingModel> get _filteredBills {
    var filtered = _bills;
    
    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((bill) {
        return bill.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            bill.id.toString().contains(_searchQuery) ||
            (bill.customerPhone ?? '').contains(_searchQuery);
      }).toList();
    }
    
    // Date filter
    if (_startDate != null) {
      filtered = filtered.where((bill) {
        if (bill.createdAt == null) return false;
        return bill.createdAt!.isAfter(_startDate!.subtract(const Duration(days: 1))) ||
               bill.createdAt!.isAtSameMomentAs(_startDate!);
      }).toList();
    }
    
    if (_endDate != null) {
      filtered = filtered.where((bill) {
        if (bill.createdAt == null) return false;
        return bill.createdAt!.isBefore(_endDate!.add(const Duration(days: 1))) ||
               bill.createdAt!.isAtSameMomentAs(_endDate!);
      }).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBills,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
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
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search bills...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 12),
                // Date Filters
                Row(
                  children: [
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
                          backgroundColor: const Color(0xFF1976D2),
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
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_startDate != null || _endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${_filteredBills.length} of ${_bills.length} bills',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                            });
                          },
                          child: const Text('Clear Date Filter'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Bills List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBills.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No bills found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first bill to get started',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchBills,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredBills.length,
                          itemBuilder: (context, index) {
                            final bill = _filteredBills[index];
                            return _buildBillCard(bill);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddBillingScreen()),
          );
          if (result == true) {
            _fetchBills();
          }
        },
        backgroundColor: const Color(0xFF1976D2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Bill', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildBillCard(BillingModel bill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewBillingScreen(billId: bill.id!),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.customerName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bill #${bill.billNumber ?? bill.id}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₹${bill.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      'Date',
                      bill.createdAt != null
                          ? '${bill.createdAt!.day}/${bill.createdAt!.month}/${bill.createdAt!.year}'
                          : '-',
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.shopping_cart,
                      'Items',
                      bill.products.length.toString(),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.receipt,
                      'Subtotal',
                      '₹${bill.subtotal.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
              if (bill.discount > 0 || bill.tax > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (bill.discount > 0)
                      Expanded(
                        child: _buildInfoItem(
                          Icons.discount,
                          'Discount',
                          '₹${bill.discount.toStringAsFixed(2)}',
                          color: Colors.red,
                        ),
                      ),
                    if (bill.tax > 0)
                      Expanded(
                        child: _buildInfoItem(
                          Icons.attach_money,
                          'Tax',
                          '₹${bill.tax.toStringAsFixed(2)}',
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

