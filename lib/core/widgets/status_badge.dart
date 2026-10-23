import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';

enum StatusType { success, warning, error, info, pending }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType status;

  const StatusBadge({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    Color tint;
    Color textColor;

    switch (status) {
      case StatusType.success:
        tint = glass.successTint;
        textColor = glass.successText;
        break;
      case StatusType.warning:
        tint = glass.warningTint;
        textColor = glass.warningText;
        break;
      case StatusType.error:
        tint = glass.errorTint;
        textColor = glass.errorText;
        break;
      case StatusType.info:
        tint = glass.infoTint;
        textColor = glass.infoText;
        break;
      case StatusType.pending:
        tint = glass.pendingTint;
        textColor = glass.pendingText;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
