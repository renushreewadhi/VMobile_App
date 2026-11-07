import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color? color;

  const StatusChip({
    super.key,
    required this.label,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(isDark ? 0.20 : 0.12),
        border: Border.all(color: chipColor.withOpacity(0.30)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
