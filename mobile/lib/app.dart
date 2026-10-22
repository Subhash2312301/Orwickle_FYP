import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class OrwickleApp extends StatefulWidget {
  const OrwickleApp({super.key});

  @override
  State<OrwickleApp> createState() => _OrwickleAppState();
}

class _OrwickleAppState extends State<OrwickleApp> {
  // created once so hot reload keeps the current screen
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Orwickle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
