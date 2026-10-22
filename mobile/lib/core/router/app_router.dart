import 'package:go_router/go_router.dart';

import '../../features/system_check/system_check_screen.dart';

/// All app routes. Phase 2 adds /login, /register, /verify-otp, /forgot-password
/// and a redirect that sends logged-out users to /login.
GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SystemCheckScreen()),
      ],
    );
