import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ProgressRing extends StatelessWidget {
  final Duration worked;
  final Duration target;
  final String formattedTime;
  final bool dark;
  final Color text;
  final Color muted;

  const ProgressRing({
    super.key,
    required this.worked,
    required this.target,
    required this.formattedTime,
    required this.dark,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final targetSeconds = target.inSeconds > 0 ? target.inSeconds : 1;
    final progress = (worked.inSeconds / targetSeconds).clamp(0.0, 1.0);

    return Center(
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 12,
              valueColor: AlwaysStoppedAnimation<Color>(
                (dark ? Colors.white : Colors.black).withOpacity(0.08),
              ),
            ),
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Worked today',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  excludeSemantics: true,
                  child: Text(
                    formattedTime,
                    style: TextStyle(
                      color: text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'of 08:00:00',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
