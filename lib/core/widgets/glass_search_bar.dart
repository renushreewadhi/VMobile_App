import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import 'glass_card.dart';

class GlassSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String placeholder;

  const GlassSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.onClear,
    this.placeholder = 'Search modules...',
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    return RepaintBoundary(
      child: GlassSurface(
        blur: true,
        height: 52,
        radius: glass.searchRadius,
        fillColor: glass.searchFill,
        borderColor: glass.searchBorder,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 20,
              color: glass.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: glass.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: glass.searchPlaceholder,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (controller != null && controller!.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller?.clear();
                  onChanged?.call('');
                  onClear?.call();
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: glass.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
