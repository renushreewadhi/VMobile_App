import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 1. Slim Dark-Teal Status Banner with White Pill Action Button (Reference Image #8 Top)
class CompactStatusBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final IconData? icon;
  final Color? backgroundColor;

  const CompactStatusBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onActionPressed,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primaryDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFD1FAE5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (actionLabel != null && actionLabel!.isNotEmpty) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onActionPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// 2. Small Pastel Pill-Shaped Summary Chips with Colored Dot Prefix (Reference Image #8 Lower)
enum PastelPillVariant { green, purple, amber, blue }

class PastelSummaryPill extends StatelessWidget {
  final String label;
  final PastelPillVariant variant;
  final Color? customDotColor;
  final Color? customTextColor;
  final Color? customBgColor;
  final VoidCallback? onTap;

  const PastelSummaryPill({
    super.key,
    required this.label,
    this.variant = PastelPillVariant.green,
    this.customDotColor,
    this.customTextColor,
    this.customBgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color dot;

    if (customBgColor != null && customTextColor != null) {
      bg = customBgColor!;
      fg = customTextColor!;
      dot = customDotColor ?? customTextColor!;
    } else {
      switch (variant) {
        case PastelPillVariant.green:
          bg = const Color(0xFFE6F4EA);
          fg = const Color(0xFF137333);
          dot = const Color(0xFF137333);
          break;
        case PastelPillVariant.purple:
          bg = const Color(0xFFF3E8FF);
          fg = const Color(0xFF6B21A8);
          dot = const Color(0xFF6B21A8);
          break;
        case PastelPillVariant.amber:
          bg = const Color(0xFFFEF3C7);
          fg = const Color(0xFFB45309);
          dot = const Color(0xFFB45309);
          break;
        case PastelPillVariant.blue:
          bg = const Color(0xFFE0F2FE);
          fg = const Color(0xFF0369A1);
          dot = const Color(0xFF0369A1);
          break;
      }
    }

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

/// 3. Circular Statistic Indicator Item (Reference Image #9)
class CircularStatItemData {
  final String label;
  final String value;
  final IconData? icon;
  final Color ringColor;
  final VoidCallback? onTap;

  const CircularStatItemData({
    required this.label,
    required this.value,
    this.icon,
    required this.ringColor,
    this.onTap,
  });
}

/// 3b. Shared Single Card with Circular Stat Indicators (Reference Image #9)
class CircularStatGroup extends StatelessWidget {
  final List<CircularStatItemData> items;
  final EdgeInsetsGeometry? padding;

  const CircularStatGroup({
    super.key,
    required this.items,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground;
    final borderColor = isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;

    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDark ? const [] : AppShadows.cardSoft,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) => _buildItem(context, item, isDark)).toList(),
      ),
    );
  }

  Widget _buildItem(BuildContext context, CircularStatItemData item, bool isDark) {
    final textColor = isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
    final labelColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: item.ringColor, width: 2.5),
          ),
          alignment: Alignment.center,
          child: item.icon != null
              ? Icon(item.icon, color: item.ringColor, size: 22)
              : Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.value,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          item.label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (item.onTap != null) {
      return InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// 4. Compact Info Row Tile with Status Dot (Reference Image #10)
class CompactInfoRowTile extends StatelessWidget {
  final String label;
  final String value;
  final Color dotColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const CompactInfoRowTile({
    super.key,
    required this.label,
    required this.value,
    this.dotColor = AppColors.warning,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground;
    final borderColor = isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final textColor = isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
    final labelColor = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;

    Widget content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDark ? const [] : AppShadows.cardSoft,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: labelColor),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }

    return content;
  }
}

/// 5. Auto-Moving / Auto-Scrolling Horizontal Row for Summary Pills / Chips
class AutoMovingRow extends StatefulWidget {
  final List<Widget> children;
  final double spacing;
  final double speed;
  final Duration timerInterval;

  const AutoMovingRow({
    super.key,
    required this.children,
    this.spacing = 8.0,
    this.speed = 0.7,
    this.timerInterval = const Duration(milliseconds: 30),
  });

  @override
  State<AutoMovingRow> createState() => _AutoMovingRowState();
}

class _AutoMovingRowState extends State<AutoMovingRow> {
  late final ScrollController _scrollController;
  final GlobalKey _firstSetKey = GlobalKey();
  Timer? _timer;
  Timer? _resumeTimer;
  bool _isUserInteracting = false;
  double _singleSetWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureAndStart();
    });
  }

  @override
  void didUpdateWidget(covariant AutoMovingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _singleSetWidth = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureAndStart();
    });
  }

  void _measureAndStart() {
    if (!mounted) return;
    _measureSetWidth();
    _startAutoScroll();
  }

  void _measureSetWidth() {
    final context = _firstSetKey.currentContext;
    if (context != null) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        _singleSetWidth = box.size.width + widget.spacing;
      }
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.timerInterval, (timer) {
      if (_isUserInteracting || !mounted || !_scrollController.hasClients) return;

      if (_singleSetWidth <= 0) {
        _measureSetWidth();
      }

      final double maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      double currentOffset = _scrollController.offset;
      double nextOffset = currentOffset + widget.speed;

      if (_singleSetWidth > 0) {
        if (nextOffset >= _singleSetWidth) {
          nextOffset -= _singleSetWidth;
        }
      } else if (nextOffset >= maxScroll) {
        nextOffset = 0;
      }

      _scrollController.jumpTo(nextOffset);
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _isUserInteracting = true;
    _resumeTimer?.cancel();
  }

  void _onPointerUp(PointerUpEvent event) {
    _scheduleResume();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _scheduleResume();
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUserInteracting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final set1 = widget.children;
    final set2 = widget.children;
    final set3 = widget.children;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            if (_singleSetWidth > 0 && _scrollController.hasClients) {
              if (_scrollController.offset >= _singleSetWidth * 2) {
                final target = _scrollController.offset - _singleSetWidth;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(target);
                  }
                });
              } else if (_scrollController.offset < 0) {
                final target = _scrollController.offset + _singleSetWidth;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(target);
                  }
                });
              }
            }
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                key: _firstSetKey,
                mainAxisSize: MainAxisSize.min,
                children: _buildSpacedChildren(set1),
              ),
              SizedBox(width: widget.spacing),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: _buildSpacedChildren(set2),
              ),
              SizedBox(width: widget.spacing),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: _buildSpacedChildren(set3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSpacedChildren(List<Widget> list) {
    final result = <Widget>[];
    for (int i = 0; i < list.length; i++) {
      result.add(list[i]);
      if (i < list.length - 1) {
        result.add(SizedBox(width: widget.spacing));
      }
    }
    return result;
  }
}

