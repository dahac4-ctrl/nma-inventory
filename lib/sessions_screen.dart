import 'package:flutter/material.dart';
import 'session_detail_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final List<Map<String, dynamic>> _sessions = [
    {
      'id': '1',
      'name': 'جرد المستودع A',
      'date': '2026-03-03',
      'status': 'open',
      'count': 24,
    },
    {
      'id': '2',
      'name': 'استلام بضاعة مارس',
      'date': '2026-03-02',
      'status': 'closed',
      'count': 156,
    },
    {
      'id': '3',
      'name': 'جرد نهاية الشهر',
      'date': '2026-03-01',
      'status': 'closed',
      'count': 89,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          title: const Text(
            'الجلسات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showNewSessionDialog,
          backgroundColor: Colors.blue.shade700,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'جلسة جديدة',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: _sessions.isEmpty
            ? const Center(
                child: Text(
                  'لا توجد جلسات بعد\nاضغط + لإنشاء جلسة جديدة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black45, fontSize: 16),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  return _SessionCard(
                    session: session,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(session: session),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showNewSessionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('جلسة جديدة'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'اسم الجلسة',
              hintText: 'مثال: جرد المستودع A',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _sessions.insert(0, {
                      'id': DateTime.now().toString(),
                      'name': controller.text,
                      'date': DateTime.now().toString().substring(0, 10),
                      'status': 'open',
                      'count': 0,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
              child: const Text('إنشاء', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOpen = session['status'] == 'open';

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
                  color: isOpen
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOpen ? Icons.lock_open : Icons.lock,
                  color: isOpen ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session['date'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.qr_code_scanner,
                          size: 12,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${session['count']} صنف',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            ],
          ),
        ),
      ),
    );
  }
}
