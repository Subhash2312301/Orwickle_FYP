import 'package:flutter/material.dart';

/// Shown while the saved session is being checked at app start.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, size: 80, color: theme.colorScheme.onPrimary),
            const SizedBox(height: 16),
            Text('Orwickle', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onPrimary)),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: theme.colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }
}
