import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';
import '../../../core/navigation/main_shell.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _tmTheaterProvider = FutureProvider<TheaterModel?>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  final theaters = await ref.watch(databaseServiceProvider).getAllTheaters();
  return theaters.cast<TheaterModel?>().firstWhere(
        (t) => t?.managerId == uid,
        orElse: () => null,
      );
});

class _TmDashStats {
  final TheaterModel? theater;
  final int todayShows;
  final int todaySeatsSold;
  final int activeScreens;
  final int todayRevenue;
  final List<ShowModel> todayShowList;
  final List<BookingModel> recentBookings;
  final Map<String, String> movieTitles;
  final Map<String, String> screenNames;

  const _TmDashStats({
    this.theater,
    this.todayShows = 0,
    this.todaySeatsSold = 0,
    this.activeScreens = 0,
    this.todayRevenue = 0,
    this.todayShowList = const [],
    this.recentBookings = const [],
    this.movieTitles = const {},
    this.screenNames = const {},
  });
}

final _tmDashStatsProvider = FutureProvider<_TmDashStats>((ref) async {
  final theater = await ref.watch(_tmTheaterProvider.future);
  if (theater == null) return const _TmDashStats();

  final db = ref.watch(databaseServiceProvider);
  final today = DateTime.now();
  final todayStart =
      DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
  final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59)
      .millisecondsSinceEpoch;

  final allBookings = await db.getAllBookings();
  final todayBookings = allBookings
      .where((b) =>
          b.theaterId == theater.theaterId &&
          b.createdAt >= todayStart &&
          (b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.redeemed))
      .toList();

  final seatsSold = todayBookings.fold(0, (s, b) => s + b.seats.length);
  final revenue = todayBookings.fold(0, (s, b) => s + b.totalAmount);

  final recentBookings = allBookings
      .where((b) =>
          b.theaterId == theater.theaterId &&
          (b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.redeemed))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final screens = await db.getScreensForTheater(theater.theaterId);
  final activeScreens = screens.where((s) => !s.isUnderMaintenance).length;

  // Today's shows across all screens
  final todayShowList = <ShowModel>[];
  for (final screen in screens) {
    final shows =
        await db.getShowsForTheaterScreen(theater.theaterId, screen.screenId);
    for (final show in shows) {
      if (show.startTs >= todayStart && show.startTs <= todayEnd) {
        todayShowList.add(show);
      }
    }
  }
  todayShowList.sort((a, b) => a.startTs.compareTo(b.startTs));

  final allMovies = await db.getAllMovies();
  final movieTitles = <String, String>{
    for (final m in allMovies) m.movieId: m.title,
  };
  final screenNames = <String, String>{
    for (final s in screens) s.screenId: s.name,
  };

  return _TmDashStats(
    theater: theater,
    todayShows: todayShowList.length,
    todaySeatsSold: seatsSold,
    activeScreens: activeScreens,
    todayRevenue: revenue,
    todayShowList: todayShowList,
    recentBookings: recentBookings.take(10).toList(),
    movieTitles: movieTitles,
    screenNames: screenNames,
  );
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class TmDashboardScreen extends ConsumerWidget {
  const TmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_tmDashStatsProvider);
    final theaterAsync = ref.watch(_tmTheaterProvider);
    final theaterName =
        theaterAsync.valueOrNull?.name ?? 'My Theater';

    return PushDrawerLayout(
      backgroundColor: TMColors.background,
      drawer: TMDrawer(
        currentRoute: AppRoutes.tmDashboard,
        theaterName: theaterName,
        onNavigateTo: (route) => context.push(route),
      ),
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        foregroundColor: TMColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: TMColors.border),
        ),
        title: Text(
          theaterName,
          style: const TextStyle(
              color: TMColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (theaterAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: TMColors.textSecondary),
              tooltip: 'Edit Theater Profile',
              onPressed: () async {
                final theater = theaterAsync.valueOrNull!;
                final result = await context.push(
                  '/admin/edit-theater/${theater.theaterId}',
                );
                if (result != null) {
                  ref.invalidate(_tmDashStatsProvider);
                  ref.invalidate(_tmTheaterProvider);
                }
              },
            ),
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(unreadNotifCountProvider).valueOrNull ?? 0;
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined, color: TMColors.textSecondary),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: TMColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => context.push('/notifications'),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: TMColors.primaryGlow,
              child: const Icon(Icons.person,
                  color: TMColors.primary, size: 18),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: TMColors.primary,
        backgroundColor: TMColors.surface,
        onRefresh: () => ref.refresh(_tmDashStatsProvider.future),
        child: statsAsync.when(
          loading: () => _buildSkeleton(),
          error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: TMColors.error)),
          ),
          data: (stats) {
            if (stats.theater == null) {
              return _buildNoTheater(context, ref);
            }
            return _buildContent(context, ref, stats);
          },
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: List.generate(
            4,
            (_) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: StaffShimmerCard(
                  height: 90,
                  baseColor: TMColors.surface,
                  highlightColor: TMColors.surfaceElevated,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        StaffShimmerCard(
            height: 300,
            baseColor: TMColors.surface,
            highlightColor: TMColors.surfaceElevated),
      ],
    );
  }

  Widget _buildNoTheater(BuildContext context, WidgetRef ref) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final displayName =
        ref.read(currentUserModelProvider).valueOrNull?.displayName ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: TMColors.primaryGlow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.theaters_rounded,
                  size: 48, color: TMColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Theater Yet',
              style: TextStyle(
                  color: TMColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your theater to start managing shows, screens, and bookings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TMColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: TMColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
              ),
              onPressed: () async {
                final result = await context.push(
                  AppRoutes.addTheater,
                  extra: {
                    'fixedManagerId': uid,
                    'fixedManagerName': displayName,
                  },
                );
                if (result != null) {
                  ref.invalidate(_tmDashStatsProvider);
                  ref.invalidate(_tmTheaterProvider);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create My Theater',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, _TmDashStats stats) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: const EdgeInsets.only(top: 20, bottom: 32),
          children: [
            // Snapshot cards
            _buildSnapshotCards(stats),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recent bookings
                  const Text(
                    'Recent Bookings',
                    style: TextStyle(
                        color: TMColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentBookings(stats),
                  const SizedBox(height: 24),
                  // Quick actions
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                        color: TMColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActions(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotCards(_TmDashStats stats) {
    final cards = [
      (
        Icons.movie_rounded,
        '${stats.todayShows}',
        "Today's Shows",
        TMColors.primary,
      ),
      (
        Icons.event_seat_rounded,
        '${stats.todaySeatsSold}',
        'Seats Sold',
        TMColors.success,
      ),
      (
        Icons.theaters_rounded,
        '${stats.activeScreens}',
        'Active Screens',
        const Color(0xFF42A5F5),
      ),
      (
        Icons.currency_rupee_rounded,
        '₹${_fmt(stats.todayRevenue)}',
        "Today's Revenue",
        TMColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        final childAspectRatio = constraints.maxWidth > 800 ? 2.5 : 1.5;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: cards.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            return StaffGlassCard(
              padding: const EdgeInsets.all(14),
              glowColor: c.$4.withOpacity(0.06),
              surfaceColor: TMColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.$4.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(c.$1, color: c.$4, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    c.$2,
                    style: TextStyle(
                        color: c.$4,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    c.$3,
                    style: const TextStyle(
                        color: TMColors.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: (i * 80).ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutQuad);
          }).toList(),
        );
      },
    );
  }
  Widget _buildRecentBookings(_TmDashStats stats) {
    if (stats.recentBookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: TMColors.surface,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          border: Border.all(color: TMColors.border),
        ),
        child: StaffEmptyState(
          icon: Icons.confirmation_number_outlined,
          message: 'No bookings yet',
          iconColor: TMColors.primary,
        ),
      );
    }

    return StaffGlassCard(
      surfaceColor: TMColors.surface,
      padding: EdgeInsets.zero,
      child: Column(
        children: stats.recentBookings.asMap().entries.map((entry) {
          final i = entry.key;
          final booking = entry.value;
          final isLast = i == stats.recentBookings.length - 1;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(
                          color: TMColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TMColors.primaryGlow,
                    borderRadius:
                        BorderRadius.circular(ShowSnapRadius.xs),
                  ),
                  child: const Icon(Icons.confirmation_number_rounded,
                      color: TMColors.primary, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.movieTitle,
                        style: const TextStyle(
                            color: TMColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${booking.seats.length} seat${booking.seats.length > 1 ? 's' : ''} · ₹${booking.totalAmount}',
                        style: const TextStyle(
                            color: TMColors.textSecondary,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(booking.createdAt),
                  style: const TextStyle(
                      color: TMColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 400.ms);
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (Icons.theaters_rounded, 'Screens', AppRoutes.screenManager),
      (Icons.movie_rounded, 'Movies', AppRoutes.movieManager),
      (Icons.schedule_rounded, 'Shows', AppRoutes.showScheduler),
      (Icons.qr_code_scanner_rounded, 'Scan Ticket', AppRoutes.ticketScanner),
      (Icons.bar_chart_rounded, 'Reports', AppRoutes.tmReports),
    ];

    return LayoutBuilder(builder: (_, constraints) {
      final cols =
          constraints.maxWidth > 700 ? 5 : (constraints.maxWidth > 400 ? 3 : 2);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: actions.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          return StaffGlassCard(
            surfaceColor: TMColors.surface,
            padding: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
              onTap: () => context.push(a.$3),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(a.$1, color: TMColors.primary, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      a.$2,
                      style: const TextStyle(
                          color: TMColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms, delay: (500 + i * 50).ms)
              .slideY(begin: 0.1, end: 0);
        }).toList(),
      );
    });
  }

  String _timeAgo(int epochMs) {
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(epochMs));
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _fmt(int amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return '$amount';
  }
}

