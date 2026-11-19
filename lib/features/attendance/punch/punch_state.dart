import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

enum PunchPhase { notCheckedIn, checkedIn, onBreak, checkedOut }

enum GpsStatus {
  detecting,
  ready,
  serviceDisabled,
  denied,
  deniedForever,
  error,
}

class PunchState {
  final PunchPhase phase;
  final GpsStatus gpsStatus;
  final String employeeId;
  final String employeeName;
  final String designation;
  final String department;
  final String avatar;

  final Map<String, dynamic> todayRecord;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime? breakStartedAt;
  final Duration completedBreak;
  final bool isOnBreak;

  final String shiftName;
  final String shiftStartTime;
  final String shiftEndTime;

  final String checkInLocation;
  final String checkOutLocation;

  final double officeLat;
  final double officeLng;
  final String officeName;
  final String officeAddress;
  final double geofenceRadiusMeters;

  final String selectedTileType;

  final Position? currentPosition;
  final String currentAddress;
  final String gpsStatusMessage;
  final bool isWithinGeofence;
  final double distanceFromOfficeMeters;

  final List<dynamic> attendanceHistory;
  final int presentDays;
  final int absentDays;
  final int lateClockIns;
  final double attendanceRatePercent;
  final String hoursLoggedBadge;

  final bool isLoading;
  final bool isActionInProgress;
  final String? error;

  // Flow and Settings fields
  final String workMode; // 'WORK_FROM_HOME' or 'OFFICE'
  final String? wfhReason;
  final XFile? capturedSelfie;
  final String? capturedSelfieBase64;
  final bool isGalleryUpload;
  final bool isTemporaryClockOut;
  final bool applyLeaveForPendingHours;
  final String? leaveReason;
  final int gracePeriodMinutes;
  final bool faceVerificationRequired;
  final double minWorkHours;
  final bool geofenceEnabled;
  final List<dynamic> branches;
  final Map<String, dynamic>? selectedOffice;
  final String checkInStatus;
  final String checkOutStatus;
  final String todayStatusText;
  final String todayApprovalText;
  final List<dynamic> weekData;
  final Map<String, dynamic> thirtyDayOverview;
  final DateTime? selectedDate;
  final Map<String, dynamic>? selectedDayRecord;
  final bool isDayLoading;
  final Map<String, dynamic> serverGeofence;

  const PunchState({
    this.phase = PunchPhase.notCheckedIn,
    this.gpsStatus = GpsStatus.detecting,
    this.employeeId = '',
    this.employeeName = '--',
    this.designation = '--',
    this.department = '--',
    this.avatar = '',
    this.todayRecord = const {},
    this.checkInAt,
    this.checkOutAt,
    this.breakStartedAt,
    this.completedBreak = Duration.zero,
    this.isOnBreak = false,
    this.shiftName = '--',
    this.shiftStartTime = '--',
    this.shiftEndTime = '--',
    this.checkInLocation = '--',
    this.checkOutLocation = '--',
    this.officeLat = 0.0,
    this.officeLng = 0.0,
    this.officeName = '--',
    this.officeAddress = '--',
    this.geofenceRadiusMeters = 300.0,
    this.selectedTileType = 'Streets',
    this.currentPosition,
    this.currentAddress = '--',
    this.gpsStatusMessage = 'Detecting location...',
    this.isWithinGeofence = false,
    this.distanceFromOfficeMeters = 0.0,
    this.attendanceHistory = const [],
    this.presentDays = 0,
    this.absentDays = 0,
    this.lateClockIns = 0,
    this.attendanceRatePercent = 0.0,
    this.hoursLoggedBadge = '--',
    this.isLoading = true,
    this.isActionInProgress = false,
    this.error,
    this.workMode = 'OFFICE',
    this.wfhReason,
    this.capturedSelfie,
    this.capturedSelfieBase64,
    this.isGalleryUpload = false,
    this.isTemporaryClockOut = false,
    this.applyLeaveForPendingHours = false,
    this.leaveReason,
    this.gracePeriodMinutes = 15,
    this.faceVerificationRequired = false,
    this.minWorkHours = 8.0,
    this.geofenceEnabled = true,
    this.branches = const [],
    this.selectedOffice,
    this.checkInStatus = '--',
    this.checkOutStatus = '--',
    this.todayStatusText = '--',
    this.todayApprovalText = '--',
    this.weekData = const [],
    this.thirtyDayOverview = const {},
    this.selectedDate,
    this.selectedDayRecord,
    this.isDayLoading = false,
    this.serverGeofence = const {},
  });

  bool get checkedIn =>
      checkInAt != null &&
      checkInAt!.year > 1970 &&
      (checkOutAt == null || checkOutAt!.year <= 1970);

  bool get isCheckedOut => checkOutAt != null && checkOutAt!.year > 1970;

  bool get isLowAccuracy =>
      currentPosition != null && currentPosition!.accuracy > 50;

  bool get hasOfficeLocation => officeLat != 0.0 && officeLng != 0.0;

  bool get isViewingPastDate {
    final d = selectedDate;
    if (d == null) return false;
    final n = DateTime.now();
    return !(d.year == n.year && d.month == n.month && d.day == n.day);
  }

  String get normalizedWorkMode {
    final m = workMode.toUpperCase();
    if (m == 'WFH' || m == 'WORK_FROM_HOME') return 'WORK_FROM_HOME';
    return 'OFFICE';
  }

  String workedTime(DateTime now) {
    final dur = workDuration(now);
    final hours = dur.inHours.toString().padLeft(2, '0');
    final minutes = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String workedTimeFormatted(DateTime now) => workedTime(now);

  Duration workDuration(DateTime now) {
    if (checkInAt == null) return Duration.zero;
    final end = checkOutAt ?? now;
    final total = end.difference(checkInAt!);
    final activeBreak = isOnBreak && breakStartedAt != null
        ? now.difference(breakStartedAt!)
        : Duration.zero;
    final value = total - completedBreak - activeBreak;
    return value.isNegative ? Duration.zero : value;
  }

  double workedHours(DateTime now) {
    if (checkInAt == null) return 0.0;
    final end = checkOutAt ?? now;
    final total = end.difference(checkInAt!);
    final activeBreak = isOnBreak && breakStartedAt != null
        ? now.difference(breakStartedAt!)
        : Duration.zero;
    final value = total - completedBreak - activeBreak;
    return value.isNegative ? 0.0 : value.inSeconds / 3600.0;
  }

  // Requirement 3 & 1: Office Unavailable Guard, OFFICE: hasLocationFix && (!geofenceEnabled || isWithinGeofence)
  bool get canProceedFromLocationCheck {
    if (normalizedWorkMode == 'OFFICE' && !hasOfficeLocation) return false;
    if (!hasLocationFix) return false;
    if (normalizedWorkMode == 'WORK_FROM_HOME') {
      return wfhReason != null && wfhReason!.trim().isNotEmpty;
    }
    return !geofenceEnabled || isWithinGeofence;
  }

  // Requirement 3 & 1: locationCheckProceedButtonLabel
  String get locationCheckProceedButtonLabel {
    if (normalizedWorkMode == 'OFFICE' && !hasOfficeLocation) {
      return 'Office location unavailable';
    }
    if (!hasLocationFix) {
      if (gpsStatus == GpsStatus.error ||
          gpsStatus == GpsStatus.serviceDisabled ||
          gpsStatus == GpsStatus.denied ||
          gpsStatus == GpsStatus.deniedForever) {
        return 'Retry location';
      }
      return 'Locating...';
    }
    if (normalizedWorkMode == 'WORK_FROM_HOME') {
      if (wfhReason == null || wfhReason!.trim().isEmpty) {
        return 'Enter WFH reason';
      }
      return 'Continue';
    }
    if (geofenceEnabled && !isWithinGeofence) return 'Move closer to office';
    return 'Continue';
  }

  double get requiredShiftHours => getRequiredShiftSeconds() / 3600.0;

  int getRequiredShiftSeconds() => (minWorkHours * 3600).round();

  double leavePendingHours(DateTime now) {
    final pending = requiredShiftHours - workedHours(now);
    return pending < 0 ? 0.0 : pending;
  }

  // Requirement 12: divisor 8.0
  double leavePendingDays(DateTime now) => leavePendingHours(now) / 8.0;

  String leavePendingHoursFormatted(DateTime now) {
    final pendingSec = (leavePendingHours(now) * 3600).round();
    final h = pendingSec ~/ 3600;
    final m = (pendingSec % 3600) ~/ 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String leavePendingDaysFormatted(DateTime now) =>
      leavePendingDays(now).toStringAsFixed(2);

  Duration breakDuration(DateTime now) {
    if (isOnBreak && breakStartedAt != null) {
      return completedBreak + now.difference(breakStartedAt!);
    }
    return completedBreak;
  }

  DateTime? getShiftEndDateTime(DateTime now) {
    try {
      if (shiftEndTime == '--' || shiftStartTime == '--') return null;
      final parts = shiftEndTime.replaceAll(RegExp(r'[^\d:]'), '').split(':');
      final startParts = shiftStartTime
          .replaceAll(RegExp(r'[^\d:]'), '')
          .split(':');
      if (parts.length >= 2) {
        int hour = int.tryParse(parts[0]) ?? 18;
        final min = int.tryParse(parts[1]) ?? 0;
        if (shiftEndTime.toUpperCase().contains('PM') && hour < 12) hour += 12;
        if (shiftEndTime.toUpperCase().contains('AM') && hour == 12) hour = 0;

        int startHour = 9;
        if (startParts.length >= 2) {
          startHour = int.tryParse(startParts[0]) ?? 9;
          if (shiftStartTime.toUpperCase().contains('PM') && startHour < 12)
            startHour += 12;
          if (shiftStartTime.toUpperCase().contains('AM') && startHour == 12)
            startHour = 0;
        }

        DateTime shiftEndDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          min,
        );
        if (hour <= startHour &&
            (shiftEndTime.toUpperCase().contains('AM') ||
                hour < 12 ||
                hour < startHour)) {
          shiftEndDateTime = shiftEndDateTime.add(const Duration(days: 1));
        }
        return shiftEndDateTime;
      }
    } catch (_) {}
    return null;
  }

  bool isPostShiftWarning30m(DateTime now) {
    if (!checkedIn || checkOutAt != null) return false;
    final endDt = getShiftEndDateTime(now);
    if (endDt == null) return false;
    return now.isAfter(endDt.add(const Duration(minutes: 30)));
  }

  bool get hasLocationFix =>
      gpsStatus == GpsStatus.ready && currentPosition != null;
  bool get isLocating =>
      gpsStatus == GpsStatus.detecting && currentPosition == null;

  String get locationProblemTitle {
    switch (gpsStatus) {
      case GpsStatus.serviceDisabled:
        return 'Location is turned off';
      case GpsStatus.denied:
        return 'Location permission needed';
      case GpsStatus.deniedForever:
        return 'Location blocked in settings';
      case GpsStatus.error:
        return "Can't detect your location";
      case GpsStatus.detecting:
        return 'Locating you...';
      case GpsStatus.ready:
        if (currentPosition == null) return 'Locating you...';
        return 'Location ready';
    }
  }

  String get locationActionLabel {
    if (gpsStatus == GpsStatus.serviceDisabled) return 'Turn on';
    if (gpsStatus == GpsStatus.deniedForever) return 'Settings';
    return 'Retry';
  }

  String get distanceDisplay {
    if (!hasLocationFix) {
      return isLocating ? 'Locating...' : '--';
    }
    if (distanceFromOfficeMeters < 1) return 'At office';
    if (distanceFromOfficeMeters < 1000) {
      return '${distanceFromOfficeMeters.round()} m away';
    }
    if (distanceFromOfficeMeters >= 100000) {
      return '${(distanceFromOfficeMeters / 1000).round()} km away';
    }
    return '${(distanceFromOfficeMeters / 1000).toStringAsFixed(1)} km away';
  }

  String checkedStatusLabel(DateTime now) {
    if (isOnBreak) return 'ON BREAK';
    if (isTemporaryClockOut) return 'SHIFT INCOMPLETE (STEPPED OUT)';
    if (checkOutAt != null) return 'SHIFT COMPLETED';
    if (checkInAt != null) {
      final mode =
          todayRecord['workMode']?.toString().toUpperCase() ?? workMode;
      return mode == 'WFH' || mode == 'WORK_FROM_HOME'
          ? 'PRESENT (WFH)'
          : 'CHECKED IN';
    }
    return 'NOT CHECKED IN';
  }

  // Requirement 4 & 5: Only require selfie step when faceVerificationRequired is true
  bool get canClockIn {
    if (isActionInProgress) return false;
    if (phase != PunchPhase.notCheckedIn) return false;
    if (faceVerificationRequired &&
        (capturedSelfieBase64 == null || capturedSelfieBase64!.isEmpty)) {
      return false;
    }
    final mode = normalizedWorkMode;
    if (mode == 'OFFICE') {
      return hasLocationFix && (!geofenceEnabled || isWithinGeofence);
    } else if (mode == 'WORK_FROM_HOME') {
      return wfhReason != null && wfhReason!.trim().isNotEmpty;
    }
    return false;
  }

  String? get clockInBlockedReason {
    if (!hasLocationFix) {
      return locationProblemTitle;
    }
    final mode = normalizedWorkMode;
    if (mode == 'OFFICE' && geofenceEnabled && !isWithinGeofence) {
      return 'You are outside the office geofence ($distanceDisplay).';
    }
    if (mode == 'WORK_FROM_HOME' &&
        (wfhReason == null || wfhReason!.trim().isEmpty)) {
      return 'Please enter a reason for working from home.';
    }
    if (faceVerificationRequired &&
        (capturedSelfieBase64 == null || capturedSelfieBase64!.isEmpty)) {
      return 'Please take a verification selfie.';
    }
    return null;
  }

  // Requirement 2: clearCheckIn = false, clearCheckOut = false, clearBreakStart = false, clearWfhReason = false
  PunchState copyWith({
    PunchPhase? phase,
    GpsStatus? gpsStatus,
    String? employeeId,
    String? employeeName,
    String? designation,
    String? department,
    String? avatar,
    Map<String, dynamic>? todayRecord,
    DateTime? checkInAt,
    bool clearCheckIn = false,
    DateTime? checkOutAt,
    bool clearCheckOut = false,
    DateTime? breakStartedAt,
    bool clearBreakStart = false,
    Duration? completedBreak,
    bool? isOnBreak,
    String? shiftName,
    String? shiftStartTime,
    String? shiftEndTime,
    String? checkInLocation,
    String? checkOutLocation,
    double? officeLat,
    double? officeLng,
    String? officeName,
    String? officeAddress,
    double? geofenceRadiusMeters,
    String? selectedTileType,
    Position? currentPosition,
    String? currentAddress,
    String? gpsStatusMessage,
    bool? isWithinGeofence,
    double? distanceFromOfficeMeters,
    List<dynamic>? attendanceHistory,
    int? presentDays,
    int? absentDays,
    int? lateClockIns,
    double? attendanceRatePercent,
    String? hoursLoggedBadge,
    bool? isLoading,
    bool? isActionInProgress,
    String? error,
    bool clearError = false,
    String? workMode,
    String? wfhReason,
    bool clearWfhReason = false,
    XFile? capturedSelfie,
    bool clearSelfie = false,
    String? capturedSelfieBase64,
    bool? isGalleryUpload,
    bool? isTemporaryClockOut,
    bool? applyLeaveForPendingHours,
    String? leaveReason,
    int? gracePeriodMinutes,
    bool? faceVerificationRequired,
    double? minWorkHours,
    bool? geofenceEnabled,
    List<dynamic>? branches,
    Map<String, dynamic>? selectedOffice,
    String? checkInStatus,
    String? checkOutStatus,
    String? todayStatusText,
    String? todayApprovalText,
    List<dynamic>? weekData,
    Map<String, dynamic>? thirtyDayOverview,
    DateTime? selectedDate,
    Map<String, dynamic>? serverGeofence,
  }) {
    final newCheckIn = clearCheckIn ? null : (checkInAt ?? this.checkInAt);
    final newCheckOut = clearCheckOut ? null : (checkOutAt ?? this.checkOutAt);
    final newBreakStartedAt = clearBreakStart
        ? null
        : (breakStartedAt ?? this.breakStartedAt);
    final newWfhReason = clearWfhReason ? null : (wfhReason ?? this.wfhReason);
    final newIsOnBreak = isOnBreak ?? this.isOnBreak;

    final rec = todayRecord ?? this.todayRecord;
    final isTempOut =
        isTemporaryClockOut ??
        ((todayRecord != null && todayRecord.isNotEmpty)
            ? (rec['isTemporaryClockOut'] == true ||
                  (rec['notes']?.toString().contains('[TEMPORARY_CLOCKOUT]') ??
                      false))
            : this.isTemporaryClockOut);

    PunchPhase computedPhase = this.phase;
    if (isTempOut) {
      computedPhase = PunchPhase.notCheckedIn;
    } else if (newCheckOut != null) {
      computedPhase = PunchPhase.checkedOut;
    } else if (newIsOnBreak) {
      computedPhase = PunchPhase.onBreak;
    } else if (newCheckIn != null) {
      computedPhase = PunchPhase.checkedIn;
    } else {
      computedPhase = PunchPhase.notCheckedIn;
    }

    return PunchState(
      phase: phase ?? computedPhase,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      avatar: avatar ?? this.avatar,
      todayRecord: todayRecord ?? this.todayRecord,
      checkInAt: newCheckIn,
      checkOutAt: newCheckOut,
      breakStartedAt: newBreakStartedAt,
      completedBreak: completedBreak ?? this.completedBreak,
      isOnBreak: newIsOnBreak,
      shiftName: shiftName ?? this.shiftName,
      shiftStartTime: shiftStartTime ?? this.shiftStartTime,
      shiftEndTime: shiftEndTime ?? this.shiftEndTime,
      checkInLocation: checkInLocation ?? this.checkInLocation,
      checkOutLocation: checkOutLocation ?? this.checkOutLocation,
      officeLat: officeLat ?? this.officeLat,
      officeLng: officeLng ?? this.officeLng,
      officeName: officeName ?? this.officeName,
      officeAddress: officeAddress ?? this.officeAddress,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      selectedTileType: selectedTileType ?? this.selectedTileType,
      currentPosition: currentPosition ?? this.currentPosition,
      currentAddress: currentAddress ?? this.currentAddress,
      gpsStatusMessage: gpsStatusMessage ?? this.gpsStatusMessage,
      isWithinGeofence: isWithinGeofence ?? this.isWithinGeofence,
      distanceFromOfficeMeters:
          distanceFromOfficeMeters ?? this.distanceFromOfficeMeters,
      attendanceHistory: attendanceHistory ?? this.attendanceHistory,
      presentDays: presentDays ?? this.presentDays,
      absentDays: absentDays ?? this.absentDays,
      lateClockIns: lateClockIns ?? this.lateClockIns,
      attendanceRatePercent:
          attendanceRatePercent ?? this.attendanceRatePercent,
      hoursLoggedBadge: hoursLoggedBadge ?? this.hoursLoggedBadge,
      isLoading: isLoading ?? this.isLoading,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      error: clearError ? null : (error ?? this.error),
      workMode: workMode ?? this.workMode,
      wfhReason: newWfhReason,
      capturedSelfie: clearSelfie
          ? null
          : (capturedSelfie ?? this.capturedSelfie),
      capturedSelfieBase64: clearSelfie
          ? null
          : (capturedSelfieBase64 ?? this.capturedSelfieBase64),
      isGalleryUpload: isGalleryUpload ?? this.isGalleryUpload,
      isTemporaryClockOut: isTemporaryClockOut ?? this.isTemporaryClockOut,
      applyLeaveForPendingHours:
          applyLeaveForPendingHours ?? this.applyLeaveForPendingHours,
      leaveReason: leaveReason ?? this.leaveReason,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      faceVerificationRequired:
          faceVerificationRequired ?? this.faceVerificationRequired,
      minWorkHours: minWorkHours ?? this.minWorkHours,
      geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
      branches: branches ?? this.branches,
      selectedOffice: selectedOffice ?? this.selectedOffice,
      checkInStatus: checkInStatus ?? this.checkInStatus,
      checkOutStatus: checkOutStatus ?? this.checkOutStatus,
      todayStatusText: todayStatusText ?? this.todayStatusText,
      todayApprovalText: todayApprovalText ?? this.todayApprovalText,
      weekData: weekData ?? this.weekData,
      thirtyDayOverview: thirtyDayOverview ?? this.thirtyDayOverview,
      selectedDate: selectedDate ?? this.selectedDate,
      serverGeofence: serverGeofence ?? this.serverGeofence,
    );
  }
}
