import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:http/http.dart' as http;
import 'dart:convert';

const _apiUrl = 'https://zcwkvadhdxwpdrjidwea.supabase.co/rest/v1/products';
const _apiKey = 'sb_publishable_mnREAEDOrm_vnZTg4cUhlQ_r2zyl9IL';
const _jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTc3MjUwNjgwNCwiZXhwIjo5OTk5OTk5OTk5fQ.EuYLr1GXZwBvV4AP6ndkS8Hg8UWnsKaHWTkVZIOEYQA';

Map<String, String> get _reqHeaders => {
  'apikey': _apiKey,
  'Authorization': 'Bearer $_jwt',
  'Content-Type': 'application/json',
  'Prefer': 'return=minimal',
};

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool _importing = false;
  String _status = '';

  Future<void> _importProducts() async {
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
      _status = 'جاري الاستيراد...';
    });

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

      // الحقول المخصصة
      final extraFields = <String, dynamic>{};
      final customFields = mappings.entries.where(
        (e) => e.key.startsWith('custom_'),
      );
      for (final cf in customFields) {
        final fieldName = cf.key.replaceFirst('custom_', '');
        final val = getVal(cf.value);
        if (val.isNotEmpty) extraFields[fieldName] = val;
      }

      final product = <String, dynamic>{'barcode': barcode, 'name': name};

      final qty = getVal(mappings['quantity'] ?? '');
      if (qty.isNotEmpty) product['quantity'] = double.tryParse(qty) ?? 0;

      final unit = getVal(mappings['unit'] ?? '');
      if (unit.isNotEmpty) product['unit'] = unit;

      if (extraFields.isNotEmpty) product['extra_fields'] = extraFields;

      try {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: _reqHeaders,
          body: jsonEncode(product),
        );
        if (response.statusCode == 201 || response.statusCode == 200) {
          success++;
        } else {
          errors++;
        }
      } catch (e) {
        errors++;
      }

      setState(() => _status = 'تم استيراد $success منتج...');
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

    // الحقول الثابتة
    String barcodeCol = headers.isNotEmpty ? headers.first : '__تجاهل__';
    String nameCol = headers.isNotEmpty ? headers.first : '__تجاهل__';
    String quantityCol = '__تجاهل__';
    String unitCol = '__تجاهل__';

    // الحقول المخصصة
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

                  // الباركود
                  _FieldDropdown(
                    label: 'الباركود *',
                    value: barcodeCol,
                    items: headers,
                    required: true,
                    onChanged: (v) => setDialogState(() => barcodeCol = v!),
                  ),
                  const SizedBox(height: 10),

                  // اسم المنتج
                  _FieldDropdown(
                    label: 'اسم المنتج *',
                    value: nameCol,
                    items: headers,
                    required: true,
                    onChanged: (v) => setDialogState(() => nameCol = v!),
                  ),
                  const SizedBox(height: 10),

                  // الكمية
                  _FieldDropdown(
                    label: 'الكمية',
                    value: quantityCol,
                    items: headersWithIgnore,
                    required: false,
                    onChanged: (v) => setDialogState(() => quantityCol = v!),
                  ),
                  const SizedBox(height: 10),

                  // الوحدة
                  _FieldDropdown(
                    label: 'الوحدة',
                    value: unitCol,
                    items: headersWithIgnore,
                    required: false,
                    onChanged: (v) => setDialogState(() => unitCol = v!),
                  ),

                  const Divider(height: 24),

                  // الحقول المخصصة
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

                  // زر إضافة حقل مخصص
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
                    if (name.isNotEmpty && col != '__تجاهل__') {
                      result['custom_$name'] = col;
                    }
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
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, size: 80, color: Colors.blue.shade200),
                const SizedBox(height: 24),
                const Text(
                  'استيراد المنتجات من Excel',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اختر ملف Excel يحتوي على بيانات المنتجات',
                  style: TextStyle(color: Colors.black45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_importing)
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_status, style: const TextStyle(fontSize: 16)),
                    ],
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
                      icon: const Icon(Icons.upload_file, color: Colors.white),
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
                          const Icon(Icons.check_circle, color: Colors.green),
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
