import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import 'tappable_scale.dart';
import '../../features/home/providers/location_provider.dart';
import '../../features/home/widgets/location_bottom_sheet.dart';
import '../../features/onboarding/feature_walkthrough.dart';

class MainAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final Widget? customTitle;
  final PreferredSizeWidget? bottom;
  final bool showSearch;
  final VoidCallback? onSearchTap;
  final double toolbarHeight;
  final bool enableShowcase;

  const MainAppBar({
    super.key,
    required this.title,
    this.customTitle,
    this.bottom,
    this.showSearch = true,
    this.onSearchTap,
    this.toolbarHeight = 80.0,
    this.enableShowcase = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(selectedAddressProvider);

    Widget locationWidget = TappableScale(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: const LocationBottomSheet(),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded, color: ShowSnapColors.primary, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              address?.fullAddress ?? 'Select Location',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ShowSnapColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_right_rounded, color: ShowSnapColors.primary, size: 16),
        ],
      ),
    );

    if (enableShowcase) {
      locationWidget = ShowcaseTarget(
        showcaseKey: walkthroughCityKey,
        title: 'Your City',
        description: 'Tap to switch city and see local shows.',
        child: locationWidget,
      );
    }

    Widget searchWidget = TappableScale(
      onTap: onSearchTap ?? () {},
      child: const Icon(Icons.search, color: Colors.white),
    );

    if (enableShowcase) {
      searchWidget = ShowcaseTarget(
        showcaseKey: walkthroughSearchKey,
        title: 'Search',
        description: 'Search for movies, events, and theaters.',
        child: searchWidget,
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: toolbarHeight,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      bottom: bottom,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title or Custom Title (like SearchBar)
            Expanded(
              child: customTitle ?? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  locationWidget,
                ],
              ),
            ),
            // Search icon
            if (showSearch) ...[
              searchWidget,
              const SizedBox(width: 16),
            ],
            // Notification bell
            TappableScale(
              onTap: () {},
              child: const Icon(Icons.notifications_outlined, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
