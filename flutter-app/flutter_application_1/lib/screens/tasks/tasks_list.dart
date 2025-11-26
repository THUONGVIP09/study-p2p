import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'task_form.dart';

String _formatDateShort(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso.toString());
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return iso.toString();
  }
}

class TasksListScreen extends StatefulWidget {
  const TasksListScreen({Key? key}) : super(key: key);

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;
  int? _markingDoneId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchTasks();
      setState(() {
        _tasks = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi khi tải tasks: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(padding: const EdgeInsets.all(12), children: [
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Lỗi: $_error',
                              style: const TextStyle(color: Colors.red)),
                        ),
                      ),
                    ])
                  : _tasks.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(12),
                          children: const [
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 48.0),
                                  child: Text(
                                      'Không có công việc nào. Nhấn + để thêm.'),
                                ),
                              ),
                            ])
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          itemCount: _tasks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final t = _tasks[i];
                            final due =
                                _formatDateShort(t['due_date'] as String?);
                            final created =
                                _formatDateShort(t['created_at'] as String?);
                            final status = (t['status'] ?? 'TODO').toString();
                            final priority = t['priority'];

                            Color statusColor = Colors.grey;
                            if (status == 'TODO') statusColor = Colors.orange;
                            if (status == 'DOING') statusColor = Colors.blue;
                            if (status == 'DONE') statusColor = Colors.green;

                            return Card(
                              elevation: 2,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: priority == null
                                      ? Colors.grey[200]
                                      : Colors.purple[100],
                                  child: priority == null
                                      ? const Icon(Icons.low_priority,
                                          color: Colors.black54)
                                      : Text('$priority'),
                                ),
                                title: Text(t['title'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text([
                                  if (due.isNotEmpty) 'Due: $due',
                                  if (created.isNotEmpty) 'Created: $created'
                                ].join(' • ')),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (status != 'DONE')
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: _markingDoneId ==
                                                (t['id'] as int?)
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : IconButton(
                                                icon: const Icon(
                                                    Icons.check_circle,
                                                    color: Colors.green),
                                                tooltip: 'Mark DONE',
                                                onPressed: () async {
                                                  final id = t['id'] as int;
                                                  setState(() =>
                                                      _markingDoneId = id);
                                                  try {
                                                    await ApiService.updateTask(
                                                        id: id, status: 'DONE');
                                                    await _load();
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                              const SnackBar(
                                                                  content: Text(
                                                                      'Marked DONE')));
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(
                                                                  'Failed to mark DONE: $e')));
                                                    }
                                                  } finally {
                                                    setState(() =>
                                                        _markingDoneId = null);
                                                  }
                                                },
                                              ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  final res =
                                      await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            TaskFormScreen(initial: t)),
                                  );
                                  if (res == true && mounted) {
                                    await _load();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Task updated')));
                                  }
                                },
                              ),
                            );
                          },
                        ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const TaskFormScreen()),
          );
          if (result == true && mounted) {
            await _load();
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Task created')));
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
