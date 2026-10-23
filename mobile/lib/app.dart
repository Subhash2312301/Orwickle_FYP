import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/session/session_controller.dart';
import 'features/profile/data/profile_api.dart';

class OrwickleApp extends StatefulWidget {
  const OrwickleApp({
    super.key,
    required this.apiClient,
    required this.authApi,
    required this.profileApi,
    required this.session,
  });

  final ApiClient apiClient;
  final AuthApi authApi;
  final ProfileApi profileApi;
  final SessionController session;

  @override
  State<OrwickleApp> createState() => _OrwickleAppState();
}

class _OrwickleAppState extends State<OrwickleApp> {
  // created once so hot reload keeps the current screen
  late final GoRouter _router = buildRouter(widget.session);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.apiClient),
        Provider.value(value: widget.authApi),
        Provider.value(value: widget.profileApi),
        ChangeNotifierProvider.value(value: widget.session),
      ],
      child: MaterialApp.router(
        title: 'Orwickle',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: _router,
        // every touch anywhere counts as activity for the 15-minute auto logout
        builder: (context, child) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => widget.session.recordActivity(),
          child: child,
        ),
      ),
    );
  }
}
