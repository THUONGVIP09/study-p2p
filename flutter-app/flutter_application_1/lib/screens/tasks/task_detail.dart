import 'package:flutter/material.dart';

class TaskDetailScreen extends StatelessWidget {
  final Map<String, dynamic> task;
  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(task['title'] ?? 'Task')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task['description'] ?? ''),
            const SizedBox(height: 12),
            Text('Due: ${task['due_date'] ?? '—'}'),
            Text('Status: ${task['status'] ?? '—'}'),
            Text('Priority: ${task['priority'] ?? '—'}'),
            Text('Created: ${task['created_at'] ?? '—'}'),
            Text('Completed: ${task['completed_at'] ?? '—'}'),
          ],
        ),
      ),
    );
  }
}
