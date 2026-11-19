import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Base shimmer box — the building block for all skeletons.
class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.width, required this.height, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
      highlightColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

// ── Home screen skeletons ─────────────────────────────────────────────────────

/// Skeleton for the home screen header (welcome + date).
class HomeHeaderSkeleton extends StatelessWidget {
  const HomeHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(width: 200, height: 28, radius: 6),
          const SizedBox(height: 8),
          _ShimmerBox(width: 140, height: 16, radius: 6),
        ],
      ),
    );
  }
}

/// Skeleton for a single meal plan card.
class MealCardSkeleton extends StatelessWidget {
  const MealCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBox(width: 120, height: 18, radius: 6),
            const SizedBox(height: 14),
            _ShimmerBox(width: double.infinity, height: 14, radius: 6),
            const SizedBox(height: 8),
            _ShimmerBox(width: 200, height: 14, radius: 6),
            const SizedBox(height: 8),
            _ShimmerBox(width: 160, height: 14, radius: 6),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a grocery list card.
class GroceryCardSkeleton extends StatelessWidget {
  const GroceryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          const _ShimmerBox(width: 20, height: 20, radius: 4),
          const SizedBox(width: 14),
          Expanded(child: _ShimmerBox(width: null, height: 16, radius: 6)),
          const SizedBox(width: 60),
        ],
      ),
    );
  }
}

/// Full home screen skeleton — shown while user data loads.
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeHeaderSkeleton(),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ShimmerBox(width: 160, height: 20, radius: 6),
          ),
          const SizedBox(height: 12),
          const MealCardSkeleton(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ShimmerBox(width: 140, height: 20, radius: 6),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < 4; i++) ...[
            const GroceryCardSkeleton(),
          ],
        ],
      ),
    );
  }
}

// ── Store finder skeletons ────────────────────────────────────────────────────

class StoreCardSkeleton extends StatelessWidget {
  const StoreCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _ShimmerBox(width: 56, height: 56, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(width: null, height: 18, radius: 6),
                  const SizedBox(height: 8),
                  _ShimmerBox(width: 120, height: 14, radius: 6),
                  const SizedBox(height: 6),
                  _ShimmerBox(width: 80, height: 14, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreListSkeleton extends StatelessWidget {
  const StoreListSkeleton({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, __) => const StoreCardSkeleton(),
    );
  }
}

// ── Generic list skeleton ─────────────────────────────────────────────────────

class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          const _ShimmerBox(width: 44, height: 44, radius: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: null, height: 16, radius: 6),
                const SizedBox(height: 6),
                _ShimmerBox(width: 160, height: 12, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GenericListSkeleton extends StatelessWidget {
  const GenericListSkeleton({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const ListItemSkeleton()),
    );
  }
}
