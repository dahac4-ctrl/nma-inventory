import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_detail_screen.dart';

const supabaseUrl = 'https://zcwkvadhdxwpdrjidwea.supabase.co';
const supabaseKey = 'sb_publishable_mnREAEDOrm_vnZTg4cUhlQ_r2zyl9IL';
const supabaseJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTc3MjUwNjgwNCwiZXhwIjo5OTk5OTk5OTk5fQ.EuYLr1GXZwBvV4AP6ndkS8Hg8UWnsKaHWTkVZIOEYQA';

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
    'Authorization': 'Bearer $supabaseJwt',
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
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createSession(Map<String, dynamic> sessionData) async {
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/inventory_sessions'),
        headers: _headers,
        body: jsonEncode(sessionData),
      );
      if (response.statusCode == 201) {
        await _loadSessions();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _showNewSessionDialog() {
    final nameController = TextEditingController();
    final employeeController = TextEditingController();
    final branchController = TextEditingController();
    final branchFromController = TextEditingController();
    final branchToController = TextEditingController();
    final referenceController = TextEditingController();
    String selectedType = 'جرد';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('جلسة جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // اسم الجلسة
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'اسم الجلسة *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // نوع الجلسة
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'نوع الجلسة *',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: ['جرد', 'استلام', 'تسليم'].map((type) {
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedType = type),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedType == type
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedType == type
                                    ? Colors.blue.shade700
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

                  // حقول حسب النوع
                  if (selectedType == 'جرد') ...[
                    TextField(
                      controller: branchController,
                      decoration: const InputDecoration(
                        labelText: 'الفرع *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
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
                  ],
                  const SizedBox(height: 12),

                  // اسم الموظف
                  TextField(
                    controller: employeeController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الموظف *',
                      border: OutlineInputBorder(),
                    ),
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
                  // التحقق من الحقول
                  if (nameController.text.isEmpty ||
                      employeeController.text.isEmpty)
                    return;
                  if (selectedType == 'جرد' && branchController.text.isEmpty)
                    return;
                  if (selectedType != 'جرد' &&
                      (branchFromController.text.isEmpty ||
                          branchToController.text.isEmpty ||
                          referenceController.text.isEmpty))
                    return;

                  final sessionData = <String, dynamic>{
                    'name': nameController.text,
                    'status': 'open',
                    'session_type': selectedType,
                    'employee_name': employeeController.text,
                    'started_at': DateTime.now().toIso8601String(),
                  };

                  if (selectedType == 'جرد') {
                    sessionData['branch'] = branchController.text;
                  } else {
                    sessionData['branch_from'] = branchFromController.text;
                    sessionData['branch_to'] = branchToController.text;
                    sessionData['reference_no'] = referenceController.text;
                  }

                  Navigator.pop(context);
                  _createSession(sessionData);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
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
    final type = session['session_type'] ?? '';
    final employee = session['employee_name'] ?? '';

    // لون حسب النوع
    Color typeColor = Colors.blue;
    IconData typeIcon = Icons.inventory;
    if (type == 'استلام') {
      typeColor = Colors.green;
      typeIcon = Icons.download;
    }
    if (type == 'تسليم') {
      typeColor = Colors.orange;
      typeIcon = Icons.upload;
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
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor),
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
                        if (type.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 11,
                                color: typeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (employee.isNotEmpty) ...[
                          const Icon(
                            Icons.person,
                            size: 12,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            employee,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 2),
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
