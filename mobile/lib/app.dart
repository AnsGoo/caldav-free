import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'design/app_theme.dart';
import 'features/home/home_shell.dart';

class CalDavApp extends StatefulWidget {
  const CalDavApp({super.key});

  @override
  State<CalDavApp> createState() => _CalDavAppState();
}

class _CalDavAppState extends State<CalDavApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 用户可能刚从系统设置把通知权限打开，回来时重新读一次并补排期。
    final app = context.read<AppState>();
    app.refreshNotificationPermission();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final accent = parseAccent(app.accent);
    return MaterialApp(
      title: 'caldav-free',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(Brightness.light, accent: accent),
      darkTheme: buildAppTheme(Brightness.dark, accent: accent),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
