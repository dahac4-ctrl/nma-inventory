import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'scan_screen.dart';

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

class SessionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Map<String, dynamic> _session;
  List<Map<String, dynamic>> _lines = [];
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _session = Map.from(widget.session);
    _loadLines();
  }

  Future<void> _loadLines() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          '$_supabaseUrl/rest/v1/inventory_lines?session_id=eq.${_session['id']}&order=scanned_at.asc',
        ),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _lines = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);

    try {
      final excel = Excel.createExcel();

      // ===== ورقة 1: الملخص =====
      final summary = excel['الملخص'];
      excel.setDefaultSheet('الملخص');

      // عنوان
      summary.cell(CellIndex.indexByString('A1')).value = TextCellValue(
        'تقرير جلسة: ${_session['name']}',
      );
      summary.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'التاريخ: ${_session['started_at']?.toString().substring(0, 10) ?? ''}',
      );
      summary.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'إجمالي عمليات المسح: ${_lines.length}',
      );

      // رؤوس الأعمدة
      summary.cell(CellIndex.indexByString('A5')).value = TextCellValue(
        'الباركود',
      );
      summary.cell(CellIndex.indexByString('B5')).value = TextCellValue(
        'اسم المنتج',
      );
      summary.cell(CellIndex.indexByString('C5')).value = TextCellValue(
        'إجمالي الكمية',
      );

      // تجميع الكميات
      final Map<String, Map<String, dynamic>> grouped = {};
      for (final line in _lines) {
        final barcode = line['barcode'] ?? '';
        if (!grouped.containsKey(barcode)) {
          grouped[barcode] = {
            'name': line['product_name'] ?? barcode,
            'qty': 0,
          };
        }
        grouped[barcode]!['qty'] += (line['scanned_qty'] ?? 1) as int;
      }

      int row = 6;
      grouped.forEach((barcode, data) {
        summary.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
          barcode,
        );
        summary.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
          data['name'],
        );
        summary.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
          data['qty'],
        );
        row++;
      });

      // ===== ورقة 2: السجل الكامل =====
      final history = excel['السجل الكامل'];

      history.cell(CellIndex.indexByString('A1')).value = TextCellValue(
        'الباركود',
      );
      history.cell(CellIndex.indexByString('B1')).value = TextCellValue(
        'اسم المنتج',
      );
      history.cell(CellIndex.indexByString('C1')).value = TextCellValue(
        'الكمية',
      );
      history.cell(CellIndex.indexByString('D1')).value = TextCellValue(
        'التاريخ',
      );
      history.cell(CellIndex.indexByString('E1')).value = TextCellValue(
        'الوقت',
      );

      int hRow = 2;
      for (final line in _lines) {
        final scannedAt = line['scanned_at']?.toString() ?? '';
        final date = scannedAt.length >= 10 ? scannedAt.substring(0, 10) : '';
        final time = scannedAt.length >= 19 ? scannedAt.substring(11, 16) : '';

        history.cell(CellIndex.indexByString('A$hRow')).value = TextCellValue(
          line['barcode'] ?? '',
        );
        history.cell(CellIndex.indexByString('B$hRow')).value = TextCellValue(
          line['product_name'] ?? '',
        );
        history.cell(CellIndex.indexByString('C$hRow')).value = IntCellValue(
          line['scanned_qty'] ?? 1,
        );
        history.cell(CellIndex.indexByString('D$hRow')).value = TextCellValue(
          date,
        );
        history.cell(CellIndex.indexByString('E$hRow')).value = TextCellValue(
          time,
        );
        hRow++;
      }

      // حذف الورقة الافتراضية
      excel.delete('Sheet1');

      // تحميل الملف في المتصفح
      final bytes = excel.encode()!;
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'جلسة_${_session['name']}.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في التصدير: $e')));
      }
    }

    setState(() => _isExporting = false);
  }

  Future<void> _lockSession() async {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إغلاق الجلسة'),
          content: const Text('هل أنت متأكد؟ لن تتمكن من المسح بعد الإغلاق.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final response = await http.patch(
                    Uri.parse(
                      '$_supabaseUrl/rest/v1/inventory_sessions?id=eq.${_session['id']}',
                    ),
                    headers: _headers,
                    body: jsonEncode({
                      'status': 'closed',
                      'closed_at': DateTime.now().toIso8601String(),
                    }),
                  );
                  if (response.statusCode == 200 ||
                      response.statusCode == 204) {
                    setState(() => _session['status'] = 'closed');
                  }
                } catch (e) {
                  debugPrint('Error: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _session['status'] == 'open';
    final date = _session['started_at'] != null
        ? _session['started_at'].toString().substring(0, 10)
        : '';

    // حساب الأصناف المختلفة
    final uniqueProducts = _lines.map((l) => l['barcode']).toSet().length;
    final totalScans = _lines.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          title: Text(
            _session['name'] ?? '',
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
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadLines,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.info_outline,
                        label: 'الحالة',
                        value: isOpen ? 'مفتوحة' : 'مغلقة',
                        valueColor: isOpen ? Colors.green : Colors.grey,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.calendar_today,
                        label: 'التاريخ',
                        value: date,
                        valueColor: Colors.black87,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.qr_code_scanner,
                        label: 'عمليات المسح',
                        value: '$totalScans عملية',
                        valueColor: Colors.blue,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.category,
                        label: 'أصناف مختلفة',
                        value: '$uniqueProducts صنف',
                        valueColor: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (isOpen) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScanScreen(
                            sessionName: _session['name'],
                            sessionId: _session['id'],
                          ),
                        ),
                      );
                      _loadLines();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'ابدأ المسح',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _lockSession,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.lock),
                    label: const Text(
                      'إغلاق الجلسة',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'الجلسة مغلقة',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // زر تصدير Excel
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _lines.isEmpty || _isExporting
                      ? null
                      : _exportExcel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.download, color: Colors.white),
                  label: Text(
                    _isExporting ? 'جاري التصدير...' : 'تصدير Excel',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'آخر عمليات المسح',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _lines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 60,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'لا توجد عمليات مسح بعد',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _lines.length,
                        itemBuilder: (context, index) {
                          final line = _lines[_lines.length - 1 - index];
                          final scannedAt =
                              line['scanned_at']?.toString() ?? '';
                          final time = scannedAt.length >= 19
                              ? scannedAt.substring(11, 16)
                              : '';
                          final date2 = scannedAt.length >= 10
                              ? scannedAt.substring(0, 10)
                              : '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.qr_code,
                                  color: Colors.blue,
                                ),
                              ),
                              title: Text(
                                line['product_name'] ?? line['barcode'] ?? '',
                              ),
                              subtitle: Text(
                                line['barcode'] ?? '',
                                textDirection: TextDirection.ltr,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    time,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    date2,
                                    style: const TextStyle(
                                      color: Colors.black45,
                                      fontSize: 11,
                                    ),
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
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black45),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
