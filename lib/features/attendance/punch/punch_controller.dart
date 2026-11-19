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
import '../../../core/config/app_config.dart';
import 'punch_state.dart';

class PunchMessage {
  final String text;
  final bool isError;
  const PunchMessage(this.text, {this.isError = false});
}

enum ClockOutResult {
  success,
  needsDeficitLeaveOverride,
  blockedOnBreak,
  failure,
}

final punchControllerProvider =
    StateNotifierProvider<PunchController, PunchState>((ref) {
      return PunchController(ref);
    });

final punchMessageProvider = StreamProvider<PunchMessage>((ref) {
  final controller = ref.watch(punchControllerProvider.notifier);
  return controller.messageStream;
});

class PunchController extends StateNotifier<PunchState>
    with WidgetsBindingObserver {
  final Ref _ref;
  final ImagePicker _imagePicker = ImagePicker();
  DateTime? _lastLoadedDate;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Throttling fields for geofence validation and reverse geocoding
  DateTime? _lastGeofenceValidationTime;
  Position? _lastValidatedPosition;
  Position? _lastGeocodedPosition;
  String? _lastGeocodedAddress;

  final _messageController = StreamController<PunchMessage>.broadcast();
  Stream<PunchMessage> get messageStream => _messageController.stream;

  PunchController(this._ref) : super(const PunchState()) {
    WidgetsBinding.instance.addObserver(this);
    loadAllData();

    _ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (!next.isAuthenticated || next.user == null) {
        state = const PunchState();
        stopGpsStream();
      } else if (previous?.user?.id != next.user?.id) {
        state = const PunchState();
        stopGpsStream();
        loadAllData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopGpsStream();
    _messageController.close();
    super.dispose();
  }

  void emitMessage(String text, {bool isError = false}) {
    if (!_messageController.isClosed) {
      _messageController.add(PunchMessage(text, isError: isError));
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastLoadedDate == null ||
          _lastLoadedDate!.year != now.year ||
          _lastLoadedDate!.month != now.month ||
          _lastLoadedDate!.day != now.day) {
        loadAllData();
      } else if (state.gpsStatus == GpsStatus.ready) {
        fetchLiveGpsLocation();
      }
    }
  }

  // Safe helper parsers (Requirement 13)
  int _parseInt(dynamic val, int fallback) {
    if (val is num) return val.toInt();
    if (val != null) return int.tryParse(val.toString()) ?? fallback;
    return fallback;
  }

  double _parseDouble(dynamic val, double fallback) {
    if (val is num) return val.toDouble();
    if (val != null) return double.tryParse(val.toString()) ?? fallback;
    return fallback;
  }

  String? _extractFirst(Map map, List<String> keys) {
    for (final k in keys) {
      if (map.containsKey(k) && map[k] != null) {
        final val = map[k].toString().trim();
        if (val.isNotEmpty &&
            val != 'null' &&
            val != 'undefined' &&
            val != '0001-01-01T00:00:00' &&
            val != '0001-01-01T00:00:00Z' &&
            val != '1970-01-01T00:00:00Z' &&
            !val.startsWith('0001-01-01') &&
            !val.startsWith('1970-01-01')) {
          return val;
        }
      }
    }
    return null;
  }

  DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final dt = DateTime.tryParse(dateStr.trim())?.toLocal();
    if (dt == null || dt.year <= 1970) return null;
    return dt;
  }

  // Requirement 7: GPS Stream Lifecycle
  void startGpsStream() {
    _startPositionStream();
  }

  void stopGpsStream() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  // Requirement 11: Selected Date Navigation (/attendance/my-date/{date})
  Future<void> loadForDate(DateTime date) async {
    state = state.copyWith(
      isLoading: true,
      selectedDate: date,
      clearError: true,
    );
    final attendanceService = _ref.read(attendanceServiceProvider);
    final dateStr = date.toIso8601String().split('T')[0];

    try {
      final res = await attendanceService
          .rawGet('/attendance/my-date/$dateStr')
          .catchError((_) => null);
      final record = res is Map ? (res['data'] ?? res) : <String, dynamic>{};

      if (record is Map && record.isNotEmpty) {
        final rec = Map<String, dynamic>.from(record);
        final checkInStr = _extractFirst(rec, [
          'checkIn',
          'checkInTime',
          'punchIn',
          'punchInTime',
          'clockIn',
          'checkInAt',
          'inTime',
        ]);
        final checkOutStr = _extractFirst(rec, [
          'checkOut',
          'checkOutTime',
          'punchOut',
          'punchOutTime',
          'clockOut',
          'checkOutAt',
          'outTime',
        ]);
        final breakStartStr = _extractFirst(rec, [
          'activeBreakStart',
          'breakStart',
          'breakStartTime',
        ]);
        final inLoc = _extractFirst(rec, [
          'checkInLocation',
          'location',
          'checkInAddress',
        ]);
        final outLoc = _extractFirst(rec, [
          'checkOutLocation',
          'checkOutAddress',
        ]);

        final checkInAt = checkInStr != null && checkInStr.isNotEmpty
            ? DateTime.tryParse(checkInStr)?.toLocal()
            : null;
        final checkOutAt = checkOutStr != null && checkOutStr.isNotEmpty
            ? DateTime.tryParse(checkOutStr)?.toLocal()
            : null;
        final breakStartedAt = breakStartStr != null && breakStartStr.isNotEmpty
            ? DateTime.tryParse(breakStartStr)?.toLocal()
            : null;

        final breakMinsVal = rec['totalBreakMinutes'] ?? rec['breakMinutes'];
        final breakMins = _parseDouble(breakMinsVal, 0.0);

        final checkInStatus =
            rec['checkInStatus']?.toString() ??
            (rec['isLate'] == true ? 'LATE' : 'ON_TIME');
        final checkOutStatus =
            rec['checkOutStatus']?.toString() ??
            (rec['isEarlyOut'] == true ? 'EARLY_LEAVE' : 'REGULAR');
        final todayStatusText =
            rec['status']?.toString() ??
            rec['attendanceStatus']?.toString() ??
            'PRESENT';
        final todayApprovalText = rec['verificationStatus'] != null
            ? 'Approved by ${rec['verifiedByRole'] ?? 'System'}'
            : 'Approved by System';

        state = state.copyWith(
          todayRecord: rec,
          checkInAt: checkInAt,
          clearCheckIn: checkInAt == null,
          checkOutAt: checkOutAt,
          clearCheckOut: checkOutAt == null,
          breakStartedAt: breakStartedAt,
          clearBreakStart: breakStartedAt == null,
          completedBreak: Duration(seconds: (breakMins * 60).round()),
          checkInLocation: inLoc ?? '--',
          checkOutLocation: outLoc ?? '--',
          checkInStatus: checkInStatus,
          checkOutStatus: checkOutStatus,
          todayStatusText: todayStatusText,
          todayApprovalText: todayApprovalText,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          todayRecord: {},
          clearCheckIn: true,
          clearCheckOut: true,
          clearBreakStart: true,
          completedBreak: Duration.zero,
          checkInLocation: '--',
          checkOutLocation: '--',
          checkInStatus: '--',
          checkOutStatus: '--',
          todayStatusText: '--',
          todayApprovalText: '--',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load date $dateStr',
      );
    }
  }

  // Requirement 13: Run independent loads with Future.wait
  Future<void> loadAllData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    _lastLoadedDate = DateTime.now();
    final apiClient = _ref.read(apiClientProvider);
    final attendanceService = _ref.read(attendanceServiceProvider);

    try {
      // Independent load parallelized with Future.wait (Requirement 13)
      final results = await Future.wait([
        apiClient
            .get(ApiEndpoints.currentUser)
            .catchError((_) => <String, dynamic>{}),
        attendanceService.getSettings().catchError((_) => null),
        attendanceService.getOfficeLocation().catchError((_) => null),
        attendanceService.getMyShift().catchError((_) => null),
        attendanceService
            .rawGet(ApiEndpoints.attendanceToday)
            .catchError((_) => null),
      ]);

      final profileRes = results[0];
      final settingsRes = results[1];
      final officeLocRes = results[2];
      final shiftRes = results[3];
      final todayRes = results[4];

      // Parse Profile
      final profile = profileRes is Map<String, dynamic>
          ? (profileRes['data'] ?? profileRes)
          : <String, dynamic>{};
      final empId =
          profile['employeeId']?.toString() ?? profile['id']?.toString() ?? '';
      final empCode = profile['employeeCode']?.toString() ?? '';
      final eName =
          profile['employeeName'] ??
          profile['fullName'] ??
          '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim();
      final designation =
          profile['designationName'] ?? profile['designation'] ?? '--';
      final department =
          profile['departmentName'] ?? profile['department'] ?? '--';
      final avatar = profile['avatar'] ?? '';

      DateTime? joiningDate;
      final jStr =
          profile['joiningDate'] ??
          profile['dateOfJoining'] ??
          profile['created_at'];
      if (jStr != null) {
        joiningDate = DateTime.tryParse(jStr.toString());
      }

      // 1. Parse Settings
      final settings = settingsRes is Map
          ? (settingsRes['data'] ?? settingsRes)
          : <String, dynamic>{};
      int gracePeriodMinutes = 15;
      bool faceVerificationRequired = false;
      double minWorkHours = 8.0;
      bool geofenceEnabled = true;

      if (settings.isNotEmpty) {
        gracePeriodMinutes = _parseInt(
          settings['gracePeriodMinutes'] ?? settings['gracePeriod'],
          15,
        );
        if (settings['faceVerificationRequired'] != null)
          faceVerificationRequired =
              settings['faceVerificationRequired'] == true;
        if (settings['requireFaceVerification'] != null)
          faceVerificationRequired =
              settings['requireFaceVerification'] == true;
        minWorkHours = _parseDouble(
          settings['minWorkHours'] ?? settings['standardWorkingHours'],
          8.0,
        );
        // Requirement 6: Read geofenceEnabled from settings
        if (settings['geofenceEnabled'] != null)
          geofenceEnabled = settings['geofenceEnabled'] == true;
        if (settings['enableGeofence'] != null)
          geofenceEnabled = settings['enableGeofence'] == true;
        if (settings['isGeofenceEnabled'] != null)
          geofenceEnabled = settings['isGeofenceEnabled'] == true;
      }

      // 2. Parse Office Location & Branches (Requirement 6, 8, 13)
      final officeLoc = officeLocRes is Map
          ? (officeLocRes['data'] ?? officeLocRes)
          : <String, dynamic>{};
      double officeLat = 21.1986872;
      double officeLng = 72.7965515;
      String officeName = 'Envision Beyond India Pvt Ltd';
      String officeAddress =
          'Green Atria, Society, Anand Mahal Rd, beside Silver Park, Adajan, Surat, Gujarat 395009, India';
      double geofenceRadius = 300.0;
      List<dynamic> branches = [];

      if (officeLoc.isNotEmpty) {
        // Requirement 6: Read geofenceEnabled from office-location as well as settings
        if (officeLoc['geofenceEnabled'] != null)
          geofenceEnabled = officeLoc['geofenceEnabled'] == true;
        if (officeLoc['enableGeofence'] != null)
          geofenceEnabled = officeLoc['enableGeofence'] == true;
        if (officeLoc['isGeofenceEnabled'] != null)
          geofenceEnabled = officeLoc['isGeofenceEnabled'] == true;

        final latVal =
            officeLoc['latitude'] ?? officeLoc['lat'] ?? officeLoc['officeLat'];
        final lngVal =
            officeLoc['longitude'] ??
            officeLoc['lng'] ??
            officeLoc['lon'] ??
            officeLoc['officeLng'];
        if (latVal != null) {
          final pLat = _parseDouble(latVal, 0.0);
          if (pLat != 0.0) officeLat = pLat;
        }
        if (lngVal != null) {
          final pLng = _parseDouble(lngVal, 0.0);
          if (pLng != 0.0) officeLng = pLng;
        }

        final n =
            officeLoc['officeName']?.toString() ??
            officeLoc['name']?.toString() ??
            officeLoc['title']?.toString();
        if (n != null &&
            n.trim().isNotEmpty &&
            n != '--' &&
            !n.toLowerCase().contains('amazon') &&
            !n.toLowerCase().contains('locker') &&
            !n.toLowerCase().contains('astonia')) {
          officeName = n;
        }

        final a =
            officeLoc['officeAddress']?.toString() ??
            officeLoc['address']?.toString();
        if (a != null &&
            a.trim().isNotEmpty &&
            a != '--' &&
            !a.toLowerCase().contains('amazon') &&
            !a.toLowerCase().contains('locker') &&
            !a.toLowerCase().contains('astonia')) {
          officeAddress = a;
        }

        final radVal =
            officeLoc['geofenceRadiusMeters'] ??
            officeLoc['radiusMeters'] ??
            officeLoc['radius'] ??
            officeLoc['geofenceRadius'];
        if (radVal != null) {
          final pRad = _parseDouble(radVal, 0.0);
          if (pRad > 0) geofenceRadius = pRad;
        }

        if (officeLoc['branches'] is List) {
          branches = officeLoc['branches'];
        } else if (officeLoc['branchList'] is List) {
          branches = officeLoc['branchList'];
        }
      }

      if ((officeLat == 21.1986872 || officeLat == 0.0) &&
          settings.isNotEmpty) {
        final sLat =
            settings['officeLatitude'] ??
            settings['latitude'] ??
            settings['lat'];
        final sLng =
            settings['officeLongitude'] ??
            settings['longitude'] ??
            settings['lng'];
        if (sLat != null) {
          final pLat = _parseDouble(sLat, 0.0);
          if (pLat != 0.0) officeLat = pLat;
        }
        if (sLng != null) {
          final pLng = _parseDouble(sLng, 0.0);
          if (pLng != 0.0) officeLng = pLng;
        }
        final sName = settings['officeName']?.toString();
        if (sName != null &&
            sName.isNotEmpty &&
            sName != '--' &&
            !sName.toLowerCase().contains('amazon') &&
            !sName.toLowerCase().contains('locker') &&
            !sName.toLowerCase().contains('astonia')) {
          officeName = sName;
        }
        final sAddr = settings['officeAddress']?.toString();
        if (sAddr != null &&
            sAddr.isNotEmpty &&
            sAddr != '--' &&
            !sAddr.toLowerCase().contains('amazon') &&
            !sAddr.toLowerCase().contains('locker') &&
            !sAddr.toLowerCase().contains('astonia')) {
          officeAddress = sAddr;
        }
        final sRad = settings['geofenceRadiusMeters'] ?? settings['radius'];
        if (sRad != null) {
          final pRad = _parseDouble(sRad, 0.0);
          if (pRad > 0) geofenceRadius = pRad;
        }
      }

      // 3. Shift
      String shiftName = '--';
      String shiftStartTime = '--';
      String shiftEndTime = '--';

      dynamic shiftData = shiftRes is Map
          ? (shiftRes['data'] ?? shiftRes)
          : null;
      if (shiftData == null || (shiftData is Map && shiftData.isEmpty)) {
        final assignmentsRes = await attendanceService
            .getShiftAssignments()
            .catchError((_) => null);
        List<dynamic> assignments = [];
        if (assignmentsRes is Map) {
          assignments =
              assignmentsRes['data'] ??
              assignmentsRes['items'] ??
              assignmentsRes['records'] ??
              [];
        } else if (assignmentsRes is List) {
          assignments = assignmentsRes;
        }

        for (final assignment in assignments) {
          if (assignment is Map) {
            final aEmpId = assignment['employeeId']?.toString();
            final aEmpCode = assignment['employeeCode']?.toString();
            if ((empId.isNotEmpty && aEmpId == empId) ||
                (empCode.isNotEmpty && aEmpCode == empCode)) {
              shiftData = assignment['shift'] ?? assignment;
              break;
            }
          }
        }
        if (shiftData == null &&
            assignments.isNotEmpty &&
            assignments.first is Map) {
          shiftData = assignments.first['shift'] ?? assignments.first;
        }
      }

      if (shiftData is Map && shiftData.isNotEmpty) {
        final sName =
            shiftData['name']?.toString() ?? shiftData['shiftName']?.toString();
        final sStart =
            shiftData['startTime']?.toString() ??
            shiftData['shiftStartTime']?.toString();
        final sEnd =
            shiftData['endTime']?.toString() ??
            shiftData['shiftEndTime']?.toString();
        if (sName != null && sName.isNotEmpty) shiftName = sName;
        if (sStart != null && sStart.isNotEmpty) shiftStartTime = sStart;
        if (sEnd != null && sEnd.isNotEmpty) shiftEndTime = sEnd;
        if (shiftData['minWorkHours'] != null) {
          minWorkHours = _parseDouble(shiftData['minWorkHours'], minWorkHours);
        }
      }

      // 4. Today Record & History
      final startDate = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String()
          .split('T')[0];
      final endDate = DateTime.now().toIso8601String().split('T')[0];

      final record = todayRes is Map
          ? (todayRes['data'] ?? todayRes)
          : <String, dynamic>{};

      List<dynamic> historyList = [];
      if (empId.isNotEmpty) {
        final empAttRes = await attendanceService
            .getEmployeeAttendance(
              empId,
              queryParams: {'startDate': startDate, 'endDate': endDate},
            )
            .catchError((_) => null);
        if (empAttRes is Map) {
          final dataField =
              empAttRes['data'] ??
              empAttRes['items'] ??
              empAttRes['records'] ??
              empAttRes['history'];
          if (dataField is List) historyList = dataField;
        } else if (empAttRes is List) {
          historyList = empAttRes;
        }
      }

      if (historyList.isEmpty) {
        final summaryRes = await attendanceService
            .getAttendanceSummary(
              queryParams: {'startDate': startDate, 'endDate': endDate},
            )
            .catchError((_) => null);
        if (summaryRes is Map) {
          final dataField =
              summaryRes['data'] ??
              summaryRes['items'] ??
              summaryRes['records'] ??
              summaryRes['history'];
          if (dataField is List) historyList = dataField;
        } else if (summaryRes is List) {
          historyList = summaryRes;
        }
      }

      DateTime? checkInAt;
      DateTime? checkOutAt;
      bool isOnBreak = false;
      DateTime? breakStartedAt;
      Duration completedBreak = Duration.zero;
      String checkInLocation = '--';
      String checkOutLocation = '--';
      Map<String, dynamic> todayRecord = {};

      String checkInStatus = '--';
      String checkOutStatus = '--';
      String todayStatusText = '--';
      String todayApprovalText = '--';

      bool isTempOut = false;
      if (record is Map && record.isNotEmpty) {
        todayRecord = Map<String, dynamic>.from(record);

        final notes = record['notes']?.toString() ?? '';
        isTempOut =
            record['isTemporaryClockOut'] == true ||
            notes.contains('[TEMPORARY_CLOCKOUT]');

        final checkInStr = _extractFirst(record, [
          'checkIn',
          'checkInTime',
          'punchIn',
          'punchInTime',
          'clockIn',
          'checkInAt',
          'inTime',
        ]);
        final checkOutStr = _extractFirst(record, [
          'checkOut',
          'checkOutTime',
          'punchOut',
          'punchOutTime',
          'clockOut',
          'checkOutAt',
          'outTime',
        ]);

        final statusStr = _extractFirst(record, [
          'status',
          'attendanceStatus',
        ])?.toUpperCase();
        isOnBreak =
            record['isOnBreak'] == true ||
            record['onBreak'] == true ||
            statusStr == 'BREAK' ||
            statusStr == 'ON_BREAK';

        final breakStartStr = _extractFirst(record, [
          'activeBreakStart',
          'breakStart',
          'breakStartTime',
          'lastBreakStart',
        ]);

        final inLoc = _extractFirst(record, [
          'checkInLocation',
          'location',
          'checkInAddress',
          'officeLocation',
        ]);
        final outLoc = _extractFirst(record, [
          'checkOutLocation',
          'checkOutAddress',
        ]);

        final breakMinsVal =
            record['totalBreakMinutes'] ??
            record['breakMinutes'] ??
            record['breakDurationMinutes'];
        double breakMinutesNum = _parseDouble(breakMinsVal, 0.0);

        checkInAt = _parseDateTime(checkInStr);
        checkOutAt = _parseDateTime(checkOutStr);
        breakStartedAt = _parseDateTime(breakStartStr);
        completedBreak = Duration(seconds: (breakMinutesNum * 60).round());

        if (inLoc != null && inLoc.isNotEmpty) checkInLocation = inLoc;
        if (outLoc != null && outLoc.isNotEmpty) checkOutLocation = outLoc;

        // Requirement 10: Status Labels
        checkInStatus =
            record['checkInStatus']?.toString() ??
            (record['isLate'] == true ? 'LATE' : 'ON_TIME');
        checkOutStatus =
            record['checkOutStatus']?.toString() ??
            (record['isEarlyOut'] == true ? 'EARLY_LEAVE' : 'REGULAR');
        todayStatusText =
            record['status']?.toString() ??
            record['attendanceStatus']?.toString() ??
            'PRESENT';
        final approvalStatus =
            record['verificationStatus']?.toString() ??
            record['approvalStatus']?.toString();
        final verifiedBy =
            record['verifiedByRole']?.toString() ??
            record['approvedBy']?.toString() ??
            record['verifiedBy']?.toString();
        if (approvalStatus != null && approvalStatus.isNotEmpty) {
          todayApprovalText = verifiedBy != null
              ? '$approvalStatus by $verifiedBy'
              : approvalStatus;
        } else if (verifiedBy != null) {
          todayApprovalText = 'Approved by $verifiedBy';
        } else {
          todayApprovalText = 'Approved by System';
        }
      }

      String currentWorkMode = state.workMode;
      String? currentWfhReason = state.wfhReason;
      if (todayRecord.isNotEmpty) {
        if (todayRecord['isWfh'] == true ||
            todayRecord['workMode'] == 'WORK_FROM_HOME' ||
            todayRecord['workMode'] == 'WFH') {
          currentWorkMode = 'WORK_FROM_HOME';
        }
        if (todayRecord['wfhReason'] != null &&
            todayRecord['wfhReason'].toString().isNotEmpty) {
          currentWfhReason = todayRecord['wfhReason'].toString();
        }
      }

      // Requirement 9: Compute values before copyWith so thirtyDayOverview isn't stale
      final overviewStats = calculateDynamic30DayOverview(
        historyList,
        joiningDate: joiningDate,
      );
      final weekData = buildWeekData(historyList);

      // Requirement 2: Honor clear flags when record lacks values
      if (!mounted) return;

      state = state.copyWith(
        employeeId: empId,
        employeeName: eName.isNotEmpty ? eName : '--',
        designation: designation,
        department: department,
        avatar: avatar,
        todayRecord: todayRecord,
        checkInAt: checkInAt,
        clearCheckIn: checkInAt == null,
        checkOutAt: checkOutAt,
        clearCheckOut: checkOutAt == null,
        breakStartedAt: breakStartedAt,
        clearBreakStart: breakStartedAt == null,
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
        gracePeriodMinutes: gracePeriodMinutes,
        faceVerificationRequired: faceVerificationRequired,
        minWorkHours: minWorkHours,
        geofenceEnabled: geofenceEnabled,
        branches: branches,
        attendanceHistory: historyList,
        isTemporaryClockOut: isTempOut,
        workMode: currentWorkMode,
        wfhReason: currentWfhReason,
        checkInStatus: checkInStatus,
        checkOutStatus: checkOutStatus,
        todayStatusText: todayStatusText,
        todayApprovalText: todayApprovalText,
        presentDays: _parseInt(overviewStats['presentDays'], 0),
        absentDays: _parseInt(overviewStats['absentDays'], 0),
        lateClockIns: _parseInt(overviewStats['lateClockIns'], 0),
        attendanceRatePercent: _parseDouble(
          overviewStats['attendanceRatePercent'],
          0.0,
        ),
        hoursLoggedBadge:
            '${_parseDouble(overviewStats['totalHours'], 0.0).toStringAsFixed(2)}h logged',
        weekData: weekData,
        thirtyDayOverview: overviewStats,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      final err = e
          .toString()
          .replaceFirst('ApiException: ', '')
          .replaceFirst('Exception: ', '');
      state = state.copyWith(isLoading: false, error: err);
    }
  }

  // Requirement 8: selectNearestOffice (Filter isActive properly without || true, read radius using double.tryParse)
  Map<String, dynamic>? selectNearestOffice(double userLat, double userLng) {
    List<Map<String, dynamic>> allOffices = [];
    if (state.officeLat != 0.0 && state.officeLng != 0.0) {
      allOffices.add({
        'latitude': state.officeLat,
        'longitude': state.officeLng,
        'officeName': state.officeName,
        'officeAddress': state.officeAddress,
        'geofenceRadiusMeters': state.geofenceRadiusMeters,
      });
    }

    for (final b in state.branches) {
      if (b is Map) {
        final bLat = _parseDouble(b['latitude'] ?? b['lat'], 0.0);
        final bLng = _parseDouble(b['longitude'] ?? b['lng'], 0.0);
        if (bLat != 0.0 && bLng != 0.0) {
          // Requirement 8: Filter branches by isActive properly (b['isActive'] == true, no || true)
          bool isActive = false;
          if (b['isActive'] != null) {
            isActive =
                b['isActive'] == true ||
                b['isActive'].toString().toLowerCase() == 'true';
          } else if (b['status'] != null) {
            final st = b['status'].toString().toUpperCase();
            isActive = st == 'ACTIVE' || st == 'ENABLED';
          } else {
            isActive = true;
          }
          if (isActive) {
            allOffices.add(Map<String, dynamic>.from(b));
          }
        }
      }
    }

    if (allOffices.isEmpty) return null;

    Map<String, dynamic>? bestOffice;
    double minExcessDistance = double.infinity;
    Map<String, dynamic>? insideOffice;
    double minInsideDistance = double.infinity;

    for (final office in allOffices) {
      final lat = _parseDouble(
        office['latitude'] ?? office['lat'],
        state.officeLat,
      );
      final lng = _parseDouble(
        office['longitude'] ?? office['lng'],
        state.officeLng,
      );
      final radius = _parseDouble(
        office['geofenceRadiusMeters'] ??
            office['radius'] ??
            office['radiusMeters'],
        state.geofenceRadiusMeters,
      );

      final distance = Geolocator.distanceBetween(userLat, userLng, lat, lng);
      final excess = distance - radius;

      if (excess <= 0) {
        if (distance < minInsideDistance) {
          minInsideDistance = distance;
          insideOffice = office;
        }
      } else {
        if (excess < minExcessDistance) {
          minExcessDistance = excess;
          bestOffice = office;
        }
      }
    }

    return insideOffice ?? bestOffice ?? allOffices.first;
  }

  void _calculateOverviewStats(List<dynamic> history, [DateTime? joiningDate]) {
    final overviewStats = calculateDynamic30DayOverview(
      history,
      joiningDate: joiningDate,
    );
    final weekData = buildWeekData(history);

    state = state.copyWith(
      presentDays: _parseInt(overviewStats['presentDays'], 0),
      absentDays: _parseInt(overviewStats['absentDays'], 0),
      lateClockIns: _parseInt(overviewStats['lateClockIns'], 0),
      attendanceRatePercent: _parseDouble(
        overviewStats['attendanceRatePercent'],
        0.0,
      ),
      hoursLoggedBadge:
          '${_parseDouble(overviewStats['totalHours'], 0.0).toStringAsFixed(2)}h logged',
      weekData: weekData,
      thirtyDayOverview: overviewStats,
    );
  }

  // Requirement 9: Port calculateDynamic30DayOverview (exclude Sundays, clamp window to joining date, absent days across window, rate, streak, points = present*10)
  Map<String, dynamic> calculateDynamic30DayOverview(
    List<dynamic> history, {
    DateTime? joiningDate,
  }) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    DateTime startDate = todayDate.subtract(const Duration(days: 29));
    if (joiningDate != null) {
      final jDate = DateTime(
        joiningDate.year,
        joiningDate.month,
        joiningDate.day,
      );
      if (jDate.isAfter(startDate)) {
        startDate = jDate;
      }
    }

    final Map<String, Map<String, dynamic>> historyByDate = {};
    for (final item in history) {
      if (item is Map) {
        final dateStr =
            item['date']?.toString() ??
            item['attendanceDate']?.toString() ??
            item['checkIn']?.toString();
        if (dateStr != null && dateStr.length >= 10) {
          final key = dateStr.substring(0, 10);
          historyByDate[key] = Map<String, dynamic>.from(item);
        }
      }
    }

    int workingDays = 0;
    int presentDays = 0;
    int absentDays = 0;
    int lateClockIns = 0;
    double totalHours = 0.0;

    DateTime curr = startDate;
    while (!curr.isAfter(todayDate)) {
      if (curr.weekday != DateTime.sunday) {
        workingDays++;
        final key = curr.toIso8601String().substring(0, 10);
        final record = historyByDate[key];

        if (record != null) {
          final status = (record['status'] ?? record['attendanceStatus'] ?? '')
              .toString()
              .toUpperCase();
          final isLate =
              record['isLate'] == true ||
              record['late'] == true ||
              status.contains('LATE');
          final lateMins =
              record['lateDurationMinutes'] ?? record['lateMinutes'];
          final pLate = _parseDouble(lateMins, 0.0);
          if (isLate || pLate > 0) {
            lateClockIns++;
          }

          final workSecs =
              record['totalWorkSeconds'] ??
              record['workSeconds'] ??
              record['workedSeconds'];
          if (workSecs != null) {
            totalHours += _parseDouble(workSecs, 0.0) / 3600.0;
          }

          if (status.contains('PRESENT') ||
              status.contains('WORK') ||
              status == 'ON_TIME' ||
              status == 'REGULAR' ||
              status.contains('HALF') ||
              status.contains('PARTIAL') ||
              status == 'APPROVED') {
            presentDays++;
          } else if (status.contains('ABSENT') || status.contains('LEAVE')) {
            absentDays++;
          } else {
            if (record['checkIn'] != null || record['checkInTime'] != null) {
              presentDays++;
            } else {
              absentDays++;
            }
          }
        } else {
          if (curr.isBefore(todayDate)) {
            absentDays++;
          }
        }
      }
      curr = curr.add(const Duration(days: 1));
    }

    final rate = workingDays > 0
        ? ((presentDays / workingDays) * 100).roundToDouble()
        : 0.0;
    final points = presentDays * 10;

    int streak = 0;
    DateTime checkDay = todayDate;
    while (true) {
      if (checkDay.weekday == DateTime.sunday) {
        checkDay = checkDay.subtract(const Duration(days: 1));
        continue;
      }
      final key = checkDay.toIso8601String().substring(0, 10);
      final record = historyByDate[key];
      if (record != null) {
        final status = (record['status'] ?? record['attendanceStatus'] ?? '')
            .toString()
            .toUpperCase();
        final isPresent =
            status.contains('PRESENT') ||
            status.contains('WORK') ||
            status == 'ON_TIME' ||
            status == 'REGULAR' ||
            status.contains('HALF') ||
            record['checkIn'] != null;
        if (isPresent) {
          streak++;
          checkDay = checkDay.subtract(const Duration(days: 1));
        } else {
          break;
        }
      } else {
        if (checkDay == todayDate) {
          checkDay = checkDay.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
    }

    return {
      'totalDays': workingDays,
      'workingDays': workingDays,
      'presentDays': presentDays,
      'absentDays': absentDays,
      'lateClockIns': lateClockIns,
      'attendanceRatePercent': rate,
      'currentStreak': streak,
      'points': points,
      'totalHours': totalHours,
    };
  }

  // Requirement 9: buildWeekData must not mark weekends/future days absent
  List<dynamic> buildWeekData(List<dynamic> history) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final weekDays = <Map<String, dynamic>>[];

    final Map<String, Map<String, dynamic>> historyByDate = {};
    for (final item in history) {
      if (item is Map) {
        final dateStr =
            item['date']?.toString() ??
            item['attendanceDate']?.toString() ??
            item['checkIn']?.toString();
        if (dateStr != null && dateStr.length >= 10) {
          final key = dateStr.substring(0, 10);
          historyByDate[key] = Map<String, dynamic>.from(item);
        }
      }
    }

    for (int i = 6; i >= 0; i--) {
      final d = todayDate.subtract(Duration(days: i));
      final dateStr = d.toIso8601String().substring(0, 10);
      final found = historyByDate[dateStr];

      String status = 'UPCOMING';
      final isWeekend =
          (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday);
      final isFuture = d.isAfter(todayDate);
      final isToday =
          d.year == todayDate.year &&
          d.month == todayDate.month &&
          d.day == todayDate.day;

      if (found != null) {
        status = (found['status'] ?? found['attendanceStatus'] ?? 'PRESENT')
            .toString()
            .toUpperCase();
      } else if (isFuture) {
        status = 'UPCOMING';
      } else if (isWeekend) {
        status = 'OFF';
      } else if (isToday) {
        status = 'NOT_CHECKED_IN';
      } else {
        status = 'ABSENT';
      }

      weekDays.add({
        'date': dateStr,
        'dayName': [
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun',
        ][d.weekday - 1],
        'record': found,
        'status': status,
        'isWeekend': isWeekend,
        'isFuture': isFuture,
        'isToday': isToday,
      });
    }
    return weekDays;
  }

  void _startPositionStream() {
    _positionStreamSubscription?.cancel();
    try {
      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((position) {
            _processPositionUpdate(position);
          });
    } catch (_) {}
  }

  Future<void> refreshGps() async {
    await fetchLiveGpsLocation();
  }

  Future<void> fetchLiveGpsLocation() async {
    state = state.copyWith(
      gpsStatus: GpsStatus.detecting,
      gpsStatusMessage: 'Detecting GPS signal & location address...',
    );

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
          gpsStatusMessage:
              'Location permission permanently denied in settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      await _processPositionUpdate(position);
    } catch (e) {
      state = state.copyWith(
        gpsStatus: GpsStatus.error,
        gpsStatusMessage:
            'GPS detection failed: ${e.toString().replaceFirst("Exception: ", "")}',
      );
    }
  }

  Future<void> _processPositionUpdate(Position position) async {
    if (position.isMocked) {
      state = state.copyWith(
        gpsStatus: GpsStatus.error,
        gpsStatusMessage:
            'Mock location is not allowed. Please disable mock GPS apps.',
        currentPosition: position,
      );
      emitMessage('Mock location detected and blocked.', isError: true);
      return;
    }

    final nearestOffice = selectNearestOffice(
      position.latitude,
      position.longitude,
    );
    final targetLat = _parseDouble(nearestOffice?['latitude'], state.officeLat);
    final targetLng = _parseDouble(
      nearestOffice?['longitude'],
      state.officeLng,
    );
    final targetRadius = _parseDouble(
      nearestOffice?['geofenceRadiusMeters'] ?? nearestOffice?['radius'],
      state.geofenceRadiusMeters,
    );
    final targetOfficeName =
        nearestOffice?['officeName']?.toString() ?? state.officeName;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetLat,
      targetLng,
    );
    final accuracyBuffer = math.max(0.0, math.min(150.0, position.accuracy));
    final isWithin =
        !state.geofenceEnabled || (distance - accuracyBuffer) <= targetRadius;
    final distStr = distance >= 1000
        ? '${(distance / 1000).toStringAsFixed(2)}km'
        : '${distance.round()}m';

    // Requirement 6: Await validate-geofence result (throttled)
    _checkAndValidateGeofenceThrottled(position);

    String address = state.currentAddress;
    if (_lastGeocodedPosition == null ||
        Geolocator.distanceBetween(
              _lastGeocodedPosition!.latitude,
              _lastGeocodedPosition!.longitude,
              position.latitude,
              position.longitude,
            ) >
            25) {
      address = await reverseGeocode(position.latitude, position.longitude);
      _lastGeocodedPosition = position;
      _lastGeocodedAddress = address;
    } else if (_lastGeocodedAddress != null) {
      address = _lastGeocodedAddress!;
    }

    if (state.normalizedWorkMode == 'WORK_FROM_HOME' &&
        !address.startsWith('WFH:')) {
      address = 'WFH: $address';
    }

    String checkInLoc = state.checkInLocation;
    if (state.checkInAt == null) {
      checkInLoc = isWithin
          ? 'Office Location ($targetOfficeName)'
          : 'Remote Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    }

    state = state.copyWith(
      gpsStatus: GpsStatus.ready,
      currentPosition: position,
      distanceFromOfficeMeters: distance,
      isWithinGeofence: isWithin,
      gpsStatusMessage: isWithin
          ? 'Inside Geofence ($distStr from $targetOfficeName)'
          : 'Outside Geofence ($distStr from $targetOfficeName, limit: ${targetRadius.round()}m)',
      currentAddress: address,
      checkInLocation: checkInLoc,
      selectedOffice: nearestOffice,
    );
  }

  // Requirement 6: Await validate-geofence result (throttled) and let it override isWithinGeofence, distanceFromOfficeMeters, geofenceRadiusMeters, geofenceEnabled
  void _checkAndValidateGeofenceThrottled(Position position) async {
    final now = DateTime.now();
    bool shouldValidate = false;
    if (_lastGeofenceValidationTime == null || _lastValidatedPosition == null) {
      shouldValidate = true;
    } else {
      final elapsedSec = now.difference(_lastGeofenceValidationTime!).inSeconds;
      final movedMeters = Geolocator.distanceBetween(
        _lastValidatedPosition!.latitude,
        _lastValidatedPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (elapsedSec > 60 || movedMeters > 25) {
        shouldValidate = true;
      }
    }

    if (shouldValidate) {
      _lastGeofenceValidationTime = now;
      _lastValidatedPosition = position;
      try {
        final attendanceService = _ref.read(attendanceServiceProvider);
        final res = await attendanceService.validateGeofence({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        });

        final data = res is Map ? (res['data'] ?? res) : null;
        if (data is Map) {
          bool? backendIsWithin;
          if (data['isWithinGeofence'] != null)
            backendIsWithin = data['isWithinGeofence'] == true;
          else if (data['isWithin'] != null)
            backendIsWithin = data['isWithin'] == true;
          else if (data['inside'] != null)
            backendIsWithin = data['inside'] == true;
          else if (data['allowed'] != null)
            backendIsWithin = data['allowed'] == true;
          else if (data['withinGeofence'] != null)
            backendIsWithin = data['withinGeofence'] == true;

          double? backendDist;
          final dVal =
              data['distanceFromOfficeMeters'] ??
              data['distance'] ??
              data['distanceMeters'];
          if (dVal != null) backendDist = double.tryParse(dVal.toString());

          double? backendRadius;
          final rVal =
              data['geofenceRadiusMeters'] ??
              data['radiusMeters'] ??
              data['radius'] ??
              data['geofenceRadius'];
          if (rVal != null) backendRadius = double.tryParse(rVal.toString());

          bool? backendGeofenceEnabled;
          if (data['geofenceEnabled'] != null)
            backendGeofenceEnabled = data['geofenceEnabled'] == true;
          else if (data['enableGeofence'] != null)
            backendGeofenceEnabled = data['enableGeofence'] == true;

          state = state.copyWith(
            isWithinGeofence: backendIsWithin ?? state.isWithinGeofence,
            distanceFromOfficeMeters:
                backendDist ?? state.distanceFromOfficeMeters,
            geofenceRadiusMeters: backendRadius ?? state.geofenceRadiusMeters,
            geofenceEnabled: backendGeofenceEnabled ?? state.geofenceEnabled,
          );
        }
      } catch (_) {}
    }
  }

  Future<String> reverseGeocode(double lat, double lng) async {
    if (AppConfig.googleMapsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${AppConfig.googleMapsApiKey}',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK' &&
              data['results'] is List &&
              (data['results'] as List).isNotEmpty) {
            return data['results'][0]['formatted_address'] ?? '';
          }
        }
      } catch (_) {}
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'EtapriseHRMS-Mobile'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['display_name'] != null) {
          return data['display_name'].toString();
        }
      }
    } catch (_) {}

    return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
  }

  void setWorkMode(String mode) {
    final norm = mode.toUpperCase();
    final finalMode = (norm == 'WFH' || norm == 'WORK_FROM_HOME')
        ? 'WORK_FROM_HOME'
        : 'OFFICE';
    String? reason = state.wfhReason;
    if (finalMode == 'WORK_FROM_HOME' &&
        (reason == null || reason.trim().isEmpty)) {
      reason = 'Working from home today';
    }
    state = state.copyWith(workMode: finalMode, wfhReason: reason);
  }

  void setWfhReason(String reason) {
    state = state.copyWith(wfhReason: reason);
  }

  void setTileType(String tileType) {
    state = state.copyWith(selectedTileType: tileType);
  }

  void setCapturedSelfie(XFile file, String base64Str) {
    state = state.copyWith(
      capturedSelfie: file,
      capturedSelfieBase64: base64Str,
      isGalleryUpload: false,
    );
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

  // Requirement 4 & 5: clockIn Payload & GPS, verifyFace
  Future<bool> clockIn({
    required String workMode,
    String? wfhReason,
    String? selfieBase64,
    bool isGallery = false,
  }) async {
    state = state.copyWith(isActionInProgress: true, clearError: true);
    final attendanceService = _ref.read(attendanceServiceProvider);

    try {
      final pos = state.currentPosition;
      // Requirement 4: Remove 12.9716/77.5946 & office fallbacks. If no GPS fix, block with "Location required".
      if (pos == null || !state.hasLocationFix) {
        state = state.copyWith(
          isActionInProgress: false,
          error: 'Location required',
        );
        emitMessage('Location required', isError: true);
        return false;
      }

      if (pos.isMocked) {
        state = state.copyWith(
          isActionInProgress: false,
          error: 'Mock location is not allowed.',
        );
        emitMessage('Mock location detected and blocked.', isError: true);
        return false;
      }

      final normWorkMode =
          (workMode.toUpperCase() == 'WFH' ||
              workMode.toUpperCase() == 'WORK_FROM_HOME')
          ? 'WORK_FROM_HOME'
          : 'OFFICE';

      String address = state.currentAddress;
      if (address.isEmpty || address == '--') {
        address =
            'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}';
      }
      if (normWorkMode == 'WORK_FROM_HOME' && !address.startsWith('WFH:')) {
        address = 'WFH: $address';
      }

      final faceBase64 = selfieBase64 ?? state.capturedSelfieBase64;
      String? finalFaceBase64 = faceBase64;
      if ((finalFaceBase64 == null || finalFaceBase64.isEmpty) &&
          state.capturedSelfie != null) {
        try {
          final bytes = await File(state.capturedSelfie!.path).readAsBytes();
          finalFaceBase64 = base64Encode(bytes);
        } catch (_) {}
      }

      // Requirement 5: verifyFace (Send {latitude, longitude, accuracy, location, capturedFaceBase64, verificationType: 'check_in'})
      // Only require selfie step when faceVerificationRequired is true.
      if (state.faceVerificationRequired) {
        if (finalFaceBase64 == null || finalFaceBase64.isEmpty) {
          state = state.copyWith(
            isActionInProgress: false,
            error: 'Please take a verification selfie.',
          );
          emitMessage('Please take a verification selfie.', isError: true);
          return false;
        }

        try {
          final verifyRes = await attendanceService.verifyFace({
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'accuracy': pos.accuracy,
            'location': address,
            'capturedFaceBase64': finalFaceBase64,
            'verificationType': 'check_in',
          });

          Map verifyMap = {};
          if (verifyRes is Map) {
            verifyMap = verifyRes['data'] is Map
                ? verifyRes['data']
                : verifyRes;
          }

          final resultStatus =
              verifyMap['result']?.toString() ??
              verifyMap['status']?.toString();
          if (resultStatus == 'Failed') {
            final failReason =
                verifyMap['failureReason']?.toString() ??
                verifyMap['message']?.toString() ??
                verifyMap['reason']?.toString() ??
                'Face not matched';
            final msg = 'Face verification failed: $failReason';
            state = state.copyWith(isActionInProgress: false, error: msg);
            emitMessage(msg, isError: true);
            return false;
          }
        } catch (e) {
          const msg =
              'Face verification service unavailable. Please try again.';
          state = state.copyWith(isActionInProgress: false, error: msg);
          emitMessage(msg, isError: true);
          return false;
        }
      }

      final finalReason = normWorkMode == 'WORK_FROM_HOME'
          ? (wfhReason ?? state.wfhReason ?? 'Working from home today')
          : null;

      final isResuming = state.isTemporaryClockOut;

      // Requirement 4: Send exact payload
      final payload = <String, dynamic>{
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'location': address,
        'workMode': normWorkMode,
        'isGalleryUpload': isGallery || state.isGalleryUpload,
        if (finalFaceBase64 != null && finalFaceBase64.isNotEmpty)
          'capturedFaceBase64': finalFaceBase64,
        if (normWorkMode == 'WORK_FROM_HOME' && finalReason != null)
          'wfhReason': finalReason,
        if (isResuming) 'isResume': true,
        if (isResuming) 'isTemporaryClockOut': false,
      };

      await attendanceService.checkIn(payload);

      // Requirement 2: Temporary clock-out then resume must show Clock Out, not "Shift Completed"
      state = state.copyWith(
        isActionInProgress: false,
        clearSelfie: true,
        isTemporaryClockOut: false,
        clearCheckOut: true,
      );
      emitMessage(
        isResuming
            ? 'Shift resumed successfully! Welcome back.'
            : 'Clocked in successfully!',
      );
      loadAllData();
      return true;
    } catch (e) {
      final err = e
          .toString()
          .replaceFirst("ApiException: ", "")
          .replaceFirst("Exception: ", "");
      state = state.copyWith(isActionInProgress: false, error: err);
      emitMessage('Clock-in failed: $err', isError: true);
      return false;
    }
  }

  // Requirement 3: clockOut Deficit Guard
  Future<ClockOutResult> clockOut({
    bool isTemporary = false,
    bool applyLeave = false,
    String? leaveType,
    String? leaveReason,
  }) async {
    if (state.isOnBreak) {
      emitMessage('End your break before clocking out.', isError: true);
      return ClockOutResult.blockedOnBreak;
    }

    final now = DateTime.now();
    final pending = state.leavePendingHours(now);
    final deficit = pending > 0.02;
    final doApplyLeave = applyLeave && deficit && leaveType != null;

    if (deficit && !applyLeave && !isTemporary) {
      return ClockOutResult.needsDeficitLeaveOverride;
    }

    state = state.copyWith(isActionInProgress: true, clearError: true);
    final attendanceService = _ref.read(attendanceServiceProvider);
    final leaveService = _ref.read(leaveServiceProvider);

    bool leaveSubmitted = false;

    try {
      if (doApplyLeave) {
        final nowStr = now.toIso8601String().split('T')[0];
        final pendingDays = state.leavePendingDays(now);
        final userReason = (leaveReason ?? '').trim();
        final autoReason =
            'Net worked hours deficit (${state.leavePendingHoursFormatted(now)} pending)';
        final fullReason = userReason.isNotEmpty
            ? '$userReason · $autoReason'
            : autoReason;
        final normType = leaveType.toUpperCase().replaceAll(' ', '_');

        await leaveService.applyLeave({
          'leaveType': leaveType,
          'type': normType,
          'startDate': nowStr,
          'endDate': nowStr,
          'totalDays': pendingDays > 0 ? pendingDays : 0.25,
          'reason': fullReason,
        });
        leaveSubmitted = true;
      }

      final pos = state.currentPosition;
      final lat = pos?.latitude;
      final lng = pos?.longitude;
      final loc =
          state.currentAddress.isNotEmpty && state.currentAddress != '--'
          ? state.currentAddress
          : (pos != null
                ? 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}'
                : (state.officeName.isNotEmpty && state.officeName != '--'
                      ? state.officeName
                      : 'Mobile App Check-Out'));

      final notesToUse = isTemporary
          ? '[TEMPORARY_CLOCKOUT] Temporary clock out (Stepping out)'
          : (doApplyLeave
                ? 'Early check-out with deficit leave applied (${state.leavePendingHoursFormatted(now)} pending)'
                : 'Punched out from mobile app');

      final payload = <String, dynamic>{
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        if (pos?.accuracy != null) 'accuracy': pos!.accuracy,
        'location': loc,
        'notes': notesToUse,
        'verificationType': 'CLOCK_OUT',
        'workMode':
            state.todayRecord['workMode']?.toString() ??
            state.normalizedWorkMode,
        'allowEarlyCheckOut': true,
        'isTemporaryClockOut': isTemporary,
      };

      await attendanceService.checkOut(payload);

      // Requirement 7: Stop stream after clock-out
      stopGpsStream();

      state = state.copyWith(
        isActionInProgress: false,
        isTemporaryClockOut: isTemporary,
        checkOutAt: isTemporary ? null : DateTime.now(),
      );

      if (isTemporary) {
        emitMessage(
          'Clocked out temporarily. Remember to clock back in before shift end!',
        );
      } else {
        emitMessage('Checked out successfully! Great work today.');
      }
      await loadAllData();
      return ClockOutResult.success;
    } catch (e) {
      final errStr = e
          .toString()
          .replaceFirst("ApiException: ", "")
          .replaceFirst("Exception: ", "");
      state = state.copyWith(isActionInProgress: false);
      if (leaveSubmitted) {
        emitMessage(
          'Leave was already submitted; please retry clock-out',
          isError: true,
        );
      } else {
        emitMessage('Clock-out failed: $errStr', isError: true);
      }
      return ClockOutResult.failure;
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
        await attendanceService.startBreak({
          'breakType': 'Regular Break',
          'reason': 'Mobile app break',
        });
        emitMessage('Break started successfully.');
      }
      state = state.copyWith(isActionInProgress: false);
      await loadAllData();
    } catch (e) {
      final err = e
          .toString()
          .replaceFirst("ApiException: ", "")
          .replaceFirst("Exception: ", "");
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
      final err = e
          .toString()
          .replaceFirst("ApiException: ", "")
          .replaceFirst("Exception: ", "");
      state = state.copyWith(isActionInProgress: false, error: err);
      emitMessage('Submission failed: $err', isError: true);
      return false;
    }
  }
}
