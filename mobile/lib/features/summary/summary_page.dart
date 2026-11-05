import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/models.dart';
import '../../core/ui_utils.dart';
import '../tasks/summary_panel.dart';

/// Top-level summary tab. The rail/bottom bar owns its entry so the task
/// sidebar stays focused on lists, filters and tags.
class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final _panel = SummaryPanelController();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final compact = isCompactAppBar(context);
    // Tablets pin the filter panel on the right, so the tune button is redundant.
    final wide = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: compactAppBarHeight(context, defaultHeight: 64),
        title: Text(
          '摘要',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: compactTitleFontSize(context),
            letterSpacing: -0.9,
          ),
        ),
        // 横屏时把工具栏按钮并入标题行，省掉编辑器顶上的一整行。
        actions: compact
            ? [
                IconButton(
                  tooltip: '重新生成',
                  onPressed: _panel.regenerate,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                if (!wide)
                  IconButton(
                    tooltip: '筛选与分组',
                    onPressed: _panel.openSettings,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                IconButton(
                  tooltip: '复制摘要',
                  onPressed: _panel.copy,
                  icon: const Icon(Icons.copy_rounded),
                ),
                IconButton(
                  tooltip: '保存为模板',
                  onPressed: _panel.saveTemplate,
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
                const SizedBox(width: 4),
              ]
            : null,
      ),
      body: StreamBuilder<List<TaskItem>>(
        stream: app.store.watchAllTasks(),
        builder: (context, snapshot) {
          final tasks = snapshot.data ?? app.store.allTasks();
          return SummaryPanel(
            tasks: tasks,
            lists: app.store.listsSnapshot(),
            controller: _panel,
          );
        },
      ),
    );
  }
}
