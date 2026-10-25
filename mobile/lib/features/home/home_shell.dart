import 'package:flutter/material.dart';

import '../../design/components.dart';
import '../calendar/calendar_page.dart';
import '../countdowns/countdown_page.dart';
import '../focus/focus_page.dart';
import '../habits/habits_page.dart';
import '../tasks/tasks_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          TasksPage(),
          CalendarPage(),
          HabitsPage(),
          FocusPage(),
          CountdownPage(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        index: _index,
        destinations: _destinations,
        onSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}
