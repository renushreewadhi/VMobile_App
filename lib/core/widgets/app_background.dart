import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';

class AppBackground extends ConsumerWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final bgColors = glass.backgroundGradientColors;
    final blobColors = glass.blobColors;
    final blobOpacities = glass.blobOpacities;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: bgColors,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: -60,
                    left: -60,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (blobColors.isNotEmpty ? blobColors[0] : const Color(0xFF0F9D8A)).withOpacity(blobOpacities.isNotEmpty ? blobOpacities[0] : 0.3),
                            (blobColors.isNotEmpty ? blobColors[0] : const Color(0xFF0F9D8A)).withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 220,
                    right: -90,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (blobColors.length > 1 ? blobColors[1] : const Color(0xFF4F46E5)).withOpacity(blobOpacities.length > 1 ? blobOpacities[1] : 0.3),
                            (blobColors.length > 1 ? blobColors[1] : const Color(0xFF4F46E5)).withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -70,
                    left: 40,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 380,
                      height: 380,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (blobColors.length > 2 ? blobColors[2] : const Color(0xFFC2570C)).withOpacity(blobOpacities.length > 2 ? blobOpacities[2] : 0.15),
                            (blobColors.length > 2 ? blobColors[2] : const Color(0xFFC2570C)).withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
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
