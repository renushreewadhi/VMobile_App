import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

enum PunchPhase { notCheckedIn, checkedIn, onBreak, checkedOut }

enum GpsStatus { detecting, ready, serviceDisabled, denied, deniedForever, error }

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

  // New flow fields
  final String workMode; // 'OFFICE' or 'WFH'
  final String? wfhReason;
  final XFile? capturedSelfie;
  final String? capturedSelfieBase64;
  final bool isGalleryUpload;

  const PunchState({
    this.phase = PunchPhase.notCheckedIn,
    this.gpsStatus = GpsStatus.detecting,
    this.employeeId = '',
    this.employeeName = 'Prince Vidyarthi',
    this.designation = 'Software Engineer',
    this.department = 'Development',
    this.avatar = '',
    this.todayRecord = const {},
    this.checkInAt,
    this.checkOutAt,
    this.breakStartedAt,
    this.completedBreak = Duration.zero,
    this.isOnBreak = false,
    this.shiftName = 'General Shift',
    this.shiftStartTime = '09:00 AM',
    this.shiftEndTime = '06:00 PM',
    this.checkInLocation = 'Office Location',
    this.checkOutLocation = 'Office Location',
    this.officeLat = 21.1986872,
    this.officeLng = 72.7965515,
    this.officeName = 'Envision Beyond India Pvt Ltd',
    this.officeAddress = '6Q2V+MR9, Anand Mahal Rd, Adajan, Surat, Gujarat 395009, India',
    this.geofenceRadiusMeters = 200.0,
    this.selectedTileType = 'Streets',
    this.currentPosition,
    this.currentAddress = 'Detecting location address...',
    this.gpsStatusMessage = 'Detecting location...',
    this.isWithinGeofence = false,
    this.distanceFromOfficeMeters = 0.0,
    this.attendanceHistory = const [],
    this.presentDays = 0,
    this.absentDays = 0,
    this.lateClockIns = 0,
    this.attendanceRatePercent = 0.0,
    this.hoursLoggedBadge = '14.44h logged',
    this.isLoading = true,
    this.isActionInProgress = false,
    this.error,
    this.workMode = 'OFFICE',
    this.wfhReason,
    this.capturedSelfie,
    this.capturedSelfieBase64,
    this.isGalleryUpload = false,
  });

  bool get checkedIn => checkInAt != null && checkOutAt == null;

  bool get isLowAccuracy => currentPosition != null && currentPosition!.accuracy > 50;

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

  Duration breakDuration(DateTime now) {
    if (isOnBreak && breakStartedAt != null) {
      return completedBreak + now.difference(breakStartedAt!);
    }
    return completedBreak;
  }

  bool isPostShiftWarning30m(DateTime now) {
    if (!checkedIn || checkOutAt != null) return false;
    try {
      final parts = shiftEndTime.replaceAll(RegExp(r'[^\d:]'), '').split(':');
      if (parts.length >= 2) {
        int hour = int.tryParse(parts[0]) ?? 18;
        final min = int.tryParse(parts[1]) ?? 0;
        if (shiftEndTime.toUpperCase().contains('PM') && hour < 12) hour += 12;
        if (shiftEndTime.toUpperCase().contains('AM') && hour == 12) hour = 0;

        final shiftEndDateTime = DateTime(now.year, now.month, now.day, hour, min);
        return now.isAfter(shiftEndDateTime.add(const Duration(minutes: 30)));
      }
    } catch (_) {}
    return false;
  }

  String get distanceDisplay {
    if (distanceFromOfficeMeters <= 0) return '0m away';
    if (distanceFromOfficeMeters >= 1000) {
      return '${(distanceFromOfficeMeters / 1000).toStringAsFixed(2)}km away';
    }
    return '${distanceFromOfficeMeters.round()}m away';
  }

  String checkedStatusLabel(DateTime now) {
    if (isOnBreak) return 'ON BREAK';
    if (checkOutAt != null) return 'SHIFT COMPLETED';
    if (checkInAt != null) {
      final mode = todayRecord['workMode']?.toString().toUpperCase() ?? workMode;
      return mode == 'WFH' || mode == 'WORK_FROM_HOME' ? 'PRESENT (WFH)' : 'CHECKED IN';
    }
    return 'NOT CHECKED IN';
  }

  bool get canClockIn {
    if (isActionInProgress) return false;
    if (phase != PunchPhase.notCheckedIn) return false;
    if (capturedSelfieBase64 == null || capturedSelfieBase64!.isEmpty) return false;
    if (workMode == 'OFFICE') {
      return gpsStatus == GpsStatus.ready && currentPosition != null && isWithinGeofence;
    } else if (workMode == 'WFH') {
      return wfhReason != null && wfhReason!.trim().isNotEmpty;
    }
    return false;
  }

  String? get clockInBlockedReason {
    if (isActionInProgress) return 'Action in progress...';
    if (phase != PunchPhase.notCheckedIn) return 'You are already checked in or out.';
    if (capturedSelfieBase64 == null || capturedSelfieBase64!.isEmpty) {
      return 'Selfie is required to clock in.';
    }
    if (workMode == 'OFFICE') {
      if (gpsStatus != GpsStatus.ready || currentPosition == null) {
        return 'Waiting for GPS fix...';
      }
      if (!isWithinGeofence) {
        return 'You are outside the office geofence ($distanceDisplay).';
      }
    } else if (workMode == 'WFH') {
      if (wfhReason == null || wfhReason!.trim().isEmpty) {
        return 'Please enter a reason for WFH.';
      }
    }
    return null;
  }

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
    DateTime? checkOutAt,
    DateTime? breakStartedAt,
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
    XFile? capturedSelfie,
    bool clearSelfie = false,
    String? capturedSelfieBase64,
    bool? isGalleryUpload,
  }) {
    final newCheckIn = checkInAt ?? this.checkInAt;
    final newCheckOut = checkOutAt ?? this.checkOutAt;
    final newIsOnBreak = isOnBreak ?? this.isOnBreak;

    PunchPhase computedPhase = this.phase;
    if (newCheckOut != null) {
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
      checkInAt: checkInAt ?? this.checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      breakStartedAt: breakStartedAt ?? this.breakStartedAt,
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
      distanceFromOfficeMeters: distanceFromOfficeMeters ?? this.distanceFromOfficeMeters,
      attendanceHistory: attendanceHistory ?? this.attendanceHistory,
      presentDays: presentDays ?? this.presentDays,
      absentDays: absentDays ?? this.absentDays,
      lateClockIns: lateClockIns ?? this.lateClockIns,
      attendanceRatePercent: attendanceRatePercent ?? this.attendanceRatePercent,
      hoursLoggedBadge: hoursLoggedBadge ?? this.hoursLoggedBadge,
      isLoading: isLoading ?? this.isLoading,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      error: clearError ? null : (error ?? this.error),
      workMode: workMode ?? this.workMode,
      wfhReason: wfhReason ?? this.wfhReason,
      capturedSelfie: clearSelfie ? null : (capturedSelfie ?? this.capturedSelfie),
      capturedSelfieBase64: clearSelfie ? null : (capturedSelfieBase64 ?? this.capturedSelfieBase64),
      isGalleryUpload: isGalleryUpload ?? this.isGalleryUpload,
    );
  }
}
