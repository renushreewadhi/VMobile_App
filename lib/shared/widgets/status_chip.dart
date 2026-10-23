import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final Color? customColor;
  final Color? customBgColor;
  final bool showDot;

  const StatusChip({
    super.key,
    required this.status,
    this.customColor,
    this.customBgColor,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final cleanStatus = status.trim().toUpperCase();

    Color textColor;
    Color bgColor;

    if (customColor != null && customBgColor != null) {
      textColor = customColor!;
      bgColor = customBgColor!;
    } else {
      switch (cleanStatus) {
        case 'APPROVED':
        case 'PRESENT':
        case 'COMPLETED':
        case 'ACTIVE':
        case 'RESOLVED':
        case 'DONE':
        case 'PAID':
        case 'VERIFIED':
          textColor = AppColors.success;
          bgColor = AppColors.successBg;
          break;
        case 'PENDING':
        case 'IN_PROGRESS':
        case 'IN PROGRESS':
        case 'ON_LEAVE':
        case 'OPEN':
        case 'PROCESSING':
        case 'DRAFT':
          textColor = AppColors.warning;
          bgColor = AppColors.warningBg;
          break;
        case 'REJECTED':
        case 'ABSENT':
        case 'CANCELLED':
        case 'HIGH':
        case 'URGENT':
        case 'OVERDUE':
        case 'FAILED':
          textColor = AppColors.error;
          bgColor = AppColors.errorBg;
          break;
        default:
          textColor = AppColors.info;
          bgColor = AppColors.infoBg;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
