import 'package:flutter/material.dart';

class ShiftTimelineBar extends StatelessWidget {
  final String startTime;
  final String endTime;
  final double progress; // 0.0 to 1.0
  final bool dark;
  final bool isOnBreak;

  const ShiftTimelineBar({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.progress,
    required this.dark,
    this.isOnBreak = false,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final fillColor = isOnBreak ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final trackColor = (dark ? Colors.white : Colors.black).withOpacity(0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Shift $startTime', style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 9.5, fontWeight: FontWeight.bold)),
            Text(endTime, style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 9.5, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(
          label: 'Shift timeline, ${(clampedProgress * 100).round()} percent completed',
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: clampedProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  left: clampedProgress <= 0 ? 0 : null,
                  right: clampedProgress >= 1 ? 0 : null,
                  child: FractionallySizedBox(
                    widthFactor: clampedProgress,
                    alignment: Alignment.centerRight,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: fillColor, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
