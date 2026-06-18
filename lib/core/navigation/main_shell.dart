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
import '../../features/explore/screens/explore_screen.dart';

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
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: _CurvedBottomNavBar(
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

class _CurvedBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _CurvedBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_CurvedBottomNavBar> createState() => _CurvedBottomNavBarState();
}

class _CurvedBottomNavBarState extends State<_CurvedBottomNavBar> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _anim = Tween<double>(begin: widget.currentIndex.toDouble(), end: widget.currentIndex.toDouble()).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(_CurvedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _anim = Tween<double>(begin: _anim.value, end: widget.currentIndex.toDouble()).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOutBack),
      );
      _animCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.receipt_long_rounded, 'label': 'Bookings'},
      {'icon': Icons.explore_rounded, 'label': 'Explore'},
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.campaign_rounded, 'label': 'Ads'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final barHeight = 68.0 + bottomPadding;
    final totalHeight = 90.0 + bottomPadding;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barHeight,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                return CustomPaint(
                  painter: _NavPainter(
                    currentPos: _anim.value,
                    itemsCount: items.length,
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding,
            height: 90, 
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(items.length, (i) {
                final isSelected = widget.currentIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 90,
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        alignment: isSelected ? const Alignment(0, -0.55) : const Alignment(0, 0.4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isSelected ? 56 : 50,
                          height: isSelected ? 56 : 50,
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: ShowSnapColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: ShowSnapColors.primary.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                )
                              : const BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                items[i]['icon'] as IconData,
                                color: isSelected ? Colors.black87 : ShowSnapColors.grey600,
                                size: isSelected ? 26 : 24,
                              ),
                              if (!isSelected) ...[
                                const SizedBox(height: 2),
                                Text(
                                  items[i]['label'] as String,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: ShowSnapColors.grey600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavPainter extends CustomPainter {
  final double currentPos;
  final int itemsCount;

  _NavPainter({required this.currentPos, required this.itemsCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final itemWidth = size.width / itemsCount;
    final centerX = (currentPos * itemWidth) + (itemWidth / 2);

    final host = Rect.fromLTWH(0, 0, size.width, size.height);
    final guest = Rect.fromCenter(center: Offset(centerX, 0), width: 64, height: 64);

    final path = const CircularNotchedRectangle().getOuterPath(host, guest);

    canvas.drawShadow(path, Colors.black87, 8, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NavPainter oldDelegate) => oldDelegate.currentPos != currentPos;
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
                ref.read(exploreTabIndexProvider.notifier).state = 0;
                context.go('/explore');
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
                ref.read(exploreTabIndexProvider.notifier).state = 1;
                context.go('/explore');
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
