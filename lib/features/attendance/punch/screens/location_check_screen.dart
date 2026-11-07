import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_theme.dart';
import '../punch_controller.dart';
import '../punch_state.dart';
import 'selfie_verify_screen.dart';

class LocationCheckScreen extends ConsumerStatefulWidget {
  const LocationCheckScreen({super.key});

  @override
  ConsumerState<LocationCheckScreen> createState() => _LocationCheckScreenState();
}

class _LocationCheckScreenState extends ConsumerState<LocationCheckScreen> {
  GoogleMapController? _googleMapController;
  final TextEditingController _wfhReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(punchControllerProvider);
    _wfhReasonController.text = state.wfhReason ?? '';
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
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(punchControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final officeLatLng = LatLng(state.officeLat, state.officeLng);
    final userLatLng = state.currentPosition != null
        ? LatLng(state.currentPosition!.latitude, state.currentPosition!.longitude)
        : officeLatLng;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _googleMapController = controller;
              if (state.currentPosition != null) {
                final southWest = LatLng(
                  mathMin(state.officeLat, state.currentPosition!.latitude),
                  mathMin(state.officeLng, state.currentPosition!.longitude),
                );
                final northEast = LatLng(
                  mathMax(state.officeLat, state.currentPosition!.latitude),
                  mathMax(state.officeLng, state.currentPosition!.longitude),
                );
                _googleMapController?.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: southWest, northeast: northEast), 80.0));
              }
            },
            initialCameraPosition: CameraPosition(target: officeLatLng, zoom: 15.0),
            mapType: state.selectedTileType == 'Satellite' ? MapType.satellite : MapType.normal,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            circles: {
              Circle(
                circleId: const CircleId('geofence_perimeter'),
                center: officeLatLng,
                radius: state.geofenceRadiusMeters,
                fillColor: const Color(0x334F46E5),
                strokeColor: const Color(0xFF4F46E5),
                strokeWidth: 2,
              ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('office_hq'),
                position: officeLatLng,
                infoWindow: InfoWindow(title: '🏢 ${state.officeName}', snippet: state.officeAddress),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
              ),
              if (state.currentPosition != null)
                Marker(
                  markerId: const MarkerId('user_position'),
                  position: userLatLng,
                  infoWindow: InfoWindow(title: '📍 YOU (LIVE GPS)', snippet: state.distanceDisplay),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    state.isWithinGeofence ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
                  ),
                ),
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Material(
                  color: isDark ? const Color(0xDD1B1D1F) : const Color(0xEEFFFFFF),
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
                      color: isDark ? const Color(0xDD1B1D1F) : const Color(0xEEFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(Icons.apartment_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.officeName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            right: 16,
            child: Column(
              children: [
                _mapFloatingButton(
                  icon: Icons.gps_fixed_rounded,
                  tooltip: 'Refresh GPS',
                  onTap: () => ref.read(punchControllerProvider.notifier).refreshGps(),
                ),
                const SizedBox(height: 8),
                _mapFloatingButton(
                  icon: state.selectedTileType == 'Satellite' ? Icons.map_rounded : Icons.satellite_rounded,
                  tooltip: 'Toggle Map Type',
                  onTap: () {
                    final next = state.selectedTileType == 'Satellite' ? 'Streets' : 'Satellite';
                    ref.read(punchControllerProvider.notifier).setTileType(next);
                  },
                ),
                const SizedBox(height: 8),
                _mapFloatingButton(
                  icon: Icons.fit_screen_rounded,
                  tooltip: 'Fit Both',
                  onTap: () {
                    if (state.currentPosition != null) {
                      final southWest = LatLng(
                        mathMin(state.officeLat, state.currentPosition!.latitude),
                        mathMin(state.officeLng, state.currentPosition!.longitude),
                      );
                      final northEast = LatLng(
                        mathMax(state.officeLat, state.currentPosition!.latitude),
                        mathMax(state.officeLng, state.currentPosition!.longitude),
                      );
                      _googleMapController?.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: southWest, northeast: northEast), 80.0));
                    }
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMainSurface : AppColors.lightMainSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, -5))],
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (state.isWithinGeofence ? const Color(0xFF10B981) : AppColors.error).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          state.isWithinGeofence ? 'Inside' : 'Outside',
                          style: TextStyle(
                            color: state.isWithinGeofence ? const Color(0xFF10B981) : AppColors.error,
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 14),
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
                          value: '${state.geofenceRadiusMeters.round()} m',
                          icon: Icons.radar_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statBox(
                          label: 'GPS accuracy',
                          value: state.currentPosition != null
                              ? '±${state.currentPosition!.accuracy.round()} m'
                              : '-- m',
                          icon: Icons.gps_fixed_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Office Mode'),
                          selected: state.workMode == 'OFFICE',
                          onSelected: (_) => ref.read(punchControllerProvider.notifier).setWorkMode('OFFICE'),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: state.workMode == 'OFFICE' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Work From Home'),
                          selected: state.workMode == 'WFH',
                          onSelected: (_) => ref.read(punchControllerProvider.notifier).setWorkMode('WFH'),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: state.workMode == 'WFH' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (state.workMode == 'WFH') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _wfhReasonController,
                      onChanged: (val) => ref.read(punchControllerProvider.notifier).setWfhReason(val),
                      decoration: InputDecoration(
                        labelText: 'Reason for WFH (Required)',
                        hintText: 'Enter remote work reason...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.gpsStatusMessage,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (state.gpsStatus == GpsStatus.serviceDisabled) {
                                await Geolocator.openLocationSettings();
                              } else if (state.gpsStatus == GpsStatus.denied) {
                                await Geolocator.requestPermission();
                              } else if (state.gpsStatus == GpsStatus.deniedForever) {
                                await Geolocator.openAppSettings();
                              }
                              ref.read(punchControllerProvider.notifier).refreshGps();
                            },
                            child: Text(
                              state.gpsStatus == GpsStatus.serviceDisabled
                                  ? 'Turn on'
                                  : state.gpsStatus == GpsStatus.denied
                                      ? 'Allow'
                                      : 'Settings',
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                          onPressed: () => _openDirections(state.officeLat, state.officeLng),
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: const Text('Directions', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: (state.workMode == 'OFFICE' && !state.isWithinGeofence) ||
                                  (state.workMode == 'WFH' && (state.wfhReason == null || state.wfhReason!.trim().isEmpty))
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const SelfieVerifyScreen()),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            state.workMode == 'OFFICE' && !state.isWithinGeofence
                                ? 'Move closer to office'
                                : state.workMode == 'WFH' && (state.wfhReason == null || state.wfhReason!.trim().isEmpty)
                                    ? 'Enter WFH reason'
                                    : 'Continue to selfie →',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                      ),
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

  Widget _mapFloatingButton({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _statBox({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  double mathMin(double a, double b) => a < b ? a : b;
  double mathMax(double a, double b) => a > b ? a : b;
}
