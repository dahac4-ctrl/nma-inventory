import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'local_db.dart';
import 'settings_provider.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Map<String, dynamic>> _scannedItems = [];
  String _lastScanned = '';
  bool _isProcessing = false;
  bool _isOnline = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadExistingLines();
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      setState(() => _isOnline = online);
      if (online) _syncPending();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(bool success) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.soundEnabled) return;
    await _audioPlayer.play(
      AssetSource(
        success ? 'sounds/beep_success.wav' : 'sounds/beep_warning.wav',
      ),
    );
  }

  Future<void> _vibrate() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.vibrationEnabled) return;
    HapticFeedback.lightImpact();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    setState(
      () => _isOnline = results.any((r) => r != ConnectivityResult.none),
    );
    if (_isOnline) _syncPending();
  }

  Future<void> _syncPending() async {
    final pending = await LocalDb.getAllPending();
    if (pending.isEmpty) return;
    for (final scan in pending) {
      try {
        final response = await http.post(
          Uri.parse('$_supabaseUrl/rest/v1/inventory_lines'),
          headers: _headers,
          body: jsonEncode({
            'session_id': scan['session_id'],
            'barcode': scan['barcode'],
            'product_name': scan['product_name'],
            'scanned_qty': scan['scanned_qty'],
            'scanned_at': scan['scanned_at'],
          }),
        );
        if (response.statusCode == 201)
          await LocalDb.markSynced(scan['id'] as int);
      } catch (e) {
        debugPrint('Sync error: $e');
      }
    }
    final remaining = await LocalDb.getAllPending();
    setState(() => _pendingCount = remaining.length);
    if (remaining.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم مزامنة جميع البيانات'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<String> _getProductName(String barcode) async {
    if (!_isOnline) return '';
    try {
      final response = await http.get(
        Uri.parse(
          '$_supabaseUrl/rest/v1/products?barcode=eq.$barcode&select=name',
        ),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) return data.first['name'] ?? '';
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    return '';
  }

  Future<void> _loadExistingLines() async {
    try {
      if (_isOnline) {
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
                'date': line['scanned_at'] != null
                    ? line['scanned_at'].toString().substring(0, 10)
                    : '',
                'id': line['id'],
                'local_id': null,
                'synced': true,
                'known': true,
              });
            }
          });
        }
      } else {
        final pending = await LocalDb.getPendingScans(widget.sessionId);
        setState(() {
          _scannedItems.clear();
          for (var scan in pending) {
            _scannedItems.add({
              'barcode': scan['barcode'],
              'name': scan['product_name'] ?? 'صنف - ${scan['barcode']}',
              'qty': scan['scanned_qty'] ?? 1,
              'time': scan['scanned_at'].toString().length >= 19
                  ? scan['scanned_at'].toString().substring(11, 16)
                  : '',
              'date': scan['scanned_at'].toString().length >= 10
                  ? scan['scanned_at'].toString().substring(0, 10)
                  : '',
              'id': null,
              'local_id': scan['id'],
              'synced': false,
              'known': false,
            });
          }
        });
      }
      final pending = await LocalDb.getAllPending();
      setState(() => _pendingCount = pending.length);
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

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final productName = await _getProductName(barcode);
    final isKnown = productName.isNotEmpty;

    // تطبيق إعداد الصنف غير المعروف
    if (!isKnown) {
      if (settings.unknownBarcodeAction == 'reject') {
        // رفض المسح
        await _playSound(false);
        await _vibrate();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⛔ تم رفض المسح — الصنف غير معروف'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() => _isProcessing = false);
        _barcodeController.clear();
        _barcodeFocus.requestFocus();
        return;
      }

      if (settings.unknownBarcodeAction == 'ask') {
        // اسأل الموظف عن الاسم
        await _playSound(false);
        await _vibrate();
        final name = await _showAskNameDialog(barcode);
        if (name == null) {
          // ألغى الموظف
          setState(() => _isProcessing = false);
          _barcodeController.clear();
          _barcodeFocus.requestFocus();
          return;
        }
        await _saveScan(
          barcode,
          name.isNotEmpty ? name : 'صنف - $barcode',
          false,
        );
        setState(() => _isProcessing = false);
        _barcodeController.clear();
        _barcodeFocus.requestFocus();
        await _vibrate();
        return;
      }
    }

    // حفظ عادي
    final finalName = isKnown ? productName : 'صنف - $barcode';
    await _playSound(isKnown);
    await _saveScan(barcode, finalName, isKnown);

    setState(() => _isProcessing = false);
    _barcodeController.clear();
    _barcodeFocus.requestFocus();
    await _vibrate();
  }

  Future<String?> _showAskNameDialog(String barcode) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('صنف غير معروف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الباركود: $barcode',
                style: const TextStyle(color: Colors.black45, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم الصنف (اختياري)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveScan(String barcode, String name, bool isKnown) async {
    final now = DateTime.now();
    final nowStr = now.toIso8601String();

    if (_isOnline) {
      try {
        final response = await http.post(
          Uri.parse('$_supabaseUrl/rest/v1/inventory_lines'),
          headers: _headers,
          body: jsonEncode({
            'session_id': widget.sessionId,
            'barcode': barcode,
            'product_name': name,
            'scanned_qty': 1,
            'scanned_at': nowStr,
          }),
        );
        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final newLine = data is List ? data[0] : data;
          setState(() {
            _scannedItems.insert(0, {
              'barcode': barcode,
              'name': name,
              'qty': 1,
              'time': now.toString().substring(11, 16),
              'date': now.toString().substring(0, 10),
              'id': newLine['id'],
              'local_id': null,
              'synced': true,
              'known': isKnown,
            });
          });
        }
      } catch (e) {
        debugPrint('Error saving scan: $e');
      }
    } else {
      final localId = await LocalDb.insertScan({
        'session_id': widget.sessionId,
        'barcode': barcode,
        'product_name': name,
        'scanned_qty': 1,
        'scanned_at': nowStr,
        'synced': 0,
      });
      setState(() {
        _scannedItems.insert(0, {
          'barcode': barcode,
          'name': name,
          'qty': 1,
          'time': now.toString().substring(11, 16),
          'date': now.toString().substring(0, 10),
          'id': null,
          'local_id': localId,
          'synced': false,
          'known': isKnown,
        });
        _pendingCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: _isOnline
              ? Colors.blue.shade700
              : Colors.grey.shade700,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.sessionName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    color: _isOnline ? Colors.greenAccent : Colors.orangeAccent,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isOnline
                        ? 'متصل'
                        : 'غير متصل${_pendingCount > 0 ? ' • $_pendingCount في الانتظار' : ''}',
                    style: TextStyle(
                      color: _isOnline
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
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
                  '${_scannedItems.length} مسح',
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
            if (!_isOnline)
              Container(
                width: double.infinity,
                color: Colors.orange.shade100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'وضع عدم الاتصال — البيانات محفوظة محلياً وستُرفع تلقائياً عند الاتصال',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                    label: 'عمليات المسح',
                    value: '${_scannedItems.length}',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'أصناف مختلفة',
                    value:
                        '${_scannedItems.map((e) => e['barcode']).toSet().length}',
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
                            if (item['synced'] == true && item['id'] != null) {
                              await http.delete(
                                Uri.parse(
                                  '$_supabaseUrl/rest/v1/inventory_lines?id=eq.${item['id']}',
                                ),
                                headers: _headers,
                              );
                            } else if (item['local_id'] != null) {
                              await LocalDb.deleteScan(item['local_id'] as int);
                              setState(() => _pendingCount--);
                            }
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
    final isSynced = item['synced'] == true;
    final isKnown = item['known'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isKnown
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.qr_code,
                color: isKnown ? Colors.blue : Colors.red,
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
                  if (!isKnown)
                    const Text(
                      '⚠️ صنف غير معرف',
                      style: TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  if (!isSynced)
                    const Text(
                      '⏳ في انتظار المزامنة',
                      style: TextStyle(color: Colors.orange, fontSize: 11),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item['time'],
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  item['date'],
                  style: const TextStyle(color: Colors.black38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(width: 4),
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
