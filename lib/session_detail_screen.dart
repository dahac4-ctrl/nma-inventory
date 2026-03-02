import 'package:flutter/material.dart';
import 'scan_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Map<String, dynamic> _session;

  @override
  void initState() {
    super.initState();
    _session = Map.from(widget.session);
  }

  void _lockSession() {
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
              onPressed: () {
                setState(() {
                  _session['status'] = 'closed';
                });
                Navigator.pop(context);
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          title: Text(
            _session['name'],
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
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // بطاقة معلومات الجلسة
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
                        value: _session['date'],
                        valueColor: Colors.black87,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.qr_code_scanner,
                        label: 'إجمالي الأصناف',
                        value: '${_session['count']} صنف',
                        valueColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // أزرار الإجراءات
              if (isOpen) ...[
                // زر ابدأ المسح
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScanScreen(
                            sessionName: _session['name'],
                            sessionId: _session['id'],
                          ),
                        ),
                      );
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

                // زر إغلاق الجلسة
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
                // الجلسة مغلقة
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
                        'الجلسة مغلقة — لا يمكن المسح',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // عنوان آخر المسح
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

              // قائمة فارغة مؤقتاً
              Expanded(
                child: Center(
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
