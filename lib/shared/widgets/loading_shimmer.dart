import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';

class LoadingShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingShimmer({
    super.key,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkSecondarySurface : AppColors.lightBordersAndDividers,
      highlightColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMainSurface : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingShimmer(width: 180, height: 24, borderRadius: 6),
                  SizedBox(height: 6),
                  LoadingShimmer(width: 120, height: 14, borderRadius: 4),
                ],
              ),
              LoadingShimmer(width: 44, height: 44, borderRadius: 22),
            ],
          ),
          const SizedBox(height: 20),
          const LoadingShimmer(width: double.infinity, height: 100, borderRadius: 16),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(child: LoadingShimmer(width: double.infinity, height: 90, borderRadius: 12)),
              SizedBox(width: 12),
              Expanded(child: LoadingShimmer(width: double.infinity, height: 90, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: LoadingShimmer(width: double.infinity, height: 90, borderRadius: 12)),
              SizedBox(width: 12),
              Expanded(child: LoadingShimmer(width: double.infinity, height: 90, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 24),
          const LoadingShimmer(width: 160, height: 20, borderRadius: 6),
          const SizedBox(height: 12),
          const ListSkeleton(itemCount: 3),
        ],
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  final int itemCount;
  const ListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkBordersAndDividers
                    : AppColors.lightBordersAndDividers,
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                const LoadingShimmer(width: 42, height: 42, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      LoadingShimmer(width: 140, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      LoadingShimmer(width: 90, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                const LoadingShimmer(width: 60, height: 22, borderRadius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
