import 'package:flutter/material.dart';

class PostShiftBanner extends StatelessWidget {
  final bool dark;
  final Color text;
  final String shiftEndTime;
  final VoidCallback onCheckOutPressed;

  const PostShiftBanner({
    super.key,
    required this.dark,
    required this.text,
    required this.shiftEndTime,
    required this.onCheckOutPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⏰ Missed Check-Out Warning (30+ Mins Post-Shift)',
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your shift ended at $shiftEndTime. Please record your check-out to prevent auto-absent cutoff.',
                  style: TextStyle(color: text.withOpacity(0.8), fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onCheckOutPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Check Out',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
