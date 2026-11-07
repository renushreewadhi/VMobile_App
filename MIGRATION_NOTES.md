# Punch In/Out Feature Migration Notes

## 1. Where Each Old Method Moved
- **`_loadAllData()`**: Moved to `PunchController.loadAllData()` in `punch_controller.dart`.
- **`_calculateOverviewStats()`**: Moved to `PunchController._calculateOverviewStats()`.
- **`_fetchLiveGpsLocation()`**: Moved to `PunchController.fetchLiveGpsLocation()` utilizing `geolocator`.
- **`_handleClockInTap()`**: Handled via `PunchHome` UI actions and `_ClockInModal`.
- **`_executeClockIn()`**: Moved to `PunchController.clockIn()`.
- **`_executeClockOut()`**: Moved to `PunchController.clockOut()` returning `ClockOutResult`.
- **`_toggleBreak()`**: Moved to `PunchController.toggleBreak()`.
- **`_openRegularizationModal()`**: Handled via `_RegularizationModal` in UI and `PunchController.submitRegularization()`.
- **`_showEarlyCheckoutOverrideDialog()`**: Handled in UI layer via `ClockOutResult.needsHalfDayOverride`.
- **`_isPostShiftWarning30m` & banner**: Reused as `PunchState.isPostShiftWarning30m()` and `PostShiftBanner` widget.

---

## 2. Where Each `_ClockInModal` Rule Lives
- **Work Mode Selection (`OFFICE` vs `WFH`)**: Managed in `PunchState` (`workMode`), selected on Location Check / Clock-In modal.
- **WFH Reason**: Required when `workMode == 'WFH'`, validated via `canClockIn` and `clockInBlockedReason`.
- **Selfie Requirement**: Mandatory for clock-in (camera or gallery upload via `image_picker`), cleared after successful submission.
- **Geofence Enforcement**: Enforced in `OFFICE` mode (`isWithinGeofence` must be true).

---

## 3. Duplicate-Summary-Call Decision
- **Decision**: Consolidated the duplicate `attendanceSummary` calls from `_loadAllData()` into a **single API call**.
- **Parsing**: Robustly handles both List history shapes and Map summary/overview shapes from the single response object.

---

## 4. Additional Decisions & Dependencies
- **`url_launcher`**: Verified existing dependency in `pubspec.yaml` (`^6.3.0`) and used for map directions on the Location Check screen.
- **One-shot Messaging**: Implemented via `punchMessageProvider` stream to avoid duplicate snackbars on rebuilds.
- **Clock Ticker**: Isolated via `clockTickerProvider` so only timers/clocks rebuild every second.
