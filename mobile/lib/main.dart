import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app_state.dart';
import 'data/countdowns/countdown_store.dart';
import 'data/db/local_store.dart';
import 'data/focus/focus_store.dart';
import 'data/habits/habit_store.dart';
import 'data/session/credentials.dart';
import 'data/tasks_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = await LocalStore.open();
    final habits = await HabitStore.open(database: store.database);
    final countdowns = await CountdownStore.open(database: store.database);
    final focus = await FocusStore.open(database: store.database);
    final app = AppState(
      store: store,
      credentials: FileCredentialsStore(),
      repository: TaskRepository(store),
      habits: habits,
      countdowns: countdowns,
      focus: focus,
    );
    await app.restore();
    runApp(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const CalDavApp(),
    ));
  } catch (error) {
    runApp(_BootFailure(error: error));
  }
}

class _BootFailure extends StatelessWidget {
  const _BootFailure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('本地数据初始化失败\n$error', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
