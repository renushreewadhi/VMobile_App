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
                      top: -60,
                      left: -60,
                      child: Container(
                        width: 360,
                        height: 360,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF0F9D8A).withOpacity(0.85),
                              const Color(0xFF0F9D8A).withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 220,
                      right: -90,
                      child: Container(
                        width: 340,
                        height: 340,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF4F46E5).withOpacity(0.85),
                              const Color(0xFF4F46E5).withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -70,
                      left: 40,
                      child: Container(
                        width: 380,
                        height: 380,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFC2570C).withOpacity(0.80),
                              const Color(0xFFC2570C).withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Positioned(
                      top: -50,
                      left: -50,
                      child: Container(
                        width: 340,
                        height: 340,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF5FD6C3).withOpacity(0.85),
                              const Color(0xFF5FD6C3).withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 200,
                      right: -70,
                      child: Container(
                        width: 320,
                        height: 340,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFA99CF0).withOpacity(0.80),
                              const Color(0xFFA99CF0).withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: 30,
                      child: Container(
                        width: 380,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFFC9A0).withOpacity(0.85),
                              const Color(0xFFFFC9A0).withOpacity(0),
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
        child,
      ],
    );
  }
}
