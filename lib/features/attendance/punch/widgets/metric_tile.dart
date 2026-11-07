import 'package:flutter/material.dart';

class MetricTile extends StatelessWidget {
  final bool dark;
  final Color text;
  final Color muted;
  final Color surface;
  final Color border;
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const MetricTile({
    super.key,
    required this.dark,
    required this.text,
    required this.muted,
    required this.surface,
    required this.border,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: muted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: text,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
