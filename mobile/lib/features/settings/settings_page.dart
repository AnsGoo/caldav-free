import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/calendar/calendar_api.dart';
import '../../design/components.dart';
import '../auth/login_page.dart';
import '../calendar/calendar_page.dart';
import '../calendar/calendar_subscription_sheet.dart';
import 'sync_diagnostics_page.dart';
import 'theme_sheet.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.watch<AppState>();
    final session = app.session;
    final username = session?.username.trim() ?? '';
    final initial = username.isEmpty
        ? null
        : String.fromCharCode(username.runes.first).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outline, width: 1.2),
                  ),
                  child: initial == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 28,
                          color: scheme.primary,
                        )
                      : Text(
                          initial,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session?.username ?? '未登录',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session?.baseUrl ?? '连接服务器后即可同步任务与日程',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (session != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '已连接',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AppSectionLabel(title: '账户'),
          AppCard(
            padding: EdgeInsets.zero,
            child: session == null
                ? _SettingsTile(
                    icon: Icons.login_rounded,
                    title: '连接服务器',
                    subtitle: '登录后同步任务、日历和习惯',
                    onTap: () => _connect(context),
                  )
                : _SettingsTile(
                    icon: Icons.link_off_rounded,
                    title: '断开连接',
                    subtitle: '回到离线模式，本地数据仍会保留',
                    danger: true,
                    onTap: () => _disconnect(context, app),
                  ),
          ),
          if (session != null) ...[
            const SizedBox(height: 18),
            const AppSectionLabel(title: '同步'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.sync_rounded,
                    title: '立即同步',
                    subtitle: '从服务器拉取最新数据',
                    onTap: () => _sync(context, app),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.cloud_download_rounded,
                    title: '完整同步',
                    subtitle: '重新下载全部数据',
                    onTap: () => _sync(context, app, full: true),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.monitor_heart_outlined,
                    title: '同步诊断',
                    subtitle: '查看同步状态与最近日志',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SyncDiagnosticsPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (session != null) ...[
            const SizedBox(height: 18),
            const AppSectionLabel(title: '日历'),
            AppCard(
              padding: EdgeInsets.zero,
              child: _SettingsTile(
                icon: Icons.rss_feed_rounded,
                title: 'iCal 订阅',
                subtitle: '添加 http/https ICS 地址，事件会出现在日历中',
                onTap: () => _subscriptions(context, app),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const AppSectionLabel(title: '外观'),
          AppCard(
            padding: EdgeInsets.zero,
            child: _SettingsTile(
              icon: Icons.palette_outlined,
              title: '主题色',
              subtitle: '调整应用强调色',
              onTap: () => _theme(context, app),
            ),
          ),
          const SizedBox(height: 26),
          Center(
            child: Text(
              'caldav-free',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connect(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ConnectServerSheet(),
    );
  }

  Future<void> _disconnect(BuildContext context, AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('断开连接'),
        content: const Text('断开后将回到离线模式，本地数据仍会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('断开'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.disconnect();
    if (context.mounted) _snack(context, '已断开连接');
  }

  Future<void> _sync(
    BuildContext context,
    AppState app, {
    bool full = false,
  }) async {
    try {
      await app.syncNow(full: full);
      if (context.mounted) {
        _snack(context, full ? '完整同步完成' : '同步完成');
      }
    } catch (error) {
      if (context.mounted) _snack(context, '同步失败：$error');
    }
  }

  Future<void> _theme(BuildContext context, AppState app) async {
    final selected = await showThemeSheet(context, current: app.accent);
    if (selected == null || !context.mounted) return;
    await app.setAccent(selected);
  }

  Future<void> _subscriptions(BuildContext context, AppState app) async {
    final session = app.session;
    if (session == null) {
      _snack(context, '请先连接服务器');
      return;
    }
    final api = CalendarApi(
      baseUrl: session.baseUrl,
      username: session.username,
      password: session.password,
    );
    try {
      await showCalendarSubscriptionSheet(context, api);
    } finally {
      api.close();
      // 订阅增删后让日历页在后台刷新。
      calendarRefreshSignal.value++;
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color ?? scheme.onSurfaceVariant),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
