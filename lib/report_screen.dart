import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _repUrl = 'https://zcwkvadhdxwpdrjidwea.supabase.co';
const _repKey = 'sb_publishable_mnREAEDOrm_vnZTg4cUhlQ_r2zyl9IL';
const _repJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTc3MjUwNjgwNCwiZXhwIjo5OTk5OTk5OTk5fQ.EuYLr1GXZwBvV4AP6ndkS8Hg8UWnsKaHWTkVZIOEYQA';

Map<String, String> get _repHeaders => {
  'apikey': _repKey,
  'Authorization': 'Bearer $_repJwt',
  'Content-Type': 'application/json',
};

class ReportScreen extends StatefulWidget {
  final String sessionId;
  final String sessionName;

  const ReportScreen({
    super.key,
    required this.sessionId,
    required this.sessionName,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Map<String, dynamic>> _report = [];
  bool _isLoading = true;
  String _filter = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      // جلب الكميات الفعلية من الجرد
      final linesRes = await http.get(
        Uri.parse(
          '$_repUrl/rest/v1/inventory_lines?session_id=eq.${widget.sessionId}',
        ),
        headers: _repHeaders,
      );

      // جلب المنتجات مع الكميات المتوقعة
      final productsRes = await http.get(
        Uri.parse(
          '$_repUrl/rest/v1/products?select=barcode,name,name_ar,quantity,category',
        ),
        headers: _repHeaders,
      );

      if (linesRes.statusCode == 200 && productsRes.statusCode == 200) {
        final List lines = jsonDecode(linesRes.body);
        final List products = jsonDecode(productsRes.body);

        // تجميع الكميات الفعلية
        final Map<String, int> actualQty = {};
        for (final line in lines) {
          final barcode = line['barcode'] ?? '';
          actualQty[barcode] = actualQty[barcode] =
              ((actualQty[barcode] ?? 0) + ((line['scanned_qty'] ?? 1) as int))
                  .toInt();
        }

        // إزالة التكرار — نأخذ أول سجل لكل باركود
        final Map<String, Map<String, dynamic>> uniqueProducts = {};
        for (final product in products) {
          final barcode = product['barcode'] ?? '';
          if (barcode.isNotEmpty && !uniqueProducts.containsKey(barcode)) {
            uniqueProducts[barcode] = product;
          }
        }

        // بناء التقرير
        final List<Map<String, dynamic>> report = [];
        for (final product in uniqueProducts.values) {
          final barcode = product['barcode'] ?? '';
          final expected = (product['quantity'] ?? 0) as int;
          final actual = actualQty[barcode] ?? 0;
          final diff = actual - expected;

          report.add({
            'barcode': barcode,
            'name': product['name_ar'] ?? product['name'] ?? barcode,
            'category': product['category'] ?? '',
            'expected': expected,
            'actual': actual,
            'diff': diff,
          });
        }

        // إضافة منتجات مسحوبة غير موجودة في قاعدة البيانات
        for (final entry in actualQty.entries) {
          final exists = products.any((p) => p['barcode'] == entry.key);
          if (!exists) {
            report.add({
              'barcode': entry.key,
              'name': 'صنف - ${entry.key}',
              'category': '',
              'expected': 0,
              'actual': entry.value,
              'diff': entry.value,
            });
          }
        }

        // ترتيب: الأكثر فرقاً أولاً
        report.sort(
          (a, b) =>
              (b['diff'] as int).abs().compareTo((a['diff'] as int).abs()),
        );

        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Report error: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'الكل') return _report;
    if (_filter == 'ناقص')
      return _report.where((r) => (r['diff'] as int) < 0).toList();
    if (_filter == 'زيادة')
      return _report.where((r) => (r['diff'] as int) > 0).toList();
    if (_filter == 'مطابق')
      return _report.where((r) => (r['diff'] as int) == 0).toList();
    return _report;
  }

  int get _totalExpected =>
      _report.fold(0, (s, r) => s + (r['expected'] as int));
  int get _totalActual => _report.fold(0, (s, r) => s + (r['actual'] as int));
  int get _totalDiff => _totalActual - _totalExpected;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          title: Column(
            children: [
              const Text(
                'تقرير المقارنة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                widget.sessionName,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadReport,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ملخص إجمالي
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _SummaryBox(
                          label: 'متوقع',
                          value: '$_totalExpected',
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _SummaryBox(
                          label: 'فعلي',
                          value: '$_totalActual',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _SummaryBox(
                          label: 'الفرق',
                          value: '${_totalDiff > 0 ? '+' : ''}$_totalDiff',
                          color: _totalDiff == 0
                              ? Colors.green
                              : _totalDiff > 0
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ],
                    ),
                  ),
                  // فلاتر
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: ['الكل', 'ناقص', 'زيادة', 'مطابق'].map((f) {
                        final selected = _filter == f;
                        return GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? Colors.white : Colors.black54,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // عدد النتائج
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_filtered.length} صنف',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // القائمة
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد نتائج',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final item = _filtered[index];
                              final diff = item['diff'] as int;
                              final diffColor = diff == 0
                                  ? Colors.green
                                  : diff > 0
                                  ? Colors.orange
                                  : Colors.red;
                              final diffIcon = diff == 0
                                  ? Icons.check_circle
                                  : diff > 0
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: diffColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(diffIcon, color: diffColor),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                              style: const TextStyle(
                                                color: Colors.black45,
                                                fontSize: 11,
                                              ),
                                              textDirection: TextDirection.ltr,
                                            ),
                                            if ((item['category'] as String)
                                                .isNotEmpty)
                                              Text(
                                                item['category'],
                                                style: const TextStyle(
                                                  color: Colors.black38,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'متوقع: ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                              Text(
                                                '${item['expected']}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                'فعلي: ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                              Text(
                                                '${item['actual']}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${diff > 0 ? '+' : ''}$diff',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: diffColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryBox({
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
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
