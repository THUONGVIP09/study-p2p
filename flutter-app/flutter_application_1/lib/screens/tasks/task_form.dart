import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class TaskFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const TaskFormScreen({Key? key, this.initial}) : super(key: key);

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dueCtrl = TextEditingController();
  int? _priority;
  String _repeat = 'NONE';
  String _status = 'TODO';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _titleCtrl.text = init['title'] ?? '';
      _descCtrl.text = init['description'] ?? '';
      _repeat = init['repeat_rule'] ?? 'NONE';
      _status = init['status'] ?? 'TODO';
      _dueCtrl.text = init['due_date'] ?? '';
      _priority = (init['priority'] is int) ? init['priority'] as int : null;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _dueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Create Task' : 'Edit Task'),
        actions: [
          if (widget.initial != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final id = widget.initial!['id'];
                final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                          title: const Text('Delete task?'),
                          content: const Text(
                              'This will permanently delete the task.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(c).pop(false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.of(c).pop(true),
                                child: const Text('Delete')),
                          ],
                        ));
                if (confirmed == true) {
                  try {
                    await ApiService.deleteTask(id: id as int);
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Delete failed: $e')));
                  }
                }
              },
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dueCtrl,
                readOnly: true,
                decoration:
                    const InputDecoration(labelText: 'Due date (yyyy-MM-dd)'),
                onTap: () async {
                  final now = DateTime.now();
                  DateTime initialDate = now;
                  if (_dueCtrl.text.isNotEmpty) {
                    try {
                      initialDate = DateTime.parse(_dueCtrl.text);
                    } catch (_) {}
                  }
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100));
                  if (picked != null) {
                    _dueCtrl.text = picked.toIso8601String().split('T').first;
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Priority:'),
                const SizedBox(width: 8),
                DropdownButton<int?>(
                  value: _priority,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(value: 1, child: Text('1')),
                    DropdownMenuItem(value: 2, child: Text('2')),
                    DropdownMenuItem(value: 3, child: Text('3')),
                    DropdownMenuItem(value: 4, child: Text('4')),
                    DropdownMenuItem(value: 5, child: Text('5')),
                  ],
                  onChanged: (v) => setState(() => _priority = v),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Repeat:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                    value: _repeat,
                    items: const [
                      DropdownMenuItem(value: 'NONE', child: Text('None')),
                      DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                      DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _repeat = v);
                    }),
              ]),
              const SizedBox(height: 12),
              // Status dropdown
              Row(children: [
                const Text('Status:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'TODO', child: Text('TODO')),
                    DropdownMenuItem(value: 'DOING', child: Text('DOING')),
                    DropdownMenuItem(value: 'DONE', child: Text('DONE')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                ),
              ]),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _saving = true);
                        try {
                          if (widget.initial == null) {
                            await ApiService.createTask(
                              title: _titleCtrl.text.trim(),
                              description: _descCtrl.text.trim(),
                              dueDate:
                                  _dueCtrl.text.isEmpty ? null : _dueCtrl.text,
                              repeatRule: _repeat,
                              status: _status,
                              priority: _priority,
                            );
                          } else {
                            final id = widget.initial!['id'] as int;
                            await ApiService.updateTask(
                              id: id,
                              title: _titleCtrl.text.trim(),
                              description: _descCtrl.text.trim(),
                              dueDate:
                                  _dueCtrl.text.isEmpty ? null : _dueCtrl.text,
                              repeatRule: _repeat,
                              status: _status,
                              priority: _priority,
                            );
                          }
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
