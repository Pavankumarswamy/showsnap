import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';

class _TmStats {
  final TheaterModel? theater;
  final int todayShows;
  final int todaySeatsSold;
  final int todayRevenue;

  const _TmStats({
    this.theater,
    this.todayShows = 0,
    this.todaySeatsSold = 0,
    this.todayRevenue = 0,
  });
}

final _tmTheaterProvider = FutureProvider<TheaterModel?>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  final theaters = await ref.watch(databaseServiceProvider).getAllTheaters();
  return theaters.cast<TheaterModel?>().firstWhere(
      (t) => t?.managerId == uid,
      orElse: () => null);
});

final _tmStatsProvider = FutureProvider<_TmStats>((ref) async {
  final theater = await ref.watch(_tmTheaterProvider.future);
  if (theater == null) return const _TmStats();

  final db = ref.watch(databaseServiceProvider);
  final today = DateTime.now();
  final todayStart =
      DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;

  // Get all bookings for this theater today
  final allBookings = await db.getAllBookings();
  final todayBookings = allBookings
      .where((b) =>
          b.theaterId == theater.theaterId &&
          b.createdAt >= todayStart &&
          (b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.redeemed))
      .toList();

  final seatsSold =
      todayBookings.fold(0, (sum, b) => sum + b.seats.length);
  final revenue =
      todayBookings.fold(0, (sum, b) => sum + b.totalAmount);

  // Count today's shows
  final screens =
      await db.getScreensForTheater(theater.theaterId);
  int todayShows = 0;
  for (final screen in screens) {
    final shows =
        await db.getShowsForTheaterScreen(theater.theaterId, screen.screenId);
    todayShows += shows.where((s) {
      final dt = DateTime.fromMillisecondsSinceEpoch(s.startTs);
      return dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
    }).length;
  }

  return _TmStats(
    theater: theater,
    todayShows: todayShows,
    todaySeatsSold: seatsSold,
    todayRevenue: revenue,
  );
});

class TmDashboardScreen extends ConsumerWidget {
  const TmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_tmStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      body: statsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) {
          if (stats.theater == null) {
            final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
            final displayName = ref
                    .read(currentUserModelProvider)
                    .valueOrNull
                    ?.displayName ??
                '';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ShowSnapColors.primaryLighter,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_business_outlined,
                          size: 48, color: ShowSnapColors.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Theater Yet',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your theater to start managing shows, screens, and bookings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ShowSnapColors.grey600),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: DecoratedBox(
                        decoration:
                            ShowSnapTheme.primaryButtonDecoration,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  ShowSnapRadius.md),
                            ),
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
                              ref.invalidate(_tmStatsProvider);
                              ref.invalidate(_tmTheaterProvider);
                            }
                          },
                          icon: const Icon(Icons.add,
                              color: Colors.black),
                          label: const Text(
                            'Create My Theater',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_tmStatsProvider),
            child: ListView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
              children: [
                // Theater info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ShowSnapColors.primaryLighter,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.theaters_outlined,
                              color: ShowSnapColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stats.theater!.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(stats.theater!.address,
                                  style: const TextStyle(
                                      color: ShowSnapColors.grey600,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                const SizedBox(height: 16),
                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _StatCard("Today's Shows",
                          '${stats.todayShows}',
                          Icons.movie_outlined,
                          ShowSnapColors.primary)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 100.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard('Seats Sold',
                          '${stats.todaySeatsSold}',
                          Icons.event_seat_outlined,
                          ShowSnapColors.secondary)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 200.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _StatCard('Today\'s Revenue', '₹${stats.todayRevenue}',
                    Icons.currency_rupee_outlined, Colors.purple)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms)
                  .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                const SizedBox(height: 24),
                // Quick actions
                Text('Quick Actions',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold))
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 400.ms),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
                    _ActionCard('Screens',
                        Icons.theaters_outlined,
                        () => context.push(AppRoutes.screenManager)),
                    _ActionCard('Movies',
                        Icons.movie_outlined,
                        () => context.push(AppRoutes.movieManager)),
                    _ActionCard('Shows',
                        Icons.schedule_outlined,
                        () => context.push(AppRoutes.showScheduler)),
                    _ActionCard('Scan Ticket',
                        Icons.qr_code_scanner_outlined,
                        () => context.push(AppRoutes.ticketScanner)),
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: 450.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: ShowSnapColors.grey600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionCard(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: ShowSnapColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, color: ShowSnapColors.grey600),
            ],
          ),
        ),
      ),
    );
  }
}
