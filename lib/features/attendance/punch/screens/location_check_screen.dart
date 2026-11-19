import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/api/leave_service.dart';
import '../punch_controller.dart';
import '../punch_state.dart';
import '../widgets/clock_out_sheet.dart';
import 'selfie_verify_screen.dart';

class LocationCheckScreen extends ConsumerStatefulWidget {
  const LocationCheckScreen({super.key});

  @override
  ConsumerState<LocationCheckScreen> createState() =>
      _LocationCheckScreenState();
}

class _LocationCheckScreenState extends ConsumerState<LocationCheckScreen> {
  GoogleMapController? _googleMapController;
  final TextEditingController _wfhReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(punchControllerProvider);
    _wfhReasonController.text = state.wfhReason ?? 'Working from home today';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(punchControllerProvider.notifier).refreshGps();
    });
  }

  @override
  void dispose() {
    _wfhReasonController.dispose();
    super.dispose();
  }

  Future<void> _openDirections(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch map directions.')),
        );
      }
    }
  }

  void _fitCamera(PunchState state) {
    if (_googleMapController == null) return;
    final officeLatLng = LatLng(state.officeLat, state.officeLng);
    if (!state.hasLocationFix || state.distanceFromOfficeMeters > 5000) {
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(officeLatLng, 16.0),
      );
    } else if (state.currentPosition != null) {
      final userLatLng = LatLng(
        state.currentPosition!.latitude,
        state.currentPosition!.longitude,
      );
      final southWest = LatLng(
        math.min(state.officeLat, userLatLng.latitude),
        math.min(state.officeLng, userLatLng.longitude),
      );
      final northEast = LatLng(
        math.max(state.officeLat, userLatLng.latitude),
        math.max(state.officeLng, userLatLng.longitude),
      );
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: southWest, northeast: northEast),
          80.0,
        ),
      );
    }
  }

  void _focusOffice(PunchState state) {
    if (_googleMapController == null) return;
    _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(state.officeLat, state.officeLng),
        17.0,
      ),
    );
  }

  void _focusMe(PunchState state) {
    if (_googleMapController == null || state.currentPosition == null) return;
    _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          state.currentPosition!.latitude,
          state.currentPosition!.longitude,
        ),
        18.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(punchControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final officeLatLng = LatLng(state.officeLat, state.officeLng);
    final userLatLng = state.hasLocationFix && state.currentPosition != null
        ? LatLng(
            state.currentPosition!.latitude,
            state.currentPosition!.longitude,
          )
        : officeLatLng;

    // Accuracy badge color
    Color accuracyColor = AppColors.success;
    String accuracyLabel = 'Good';
    final accuracyM = state.currentPosition?.accuracy ?? 0;
    if (accuracyM > 50) {
      accuracyColor = AppColors.error;
      accuracyLabel = 'Poor';
    } else if (accuracyM > 20) {
      accuracyColor = AppColors.warning;
      accuracyLabel = 'Fair';
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _googleMapController = controller;
              _fitCamera(state);
            },
            initialCameraPosition: CameraPosition(
              target: officeLatLng,
              zoom: 16.0,
            ),
            mapType: state.selectedTileType == 'Satellite'
                ? MapType.satellite
                : MapType.normal,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            circles: {
              Circle(
                circleId: const CircleId('geofence_perimeter'),
                center: officeLatLng,
                radius: state.geofenceRadiusMeters > 0
                    ? state.geofenceRadiusMeters
                    : 300.0,
                fillColor: const Color(0x330F6B66),
                strokeColor: AppColors.primary,
                strokeWidth: 2,
              ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('office_hq'),
                position: officeLatLng,
                infoWindow: InfoWindow(
                  title: state.officeName,
                  snippet: state.officeAddress,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
              ),
              if (state.hasLocationFix)
                Marker(
                  markerId: const MarkerId('user_position'),
                  position: userLatLng,
                  infoWindow: InfoWindow(
                    title: 'YOU (LIVE GPS)',
                    snippet: state.distanceDisplay,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    state.isWithinGeofence
                        ? BitmapDescriptor.hueGreen
                        : BitmapDescriptor.hueRed,
                  ),
                ),
            },
          ),

          // Top Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Material(
                  color: isDark ? AppColors.darkMainSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 4,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(14),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.arrow_back_rounded, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkMainSurface : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.apartment_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.officeName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Map Controls (Focus Office, Focus Me, Fit Both, Map Type)
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            right: 16,
            child: Column(
              children: [
                _mapFloatingButton(
                  icon: Icons.business_rounded,
                  tooltip: 'Focus Office',
                  onTap: () => _focusOffice(state),
                ),
                const SizedBox(height: 8),
                _mapFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Focus Me',
                  onTap: () => _focusMe(state),
                ),
                const SizedBox(height: 8),
                _mapFloatingButton(
                  icon: Icons.fit_screen_rounded,
                  tooltip: 'Fit Both',
                  onTap: () => _fitCamera(state),
                ),
                const SizedBox(height: 8),
                _mapFloatingButton(
                  icon: state.selectedTileType == 'Satellite'
                      ? Icons.map_rounded
                      : Icons.satellite_rounded,
                  tooltip: 'Toggle Map Type',
                  onTap: () {
                    final next = state.selectedTileType == 'Satellite'
                        ? 'Streets'
                        : 'Satellite';
                    ref
                        .read(punchControllerProvider.notifier)
                        .setTileType(next);
                  },
                ),
              ],
            ),
          ),

          // Bottom Geofence & Work Mode Control Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMainSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.officeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (state.isWithinGeofence
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          state.isWithinGeofence ? 'Inside' : 'Outside',
                          style: TextStyle(
                            color: state.isWithinGeofence
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.officeAddress,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Distance & Accuracy Row
                  Row(
                    children: [
                      Expanded(
                        child: _statBox(
                          label: 'distance',
                          value: state.distanceDisplay,
                          icon: Icons.navigation_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statBox(
                          label: 'radius',
                          value:
                              '${state.geofenceRadiusMeters > 0 ? state.geofenceRadiusMeters.round() : 300} m',
                          icon: Icons.radar_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statBox(
                          label: 'GPS accuracy',
                          value: state.currentPosition != null
                              ? '±${state.currentPosition!.accuracy.round()} m ($accuracyLabel)'
                              : '-- m',
                          icon: Icons.gps_fixed_rounded,
                          accentColor: accuracyColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // SegmentedButton Work Mode ("Office" | "Work From Home")
                  Semantics(
                    label: 'Select work mode',
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'OFFICE',
                            label: Text('Office Mode'),
                            icon: Icon(Icons.apartment_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: 'WORK_FROM_HOME',
                            label: Text('Work From Home'),
                            icon: Icon(Icons.home_rounded, size: 16),
                          ),
                        ],
                        selected: {state.normalizedWorkMode},
                        onSelectionChanged: (selection) {
                          ref
                              .read(punchControllerProvider.notifier)
                              .setWorkMode(selection.first);
                        },
                        style: ButtonStyle(
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (state.normalizedWorkMode == 'WORK_FROM_HOME') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _wfhReasonController,
                      onChanged: (val) => ref
                          .read(punchControllerProvider.notifier)
                          .setWfhReason(val),
                      decoration: InputDecoration(
                        labelText: 'Reason for WFH (Required)',
                        hintText: 'Working from home today',
                        helperText: 'Provide a reason for manager review',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],

                  if (state.gpsStatus == GpsStatus.serviceDisabled ||
                      state.gpsStatus == GpsStatus.denied ||
                      state.gpsStatus == GpsStatus.deniedForever) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.gpsStatusMessage,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (state.gpsStatus ==
                                  GpsStatus.serviceDisabled) {
                                await Geolocator.openLocationSettings();
                              } else if (state.gpsStatus == GpsStatus.denied) {
                                await Geolocator.requestPermission();
                              } else if (state.gpsStatus ==
                                  GpsStatus.deniedForever) {
                                await Geolocator.openAppSettings();
                              }
                              ref
                                  .read(punchControllerProvider.notifier)
                                  .refreshGps();
                            },
                            child: Text(
                              state.gpsStatus == GpsStatus.serviceDisabled
                                  ? 'Turn on'
                                  : state.gpsStatus == GpsStatus.denied
                                  ? 'Allow'
                                  : 'Settings',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openDirections(state.officeLat, state.officeLng),
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: const Text(
                            'Directions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _buildActionButton(state)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(PunchState state) {
    final String buttonLabel;
    final VoidCallback? buttonAction;
    final IconData buttonIcon;
    final Color buttonBgColor;

    if (state.isCheckedOut && !state.isTemporaryClockOut) {
      buttonLabel = 'Shift Completed Today';
      buttonAction = null;
      buttonIcon = Icons.check_circle_rounded;
      buttonBgColor = AppColors.success;
    } else if (state.isTemporaryClockOut) {
      buttonLabel = 'Resume Shift (Photo)';
      buttonAction = () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SelfieVerifyScreen()));
      };
      buttonIcon = Icons.camera_alt_rounded;
      buttonBgColor = AppColors.primary;
    } else if (state.checkedIn) {
      buttonLabel = 'Clock Out';
      buttonAction = () => _openClockOutModal(state);
      buttonIcon = Icons.logout_rounded;
      buttonBgColor = AppColors.error;
    } else {
      buttonLabel = 'Continue to Photo Verification';
      buttonAction = () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SelfieVerifyScreen()));
      };
      buttonIcon = Icons.arrow_forward_rounded;
      buttonBgColor = AppColors.primary;
    }

    return Semantics(
      button: true,
      label: buttonLabel,
      child: ElevatedButton.icon(
        onPressed: buttonAction,
        icon: Icon(buttonIcon, size: 18),
        label: Text(
          buttonLabel,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBgColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _openClockOutModal(PunchState state) async {
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
            if (applyLeave && pending > 0.02) {
              await controller.clockOut(
                applyLeave: true,
                leaveType: leaveType ?? 'Unpaid Leave',
                leaveReason: reason,
              );
            } else if (pending > 0.02) {
              await controller.clockOut(isTemporary: true);
            } else {
              await controller.clockOut(isTemporary: false, applyLeave: false);
            }
          },
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Widget _mapFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkMainSurface : Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _statBox({
    required String label,
    required String value,
    required IconData icon,
    Color? accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSecondarySurface
            : AppColors.lightSecondarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accentColor ?? AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkMutedText
                        : AppColors.lightMutedText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color:
                  accentColor ??
                  (isDark
                      ? AppColors.darkPrimaryText
                      : AppColors.lightPrimaryText),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
