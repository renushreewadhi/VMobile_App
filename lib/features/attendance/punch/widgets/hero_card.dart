import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../clock_ticker.dart';
import '../punch_state.dart';

class HeroCard extends ConsumerWidget {
  final PunchState state;
  final bool dark;
  final Color text;
  final Color muted;
  final Color surface;
  final Color border;
  final VoidCallback? onClockIn;
  final VoidCallback? onClockOut;
  final VoidCallback? onToggleBreak;
  final VoidCallback? onTapLocation;

  const HeroCard({
    super.key,
    required this.state,
    required this.dark,
    required this.text,
    required this.muted,
    required this.surface,
    required this.border,
    this.onClockIn,
    this.onClockOut,
    this.onToggleBreak,
    this.onTapLocation,
  });

  String _two(int value) => value.toString().padLeft(2, '0');

  String _time(DateTime? value) {
    if (value == null) return '--:--';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '${_two(hour)}:${_two(value.minute)} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  String _fullDayEstimate(DateTime? checkIn, Duration completedBreak) {
    if (checkIn == null) return '06:00 PM';
    final totalShiftTime = const Duration(hours: 8) + completedBreak;
    final estimate = checkIn.add(totalShiftTime);
    return _time(estimate);
  }

  String _normalizeAvatarUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('data:')) {
      return url;
    }
    return url.startsWith('/')
        ? 'https://hrms.etaprise.ai$url'
        : 'https://hrms.etaprise.ai/$url';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickerAsync = ref.watch(clockTickerProvider);
    final now = tickerAsync.value ?? DateTime.now();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkMainSurface : Colors.white;
    final borderColor = isDark
        ? AppColors.darkBordersAndDividers
        : AppColors.lightBordersAndDividers;
    final textColor = isDark
        ? AppColors.darkPrimaryText
        : AppColors.lightPrimaryText;
    final secondaryText = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;

    final workDur = state.workDuration(now);
    final remaining = const Duration(hours: 8) - workDur;
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
    final progress = (workDur.inSeconds / (state.minWorkHours * 3600)).clamp(
      0.0,
      1.0,
    );

    // Single Status Chip Priority
    String statusText;
    Color statusBgColor;
    Color statusTextColor;

    if (state.isTemporaryClockOut) {
      statusText = 'Stepped Out';
      statusBgColor = Colors.amber.withOpacity(0.15);
      statusTextColor = Colors.amber[800] ?? Colors.amber;
    } else if (state.checkedIn) {
      if (state.checkInStatus == 'LATE') {
        statusText = 'Late';
        statusBgColor = AppColors.warningBg;
        statusTextColor = AppColors.warning;
      } else {
        statusText = 'Present';
        statusBgColor = AppColors.successBg;
        statusTextColor = AppColors.success;
      }
    } else if (state.isCheckedOut) {
      statusText = 'Completed';
      statusBgColor = AppColors.primary.withOpacity(0.12);
      statusTextColor = AppColors.primary;
    } else {
      statusText = 'Not Checked In';
      statusBgColor = (isDark ? Colors.white : Colors.black).withOpacity(0.08);
      statusTextColor = secondaryText;
    }

    // Clean Shift Label
    String shiftLabel = state.shiftName.isNotEmpty
        ? state.shiftName
        : 'Standard Shift';
    final hasValidTimes =
        state.shiftStartTime.isNotEmpty &&
        state.shiftEndTime.isNotEmpty &&
        state.shiftStartTime != '--' &&
        state.shiftEndTime != '--' &&
        !state.shiftStartTime.contains('--');
    if (hasValidTimes) {
      shiftLabel =
          '$shiftLabel (${state.shiftStartTime} – ${state.shiftEndTime})';
    }

    final avatarUrl = _normalizeAvatarUrl(state.avatar);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Identity Row with Single Status Chip
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        state.employeeName.isNotEmpty
                            ? state.employeeName[0].toUpperCase()
                            : 'E',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.employeeName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      state.designation.isNotEmpty
                          ? state.designation
                          : 'Employee',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusTextColor,
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: borderColor),
          ),

          // 2. Circular Progress Ring & Live Timer
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        backgroundColor: borderColor,
                        color: state.isOnBreak
                            ? AppColors.warning
                            : AppColors.primary,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _duration(workDur),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.workedTimeFormatted(now),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shiftLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target ${state.minWorkHours.toInt()}h · Est. End ${_fullDayEstimate(state.checkInAt, state.completedBreak)}',
                      style: TextStyle(fontSize: 11, color: secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 3. Action Row inside HeroCard (Below Progress Ring & Timer, Above 3-col stats)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildActionRow(context, isDark),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: borderColor),
          ),

          // 4. 3-Column Inline Stats
          Row(
            children: [
              Expanded(
                child: _inlineStatCol(
                  'Check-in',
                  _time(state.checkInAt),
                  AppColors.success,
                  secondaryText,
                ),
              ),
              Container(width: 1, height: 28, color: borderColor),
              Expanded(
                child: _inlineStatCol(
                  'Check-out',
                  state.checkOutAt != null
                      ? _time(state.checkOutAt)
                      : 'In Progress',
                  state.checkOutAt != null ? AppColors.primary : secondaryText,
                  secondaryText,
                ),
              ),
              Container(width: 1, height: 28, color: borderColor),
              Expanded(
                child: _inlineStatCol(
                  'Hours Left',
                  _duration(safeRemaining),
                  textColor,
                  secondaryText,
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: borderColor),
          ),

          // 5. Slim Location Row
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTapLocation,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      state.isWithinGeofence
                          ? Icons.location_on_rounded
                          : Icons.location_off_rounded,
                      size: 16,
                      color: state.isWithinGeofence
                          ? AppColors.primary
                          : AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${state.isWithinGeofence ? "Inside office" : "Outside office"} · ${state.distanceDisplay}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: secondaryText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, bool isDark) {
    const double buttonHeight = 42.0;

    if (state.isCheckedOut && !state.isTemporaryClockOut) {
      return SizedBox(
        height: buttonHeight,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text(
            'Shift Completed Today',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (state.isTemporaryClockOut) {
      return SizedBox(
        height: buttonHeight,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: state.isActionInProgress ? null : onClockIn,
          icon: const Icon(Icons.login_rounded, size: 18),
          label: state.isActionInProgress
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Clock In (Resume Shift)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (state.checkedIn) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: FilledButton.icon(
                onPressed: state.isActionInProgress ? null : onClockOut,
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                label: const Text(
                  'Clock Out',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.12),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: OutlinedButton.icon(
                onPressed: state.isActionInProgress ? null : onToggleBreak,
                icon: Icon(
                  state.isOnBreak
                      ? Icons.play_arrow_rounded
                      : Icons.coffee_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                label: Text(
                  state.isOnBreak ? 'Resume' : 'Break',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.warning, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: buttonHeight,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: state.isActionInProgress ? null : onClockIn,
        icon: const Icon(Icons.login_rounded, size: 18),
        label: state.isActionInProgress
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Clock In',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _inlineStatCol(
    String label,
    String value,
    Color valColor,
    Color labelColor,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
