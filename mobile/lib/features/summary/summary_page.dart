import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/models.dart';
import '../tasks/summary_panel.dart';

/// Top-level summary tab. The rail/bottom bar owns its entry so the task
/// sidebar stays focused on lists, filters and tags.
class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('摘要'), toolbarHeight: 64),
      body: StreamBuilder<List<TaskItem>>(
        stream: app.store.watchAllTasks(),
        builder: (context, snapshot) {
          final tasks = snapshot.data ?? app.store.allTasks();
          return SummaryPanel(tasks: tasks, lists: app.store.listsSnapshot());
        },
      ),
    );
  }
}
