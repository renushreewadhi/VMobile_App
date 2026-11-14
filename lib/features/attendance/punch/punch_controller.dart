import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/attendance_service.dart';
import '../../../core/api/leave_service.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/errors/api_exception.dart';
import 'punch_state.dart';

class PunchMessage {
  final String text;
  final bool isError;
  const PunchMessage(this.text, {this.isError = false});
}

enum ClockOutResult { success, needsHalfDayOverride, blockedOnBreak, failure }

final punchControllerProvider = StateNotifierProvider<PunchController, PunchState>((ref) {
  return PunchController(ref);
});

final punchMessageProvider = StreamProvider<PunchMessage>((ref) {
  final controller = ref.watch(punchControllerProvider.notifier);
  return controller.messageStream;
});

class PunchController extends StateNotifier<PunchState> with WidgetsBindingObserver {
  final Ref _ref;
  final ImagePicker _imagePicker = ImagePicker();
  DateTime? _lastLoadedDate;

  final _messageController = StreamController<PunchMessage>.broadcast();
  Stream<PunchMessage> get messageStream => _messageController.stream;

  PunchController(this._ref) : super(const PunchState()) {
    WidgetsBinding.instance.addObserver(this);
    loadAllData();

    _ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (!next.isAuthenticated || next.user == null) {
        state = const PunchState();
      } else if (previous?.user?.id != next.user?.id) {
        state = const PunchState();
        loadAllData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.close();
    super.dispose();
  }

  void emitMessage(String text, {bool isError = false}) {
    if (!_messageController.isClosed) {
      _messageController.add(PunchMessage(text, isError: isError));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastLoadedDate == null ||
          _lastLoadedDate!.year != now.year ||
          _lastLoadedDate!.month != now.month ||
          _lastLoadedDate!.day != now.day) {
        loadAllData();
      } else {
        fetchLiveGpsLocation();
      }
    }
  }

  String? _extractFirst(Map map, List<String> keys) {
    for (final k in keys) {
      if (map.containsKey(k) && map[k] != null) {
        final val = map[k].toString().trim();
        if (val.isNotEmpty && val != 'null') return val;
      }
    }
    return null;
  }

  Future<dynamic> _tryFetch(AttendanceService attendanceService, List<String> endpoints, {Map<String, String>? queryParams}) async {
    for (final ep in endpoints) {
      try {
        final res = await attendanceService.rawGet(ep, queryParams: queryParams);
        if (res != null) return res;
      } catch (_) {}
    }
    return null;
  }

  Future<void> loadAllData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    _lastLoadedDate = DateTime.now();
    final apiClient = _ref.read(apiClientProvider);
    final attendanceService = _ref.read(attendanceServiceProvider);

    try {
      final profileRes = await apiClient.get(ApiEndpoints.currentUser).catchError((_) => <String, dynamic>{});
      final profile = profileRes is Map<String, dynamic> ? (profileRes['data'] ?? profileRes) : <String, dynamic>{};
      
      final empId = profile['id']?.toString() ?? profile['employeeId']?.toString() ?? '';
      final eName = profile['employeeName'] ?? profile['fullName'] ??
          '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim();
      final designation = profile['designationName'] ?? profile['designation'] ?? 'Software Engineer';
      final department = profile['departmentName'] ?? profile['department'] ?? 'Development';
      final avatar = profile['avatar'] ?? '';

      final startDate = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T')[0];
      final endDate = DateTime.now().toIso8601String().split('T')[0];

      final todayRes = await _tryFetch(attendanceService, [
        ApiEndpoints.attendanceToday,
        '/attendance/today',
        '/attendance/active',
        '/attendance/current',
      ]);

      final shiftRes = await _tryFetch(attendanceService, [
        '/attendance/my-shift',
        '/shifts/my-shift',
        '/attendance/shift',
        '/shifts/current',
      ]);

      final officeLocRes = await _tryFetch(attendanceService, [
        '/attendance/office-location',
        '/attendance/office',
        '/attendance/geofence',
      ]);

      final summaryRes = await _tryFetch(attendanceService, [
        ApiEndpoints.attendanceSummary,
        '/attendance/my',
        '/attendance/records',
        '/attendance',
      ], queryParams: {'startDate': startDate, 'endDate': endDate});

      final record = todayRes is Map ? (todayRes['data'] ?? todayRes) : <String, dynamic>{};
      final shift = shiftRes is Map ? (shiftRes['data'] ?? shiftRes) : <String, dynamic>{};
      final officeLoc = officeLocRes is Map ? (officeLocRes['data'] ?? officeLocRes) : <String, dynamic>{};
      
      List<dynamic> historyList = [];
      dynamic summaryData = summaryRes;
      if (summaryRes is Map) {
        final dataField = summaryRes['data'] ?? summaryRes['items'] ?? summaryRes['records'];
        if (dataField is List) {
          historyList = dataField;
        } else if (dataField is Map) {
          summaryData = dataField;
        }
        if (summaryRes['history'] is List) {
          historyList = summaryRes['history'];
        }
      } else if (summaryRes is List) {
        historyList = summaryRes;
      }

      double officeLat = state.officeLat;
      double officeLng = state.officeLng;
      String officeName = state.officeName;
      String officeAddress = state.officeAddress;
      double geofenceRadius = state.geofenceRadiusMeters;

      if (officeLoc is Map && officeLoc.isNotEmpty) {
        if (officeLoc['latitude'] != null && officeLoc['longitude'] != null) {
          officeLat = (officeLoc['latitude'] as num).toDouble();
          officeLng = (officeLoc['longitude'] as num).toDouble();
        }
        if (officeLoc['officeName'] != null) officeName = officeLoc['officeName'].toString();
        if (officeLoc['officeAddress'] != null) officeAddress = officeLoc['officeAddress'].toString();
        if (officeLoc['geofenceRadiusMeters'] != null) {
          geofenceRadius = (officeLoc['geofenceRadiusMeters'] as num).toDouble();
        }
      }

      String shiftName = state.shiftName;
      String shiftStartTime = state.shiftStartTime;
      String shiftEndTime = state.shiftEndTime;

      if (shift is Map && shift.isNotEmpty) {
        final sName = shift['name']?.toString() ?? shift['shiftName']?.toString();
        final sStart = shift['startTime']?.toString() ?? shift['shiftStartTime']?.toString();
        final sEnd = shift['endTime']?.toString() ?? shift['shiftEndTime']?.toString();
        if (sName != null && sName.isNotEmpty) shiftName = sName;
        if (sStart != null && sStart.isNotEmpty) shiftStartTime = sStart;
        if (sEnd != null && sEnd.isNotEmpty) shiftEndTime = sEnd;
      }

      DateTime? checkInAt;
      DateTime? checkOutAt;
      bool isOnBreak = false;
      DateTime? breakStartedAt;
      Duration completedBreak = Duration.zero;
      String checkInLocation = state.checkInLocation;
      String checkOutLocation = state.checkOutLocation;
      Map<String, dynamic> todayRecord = {};

      bool isTempOut = false;
      if (record is Map && record.isNotEmpty) {
        todayRecord = Map<String, dynamic>.from(record);

        final notes = record['notes']?.toString() ?? '';
        isTempOut = record['isTemporaryClockOut'] == true || notes.contains('[TEMPORARY_CLOCKOUT]');

        final checkInStr = _extractFirst(record, [
          'checkIn', 'checkInTime', 'punchIn', 'punchInTime', 'clockIn', 'checkInAt', 'inTime'
        ]);
        final checkOutStr = _extractFirst(record, [
          'checkOut', 'checkOutTime', 'punchOut', 'punchOutTime', 'clockOut', 'checkOutAt', 'outTime'
        ]);

        final statusStr = _extractFirst(record, ['status', 'attendanceStatus'])?.toUpperCase();
        isOnBreak = record['isOnBreak'] == true ||
            record['onBreak'] == true ||
            statusStr == 'BREAK' ||
            statusStr == 'ON_BREAK';

        final breakStartStr = _extractFirst(record, [
          'activeBreakStart', 'breakStart', 'breakStartTime', 'lastBreakStart'
        ]);

        final inLoc = _extractFirst(record, [
          'checkInLocation', 'location', 'checkInAddress', 'officeLocation'
        ]);
        final outLoc = _extractFirst(record, ['checkOutLocation', 'checkOutAddress']);

        final breakMinsVal = record['totalBreakMinutes'] ?? record['breakMinutes'] ?? record['breakDurationMinutes'];
        double breakMinutesNum = 0;
        if (breakMinsVal is num) {
          breakMinutesNum = breakMinsVal.toDouble();
        } else if (breakMinsVal != null) {
          breakMinutesNum = double.tryParse(breakMinsVal.toString()) ?? 0;
        }

        checkInAt = checkInStr != null && checkInStr.trim().isNotEmpty ? DateTime.tryParse(checkInStr)?.toLocal() : null;
        checkOutAt = checkOutStr != null && checkOutStr.trim().isNotEmpty ? DateTime.tryParse(checkOutStr)?.toLocal() : null;
        breakStartedAt = breakStartStr != null && breakStartStr.trim().isNotEmpty ? DateTime.tryParse(breakStartStr)?.toLocal() : null;
        completedBreak = Duration(seconds: (breakMinutesNum * 60).round());

        if (inLoc != null && inLoc.isNotEmpty) checkInLocation = inLoc;
        if (outLoc != null && outLoc.isNotEmpty) checkOutLocation = outLoc;
      }

      state = state.copyWith(
        employeeId: empId.isNotEmpty ? empId : state.employeeId,
        employeeName: eName.isNotEmpty ? eName : state.employeeName,
        designation: designation,
        department: department,
        avatar: avatar,
        todayRecord: todayRecord,
        checkInAt: checkInAt,
        checkOutAt: checkOutAt,
        breakStartedAt: breakStartedAt,
        completedBreak: completedBreak,
        isOnBreak: isOnBreak,
        shiftName: shiftName,
        shiftStartTime: shiftStartTime,
        shiftEndTime: shiftEndTime,
        checkInLocation: checkInLocation,
        checkOutLocation: checkOutLocation,
        officeLat: officeLat,
        officeLng: officeLng,
        officeName: officeName,
        officeAddress: officeAddress,
        geofenceRadiusMeters: geofenceRadius,
        attendanceHistory: historyList,
        isTemporaryClockOut: isTempOut,
        isLoading: false,
      );

      _calculateOverviewStats(historyList, summaryData);
    } catch (e) {
      final err = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      state = state.copyWith(isLoading: false, error: err);
    }

    await fetchLiveGpsLocation(officeLat: state.officeLat, officeLng: state.officeLng, radius: state.geofenceRadiusMeters);
  }

  void _calculateOverviewStats(List<dynamic> history, [dynamic summaryRaw]) {
    int presentDays = 0;
    int absentDays = 0;
    int lateClockIns = 0;
    double attendanceRatePercent = 0.0;
    String hoursLoggedBadge = state.hoursLoggedBadge;

    if (summaryRaw is Map && summaryRaw.isNotEmpty) {
      final pDays = summaryRaw['presentDays'] ?? summaryRaw['presentCount'] ?? summaryRaw['present'];
      final aDays = summaryRaw['absentDays'] ?? summaryRaw['absentCount'] ?? summaryRaw['absent'] ?? summaryRaw['leavesCount'];
      final lIns = summaryRaw['lateClockIns'] ?? summaryRaw['lateCount'] ?? summaryRaw['lateIn'] ?? summaryRaw['late'];
      final rate = summaryRaw['attendanceRate'] ?? summaryRaw['attendanceRatePercent'] ?? summaryRaw['percentage'];
      final hrs = summaryRaw['totalLoggedHours'] ?? summaryRaw['hoursLogged'] ?? summaryRaw['totalHours'] ?? summaryRaw['loggedHours'];

      if (pDays != null) presentDays = (pDays as num).toInt();
      if (aDays != null) absentDays = (aDays as num).toInt();
      if (lIns != null) lateClockIns = (lIns as num).toInt();
      if (rate != null) attendanceRatePercent = (rate as num).toDouble();
      if (hrs != null) {
        final hrsVal = (hrs as num).toDouble();
        hoursLoggedBadge = '${hrsVal.toStringAsFixed(2)}h logged';
      }
      state = state.copyWith(
        presentDays: presentDays,
        absentDays: absentDays,
        lateClockIns: lateClockIns,
        attendanceRatePercent: attendanceRatePercent,
        hoursLoggedBadge: hoursLoggedBadge,
      );
      return;
    }

    int presentCount = 0;
    int absentCount = 0;
    int lateCount = 0;

    for (final item in history) {
      if (item is Map) {
        final status = (item['status'] ?? item['attendanceStatus'] ?? '').toString().toUpperCase();
        final lateMins = item['lateDurationMinutes'] ?? item['lateMinutes'] ?? item['lateInMinutes'];
        final isLateFlag = item['isLate'] == true || item['late'] == true || status == 'LATE' || status.contains('LATE');

        if (status.contains('PRESENT') || status.contains('WORK') || status == 'ON_TIME' || status == 'REGULAR') {
          presentCount++;
        } else if (status.contains('ABSENT') || status == 'LEAVE' || status == 'ON_LEAVE') {
          absentCount++;
        } else if (status.contains('HALF') || status.contains('PARTIAL')) {
          presentCount++;
        }

        if (isLateFlag || (lateMins != null && (lateMins as num) > 0)) {
          lateCount++;
        }
      }
    }

    final totalDays = math.max(1, history.length);
    state = state.copyWith(
      presentDays: presentCount,
      absentDays: absentCount,
      lateClockIns: lateCount,
      attendanceRatePercent: (presentCount / totalDays * 100).roundToDouble(),
    );
  }

  Future<void> refreshGps() async {
    await fetchLiveGpsLocation(officeLat: state.officeLat, officeLng: state.officeLng, radius: state.geofenceRadiusMeters);
  }

  Future<void> fetchLiveGpsLocation({double? officeLat, double? officeLng, double? radius}) async {
    final lat = officeLat ?? state.officeLat;
    final lng = officeLng ?? state.officeLng;
    final rad = radius ?? state.geofenceRadiusMeters;

    state = state.copyWith(gpsStatus: GpsStatus.detecting, gpsStatusMessage: 'Detecting GPS signal & location address...');

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          gpsStatus: GpsStatus.serviceDisabled,
          gpsStatusMessage: 'GPS disabled. Please enable device location.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            gpsStatus: GpsStatus.denied,
            gpsStatusMessage: 'Location permission denied.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          gpsStatus: GpsStatus.deniedForever,
          gpsStatusMessage: 'Location permission permanently denied in settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final distance = Geolocator.distanceBetween(position.latitude, position.longitude, lat, lng);
      final isWithin = distance <= rad;
      final distStr = distance >= 1000 ? '${(distance / 1000).toStringAsFixed(2)}km' : '${distance.round()}m';

      String checkInLoc = state.checkInLocation;
      if (state.checkInAt == null) {
        checkInLoc = isWithin
            ? 'Office Location (${state.officeName})'
            : 'Remote Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      }

      state = state.copyWith(
        gpsStatus: GpsStatus.ready,
        currentPosition: position,
        distanceFromOfficeMeters: distance,
        isWithinGeofence: isWithin,
        gpsStatusMessage: isWithin
            ? 'Inside Geofence ($distStr from office)'
            : 'Outside Geofence ($distStr from office, limit: ${rad.round()}m)',
        currentAddress: 'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)} (±${position.accuracy.round()}m)',
        checkInLocation: checkInLoc,
      );
    } catch (e) {
      state = state.copyWith(
        gpsStatus: GpsStatus.error,
        gpsStatusMessage: 'GPS detection failed: ${e.toString().replaceFirst("Exception: ", "")}',
      );
    }
  }

  void setWorkMode(String mode) {
    state = state.copyWith(workMode: mode);
  }

  void setWfhReason(String reason) {
    state = state.copyWith(wfhReason: reason);
  }

  void setTileType(String tileType) {
    state = state.copyWith(selectedTileType: tileType);
  }

  Future<void> takeSelfie(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Str = base64Encode(bytes);
        state = state.copyWith(
          capturedSelfie: image,
          capturedSelfieBase64: base64Str,
          isGalleryUpload: (source == ImageSource.gallery),
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Camera error: $e');
      emitMessage('Camera error: $e', isError: true);
    }
  }

  void clearSelfie() {
    state = state.copyWith(clearSelfie: true);
  }

  Future<bool> clockIn({required String workMode, String? wfhReason, String? selfieBase64, bool isGallery = false}) async {
    state = state.copyWith(isActionInProgress: true, clearError: true);
    final attendanceService = _ref.read(attendanceServiceProvider);

    try {
      final pos = state.currentPosition;
      final lat = pos?.latitude ?? (state.officeLat != 0.0 ? state.officeLat : 12.9716);
      final lng = pos?.longitude ?? (state.officeLng != 0.0 ? state.officeLng : 77.5946);
      final loc = pos != null
          ? 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}'
          : (state.officeName.isNotEmpty ? state.officeName : 'Mobile App Check-In');

      final faceBase64 = selfieBase64 ?? state.capturedSelfieBase64;
      String? finalFaceBase64 = faceBase64;
      if ((finalFaceBase64 == null || finalFaceBase64.isEmpty) && state.capturedSelfie != null) {
        try {
          final bytes = await File(state.capturedSelfie!.path).readAsBytes();
          finalFaceBase64 = base64Encode(bytes);
        } catch (_) {}
      }

      final isResuming = state.isTemporaryClockOut;

      await attendanceService.checkIn({
        'latitude': lat,
        'longitude': lng,
        'location': loc,
        'notes': isResuming ? 'Resuming shift (Temporary clock-out resumption)' : 'Punched in from mobile app',
        'capturedFaceBase64': finalFaceBase64 ?? '',
        'verificationType': 'CLOCK_IN',
        'workMode': workMode,
        'wfhReason': wfhReason ?? state.wfhReason ?? '',
        'isGalleryUpload': isGallery,
        if (isResuming) 'isResume': true,
        if (isResuming) 'isTemporaryClockOut': false,
      });

      // Clear selfie memory and reset temporary clock out state after successful submit
      state = state.copyWith(
        isActionInProgress: false,
        clearSelfie: true,
        isTemporaryClockOut: false,
      );
      emitMessage(isResuming ? 'Shift resumed successfully! Welcome back.' : 'Clocked in successfully!');
      await loadAllData();
      return true;
    } catch (e) {
      final err = e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "");
      state = state.copyWith(isActionInProgress: false, error: err);
      emitMessage('Clock-in failed: $err', isError: true);
      return false;
    }
  }

  Future<ClockOutResult> clockOut({
    bool isHalfDayOverride = false,
    bool isTemporary = false,
    bool applyLeave = false,
    String? leaveType,
    String? leaveReason,
  }) async {
    if (state.isOnBreak) {
      emitMessage('End your break before clocking out.', isError: true);
      return ClockOutResult.blockedOnBreak;
    }

    state = state.copyWith(isActionInProgress: true, clearError: true);
    final attendanceService = _ref.read(attendanceServiceProvider);
    final leaveService = _ref.read(leaveServiceProvider);

    try {
      if (applyLeave && leaveType != null) {
        final nowStr = DateTime.now().toIso8601String().split('T')[0];
        await leaveService.applyLeave({
          'leaveType': leaveType,
          'startDate': nowStr,
          'endDate': nowStr,
          'reason': leaveReason ?? 'Early check-out deficit hours charge',
          'session': 'FULL_DAY',
        });
      }

      final pos = state.currentPosition;
      final lat = pos?.latitude ?? (state.officeLat != 0.0 ? state.officeLat : 12.9716);
      final lng = pos?.longitude ?? (state.officeLng != 0.0 ? state.officeLng : 77.5946);
      final loc = pos != null
          ? 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}'
          : (state.officeName.isNotEmpty ? state.officeName : 'Mobile App Check-Out');

      final workDuration = state.workDuration(DateTime.now());
      final isLess8Hrs = workDuration.inHours < 8 && !isTemporary;
      final workModeToUse = (isHalfDayOverride || isLess8Hrs || state.todayRecord['workMode'] == 'HALF_DAY')
          ? 'HALF_DAY'
          : (state.todayRecord['workMode']?.toString() ?? 'OFFICE');

      final notesToUse = isTemporary
          ? 'Temporary clock out (Stepping out)'
          : ((isHalfDayOverride || isLess8Hrs)
              ? 'Half Day Check-Out (${workDuration.inHours}h ${workDuration.inMinutes.remainder(60)}m worked)'
              : 'Punched out from mobile app');

      await attendanceService.rawPost(ApiEndpoints.punchOut, body: {
        'latitude': lat,
        'longitude': lng,
        'location': loc,
        'notes': notesToUse,
        'verificationType': 'CLOCK_OUT',
        'workMode': workModeToUse,
        'wfhReason': 'Check-out authorized',
        'isTemporaryClockOut': isTemporary,
      });

      state = state.copyWith(isActionInProgress: false, isTemporaryClockOut: isTemporary);
      if (isTemporary) {
        emitMessage('Clocked out temporarily. Remember to clock back in before shift end!');
      } else {
        emitMessage('Checked out successfully! Great work today.');
      }
      await loadAllData();
      return ClockOutResult.success;
    } catch (e) {
      final errStr = e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "");
      
      if (!isTemporary && (errStr.contains('8.00 net working hours') ||
          errStr.contains('complete at least') ||
          errStr.contains('Status: 400') ||
          state.workDuration(DateTime.now()).inHours < 8)) {
        state = state.copyWith(isActionInProgress: false);
        return ClockOutResult.needsHalfDayOverride;
      } else {
        state = state.copyWith(isActionInProgress: false);
        emitMessage('Clock-out failed: $errStr', isError: true);
        return ClockOutResult.failure;
      }
    }
  }

  Future<void> toggleBreak() async {
    if (state.checkInAt == null) {
      emitMessage('Clock in before starting a break.', isError: true);
      return;
    }
    if (state.checkOutAt != null) {
      emitMessage('Your workday is already complete.', isError: true);
      return;
    }

    state = state.copyWith(isActionInProgress: true, clearError: true);
    final attendanceService = _ref.read(attendanceServiceProvider);

    try {
      if (state.isOnBreak) {
        await attendanceService.endBreak();
        emitMessage('Break ended successfully.');
      } else {
        await attendanceService.rawPost(ApiEndpoints.breakStart, body: {
          'breakType': 'SHORT',
          'reason': 'Mobile app break',
        });
        emitMessage('Break started successfully.');
      }
      state = state.copyWith(isActionInProgress: false);
      await loadAllData();
    } catch (e) {
      final err = e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "");
      state = state.copyWith(isActionInProgress: false);
      emitMessage(err, isError: true);
    }
  }

  Future<bool> submitRegularization(Map<String, dynamic> payload) async {
    state = state.copyWith(isActionInProgress: true, clearError: true);
    final attendanceService = _ref.read(attendanceServiceProvider);

    try {
      await attendanceService.requestCorrection(payload);
      state = state.copyWith(isActionInProgress: false);
      emitMessage('Correction request submitted successfully.');
      await loadAllData();
      return true;
    } catch (e) {
      final err = e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "");
      state = state.copyWith(isActionInProgress: false, error: err);
      emitMessage('Submission failed: $err', isError: true);
      return false;
      state = state.copyWith(isActionInProgress: false, error: err);
      emitMessage('Submission failed: $err', isError: true);
      return false;
    }
  }
}
