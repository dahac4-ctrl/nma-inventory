import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    // التركيز على حقل الباركود فور فتح الشاشة
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

  void _processScan(String barcode) {
    if (barcode.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _lastScanned = barcode;

      // ابحث إذا الباركود موجود مسبقاً
      final existingIndex = _scannedItems.indexWhere(
        (item) => item['barcode'] == barcode,
      );

      if (existingIndex != -1) {
        // زد الكمية
        _scannedItems[existingIndex]['qty'] =
            _scannedItems[existingIndex]['qty'] + 1;
      } else {
        // أضف صنف جديد
        _scannedItems.insert(0, {
          'barcode': barcode,
          'name': 'صنف - $barcode',
          'qty': 1,
          'time': DateTime.now().toString().substring(11, 16),
        });
      }

      _isProcessing = false;
    });

    // امسح الحقل وأعد التركيز
    _barcodeController.clear();
    _barcodeFocus.requestFocus();

    // اهتزاز خفيف
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
            // قسم المسح
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // حقل الباركود
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
                  // آخر مسح
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
            // إحصائيات سريعة
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
            // قائمة المسح
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
                          onDelete: () {
                            setState(() {
                              _scannedItems.removeAt(index);
                            });
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
              value,
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
