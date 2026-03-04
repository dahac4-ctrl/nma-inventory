import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'session_detail_screen.dart';

const _opsUrl = 'https://zcwkvadhdxwpdrjidwea.supabase.co';
const _opsKey = 'sb_publishable_mnREAEDOrm_vnZTg4cUhlQ_r2zyl9IL';
const _opsJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTc3MjUwNjgwNCwiZXhwIjo5OTk5OTk5OTk5fQ.EuYLr1GXZwBvV4AP6ndkS8Hg8UWnsKaHWTkVZIOEYQA';

Map<String, String> get _opsHeaders => {
  'apikey': _opsKey,
  'Authorization': 'Bearer $_opsJwt',
  'Content-Type': 'application/json',
  'Prefer': 'return=representation',
};

class OperationsScreen extends StatefulWidget {
  final String type;
  const OperationsScreen({super.key, required this.type});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  List<Map<String, dynamic>> _operations = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, Map<String, int>> _scanCounts = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'الكل';
  String _dateFilter = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadOperations();
    await _loadScanCounts();
  }

  Future<void> _loadScanCounts() async {
    try {
      final response = await http.get(
        Uri.parse('$_opsUrl/rest/v1/session_scan_counts'),
        headers: _opsHeaders,
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final Map<String, Map<String, int>> counts = {};
        for (final item in data) {
          counts[item['session_id'].toString()] = {
            'total_scans': (item['total_scans'] ?? 0) as int,
            'unique_products': (item['unique_products'] ?? 0) as int,
          };
        }
        setState(() => _scanCounts = counts);
      }
    } catch (e) {
      debugPrint('Error loading counts: $e');
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final now = DateTime.now();
    setState(() {
      _filtered = _operations.where((op) {
        final name = (op['name'] ?? '').toLowerCase();
        final employee = (op['employee_name'] ?? '').toLowerCase();
        final branch = (op['branch'] ?? '').toLowerCase();
        final branchFrom = (op['branch_from'] ?? '').toLowerCase();
        final branchTo = (op['branch_to'] ?? '').toLowerCase();
        final refNo = (op['reference_no'] ?? '').toLowerCase();
        final matchSearch =
            query.isEmpty ||
            name.contains(query) ||
            employee.contains(query) ||
            branch.contains(query) ||
            branchFrom.contains(query) ||
            branchTo.contains(query) ||
            refNo.contains(query);
        final matchStatus =
            _statusFilter == 'الكل' ||
            (_statusFilter == 'مفتوحة' && op['status'] == 'open') ||
            (_statusFilter == 'مغلقة' && op['status'] == 'closed');
        bool matchDate = true;
        if (_dateFilter != 'الكل' && op['started_at'] != null) {
          final opDate = DateTime.tryParse(op['started_at']) ?? now;
          if (_dateFilter == 'اليوم')
            matchDate =
                opDate.year == now.year &&
                opDate.month == now.month &&
                opDate.day == now.day;
          else if (_dateFilter == 'هذا الأسبوع')
            matchDate = opDate.isAfter(now.subtract(const Duration(days: 7)));
          else if (_dateFilter == 'هذا الشهر')
            matchDate = opDate.year == now.year && opDate.month == now.month;
        }
        return matchSearch && matchStatus && matchDate;
      }).toList();
    });
  }

  Future<void> _loadOperations() async {
    setState(() => _isLoading = true);
    try {
      String filter = widget.type == 'جرد'
          ? 'session_type=eq.جرد'
          : 'or=(session_type.eq.استلام,session_type.eq.تسليم)';
      final response = await http.get(
        Uri.parse(
          '$_opsUrl/rest/v1/inventory_sessions?$filter&order=started_at.desc',
        ),
        headers: _opsHeaders,
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _operations = List<Map<String, dynamic>>.from(data);
          _filtered = _operations;
          _isLoading = false;
        });
        _applyFilters();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createOperation(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_opsUrl/rest/v1/inventory_sessions'),
        headers: _opsHeaders,
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final newSession = responseData is List
            ? responseData[0]
            : responseData;
        await _loadAll();

        // سؤال الاستيراد
        if (mounted) _showImportDialog(newSession);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _showImportDialog(Map<String, dynamic> session) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('تم إنشاء العملية'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${session['name']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'هل تريد استيراد قائمة الأصناف؟',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              const Text(
                'يمكنك استيراد ملف Excel يحتوي على الأصناف والكميات المتوقعة لهذه العملية',
                style: TextStyle(color: Colors.black38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openSession(session);
              },
              child: const Text(
                'تخطي — ابدأ المسح',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _importForSession(session);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(
                Icons.upload_file,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'استيراد Excel',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSession(Map<String, dynamic> session) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session)),
    ).then((_) => _loadAll());
  }

  Future<void> _importForSession(Map<String, dynamic> session) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null) {
      _openSession(session);
      return;
    }

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      _openSession(session);
      return;
    }

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) {
      _openSession(session);
      return;
    }

    final rows = sheet.rows;
    if (rows.isEmpty) {
      _openSession(session);
      return;
    }

    final headers = rows.first
        .map((cell) => cell?.value?.toString() ?? '')
        .where((h) => h.isNotEmpty)
        .toList();
    final mappings = await _showColumnMappingDialog(headers);
    if (mappings == null) {
      _openSession(session);
      return;
    }

    // شاشة التحميل
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('جاري الاستيراد...'),
              ],
            ),
          ),
        ),
      );
    }

    int success = 0;
    int errors = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell == null || cell.value == null)) continue;

      String getVal(String colName) {
        if (colName == '__تجاهل__') return '';
        final idx = headers.indexOf(colName);
        if (idx == -1 || idx >= row.length) return '';
        return row[idx]?.value?.toString() ?? '';
      }

      final barcode = getVal(mappings['barcode'] ?? '');
      final name = getVal(mappings['name'] ?? '');
      if (barcode.isEmpty) continue;

      final product = <String, dynamic>{
        'barcode': barcode,
        'name': name,
        'warehouse_id': session['warehouse_id'],
      };

      final qty = getVal(mappings['quantity'] ?? '');
      if (qty.isNotEmpty) product['quantity'] = double.tryParse(qty) ?? 0;

      final unit = getVal(mappings['unit'] ?? '');
      if (unit.isNotEmpty) product['unit'] = unit;

      try {
        final response = await http.post(
          Uri.parse('$_opsUrl/rest/v1/products'),
          headers: _opsHeaders,
          body: jsonEncode(product),
        );
        if (response.statusCode == 201 || response.statusCode == 200)
          success++;
        else
          errors++;
      } catch (e) {
        errors++;
      }
    }

    if (mounted) Navigator.pop(context); // أغلق loading

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ تم استيراد $success صنف${errors > 0 ? ' | $errors أخطاء' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }

    _openSession(session);
  }

  Future<Map<String, String>?> _showColumnMappingDialog(
    List<String> headers,
  ) async {
    final headersWithIgnore = ['__تجاهل__', ...headers];
    String barcodeCol = headers.isNotEmpty ? headers.first : '__تجاهل__';
    String nameCol = headers.isNotEmpty ? headers.first : '__تجاهل__';
    String quantityCol = '__تجاهل__';
    String unitCol = '__تجاهل__';

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('ربط الأعمدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اختر العمود المناسب لكل حقل:',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  _FieldDropdown(
                    label: 'الباركود *',
                    value: barcodeCol,
                    items: headers,
                    onChanged: (v) => setDialogState(() => barcodeCol = v!),
                  ),
                  const SizedBox(height: 10),
                  _FieldDropdown(
                    label: 'اسم المنتج *',
                    value: nameCol,
                    items: headers,
                    onChanged: (v) => setDialogState(() => nameCol = v!),
                  ),
                  const SizedBox(height: 10),
                  _FieldDropdown(
                    label: 'الكمية',
                    value: quantityCol,
                    items: headersWithIgnore,
                    onChanged: (v) => setDialogState(() => quantityCol = v!),
                  ),
                  const SizedBox(height: 10),
                  _FieldDropdown(
                    label: 'الوحدة',
                    value: unitCol,
                    items: headersWithIgnore,
                    onChanged: (v) => setDialogState(() => unitCol = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, {
                  'barcode': barcodeCol,
                  'name': nameCol,
                  'quantity': quantityCol,
                  'unit': unitCol,
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                ),
                child: const Text(
                  'استيراد',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateName(String type, Map<String, String> fields) {
    final date = DateTime.now().toString().substring(0, 10);
    if (type == 'جرد') return 'جرد - ${fields['branch']} - $date';
    return '$type - ${fields['branch_from']} إلى ${fields['branch_to']} - $date';
  }

  Future<void> _confirmDelete(Map<String, dynamic> op) async {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف العملية'),
          content: Text('هل أنت متأكد من حذف "${op['name']}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await http.delete(
                    Uri.parse(
                      '$_opsUrl/rest/v1/inventory_lines?session_id=eq.${op['id']}',
                    ),
                    headers: _opsHeaders,
                  );
                  await http.delete(
                    Uri.parse(
                      '$_opsUrl/rest/v1/inventory_sessions?id=eq.${op['id']}',
                    ),
                    headers: _opsHeaders,
                  );
                  await _loadAll();
                } catch (e) {
                  debugPrint('Error deleting: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewOperationDialog() {
    final employeeController = TextEditingController();
    final branchController = TextEditingController();
    final branchFromController = TextEditingController();
    final branchToController = TextEditingController();
    final referenceController = TextEditingController();
    final customFieldNameController = TextEditingController();
    final customFieldValueController = TextEditingController();
    String selectedType = widget.type == 'جرد' ? 'جرد' : 'استلام';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('عملية ${widget.type} جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.type == 'تحويلات') ...[
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'نوع العملية *',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: ['استلام', 'تسليم'].map((type) {
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedType = type),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedType == type
                                    ? Colors.orange
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selectedType == type
                                      ? Colors.orange
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: selectedType == type
                                        ? Colors.white
                                        : Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.type == 'جرد') ...[
                    TextField(
                      controller: branchController,
                      decoration: const InputDecoration(
                        labelText: 'الفرع *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.type == 'تحويلات') ...[
                    TextField(
                      controller: branchFromController,
                      decoration: const InputDecoration(
                        labelText: 'من فرع *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: branchToController,
                      decoration: const InputDecoration(
                        labelText: 'إلى فرع *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'رقم التحويل *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: employeeController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الموظف *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (widget.type == 'جرد') ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'حقل مخصص (اختياري)',
                        style: TextStyle(color: Colors.black45, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: customFieldNameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم الحقل',
                              hintText: 'مثال: لوكيشن',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: customFieldValueController,
                            decoration: const InputDecoration(
                              labelText: 'القيمة',
                              hintText: 'مثال: A1',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (employeeController.text.isEmpty) return;
                  if (widget.type == 'جرد' && branchController.text.isEmpty)
                    return;
                  if (widget.type == 'تحويلات' &&
                      (branchFromController.text.isEmpty ||
                          branchToController.text.isEmpty ||
                          referenceController.text.isEmpty))
                    return;

                  final fields = <String, String>{
                    'branch': branchController.text,
                    'branch_from': branchFromController.text,
                    'branch_to': branchToController.text,
                  };
                  final opData = <String, dynamic>{
                    'name': _generateName(selectedType, fields),
                    'status': 'open',
                    'session_type': selectedType,
                    'employee_name': employeeController.text,
                    'started_at': DateTime.now().toIso8601String(),
                  };
                  if (widget.type == 'جرد') {
                    opData['branch'] = branchController.text;
                    if (customFieldNameController.text.isNotEmpty) {
                      opData['custom_field_name'] =
                          customFieldNameController.text;
                      opData['custom_field_value'] =
                          customFieldValueController.text;
                    }
                  } else {
                    opData['branch_from'] = branchFromController.text;
                    opData['branch_to'] = branchToController.text;
                    opData['reference_no'] = referenceController.text;
                  }
                  Navigator.pop(context);
                  _createOperation(opData);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.type == 'جرد'
                      ? Colors.blue.shade700
                      : Colors.orange,
                ),
                child: const Text(
                  'إنشاء',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(
    String label,
    String current,
    void Function(String) onSelected,
    Color color,
  ) {
    final selected = current == label;
    return GestureDetector(
      onTap: () {
        onSelected(label);
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.black54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isJard = widget.type == 'جرد';
    final color = isJard ? Colors.blue.shade700 : Colors.orange;
    final hasActiveFilter = _statusFilter != 'الكل' || _dateFilter != 'الكل';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: color,
          title: Text(
            widget.type == 'جرد' ? 'عمليات الجرد' : 'التحويلات',
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
              onPressed: _loadAll,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showNewOperationDialog,
          backgroundColor: color,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'عملية جديدة',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'ابحث باسم العملية أو الموظف أو الفرع...',
                            prefixIcon: Icon(Icons.search, color: color),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _applyFilters();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: color, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              'الحالة:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ...['الكل', 'مفتوحة', 'مغلقة'].map(
                              (s) => _filterChip(
                                s,
                                _statusFilter,
                                (v) => setState(() => _statusFilter = v),
                                color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              'التاريخ:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ...[
                              'الكل',
                              'اليوم',
                              'هذا الأسبوع',
                              'هذا الشهر',
                            ].map(
                              (s) => _filterChip(
                                s,
                                _dateFilter,
                                (v) => setState(() => _dateFilter = v),
                                color,
                              ),
                            ),
                          ],
                        ),
                        if (hasActiveFilter) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _statusFilter = 'الكل';
                                _dateFilter = 'الكل';
                              });
                              _applyFilters();
                            },
                            child: const Text(
                              'مسح الفلاتر',
                              style: TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_filtered.length} عملية',
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 80,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد نتائج',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAll,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final op = _filtered[index];
                                final counts = _scanCounts[op['id'].toString()];
                                return _OperationCard(
                                  operation: op,
                                  color: color,
                                  totalScans: counts?['total_scans'] ?? 0,
                                  uniqueProducts:
                                      counts?['unique_products'] ?? 0,
                                  onDelete: () => _confirmDelete(op),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SessionDetailScreen(session: op),
                                      ),
                                    );
                                    _loadAll();
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FieldDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FieldDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items
          .map(
            (h) => DropdownMenuItem(
              value: h,
              child: Text(
                h == '__تجاهل__' ? 'تجاهل' : h,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _OperationCard extends StatelessWidget {
  final Map<String, dynamic> operation;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final int totalScans;
  final int uniqueProducts;

  const _OperationCard({
    required this.operation,
    required this.color,
    required this.onTap,
    required this.onDelete,
    required this.totalScans,
    required this.uniqueProducts,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = operation['status'] == 'open';
    final type = operation['session_type'] ?? '';
    final employee = operation['employee_name'] ?? '';
    final branch = operation['branch'] ?? '';
    final branchFrom = operation['branch_from'] ?? '';
    final branchTo = operation['branch_to'] ?? '';
    final refNo = operation['reference_no'] ?? '';
    final customName = operation['custom_field_name'] ?? '';
    final customValue = operation['custom_field_value'] ?? '';
    final date = operation['started_at'] != null
        ? operation['started_at'].toString().substring(0, 10)
        : '';

    String subtitle = '';
    if (type == 'جرد') {
      subtitle = branch;
      if (customName.isNotEmpty) subtitle += '  |  $customName: $customValue';
    }
    if (type == 'استلام' || type == 'تسليم') {
      subtitle = '$branchFrom ← $branchTo';
      if (refNo.isNotEmpty) subtitle += '  |  $refNo';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  type == 'جرد'
                      ? Icons.inventory_2
                      : type == 'استلام'
                      ? Icons.download
                      : Icons.upload,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operation['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (employee.isNotEmpty) ...[
                          const Icon(
                            Icons.person,
                            size: 12,
                            color: Colors.black38,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            employee,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.black38,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 12,
                          color: color.withOpacity(0.7),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$totalScans مسح',
                          style: TextStyle(
                            fontSize: 11,
                            color: color.withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.category,
                          size: 12,
                          color: Colors.green.withOpacity(0.7),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$uniqueProducts ${uniqueProducts == 1 ? 'صنف' : 'أصناف'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOpen ? 'مفتوحة' : 'مغلقة',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOpen ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isOpen) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'حذف',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
