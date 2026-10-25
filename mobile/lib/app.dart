import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'design/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_shell.dart';

class CalDavApp extends StatelessWidget {
  const CalDavApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      title: 'caldav-free',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: app.signedIn ? const HomeShell() : const LoginPage(),
    );
  }
}
