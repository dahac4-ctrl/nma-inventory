import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  final String type; // 'جرد' أو 'تحويلات'

  const OperationsScreen({super.key, required this.type});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  List<Map<String, dynamic>> _operations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOperations();
  }

  Future<void> _loadOperations() async {
    setState(() => _isLoading = true);
    try {
      String filter;
      if (widget.type == 'جرد') {
        filter = 'session_type=eq.جرد';
      } else {
        filter = 'or=(session_type.eq.استلام,session_type.eq.تسليم)';
      }

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
          _isLoading = false;
        });
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
        await _loadOperations();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  String _generateName(String type, Map<String, String> fields) {
    final date = DateTime.now().toString().substring(0, 10);
    if (type == 'جرد') {
      return 'جرد - ${fields['branch']} - $date';
    } else {
      return '$type - ${fields['branch_from']} إلى ${fields['branch_to']} - $date';
    }
  }

  void _showNewOperationDialog() {
    final employeeController = TextEditingController();
    final branchController = TextEditingController();
    final branchFromController = TextEditingController();
    final branchToController = TextEditingController();
    final referenceController = TextEditingController();
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
                  // نوع التحويل (فقط في التحويلات)
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

                  // حقول الجرد
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

                  // حقول التحويلات
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

  @override
  Widget build(BuildContext context) {
    final isJard = widget.type == 'جرد';
    final color = isJard ? Colors.blue.shade700 : Colors.orange;

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
              onPressed: _loadOperations,
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
            : _operations.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isJard ? Icons.inventory_2 : Icons.swap_horiz,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد عمليات بعد\nاضغط + لإنشاء عملية جديدة',
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
                onRefresh: _loadOperations,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _operations.length,
                  itemBuilder: (context, index) {
                    final op = _operations[index];
                    return _OperationCard(
                      operation: op,
                      color: color,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SessionDetailScreen(session: op),
                          ),
                        );
                        _loadOperations();
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  final Map<String, dynamic> operation;
  final Color color;
  final VoidCallback onTap;

  const _OperationCard({
    required this.operation,
    required this.color,
    required this.onTap,
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
    final date = operation['started_at'] != null
        ? operation['started_at'].toString().substring(0, 10)
        : '';

    String subtitle = '';
    if (type == 'جرد') subtitle = branch;
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
