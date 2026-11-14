import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../punch_state.dart';
import 'work_progress_ring.dart';
import 'shift_timeline_bar.dart';
import 'info_tile.dart';

class HeroCard extends StatelessWidget {
  final PunchState state;
  final DateTime now;
  final bool dark;
  final Color text;
  final Color muted;
  final Color surface;
  final Color border;

  const HeroCard({
    super.key,
    required this.state,
    required this.now,
    required this.dark,
    required this.text,
    required this.muted,
    required this.surface,
    required this.border,
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

  String _exactDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
  }

  String _dateChipLabel(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  String _fullDayEstimate(DateTime? checkIn, Duration completedBreak) {
    if (checkIn == null) return '01:33 AM';
    final totalShiftTime = const Duration(hours: 8) + completedBreak;
    final estimate = checkIn.add(totalShiftTime);
    return _time(estimate);
  }

  @override
  Widget build(BuildContext context) {
    final surfaceTop = dark ? const Color(0xE62A2D2E) : const Color(0xF5FFFFFF);
    final surfaceBottom = dark ? const Color(0xE61B1D1F) : const Color(0xE8F5F1EB);

    final isWorking = state.checkedIn || state.isOnBreak;
    final isCheckedOut = state.checkOutAt != null;

    final workDur = state.workDuration(now);
    final remaining = const Duration(hours: 8) - workDur;
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
    final breakDur = state.breakDuration(now);

    double shiftProgress = 0.0;
    try {
      final parts = state.shiftStartTime.replaceAll(RegExp(r'[^\d:]'), '').split(':');
      final endParts = state.shiftEndTime.replaceAll(RegExp(r'[^\d:]'), '').split(':');
      if (parts.length >= 2 && endParts.length >= 2) {
        int sHour = int.parse(parts[0]);
        int sMin = int.parse(parts[1]);
        if (state.shiftStartTime.toUpperCase().contains('PM') && sHour < 12) sHour += 12;
        if (state.shiftStartTime.toUpperCase().contains('AM') && sHour == 12) sHour = 0;

        int eHour = int.parse(endParts[0]);
        int eMin = int.parse(endParts[1]);
        if (state.shiftEndTime.toUpperCase().contains('PM') && eHour < 12) eHour += 12;
        if (state.shiftEndTime.toUpperCase().contains('AM') && eHour == 12) eHour = 0;

        final startDt = DateTime(now.year, now.month, now.day, sHour, sMin);
        final endDt = DateTime(now.year, now.month, now.day, eHour, eMin);
        final totalDuration = endDt.difference(startDt).inSeconds;
        final elapsed = now.difference(startDt).inSeconds;
        if (totalDuration > 0) {
          shiftProgress = (elapsed / totalDuration).clamp(0.0, 1.0);
        }
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [surfaceTop, surfaceBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.20 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.transparent,
                  backgroundImage: state.avatar.isNotEmpty ? NetworkImage(state.avatar) : null,
                  child: state.avatar.isEmpty
                      ? Text(state.employeeName.isNotEmpty ? state.employeeName[0].toUpperCase() : 'E',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${now.hour < 12 ? "Morning" : now.hour < 17 ? "Afternoon" : "Evening"},',
                      style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            state.employeeName,
                            style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('👋', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Your workday at a glance',
                      style: TextStyle(color: muted, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : Colors.black).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      _dateChipLabel(now),
                      style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.chevron_right_rounded, size: 14, color: muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(dark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  state.checkedStatusLabel(now),
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (dark ? Colors.black : Colors.white).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border.withOpacity(0.8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(dark ? 0.1 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isWorking ? 'Worked today' : 'Current time',
                              style: TextStyle(color: muted, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Semantics(
                              excludeSemantics: true,
                              child: Text(
                                isWorking ? _exactDuration(workDur) : _time(now),
                                style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isWorking
                                  ? 'of 08:00:00'
                                  : '${state.shiftName} · ${state.shiftStartTime} – ${state.shiftEndTime}',
                              style: TextStyle(color: muted, fontSize: 9.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 60,
                  width: 1,
                  color: border.withOpacity(0.6),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    WorkProgressRing(
                      progress: (workDur.inSeconds / (8 * 3600)).clamp(0.0, 1.0),
                      centerText: _duration(workDur),
                      subText: state.isOnBreak ? 'On break' : (isWorking ? 'Completed' : 'Not started'),
                      dark: dark,
                      isOnBreak: state.isOnBreak,
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(Icons.bar_chart_rounded, size: 16, color: muted.withOpacity(0.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ShiftTimelineBar(
            startTime: state.shiftStartTime,
            endTime: state.shiftEndTime,
            progress: shiftProgress,
            dark: dark,
            isOnBreak: state.isOnBreak,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              InfoTile(
                label: 'Hours Left',
                value: _duration(safeRemaining),
                icon: Icons.hourglass_bottom_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
                dark: dark, text: text, muted: muted, surface: surface, border: border,
              ),
              const SizedBox(width: 8),
              InfoTile(
                label: 'Target 8h',
                value: '08:00:00',
                icon: Icons.flag_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFD1FAE5),
                dark: dark, text: text, muted: muted, surface: surface, border: border,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              InfoTile(
                label: !state.hasLocationFix
                    ? 'Location'
                    : (state.isWithinGeofence ? 'Geofence OK' : 'Out of Range'),
                value: state.distanceDisplay,
                icon: !state.hasLocationFix
                    ? Icons.location_searching_rounded
                    : Icons.location_on_rounded,
                iconColor: !state.hasLocationFix
                    ? const Color(0xFFD97706)
                    : (state.isWithinGeofence ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                bgColor: !state.hasLocationFix
                    ? const Color(0xFFFEF3C7)
                    : (state.isWithinGeofence ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2)),
                dark: dark, text: text, muted: muted, surface: surface, border: border,
              ),
              const SizedBox(width: 8),
              InfoTile(
                label: 'Est. End',
                value: _fullDayEstimate(state.checkInAt, state.completedBreak),
                icon: Icons.access_time_filled_rounded,
                iconColor: const Color(0xFF0D9488),
                bgColor: const Color(0xFFCCFBF1),
                dark: dark, text: text, muted: muted, surface: surface, border: border,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
