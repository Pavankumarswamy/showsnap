import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme.dart';

// Shared shimmer wrapper
class _Shimmer extends StatelessWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: ShowSnapColors.grey300,
      highlightColor: const Color(0xFFF5F5F5),
      child: child,
    );
  }
}

Widget _box({double width = double.infinity, double height = 16, double radius = ShowSnapRadius.xs}) =>
    Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

// ─── Movie Card Skeleton ───────────────────────────────────────────────────

class SkeletonMovieCard extends StatelessWidget {
  const SkeletonMovieCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(width: 130, height: 190, radius: ShowSnapRadius.md),
            const SizedBox(height: 8),
            _box(width: 110, height: 12),
            const SizedBox(height: 4),
            _box(width: 80, height: 10),
          ],
        ),
      ),
    );
  }
}

// ─── Show Row Skeleton ────────────────────────────────────────────────────

class SkeletonShowRow extends StatelessWidget {
  const SkeletonShowRow({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Row(
        children: List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _box(width: 80, height: 44, radius: ShowSnapRadius.sm),
          ),
        ),
      ),
    );
  }
}

// ─── Booking Item Skeleton ────────────────────────────────────────────────

class SkeletonBookingItem extends StatelessWidget {
  const SkeletonBookingItem({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        ),
        child: Row(
          children: [
            _box(width: 44, height: 60, radius: ShowSnapRadius.xs),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(height: 14),
                  const SizedBox(height: 6),
                  _box(width: 160, height: 12),
                  const SizedBox(height: 6),
                  _box(width: 100, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card Skeleton ───────────────────────────────────────────────────

class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(width: 36, height: 36, radius: 18),
            const SizedBox(height: 12),
            _box(width: 60, height: 22),
            const SizedBox(height: 6),
            _box(width: 100, height: 12),
          ],
        ),
      ),
    );
  }
}

// ─── Chart Area Skeleton ──────────────────────────────────────────────────

class SkeletonChartArea extends StatelessWidget {
  final double height;
  const SkeletonChartArea({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        ),
      ),
    );
  }
}
