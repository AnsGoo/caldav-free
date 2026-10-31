import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../design/components.dart';
import '../calendar/calendar_page.dart';
import '../countdowns/countdown_page.dart';
import '../focus/focus_page.dart';
import '../habits/habits_page.dart';
import '../settings/settings_page.dart';
import '../tasks/tasks_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Slots are built on first visit and stay mounted afterwards. That keeps
  /// scroll offsets and in-progress edits across tab switches without paying
  /// to initialise — and immediately fetch — all five tabs at startup.
  final Set<int> _built = <int>{0};

  static const _destinations = [
    AppNavDestination(
      icon: Icons.checklist_rounded,
      selectedIcon: Icons.checklist_rtl_rounded,
      label: '任务',
    ),
    AppNavDestination(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      label: '日历',
    ),
    AppNavDestination(
      icon: Icons.local_fire_department_outlined,
      selectedIcon: Icons.local_fire_department_rounded,
      label: '习惯',
    ),
    AppNavDestination(
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer_rounded,
      label: '专注',
    ),
    AppNavDestination(
      icon: Icons.hourglass_bottom_rounded,
      selectedIcon: Icons.hourglass_full_rounded,
      label: '倒数',
    ),
  ];

  void _select(int value) {
    if (value == _index) return;
    setState(() {
      _index = value;
      _built.add(value);
    });
  }

  Widget _page(int slot) {
    switch (slot) {
      case 0:
        return const TasksPage();
      case 1:
        return const CalendarPage();
      case 2:
        return const HabitsPage();
      case 3:
        return const FocusPage();
      case 4:
        return const CountdownPage();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Mutes tickers on inactive tabs so their animations stop producing frames,
  /// and returns a zero-size placeholder for tabs that were never opened.
  Widget _slot(int slot) {
    if (!_built.contains(slot)) return const SizedBox.shrink();
    return TickerMode(enabled: slot == _index, child: _page(slot));
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final useRail = isWideLayout(context);
    final app = context.watch<AppState>();
    final username = app.session?.username.trim() ?? '';
    final initial = username.isEmpty
        ? null
        : String.fromCharCode(username.runes.first).toUpperCase();
    return Scaffold(
      body: Row(
        children: [
          if (useRail)
            AppSideNav(
              index: _index,
              destinations: _destinations,
              onSelected: _select,
              onSettings: _openSettings,
              userInitial: initial,
            )
          else
            const SizedBox.shrink(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < _destinations.length; i++) _slot(i),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : AppBottomNav(
              index: _index,
              destinations: _destinations,
              onSelected: _select,
              onSettings: _openSettings,
              userInitial: initial,
            ),
    );
  }
}
