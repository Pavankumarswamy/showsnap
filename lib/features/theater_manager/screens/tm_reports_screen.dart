import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';

class _TmReportData {
  final int totalRevenue;
  final int totalBookings;
  final List<FlSpot> revenueSpots;
  final Map<String, double> screenOccupancy;
  final Map<String, int> screenSeatsSold;
  final Map<String, int> movieBookings;
  final List<ScreenModel> screens;

  const _TmReportData({
    this.totalRevenue = 0,
    this.totalBookings = 0,
    this.revenueSpots = const [],
    this.screenOccupancy = const {},
    this.screenSeatsSold = const {},
    this.movieBookings = const {},
    this.screens = const [],
  });
}

final _tmReportPeriodProvider = StateProvider<String>((ref) => 'Week');

final _tmReportDataProvider = FutureProvider<_TmReportData>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const _TmReportData();

  final db = ref.watch(databaseServiceProvider);
  final theaters = await db.getAllTheaters();
  final theater =
      theaters.cast<dynamic>().firstWhere((t) => t.managerId == uid, orElse: () => null);
  if (theater == null) return const _TmReportData();

  final allBookings = await db.getAllBookings();
  final now = DateTime.now();
  final cutoff =
      now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;

  final bookings = allBookings
      .where((b) =>
          b.theaterId == theater.theaterId &&
          b.createdAt >= cutoff &&
          (b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.redeemed))
      .toList();

  final totalRevenue = bookings.fold(0, (s, b) => s + b.totalAmount);
  final totalBookings = bookings.length;

  // Revenue spots (last 7 days)
  final dayRevenue = <int, int>{};
  for (final b in bookings) {
    final dayIndex =
        now.difference(DateTime.fromMillisecondsSinceEpoch(b.createdAt)).inDays;
    final slot = (6 - dayIndex.clamp(0, 6));
    dayRevenue[slot] = (dayRevenue[slot] ?? 0) + b.totalAmount;
  }
  final spots = List.generate(
    7,
    (i) => FlSpot(i.toDouble(), (dayRevenue[i] ?? 0).toDouble()),
  );

  // Movie bookings
  final movieBkgs = <String, int>{};
  for (final b in bookings) {
    movieBkgs[b.movieTitle] = (movieBkgs[b.movieTitle] ?? 0) + b.seats.length;
  }

  // Screen occupancy (approximate)
  final screens = await db.getScreensForTheater(theater.theaterId);
  final screenOcc = <String, double>{};
  final screenSeats = <String, int>{};
  for (final screen in screens) {
    final screenBookings =
        bookings.where((b) => b.screenId == screen.screenId).toList();
    final sold = screenBookings.fold(0, (s, b) => s + b.seats.length);
    final capacity = screen.totalSeats > 0 ? screen.totalSeats : 1;
    screenOcc[screen.name] = sold / capacity;
    screenSeats[screen.name] = sold;
  }

  return _TmReportData(
    totalRevenue: totalRevenue,
    totalBookings: totalBookings,
    revenueSpots: spots,
    screenOccupancy: screenOcc,
    screenSeatsSold: screenSeats,
    movieBookings: movieBkgs,
    screens: screens,
  );
});

class TmReportsScreen extends ConsumerWidget {
  const TmReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(_tmReportDataProvider);
    final period = ref.watch(_tmReportPeriodProvider);

    return Scaffold(
      backgroundColor: TMColors.background,
      drawer: TMDrawer(
        currentRoute: AppRoutes.tmReports,
        onNavigateTo: (route) => context.push(route),
        onSignOut: () {},
      ),
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        foregroundColor: TMColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: TMColors.border),
        ),
        title: const Text(
          'Reports',
          style: TextStyle(
              color: TMColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: reportAsync.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: TMColors.error)),
        ),
        data: (data) => _buildContent(context, ref, data, period),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: StaffShimmerCard(
            height: 120,
            baseColor: TMColors.surface,
            highlightColor: TMColors.surfaceElevated,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      _TmReportData data, String period) {
    return RefreshIndicator(
      color: TMColors.primary,
      backgroundColor: TMColors.surface,
      onRefresh: () => ref.refresh(_tmReportDataProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period selector
          _buildPeriodSelector(ref, period),
          const SizedBox(height: 16),
          // Revenue card
          _buildRevenueCard(data).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 16),
          // Screen occupancy
          _buildScreenOccupancy(data)
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms),
          const SizedBox(height: 16),
          // Movie performance
          _buildMoviePerformance(data)
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(WidgetRef ref, String period) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['Today', 'Week', 'Month', 'Custom'].map((p) {
          final isSelected = period == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  ref.read(_tmReportPeriodProvider.notifier).state = p,
              child: AnimatedContainer(
                duration: 150.ms,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? TMColors.primary : TMColors.surface,
                  borderRadius:
                      BorderRadius.circular(ShowSnapRadius.pill),
                  border: Border.all(
                    color: isSelected ? TMColors.primary : TMColors.border,
                  ),
                ),
                child: Text(
                  p,
                  style: TextStyle(
                    color: isSelected ? Colors.black : TMColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRevenueCard(_TmReportData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TMColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: TMColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenue',
                    style: TextStyle(
                        color: TMColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_fmt(data.totalRevenue)}',
                    style: const TextStyle(
                        color: TMColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 28),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TMColors.primaryGlow,
                  borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                ),
                child: const Icon(Icons.currency_rupee_rounded,
                    color: TMColors.primary, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: data.revenueSpots.every((s) => s.y == 0)
                ? const Center(
                    child: Text('No data for this period',
                        style: TextStyle(
                            color: TMColors.textSecondary, fontSize: 12)))
                : LineChart(
                    LineChartData(
                      backgroundColor: TMColors.surface,
                      lineBarsData: [
                        LineChartBarData(
                          spots: data.revenueSpots,
                          isCurved: true,
                          color: TMColors.primary,
                          barWidth: 2.5,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                TMColors.primary.withOpacity(0.25),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenOccupancy(_TmReportData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TMColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: TMColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Screen Occupancy',
            style: TextStyle(
                color: TMColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const SizedBox(height: 16),
          if (data.screenOccupancy.isEmpty)
            StaffEmptyState(
              icon: Icons.theaters_outlined,
              message: 'No screen data yet',
              iconColor: TMColors.primary,
            )
          else
            ...data.screenOccupancy.entries.map((entry) {
              final pct = entry.value.clamp(0.0, 1.0);
              final color = pct > 0.7
                  ? TMColors.success
                  : pct > 0.4
                      ? TMColors.warning
                      : TMColors.error;
              final sold = data.screenSeatsSold[entry.key] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                                color: TMColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${(pct * 100).round()}%',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$sold seats sold',
                          style: const TextStyle(
                              color: TMColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearPercentIndicator(
                      percent: pct,
                      lineHeight: 8,
                      backgroundColor: TMColors.border,
                      progressColor: color,
                      barRadius:
                          const Radius.circular(ShowSnapRadius.pill),
                      padding: EdgeInsets.zero,
                      animation: true,
                      animationDuration: 800,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMoviePerformance(_TmReportData data) {
    final sorted = data.movieBookings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal =
        sorted.isEmpty ? 1 : sorted.first.value.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TMColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: TMColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Movie Performance',
            style: TextStyle(
                color: TMColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            StaffEmptyState(
              icon: Icons.movie_outlined,
              message: 'No movie data yet',
              iconColor: TMColors.primary,
            )
          else
            ...sorted.take(6).map((entry) {
              final pct = entry.value / maxVal;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                            color: TMColors.textSecondary,
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearPercentIndicator(
                        percent: pct,
                        lineHeight: 7,
                        backgroundColor: TMColors.border,
                        progressColor: TMColors.primary,
                        barRadius: const Radius.circular(ShowSnapRadius.pill),
                        padding: EdgeInsets.zero,
                        animation: true,
                        animationDuration: 700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                          color: TMColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _fmt(int amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return '$amount';
  }
}
