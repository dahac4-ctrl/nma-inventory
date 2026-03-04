import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:http/http.dart' as http;
import 'dart:convert';

const _apiUrl = 'https://zcwkvadhdxwpdrjidwea.supabase.co/rest/v1/products';
const _whUrl = 'https://zcwkvadhdxwpdrjidwea.supabase.co/rest/v1/warehouses';
const _apiKey = 'sb_publishable_mnREAEDOrm_vnZTg4cUhlQ_r2zyl9IL';
const _jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTc3MjUwNjgwNCwiZXhwIjo5OTk5OTk5OTk5fQ.EuYLr1GXZwBvV4AP6ndkS8Hg8UWnsKaHWTkVZIOEYQA';

Map<String, String> get _reqHeaders => {
  'apikey': _apiKey,
  'Authorization': 'Bearer $_jwt',
  'Content-Type': 'application/json',
  'Prefer': 'return=representation',
};

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool _importing = false;
  String _status = '';
  List<Map<String, dynamic>> _warehouses = [];
  Map<String, dynamic>? _selectedWarehouse;
  bool _loadingWarehouses = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    setState(() => _loadingWarehouses = true);
    try {
      final response = await http.get(
        Uri.parse('$_whUrl?order=created_at.desc'),
        headers: _reqHeaders,
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _warehouses = List<Map<String, dynamic>>.from(data);
          _loadingWarehouses = false;
        });
      }
    } catch (e) {
      setState(() => _loadingWarehouses = false);
    }
  }

  Future<void> _createWarehouse() async {
    final controller = TextEditingController();
    final locationController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة مستودع جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم المستودع *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: 'الموقع (اختياري)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
              child: const Text('إضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != true || controller.text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(_whUrl),
        headers: _reqHeaders,
        body: jsonEncode({
          'name': controller.text.trim(),
          'location': locationController.text.trim(),
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newWh = data is List ? data[0] : data;
        setState(() {
          _warehouses.insert(0, newWh);
          _selectedWarehouse = newWh;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _importProducts() async {
    if (_selectedWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ اختر مستودعاً أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return;

    final rows = sheet.rows;
    if (rows.isEmpty) return;

    final headers = rows.first
        .map((cell) => cell?.value?.toString() ?? '')
        .where((h) => h.isNotEmpty)
        .toList();
    final mappings = await _showColumnMappingDialog(headers);
    if (mappings == null) return;

    setState(() {
      _importing = true;
      _status = 'جاري تحضير البيانات...';
    });

    // بناء كل المنتجات دفعة واحدة
    final List<Map<String, dynamic>> products = [];

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

      final extraFields = <String, dynamic>{};
      final customFields = mappings.entries.where(
        (e) => e.key.startsWith('custom_'),
      );
      for (final cf in customFields) {
        final fieldName = cf.key.replaceFirst('custom_', '');
        final val = getVal(cf.value);
        if (val.isNotEmpty) extraFields[fieldName] = val;
      }

      final product = <String, dynamic>{
        'barcode': barcode,
        'name': name,
        'warehouse_id': _selectedWarehouse!['id'],
      };

      final qty = getVal(mappings['quantity'] ?? '');
      if (qty.isNotEmpty) product['quantity'] = double.tryParse(qty) ?? 0;

      final unit = getVal(mappings['unit'] ?? '');
      if (unit.isNotEmpty) product['unit'] = unit;

      if (extraFields.isNotEmpty) product['extra_fields'] = extraFields;

      products.add(product);
    }

    if (products.isEmpty) {
      setState(() {
        _importing = false;
        _status = 'لا توجد بيانات للاستيراد';
      });
      return;
    }

    setState(() => _status = 'جاري رفع ${products.length} منتج...');

    // إرسال دفعات بحجم 500 لكل مرة
    int success = 0;
    int errors = 0;
    const batchSize = 500;

    for (int i = 0; i < products.length; i += batchSize) {
      final batch = products.sublist(
        i,
        i + batchSize > products.length ? products.length : i + batchSize,
      );
      try {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {..._reqHeaders, 'Prefer': 'return=minimal'},
          body: jsonEncode(batch),
        );
        if (response.statusCode == 201 || response.statusCode == 200) {
          success += batch.length;
        } else {
          errors += batch.length;
        }
      } catch (e) {
        errors += batch.length;
      }
      setState(() => _status = 'تم رفع $success من ${products.length}...');
    }

    setState(() {
      _importing = false;
      _status =
          'اكتمل: $success منتج ✅${errors > 0 ? '  |  $errors أخطاء' : ''}';
    });
  }

  Future<Map<String, String>?> _showColumnMappingDialog(
    List<String> headers,
  ) async {
    final headersWithIgnore = ['__تجاهل__', ...headers];
    String barcodeCol = headers.isNotEmpty ? headers.first : '__تجاهل__';
    String nameCol = headers.isNotEmpty ? headers.first : '__تجاهل__';
    String quantityCol = '__تجاهل__';
    String unitCol = '__تجاهل__';
    final customFields = <Map<String, String>>[];

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
                    required: true,
                    onChanged: (v) => setDialogState(() => barcodeCol = v!),
                  ),
                  const SizedBox(height: 10),
                  _FieldDropdown(
                    label: 'اسم المنتج *',
                    value: nameCol,
                    items: headers,
                    required: true,
                    onChanged: (v) => setDialogState(() => nameCol = v!),
                  ),
                  const SizedBox(height: 10),
                  _FieldDropdown(
                    label: 'الكمية',
                    value: quantityCol,
                    items: headersWithIgnore,
                    required: false,
                    onChanged: (v) => setDialogState(() => quantityCol = v!),
                  ),
                  const SizedBox(height: 10),
                  _FieldDropdown(
                    label: 'الوحدة',
                    value: unitCol,
                    items: headersWithIgnore,
                    required: false,
                    onChanged: (v) => setDialogState(() => unitCol = v!),
                  ),
                  const Divider(height: 24),
                  ...customFields.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final cf = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'اسم الحقل',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (v) => setDialogState(
                                () => customFields[idx]['name'] = v,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: cf['col'],
                              decoration: const InputDecoration(
                                labelText: 'العمود',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              items: headersWithIgnore
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
                              onChanged: (v) => setDialogState(
                                () => customFields[idx]['col'] = v!,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => setDialogState(
                              () => customFields.removeAt(idx),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => setDialogState(
                      () => customFields.add({
                        'name': '',
                        'col': headersWithIgnore.first,
                      }),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة حقل مخصص'),
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
                onPressed: () {
                  final result = <String, String>{
                    'barcode': barcodeCol,
                    'name': nameCol,
                    'quantity': quantityCol,
                    'unit': unitCol,
                  };
                  for (final cf in customFields) {
                    final name = cf['name'] ?? '';
                    final col = cf['col'] ?? '__تجاهل__';
                    if (name.isNotEmpty && col != '__تجاهل__')
                      result['custom_$name'] = col;
                  }
                  Navigator.pop(context, result);
                },
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          title: const Text(
            'استيراد المنتجات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadWarehouses,
            ),
          ],
        ),
        body: _loadingWarehouses
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اختيار المستودع
                    const Text(
                      'المستودع',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Map<String, dynamic>>(
                                value: _selectedWarehouse,
                                hint: const Text('اختر مستودع'),
                                isExpanded: true,
                                items: _warehouses
                                    .map(
                                      (wh) => DropdownMenuItem(
                                        value: wh,
                                        child: Text(wh['name'] ?? ''),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedWarehouse = v),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _createWarehouse,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'جديد',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),

                    if (_selectedWarehouse != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warehouse,
                              color: Colors.blue,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'المستودع المختار: ${_selectedWarehouse!['name']}',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    Center(
                      child: Icon(
                        Icons.upload_file,
                        size: 80,
                        color: Colors.blue.shade200,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'استيراد المنتجات من Excel',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'اختر ملف Excel يحتوي على بيانات المنتجات',
                        style: TextStyle(color: Colors.black45),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_importing)
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(_status, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      )
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _importProducts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.upload_file,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'اختر ملف Excel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (_status.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _status,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _FieldDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final bool required;
  final ValueChanged<String?> onChanged;

  const _FieldDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.required,
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
