import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/config/theme.dart';

class CarouselSection extends StatelessWidget {
  final String title;
  final List<Widget> items;
  final bool isLoading;
  final double itemHeight;
  final String? emptyMessage;

  const CarouselSection({
    super.key,
    required this.title,
    required this.items,
    this.isLoading = false,
    this.itemHeight = 260,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (isLoading)
          _buildShimmer(context)
        else if (items.isEmpty && emptyMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              emptyMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ShowSnapColors.grey600,
                  ),
            ),
          )
        else
          SizedBox(
            height: itemHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => items[i],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return SizedBox(
      height: itemHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: ShowSnapColors.grey300,
          highlightColor: ShowSnapColors.grey100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 150,
              height: itemHeight,
              color: ShowSnapColors.grey300,
            ),
          ),
        ),
      ),
    );
  }
}
