import 'package:flutter/material.dart';

class ActivityRow extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title;
  final String time;
  final String location;
  final Color color;
  final Color text;
  final Color muted;

  const ActivityRow({
    super.key,
    required this.dark,
    required this.icon,
    required this.title,
    required this.time,
    required this.location,
    required this.color,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(location, style: TextStyle(color: muted, fontSize: 10)),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
