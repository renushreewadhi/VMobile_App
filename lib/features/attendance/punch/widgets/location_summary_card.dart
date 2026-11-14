import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../employee/screens/wfh_apply_screen.dart';
import '../punch_state.dart';

class LocationSummaryCard extends StatelessWidget {
  final PunchState state;
  final bool dark;
  final Color text;
  final Color muted;
  final Color surface;
  final Color border;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

  const LocationSummaryCard({
    super.key,
    required this.state,
    required this.dark,
    required this.text,
    required this.muted,
    required this.surface,
    required this.border,
    required this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final officeLatLng = LatLng(state.officeLat, state.officeLng);
    final hasFix = state.hasLocationFix;
    final isInside = hasFix && state.isWithinGeofence;

    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    if (!hasFix) {
      statusColor = const Color(0xFFD97706);
      statusIcon = Icons.location_searching_rounded;
      statusLabel = state.locationProblemTitle;
    } else if (isInside) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.location_on_rounded;
      statusLabel = 'Inside office area';
    } else {
      statusColor = AppColors.error;
      statusIcon = Icons.location_on_rounded;
      statusLabel = 'Outside office area';
    }

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.officeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${state.distanceDisplay} · ${state.geofenceRadiusMeters.round()} m radius',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: muted),
                ],
              ),
            ),
          ),
        ),
        if (!hasFix && !state.isLocating) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location not detected',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.amber),
                      ),
                      Text(
                        state.gpsStatusMessage,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () async {
                    if (state.gpsStatus == GpsStatus.serviceDisabled) {
                      await Geolocator.openLocationSettings();
                    } else if (state.gpsStatus == GpsStatus.deniedForever) {
                      await Geolocator.openAppSettings();
                    }
                    onRetry?.call();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(state.locationActionLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (hasFix && !state.isWithinGeofence) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outside Office Geofence',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.amber),
                      ),
                      Text(
                        'Need to punch in remotely or apply for WFH?',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const WfhApplyScreen()));
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('WFH Request', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
