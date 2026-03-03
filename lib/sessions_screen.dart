import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_detail_screen.dart';

const supabaseUrl = 'https://zcwkvadhdxwpdrjidwea.supabase.co';
const supabaseKey = 'sb_publishable_mnREAEDOrm_vnZTg4cUhlQ_r2zyl9IL';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Map<String, String> get _headers => {
    'apikey': supabaseKey,
    'Authorization':
        'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTc3MjUwNjgwNCwiZXhwIjo5OTk5OTk5OTk5fQ.EuYLr1GXZwBvV4AP6ndkS8Hg8UWnsKaHWTkVZIOEYQA',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/inventory_sessions?order=started_at.desc',
        ),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        debugPrint('Error: ${response.body}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error: $e');
    }
  }

  Future<void> _createSession(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/inventory_sessions'),
        headers: _headers,
        body: jsonEncode({'name': name, 'status': 'open', 'type': 'count'}),
      );
      if (response.statusCode == 201) {
        await _loadSessions();
      } else {
        debugPrint('Error creating: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
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
            'الجلسات',
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
              onPressed: _loadSessions,
            ),
          ],
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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _sessions.isEmpty
            ? const Center(
                child: Text(
                  'لا توجد جلسات بعد\nاضغط + لإنشاء جلسة جديدة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black45, fontSize: 16),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadSessions,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return _SessionCard(
                      session: session,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SessionDetailScreen(session: session),
                          ),
                        );
                        _loadSessions();
                      },
                    );
                  },
                ),
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
                  Navigator.pop(context);
                  _createSession(controller.text);
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
    final date = session['started_at'] != null
        ? session['started_at'].toString().substring(0, 10)
        : '';

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
                      session['name'] ?? '',
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
                          date,
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
