import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../helpers/billing_service.dart';
import '../../../../models/billing_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ViewBillingScreen extends StatefulWidget {
  final int billId;

  const ViewBillingScreen({Key? key, required this.billId}) : super(key: key);

  @override
  State<ViewBillingScreen> createState() => _ViewBillingScreenState();
}

class _ViewBillingScreenState extends State<ViewBillingScreen> {
  BillingModel? _bill;
  Map<String, dynamic>? _store;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBillData();
  }

  Future<void> _fetchBillData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch bill
      final billData = await BillingService.getBillById(widget.billId);
      
      // Use store from bill response if available, otherwise fetch separately
      if (billData['store'] != null && billData['store'] is Map) {
        _store = billData['store'] as Map<String, dynamic>;
      } else {
        // Fallback: Fetch store separately
        final prefs = await SharedPreferences.getInstance();
        final storeId = prefs.getString('storeId') ?? prefs.getInt('storeid')?.toString();

        if (storeId != null) {
          final storeResponse = await http.get(
            Uri.parse('https://nicknameinfo.net/api/store/list/$storeId'),
            headers: {
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 15));

          if (storeResponse.statusCode == 200) {
            final storeData = jsonDecode(storeResponse.body);
            _store = storeData['data'];
          }
        }
      }

      setState(() {
        _bill = BillingModel.fromJson(billData);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bill: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                   'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _handlePrint() async {
    if (_bill == null) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 42,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.Container(
                    width: 300,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          _store?['storename'] ?? 'Nickname Infotech',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                        pw.SizedBox(height: 5),
                        if (_store?['storeaddress'] != null)
                          pw.Text(
                            _store!['storeaddress'],
                            style: const pw.TextStyle(fontSize: 10),
                            textAlign: pw.TextAlign.right,
                          ),
                        if (_store?['phone'] != null)
                          pw.Text(
                            'Phone: ${_store!['phone']}',
                            style: const pw.TextStyle(fontSize: 10),
                            textAlign: pw.TextAlign.right,
                          ),
                        if (_store?['email'] != null)
                          pw.Text(
                            'Email: ${_store!['email']}',
                            style: const pw.TextStyle(fontSize: 10),
                            textAlign: pw.TextAlign.right,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text('Invoice #: ${_bill!.billNumber ?? 'INV-${_bill!.id ?? widget.billId}'}', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Date: ${_formatDate(_bill!.createdAt)}', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Bill To
              pw.Text('Bill To:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(_bill!.customerName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 25),

              // Invoice Details
              pw.Text('Invoice Details:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Invoice Number:', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text(_bill!.billNumber ?? 'INV-${_bill!.id}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Invoice Date:', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text(_formatDate(_bill!.createdAt), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Status:', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('Paid', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Products Table
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Table(
                  border: pw.TableBorder(
                    horizontalInside: const pw.BorderSide(color: PdfColors.grey300),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(0.8),
                    2: const pw.FlexColumnWidth(0.8),
                    3: const pw.FlexColumnWidth(1.2),
                    4: const pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text('ITEM', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text('SIZE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text('QTY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text('UNIT PRICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                    // Products
                    ..._bill!.products.map((product) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(12),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text(
                                  product.name ?? product.productName ?? (product.productId != null ? 'Product #${product.productId}' : 'Product'),
                                  style: const pw.TextStyle(fontSize: 11),
                                ),
                                if (product.weight != null && product.weight!.isNotEmpty)
                                  pw.Text('Weight: ${product.weight}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                              ],
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(12),
                            child: pw.Text(
                              product.size != null && product.size!.isNotEmpty ? product.size!.toUpperCase() : '-',
                              style: const pw.TextStyle(fontSize: 11),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(12),
                            child: pw.Text(product.quantity.toString(), style: const pw.TextStyle(fontSize: 11), textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(12),
                            child: pw.Text('Rs.${product.price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 11), textAlign: pw.TextAlign.right),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(12),
                            child: pw.Text('Rs.${product.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Subtotal: ', style: const pw.TextStyle(fontSize: 12)),
                          pw.SizedBox(width: 50),
                          pw.Text('Rs.${_bill!.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                      if (_bill!.discount > 0) pw.SizedBox(height: 5),
                      if (_bill!.discount > 0)
                        pw.Row(
                          children: [
                            pw.Text('Discount: ', style: const pw.TextStyle(fontSize: 12)),
                            pw.SizedBox(width: 50),
                            pw.Text('-Rs.${_bill!.discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                      if (_bill!.tax > 0) pw.SizedBox(height: 5),
                      if (_bill!.tax > 0)
                        pw.Row(
                          children: [
                            pw.Text('Tax: ', style: const pw.TextStyle(fontSize: 12)),
                            pw.SizedBox(width: 50),
                            pw.Text('Rs.${_bill!.tax.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(width: 2)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text('Total: ', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(width: 30),
                            pw.Text('Rs.${_bill!.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'This is a computer-generated invoice and does not require a signature.',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Invoice #${_bill?.billNumber ?? 'INV-${_bill?.id ?? widget.billId}'}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _handlePrint,
            tooltip: 'Print Invoice',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bill == null
              ? const Center(child: Text('Bill not found'))
              : SingleChildScrollView(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'INVOICE',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2196F3),
                                  ),
                                ),
                                Container(
                                  constraints: const BoxConstraints(maxWidth: 350),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _store?['storename'] ?? 'Nickname Infotech',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                      const SizedBox(height: 5),
                                      if (_store?['storeaddress'] != null)
                                        Text(
                                          _store!['storeaddress'],
                                          style: const TextStyle(fontSize: 11),
                                          textAlign: TextAlign.right,
                                        ),
                                      if (_store?['phone'] != null)
                                        Text(
                                          'Phone: ${_store!['phone']}',
                                          style: const TextStyle(fontSize: 11),
                                          textAlign: TextAlign.right,
                                        ),
                                      if (_store?['email'] != null)
                                        Text(
                                          'Email: ${_store!['email']}',
                                          style: const TextStyle(fontSize: 11),
                                          textAlign: TextAlign.right,
                                        ),
                                      if (_store?['website'] != null)
                                        Text(
                                          'Website: ${_store!['website']}',
                                          style: const TextStyle(fontSize: 11),
                                          textAlign: TextAlign.right,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Invoice #: ${_bill!.billNumber ?? 'INV-${_bill!.id ?? widget.billId}'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Date: ${_formatDate(_bill!.createdAt)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 30),
                            const Divider(),
                            const SizedBox(height: 30),

                            // Bill To
                            const Text(
                              'Bill To:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _bill!.customerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Invoice Details
                            const Text(
                              'Invoice Details:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  _buildDetailRow(
                                    'Invoice Number:',
                                    _bill!.billNumber ?? 'INV-${_bill!.id ?? widget.billId}',
                                  ),
                                  const SizedBox(height: 10),
                                  _buildDetailRow(
                                    'Invoice Date:',
                                    _formatDate(_bill!.createdAt),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Status:',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Paid',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Products Table
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  // Table Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 15,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'ITEM',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'SIZE',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'QTY',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'UNIT PRICE',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'TOTAL',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Table Body
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _bill!.products.length,
                                    separatorBuilder: (context, index) => Divider(
                                      height: 1,
                                      color: Colors.grey[300],
                                    ),
                                    itemBuilder: (context, index) {
                                      final product = _bill!.products[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 15,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                children: [
                                                  if (product.photo != null && product.photo!.isNotEmpty)
                                                    Container(
                                                      margin: const EdgeInsets.only(right: 12),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(4),
                                                        child: Image.network(
                                                          product.photo!,
                                                          width: 40,
                                                          height: 40,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) =>
                                                              Container(
                                                            width: 40,
                                                            height: 40,
                                                            color: Colors.grey[200],
                                                            child: const Icon(
                                                              Icons.image,
                                                              size: 20,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          product.name ?? product.productName ?? (product.productId != null ? 'Product #${product.productId}' : 'Product'),
                                                          style: const TextStyle(fontSize: 14),
                                                        ),
                                                        if (product.weight != null && product.weight!.isNotEmpty)
                                                          Text(
                                                            'Weight: ${product.weight}',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey[600],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                product.size != null && product.size!.isNotEmpty
                                                    ? product.size!.toUpperCase()
                                                    : '-',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: product.size != null && product.size!.isNotEmpty
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: product.size != null && product.size!.isNotEmpty
                                                      ? Colors.blue[700]
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                product.quantity.toString(),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '₹${product.price.toStringAsFixed(2)}',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '₹${product.total.toStringAsFixed(2)}',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Totals
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildTotalRow('Subtotal:', _bill!.subtotal),
                                    if (_bill!.discount > 0)
                                      const SizedBox(height: 8),
                                    if (_bill!.discount > 0)
                                      _buildTotalRow('Discount:', _bill!.discount, isNegative: true),
                                    if (_bill!.tax > 0)
                                      const SizedBox(height: 8),
                                    if (_bill!.tax > 0)
                                      _buildTotalRow('Tax:', _bill!.tax),
                                    const SizedBox(height: 15),
                                    Container(
                                      padding: const EdgeInsets.only(top: 15),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(width: 2, color: Colors.black),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text(
                                            'Total: ',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 40),
                                          Text(
                                            '₹${_bill!.total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2196F3),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 50),

                            // Footer
                            const Divider(),
                            const SizedBox(height: 20),
                            const Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Thank you for your business!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'This is a computer-generated invoice and does not require a signature.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isNegative = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 50),
        Text(
          '${isNegative ? '-' : ''}₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isNegative ? Colors.red : Colors.black,
          ),
        ),
      ],
    );
  }
}
