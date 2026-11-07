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

  factory StatusBadge.fromText(String rawStatus, {String? customLabel}) {
    final s = rawStatus.toUpperCase().trim();
    StatusType type = StatusType.info;

    if (s == 'ACTIVE' || s == 'APPROVED' || s == 'COMPLETED' || s == 'PRESENT' || s == 'PAID' || s == 'TRUE' || s == 'SUCCESS') {
      type = StatusType.success;
    } else if (s == 'PENDING' || s == 'DRAFT' || s == 'IN_PROGRESS' || s == 'SUBMITTED' || s == 'WFH') {
      type = StatusType.pending;
    } else if (s == 'WARNING' || s == 'LATE' || s == 'ON_LEAVE' || s == 'PARTIAL') {
      type = StatusType.warning;
    } else if (s == 'INACTIVE' || s == 'REJECTED' || s == 'CANCELLED' || s == 'ABSENT' || s == 'EXPIRED' || s == 'FALSE' || s == 'ERROR') {
      type = StatusType.error;
    }

    final displayText = customLabel ?? (rawStatus.isEmpty ? 'N/A' : rawStatus[0].toUpperCase() + rawStatus.substring(1).toLowerCase());
    return StatusBadge(label: displayText, status: type);
  }

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
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
