import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';

/// Shown while the saved session is being checked at app start. Navy like the phone's own
/// launch screen, so there is no colour jump between the two.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: iconBackground),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandMark(size: 140, onDark: true),
                  SizedBox(height: Gaps.lg),
                  BrandTitle(color: Colors.white),
                ],
              ),
            ),
            Align(
              alignment: Alignment(0, 0.82),
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
