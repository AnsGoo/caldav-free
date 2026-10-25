import 'package:flutter/material.dart';

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            selectedIcon: Icon(Icons.checklist_rtl_rounded),
            label: '任务',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: '日历',
          ),
          NavigationDestination(
            icon: Icon(Icons.loop_rounded),
            selectedIcon: Icon(Icons.loop_rounded),
            label: '习惯',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: '专注',
          ),
          NavigationDestination(
            icon: Icon(Icons.hourglass_bottom_rounded),
            selectedIcon: Icon(Icons.hourglass_full_rounded),
            label: '倒数',
          ),
        ],
      ),
    );
  }
}
