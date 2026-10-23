import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/glass_theme.dart';
import '../theme/theme_provider.dart';

class GlassSurface extends ConsumerWidget {
  final Widget child;
  final double? radius;
  final bool blur;
  final Color? fillColor;
  final Color? borderColor;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const GlassSurface({
    super.key,
    required this.child,
    this.radius,
    this.blur = false,
    this.fillColor,
    this.borderColor,
    this.shadow,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final reduceTransparencySetting = ref.watch(reduceTransparencyProvider);
    final reduceTransparency = mediaQuery.highContrast || mediaQuery.disableAnimations || reduceTransparencySetting;
    final glass = context.glass;

    final r = radius ?? glass.cardRadius;
    final fill = fillColor ?? glass.cardFill;
    final border = borderColor ?? glass.cardBorder;
    final sh = shadow ?? glass.cardShadow;

    Widget surface = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: reduceTransparency ? fill.withOpacity(0.95) : fill,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border, width: 1),
        boxShadow: sh,
      ),
      child: child,
    );

    if (blur && !reduceTransparency) {
      surface = RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: glass.cardBlur, sigmaY: glass.cardBlur),
            child: surface,
          ),
        ),
      );
    } else {
      surface = RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: surface,
        ),
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: surface,
      );
    }

    return surface;
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? radius;
  final bool blur;
  final Color? fillColor;
  final Color? borderColor;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.radius,
    this.blur = false,
    this.fillColor,
    this.borderColor,
    this.shadow,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: radius,
      blur: blur,
      fillColor: fillColor,
      borderColor: borderColor,
      shadow: shadow,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }
}
