import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_theme.dart';
import '../../../../core/widgets/glass_scaffold.dart';
import '../../../../core/api/leave_service.dart';
import '../../../../employee/screens/apply_leave_screen.dart';
import '../../../../employee/screens/break_tracker_screen.dart';
import '../../../../employee/screens/my_attendance_screen.dart';
import '../clock_ticker.dart';
import '../punch_controller.dart';
import '../widgets/hero_card.dart';
import '../widgets/post_shift_banner.dart';
import '../widgets/punch_overview_section.dart';
import '../widgets/punch_activity_timeline.dart';
import '../widgets/clock_out_sheet.dart';
import 'location_check_screen.dart';
import '../../../../shared/widgets/loading_shimmer.dart';

class PunchInOutScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const PunchInOutScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<PunchInOutScreen> createState() => _PunchHomeState();
}

class PunchInOutPage extends PunchInOutScreen {
  const PunchInOutPage({super.key});
}

class _PunchHomeState extends ConsumerState<PunchInOutScreen> {
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 64.0;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: bottomInset, left: 16, right: 16),
          backgroundColor: isError ? AppColors.error : AppColors.success,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  void _openLocationCheck() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LocationCheckScreen()));
  }

  void _openBreakTracker() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BreakTrackerScreen(showAppBar: true),
      ),
    );
    ref.read(punchControllerProvider.notifier).loadAllData();
  }

  void _openClockOutModal() async {
    final state = ref.read(punchControllerProvider);
    final now = DateTime.now();
    final workedHours = state.workedHours(now);
    final requiredHours = state.minWorkHours;

    List<dynamic> balances = [];
    try {
      final leaveService = ref.read(leaveServiceProvider);
      final res = await leaveService.getLeaveBalances();
      if (res is List) {
        balances = res;
      } else if (res is Map && res['data'] is List) {
        balances = res['data'];
      }
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withAlpha(140),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClockOutSheet(
          workedHours: workedHours,
          requiredHours: requiredHours,
          pendingHours: state.leavePendingHours(now),
          workedFormatted: state.workedTimeFormatted(now),
          requiredFormatted: '${requiredHours.toInt()}h 00m',
          pendingFormatted: state.leavePendingHoursFormatted(now),
          leaveBalances: balances,
          onConfirm: (applyLeave, leaveType, reason) async {
            Navigator.pop(ctx);
            final controller = ref.read(punchControllerProvider.notifier);
            final pending = state.leavePendingHours(now);
            ClockOutResult result;
            if (applyLeave && pending > 0.02) {
              result = await controller.clockOut(
                applyLeave: true,
                leaveType: leaveType ?? 'Unpaid Leave',
                leaveReason: reason,
              );
            } else if (pending > 0.02) {
              result = await controller.clockOut(isTemporary: true);
            } else {
              result = await controller.clockOut(
                isTemporary: false,
                applyLeave: false,
              );
            }
            if (result == ClockOutResult.needsDeficitLeaveOverride) {
              _showMessage(
                'Net worked hours deficit detected. Apply leave or clock out temporarily.',
                isError: true,
              );
            }
          },
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _openRegularizationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RegularizationModal(
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
    final now = DateTime.now();

    if (state.isLoading && state.todayRecord.isEmpty) {
      final skeleton = const DashboardSkeleton();
      if (!widget.showAppBar) return skeleton;
      return GlassScaffold(
        title: 'Punch In / Out',
        showBottomBar: true,
        body: skeleton,
      );
    }

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
    final bottomNavInset = MediaQuery.paddingOf(context).bottom;

    final content = RefreshIndicator(
      onRefresh: () => ref.read(punchControllerProvider.notifier).loadAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomNavInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            // Status Banner Slot (Slim 40px warning banner)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.red,
                              ),
                              onPressed: () => ref
                                  .read(punchControllerProvider.notifier)
                                  .clearError(),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (state.isPostShiftWarning30m(now))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PostShiftBanner(
                        dark: isDark,
                        text: textColor,
                        shiftEndTime: state.shiftEndTime,
                        onCheckOutPressed: _openClockOutModal,
                      ),
                    ),
                  if (state.isTemporaryClockOut)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Stepped out early. Clock in to resume work.',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 1. ONE Unified Hero Card with Action Row embedded inside
            HeroCard(
              state: state,
              dark: isDark,
              text: textColor,
              muted: mutedColor,
              surface: surfaceColor,
              border: borderColor,
              onClockIn: _openLocationCheck,
              onClockOut: _openClockOutModal,
              onToggleBreak: _openBreakTracker,
              onTapLocation: _openLocationCheck,
            ),
            const SizedBox(height: 12),

            // 2. Quick Action Buttons (Apply Leave | Regularize)
            _buildQuickActionButtons(isDark, textColor, borderColor),
            const SizedBox(height: 12),

            // 3. Today's Activity Timeline
            PunchActivityTimeline(
              state: state,
              isDark: isDark,
              isTodaySelected: true,
              selectedDateDisplay: 'Today',
              onPrevDay: () {},
              onNextDay: () {},
              onToday: () {},
            ),
            const SizedBox(height: 12),

            // 4. Collapsed 30-Day Overview 4-Column Strip
            PunchOverviewSection(
              state: state,
              isDark: isDark,
              onViewAll: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MyAttendanceScreen(showAppBar: true),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) return content;

    return GlassScaffold(
      title: 'Punch In / Out',
      showBottomBar: true,
      body: content,
    );
  }

  Widget _buildQuickActionButtons(bool dark, Color text, Color border) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()),
                );
                ref.read(punchControllerProvider.notifier).loadAllData();
              },
              icon: const Icon(
                Icons.umbrella_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text(
                'Apply Leave',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _openRegularizationModal,
              icon: const Icon(
                Icons.edit_calendar_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text(
                'Regularize',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RegularizationModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  const _RegularizationModal({required this.onSubmit});

  @override
  State<_RegularizationModal> createState() => _RegularizationModalState();
}

class _RegularizationModalState extends State<_RegularizationModal> {
  final TextEditingController _reasonController = TextEditingController();
  final String _dateStr = DateTime.now().toIso8601String().substring(0, 10);

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkMainSurface : Colors.white;
    final textColor = isDark
        ? AppColors.darkPrimaryText
        : AppColors.lightPrimaryText;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance Regularization Request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: _dateStr),
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Select Date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason for Regularization',
                hintText: 'Explain missing clock-in/out or network issue...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSubmit({
                    'attendanceDate': _dateStr,
                    'reason': _reasonController.text.trim(),
                    'correctionType': 'MISSING_PUNCH',
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Submit Request',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
