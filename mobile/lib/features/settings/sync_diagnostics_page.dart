import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/engine/sync_controller.dart';
import '../../design/format.dart';

class SyncDiagnosticsPage extends StatelessWidget {
  const SyncDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sync = app.syncController;
    final session = app.session;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('同步诊断')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      sync?.error == null
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: sync?.error == null
                          ? const Color(0xFF22C55E)
                          : scheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sync?.error == null ? '同步正常' : '同步异常',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoRow('服务器', session?.baseUrl ?? '-'),
                _InfoRow('账号', session?.username ?? '-'),
                _InfoRow('设备 ID', session?.deviceId ?? '-', mono: true),
                const Divider(height: 26),
                _InfoRow('游标', sync?.cursor ?? app.store.cursor, mono: true),
                _InfoRow('最近同步', relativeTime(sync?.lastSyncedAt)),
                _InfoRow('待推送', '${sync?.pending ?? app.store.pendingCount}'),
                _InfoRow('失败操作', '${sync?.failed ?? app.store.failedCount}'),
                _InfoRow('冲突', '${sync?.conflicts ?? app.store.conflictCount}'),
                if (sync?.error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      sync!.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: sync?.phase == SyncPhase.syncing
                      ? null
                      : () => app.syncNow(),
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('立即同步'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: sync?.phase == SyncPhase.syncing
                      ? null
                      : () => app.syncNow(full: true),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('全量同步'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '全量同步会从游标 0 重新拉取全部任务与清单，不会清空本地未推送的修改。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            'P0 本地库为原子写入的 JSON 文件（LocalStore 接口）；drift/SQLite '
            '依赖在当前构建环境不可用，迁移计划见 docs/客户端P0.md。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('退出登录？'),
                  content: const Text('本地任务、待推送操作和凭据都会被清空。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('退出'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await app.logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            icon: Icon(Icons.logout_rounded, size: 18, color: scheme.error),
            label: Text('退出登录', style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
