import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';

class AppBackground extends ConsumerWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Base gradient & blobs (IgnorePointer, RepaintBoundary)
        RepaintBoundary(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: glass.backgroundGradientColors,
                ),
              ),
              child: Stack(
                children: [
                  if (isDark) ...[
                    Positioned(
                      top: -50,
                      left: -50,
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glass.blobColors[0].withOpacity(glass.blobOpacities[0]),
                              glass.blobColors[0].withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 250,
                      right: -80,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glass.blobColors[1].withOpacity(glass.blobOpacities[1]),
                              glass.blobColors[1].withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      left: 60,
                      child: Container(
                        width: 340,
                        height: 340,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glass.blobColors[2].withOpacity(glass.blobOpacities[2]),
                              glass.blobColors[2].withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Positioned(
                      top: -40,
                      left: -40,
                      child: Container(
                        width: 300,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glass.blobColors[0].withOpacity(glass.blobOpacities[0]),
                              glass.blobColors[0].withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 220,
                      right: -60,
                      child: Container(
                        width: 280,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glass.blobColors[1].withOpacity(glass.blobOpacities[1]),
                              glass.blobColors[1].withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -60,
                      left: 40,
                      child: Container(
                        width: 340,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glass.blobColors[2].withOpacity(glass.blobOpacities[2]),
                              glass.blobColors[2].withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Actual interactive content
        child,
      ],
    );
  }
}
