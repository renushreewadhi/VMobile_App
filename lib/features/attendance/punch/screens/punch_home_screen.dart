import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_theme.dart';
import '../../../../core/widgets/glass_scaffold.dart';
import '../../../../employee/screens/apply_leave_screen.dart';
import '../../../../employee/screens/my_attendance_screen.dart';
import '../clock_ticker.dart';
import '../punch_controller.dart';
import '../punch_state.dart';
import '../widgets/activity_row.dart';
import '../widgets/hero_card.dart';
import '../widgets/location_summary_card.dart';
import '../widgets/metric_tile.dart';
import '../widgets/post_shift_banner.dart';
import '../widgets/primary_action_button.dart';
import 'location_check_screen.dart';

class PunchInOutScreen extends ConsumerStatefulWidget {
  const PunchInOutScreen({super.key});

  @override
  ConsumerState<PunchInOutScreen> createState() => _PunchHomeState();
}

class PunchInOutPage extends PunchInOutScreen {
  const PunchInOutPage({super.key});
}

class _PunchHomeState extends ConsumerState<PunchInOutScreen> {
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.error : AppColors.success,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _time(DateTime? value) {
    if (value == null) return '--:--';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '${_two(hour)}:${_two(value.minute)} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
  }

  void _openLocationCheck() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LocationCheckScreen()),
    );
  }

  void _openClockOutModal() {
    final state = ref.read(punchControllerProvider);
    final workedHours = state.workDuration(DateTime.now()).inHours;
    final isHalfDayEligible = workedHours >= 4 ||
        state.todayRecord['workMode'] == 'HALF_DAY' ||
        state.todayRecord['isHalfDay'] == true;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isHalfDayEligible && workedHours < 8
            ? 'Confirm Half-Day Clock Out'
            : 'Confirm Clock Out'),
        content: Text(
          isHalfDayEligible && workedHours < 8
              ? 'You have completed ${workedHours}h ${state.workDuration(DateTime.now()).inMinutes.remainder(60)}m today (Half-Day threshold met). Ready to clock out now?'
              : 'Are you ready to end your workday? Your check-out time will be recorded on the server.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final controller = ref.read(punchControllerProvider.notifier);
              final result = await controller.clockOut(isHalfDayOverride: isHalfDayEligible);
              if (result == ClockOutResult.needsHalfDayOverride) {
                _showEarlyCheckoutOverrideDialog();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Clock Out'),
          ),
        ],
      ),
    );
  }

  void _showEarlyCheckoutOverrideDialog() {
    final state = ref.read(punchControllerProvider);
    final workDuration = state.workDuration(DateTime.now());
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Early / Half-Day Check-Out Override',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                'Server Policy: Net work duration is under 8.0 hours (${workDuration.inHours}h ${workDuration.inMinutes.remainder(60)}m worked).\n\nChoose an override option below:',
                style: const TextStyle(fontSize: 11.5, height: 1.35),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final controller = ref.read(punchControllerProvider.notifier);
                await controller.clockOut(isHalfDayOverride: true);
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Clock Out as Half-Day'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _openRegularizationModal();
              },
              icon: const Icon(Icons.edit_calendar_rounded, size: 18),
              label: const Text('Submit Instant Regularization'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _openRegularizationModal() {
    final state = ref.read(punchControllerProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RegularizationModal(
        employeeId: state.employeeId,
        todayRecord: state.todayRecord,
        onSubmit: (payload) async {
          Navigator.pop(ctx);
          final controller = ref.read(punchControllerProvider.notifier);
          await controller.submitRegularization(payload);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(punchControllerProvider);
    final tickerAsync = ref.watch(clockTickerProvider);
    final now = tickerAsync.value ?? DateTime.now();

    ref.listen(punchMessageProvider, (_, next) {
      next.whenData((msg) {
        _showMessage(msg.text, isError: msg.isError);
      });
    });

    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = glass.textPrimary;
    final mutedColor = glass.textSecondary;
    final surfaceColor = glass.cardFill;
    final borderColor = glass.cardBorder;

    return GlassScaffold(
      title: 'Punch In / Out',
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(punchControllerProvider.notifier).loadAllData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (state.error != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(state.error!, style: TextStyle(color: textColor, fontSize: 12)),
                    ),
                  ),

                if (state.isPostShiftWarning30m(now)) ...[
                  PostShiftBanner(
                    dark: isDark,
                    text: textColor,
                    shiftEndTime: state.shiftEndTime,
                    onCheckOutPressed: _openClockOutModal,
                  ),
                  const SizedBox(height: 14),
                ],

                HeroCard(
                  state: state,
                  now: now,
                  dark: isDark,
                  text: textColor,
                  muted: mutedColor,
                  surface: surfaceColor,
                  border: borderColor,
                ),
                const SizedBox(height: 14),

                LocationSummaryCard(
                  state: state,
                  dark: isDark,
                  text: textColor,
                  muted: mutedColor,
                  surface: surfaceColor,
                  border: borderColor,
                  onTap: _openLocationCheck,
                ),
                const SizedBox(height: 14),

                _buildMetricsSection(isDark, textColor, mutedColor, surfaceColor, borderColor, now, state),
                const SizedBox(height: 14),

                _buildQuickActionButtons(isDark, textColor, borderColor),
                const SizedBox(height: 18),

                _buildTodayActivityCard(isDark, textColor, mutedColor, surfaceColor, borderColor, now, state),
                const SizedBox(height: 24),

                _buildPrimaryActionArea(state),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'SERVER SYNCED  •  LIVE ATTENDANCE PROTOCOL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsSection(bool dark, Color text, Color muted, Color surface, Color border, DateTime now, PunchState state) {
    final workDur = state.workDuration(now);
    final remaining = const Duration(hours: 8) - workDur;
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
    final breakDur = state.breakDuration(now);

    return Row(
      children: [
        Expanded(
          child: MetricTile(
            dark: dark, text: text, muted: muted, surface: surface, border: border,
            icon: Icons.work_history_rounded, label: 'WORKED', value: _duration(workDur), iconColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricTile(
            dark: dark, text: text, muted: muted, surface: surface, border: border,
            icon: Icons.hourglass_bottom_rounded, label: 'REMAINING', value: _duration(safeRemaining), iconColor: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricTile(
            dark: dark, text: text, muted: muted, surface: surface, border: border,
            icon: Icons.login_rounded, label: 'CHECK IN', value: _time(state.checkInAt), iconColor: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricTile(
            dark: dark, text: text, muted: muted, surface: surface, border: border,
            icon: state.checkedIn ? Icons.coffee_rounded : Icons.logout_rounded,
            label: state.checkedIn ? 'BREAK' : 'CHECK OUT',
            value: state.checkedIn ? _duration(breakDur) : _time(state.checkOutAt),
            iconColor: state.checkedIn ? const Color(0xFFF59E0B) : const Color(0xFFEC4899),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButtons(bool dark, Color text, Color border) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()));
              ref.read(punchControllerProvider.notifier).loadAllData();
            },
            icon: const Icon(Icons.umbrella_rounded, size: 16),
            label: const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: text,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openRegularizationModal,
            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
            label: const Text('Regularize', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: text,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyAttendanceScreen(showAppBar: true)));
              ref.read(punchControllerProvider.notifier).loadAllData();
            },
            icon: const Icon(Icons.bar_chart_rounded, size: 16),
            label: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: text,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayActivityCard(bool dark, Color text, Color muted, Color surface, Color border, DateTime now, PunchState state) {
    final hasActivity = state.checkInAt != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Attendance Activity", style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (!hasActivity)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.event_note_rounded, size: 36, color: muted.withOpacity(0.5)),
                  const SizedBox(height: 8),
                  Text('No attendance recorded today yet.', style: TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            )
          else ...[
            ActivityRow(
              dark: dark,
              icon: Icons.login_rounded,
              title: 'Check-In',
              time: _time(state.checkInAt),
              location: state.checkInLocation,
              color: const Color(0xFF10B981),
              text: text,
              muted: muted,
            ),
            if (state.completedBreak > Duration.zero || state.isOnBreak)
              ActivityRow(
                dark: dark,
                icon: Icons.coffee_rounded,
                title: state.isOnBreak ? 'Break (Active)' : 'Break Duration',
                time: _duration(state.breakDuration(now)),
                location: 'Total Break Time',
                color: const Color(0xFFF59E0B),
                text: text,
                muted: muted,
              ),
            if (state.checkOutAt != null)
              ActivityRow(
                dark: dark,
                icon: Icons.logout_rounded,
                title: 'Check-Out',
                time: _time(state.checkOutAt),
                location: state.checkOutLocation,
                color: const Color(0xFFEC4899),
                text: text,
                muted: muted,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryActionArea(PunchState state) {
    if (state.checkOutAt != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: const Text(
          '✨ Day Complete · Shift Finished Successfully',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      );
    }

    if (state.checkedIn) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: state.isActionInProgress ? null : () => ref.read(punchControllerProvider.notifier).toggleBreak(),
              icon: Icon(state.isOnBreak ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
              label: Text(state.isOnBreak ? 'End break' : 'Start break', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryActionButton(
              title: 'Clock out',
              backgroundColor: const Color(0xFFEF4444),
              icon: Icons.logout_rounded,
              isLoading: state.isActionInProgress,
              onPressed: state.isOnBreak
                  ? () => _showMessage('End your break before clocking out.', isError: true)
                  : _openClockOutModal,
            ),
          ),
        ],
      );
    }

    return PrimaryActionButton(
      title: 'Clock in',
      subtitle: 'Location + selfie check',
      icon: Icons.login_rounded,
      isLoading: state.isActionInProgress,
      onPressed: _openLocationCheck,
    );
  }
}

class _RegularizationModal extends StatefulWidget {
  final String employeeId;
  final Map<String, dynamic> todayRecord;
  final Function(Map<String, dynamic> payload) onSubmit;

  const _RegularizationModal({
    required this.employeeId,
    required this.todayRecord,
    required this.onSubmit,
  });

  @override
  State<_RegularizationModal> createState() => _RegularizationModalState();
}

class _RegularizationModalState extends State<_RegularizationModal> {
  final _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _correctedCheckIn = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _correctedCheckOut = const TimeOfDay(hour: 18, minute: 0);

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isIn ? _correctedCheckIn : _correctedCheckOut,
    );
    if (picked != null) {
      setState(() {
        if (isIn) {
          _correctedCheckIn = picked;
        } else {
          _correctedCheckOut = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final dt = DateTime(2026, 1, 1, tod.hour, tod.minute);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
    final muted = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final surface = isDark ? AppColors.darkMainSurface : AppColors.lightMainSurface;

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Container(
      padding: EdgeInsets.only(
        top: 20, left: 20, right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: muted.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Regularize Attendance', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900)),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: muted)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Target Date: $dateStr', style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: const Text('Change Date'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text('In: ${_formatTimeOfDay(_correctedCheckIn)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text('Out: ${_formatTimeOfDay(_correctedCheckOut)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason for Regularization',
                hintText: 'Forgot to clock in, device battery died, etc...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final payload = {
                    'employeeId': widget.employeeId,
                    'date': dateStr,
                    'correctedCheckIn': _formatTimeOfDay(_correctedCheckIn),
                    'correctedCheckOut': _formatTimeOfDay(_correctedCheckOut),
                    'reason': _reasonController.text.trim(),
                  };
                  widget.onSubmit(payload);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('SUBMIT REGULARIZATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
