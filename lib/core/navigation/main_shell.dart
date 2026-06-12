import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../../features/onboarding/feature_walkthrough.dart';

// ─── Unread notification count (real-time) ───────────────────────────────────

final unreadNotifCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(0);
  return FirebaseDatabase.instance
      .ref('${AppConstants.usersPath}/$uid/unreadNotifications')
      .onValue
      .map((e) => (e.snapshot.value as num?)?.toInt() ?? 0);
});

// ─── Current shell tab index ──────────────────────────────────────────────────

final shellTabIndexProvider = StateProvider<int>((ref) => 0);

// ─── MainShell ────────────────────────────────────────────────────────────────

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureWalkthroughWrapper(
      child: Scaffold(
        body: navigationShell,
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerDocked,
        floatingActionButton: ShowcaseTarget(
          showcaseKey: walkthroughFabKey,
          title: 'Quick Book',
          description: 'Tap here any time to quickly search and book shows.',
          shape: const CircleBorder(),
          child: FloatingActionButton(
            backgroundColor: ShowSnapColors.primary,
            elevation: 4,
            onPressed: () => _showQuickBook(context, ref),
            child: const Icon(Icons.confirmation_number_rounded,
                color: Colors.black87),
          ),
        ),
        bottomNavigationBar: _ShowSnapBottomNav(
          currentIndex: navigationShell.currentIndex,
          onTap: (i) {
            HapticFeedback.selectionClick();
            navigationShell.goBranch(i,
                initialLocation: i == navigationShell.currentIndex);
          },
        ),
      ),
    );
  }

  void _showQuickBook(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(ShowSnapRadius.lg)),
      ),
      builder: (_) => _QuickBookSheet(),
    );
  }
}

// ─── Bottom Navigation Bar ────────────────────────────────────────────────────

class _ShowSnapBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _ShowSnapBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      color: Colors.white,
      elevation: 12,
      height: 68,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // ── Left: Home, Explore ──────────────────────────────────────────
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isActive: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.explore_rounded,
                  label: 'Explore',
                  isActive: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              ],
            ),
          ),
          // ── FAB gap ──────────────────────────────────────────────────────
          const SizedBox(width: 72),
          // ── Right: Bookings, Offers ──────────────────────────────────
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Bookings',
                  isActive: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
                _NavItem(
                  icon: Icons.local_offer_rounded,
                  label: 'Offers',
                  isActive: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: ShowSnapDuration.fast,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: isActive
                  ? BoxDecoration(
                      color: ShowSnapColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: Icon(
                icon,
                color: isActive
                    ? ShowSnapColors.primary
                    : ShowSnapColors.grey600,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? ShowSnapColors.primary
                    : ShowSnapColors.grey600,
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Quick Book Bottom Sheet ──────────────────────────────────────────────────

class _QuickBookSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Book',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text('What would you like to book?',
                style: TextStyle(
                    color: ShowSnapColors.grey600, fontSize: 13)),
            const SizedBox(height: 20),
            _QuickOption(
              icon: Icons.movie_rounded,
              iconColor: ShowSnapColors.primary,
              label: 'Book a Movie',
              subtitle: 'Browse now showing movies',
              onTap: () {
                Navigator.pop(context);
                context.go('/explore?tab=movies');
              },
            ),
            const SizedBox(height: 12),
            _QuickOption(
              icon: Icons.celebration_rounded,
              iconColor: ShowSnapColors.secondary,
              label: 'Book an Event',
              subtitle: 'Concerts, sports, plays & more',
              onTap: () {
                Navigator.pop(context);
                context.go('/explore?tab=events');
              },
            ),
            const SizedBox(height: 12),
            _QuickOption(
              icon: Icons.campaign_rounded,
              iconColor: Colors.deepPurple,
              label: 'Submit Ad Request',
              subtitle: 'Advertise at ShowSnap theaters',
              onTap: () {
                Navigator.pop(context);
                context.push('/influencer/ad-request');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ShowSnapRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ShowSnapColors.grey100,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: ShowSnapColors.grey600, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: ShowSnapColors.grey600),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: ShowSnapDuration.fast)
        .slideX(begin: 0.05, end: 0);
  }
}
