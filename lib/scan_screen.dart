import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _supabaseUrl = 'https://zcwkvadhdxwpdrjidwea.supabase.co';
const _supabaseKey = 'sb_publishable_mnREAEDOrm_vnZTg4cUhlQ_r2zyl9IL';
const _supabaseJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTc3MjUwNjgwNCwiZXhwIjo5OTk5OTk5OTk5fQ.EuYLr1GXZwBvV4AP6ndkS8Hg8UWnsKaHWTkVZIOEYQA';

Map<String, String> get _headers => {
  'apikey': _supabaseKey,
  'Authorization': 'Bearer $_supabaseJwt',
  'Content-Type': 'application/json',
  'Prefer': 'return=representation',
};

class ScanScreen extends StatefulWidget {
  final String sessionName;
  final String sessionId;

  const ScanScreen({
    super.key,
    required this.sessionName,
    required this.sessionId,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocus = FocusNode();
  final List<Map<String, dynamic>> _scannedItems = [];
  String _lastScanned = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadExistingLines();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _loadExistingLines() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_supabaseUrl/rest/v1/inventory_lines?session_id=eq.${widget.sessionId}&order=scanned_at.desc',
        ),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _scannedItems.clear();
          for (var line in data) {
            _scannedItems.add({
              'barcode': line['barcode'],
              'name': line['product_name'] ?? 'صنف - ${line['barcode']}',
              'qty': line['scanned_qty'] ?? 1,
              'time': line['scanned_at'] != null
                  ? line['scanned_at'].toString().substring(11, 16)
                  : '',
              'id': line['id'],
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading lines: $e');
    }
  }

  Future<void> _processScan(String barcode) async {
    if (barcode.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _lastScanned = barcode;
    });

    try {
      // ابحث إذا الباركود موجود مسبقاً في القائمة
      final existingIndex = _scannedItems.indexWhere(
        (item) => item['barcode'] == barcode,
      );

      if (existingIndex != -1) {
        // زد الكمية في قاعدة البيانات
        final newQty = _scannedItems[existingIndex]['qty'] + 1;
        final lineId = _scannedItems[existingIndex]['id'];

        await http.patch(
          Uri.parse('$_supabaseUrl/rest/v1/inventory_lines?id=eq.$lineId'),
          headers: _headers,
          body: jsonEncode({'scanned_qty': newQty}),
        );

        setState(() {
          _scannedItems[existingIndex]['qty'] = newQty;
        });
      } else {
        // أضف سطر جديد في قاعدة البيانات
        final response = await http.post(
          Uri.parse('$_supabaseUrl/rest/v1/inventory_lines'),
          headers: _headers,
          body: jsonEncode({
            'session_id': widget.sessionId,
            'barcode': barcode,
            'product_name': 'صنف - $barcode',
            'scanned_qty': 1,
            'scanned_at': DateTime.now().toIso8601String(),
          }),
        );

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final newLine = data is List ? data[0] : data;
          setState(() {
            _scannedItems.insert(0, {
              'barcode': barcode,
              'name': 'صنف - $barcode',
              'qty': 1,
              'time': DateTime.now().toString().substring(11, 16),
              'id': newLine['id'],
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Error saving scan: $e');
    }

    setState(() => _isProcessing = false);
    _barcodeController.clear();
    _barcodeFocus.requestFocus();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          title: Text(
            widget.sessionName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  '${_scannedItems.length} صنف',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _barcodeController,
                    focusNode: _barcodeFocus,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'امسح الباركود أو اكتبه',
                      hintText: '← اكتب ثم اضغط Enter',
                      prefixIcon: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade700,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: _processScan,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 12),
                  if (_lastScanned.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'آخر مسح: $_lastScanned',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _StatChip(
                    label: 'إجمالي الأصناف',
                    value: '${_scannedItems.length}',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'إجمالي الكمية',
                    value:
                        '${_scannedItems.fold(0, (sum, item) => sum + (item['qty'] as int))}',
                    color: Colors.green,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _scannedItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ابدأ المسح',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'اكتب الباركود واضغط Enter',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _scannedItems.length,
                      itemBuilder: (context, index) {
                        final item = _scannedItems[index];
                        return _ScannedItemCard(
                          item: item,
                          onDelete: () async {
                            final lineId = item['id'];
                            await http.delete(
                              Uri.parse(
                                '$_supabaseUrl/rest/v1/inventory_lines?id=eq.$lineId',
                              ),
                              headers: _headers,
                            );
                            setState(() => _scannedItems.removeAt(index));
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ScannedItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;

  const _ScannedItemCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${item['qty']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    item['barcode'],
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
            Text(
              item['time'],
              style: const TextStyle(color: Colors.black45, fontSize: 11),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
              iconSize: 20,
            ),
          ],
        ),
      ),
    );
  }
}
