import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SteamGradientBackground extends StatelessWidget {
  const SteamGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Keep this cheap: large boxShadows are very expensive while scrolling on
    // Flutter web (CanvasKit/skwasm re-rasterizes them every frame).
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.steamNavy,
            AppTheme.steamDark,
            Color(0xFF0E1419),
          ],
        ),
      ),
      child: child,
    );
  }
}
