import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app_state.dart';
import 'data/db/local_store.dart';
import 'data/session/credentials.dart';
import 'data/tasks_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = await LocalStore.open();
    final app = AppState(
      store: store,
      credentials: FileCredentialsStore(),
      repository: TaskRepository(store),
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
