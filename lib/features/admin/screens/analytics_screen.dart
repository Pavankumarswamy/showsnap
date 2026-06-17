import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/services/database_service.dart';

class _AnalyticsData {
  final List<FlSpot> revenueSpots;
  final Map<String, int> movieRevenue;
  final Map<String, int> cityRevenue;
  final Map<String, int> genreBookings;
  final int totalRevenue;
  final int totalBookings;
  final double avgOccupancy;

  const _AnalyticsData({
    this.revenueSpots = const [],
    this.movieRevenue = const {},
    this.cityRevenue = const {},
    this.genreBookings = const {},
    this.totalRevenue = 0,
    this.totalBookings = 0,
    this.avgOccupancy = 0,
  });
}

final _analyticsProvider = FutureProvider<_AnalyticsData>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final bookings = await db.getAllBookings();
  final confirmed = bookings.where(
    (b) =>
        b.status == BookingStatus.confirmed ||
        b.status == BookingStatus.redeemed,
  );

  final totalRevenue = confirmed.fold(0, (s, b) => s + b.totalAmount);
  final totalBookings = confirmed.length;

  // Last 30 days spots
  final now = DateTime.now();
  final dayRevenue = <int, int>{};
  final thirtyAgo =
      now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  for (final b in confirmed.where((b) => b.createdAt >= thirtyAgo)) {
    final dayIndex =
        now.difference(DateTime.fromMillisecondsSinceEpoch(b.createdAt)).inDays;
    final slot = (29 - dayIndex.clamp(0, 29));
    dayRevenue[slot] = (dayRevenue[slot] ?? 0) + b.totalAmount;
  }
  final spots = List.generate(
    30,
    (i) => FlSpot(i.toDouble(), (dayRevenue[i] ?? 0).toDouble()),
  );

  // Movie revenue
  final movieRev = <String, int>{};
  for (final b in confirmed) {
    movieRev[b.movieTitle] = (movieRev[b.movieTitle] ?? 0) + b.totalAmount;
  }

  // City revenue
  final cityRev = <String, int>{};
  for (final b in confirmed) {
    cityRev[b.theaterName] = (cityRev[b.theaterName] ?? 0) + b.totalAmount;
  }

  return _AnalyticsData(
    revenueSpots: spots,
    movieRevenue: movieRev,
    cityRevenue: cityRev,
    genreBookings: const {},
    totalRevenue: totalRevenue,
    totalBookings: totalBookings,
    avgOccupancy: totalBookings > 0 ? 65.0 : 0,
  );
});

final _periodProvider =
    StateProvider<String>((ref) => 'Month');

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(_analyticsProvider);
    final period = ref.watch(_periodProvider);

    return PushDrawerLayout(
      backgroundColor: AdminColors.background,
      drawer: AdminDrawer(
        currentRoute: AppRoutes.adminAnalytics,
        onNavigateTo: (route) => context.push(route),
      ),
      appBar: AppBar(
        backgroundColor: AdminColors.surface,
        foregroundColor: AdminColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AdminColors.border),
        ),
        title: const Text(
          'Analytics',
          style: TextStyle(
              color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: analyticsAsync.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AdminColors.error)),
        ),
        data: (data) => _buildContent(context, ref, data, period),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StaffShimmerCard(
            height: 80,
            baseColor: AdminColors.surface,
            highlightColor: AdminColors.surfaceElevated),
        const SizedBox(height: 16),
        const StaffShimmerCard(
            height: 240,
            baseColor: AdminColors.surface,
            highlightColor: AdminColors.surfaceElevated),
        const SizedBox(height: 16),
        const StaffShimmerCard(
            height: 200,
            baseColor: AdminColors.surface,
            highlightColor: AdminColors.surfaceElevated),
      ],
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      _AnalyticsData data, String period) {
    return RefreshIndicator(
      color: AdminColors.primary,
      backgroundColor: AdminColors.surface,
      onRefresh: () => ref.refresh(_analyticsProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary row
          _buildSummaryRow(data),
          const SizedBox(height: 20),
          // Period selector
          _buildPeriodSelector(ref, period),
          const SizedBox(height: 16),
          // Revenue over time
          _buildRevenueChart(data),
          const SizedBox(height: 20),
          // Movie performance
          _buildMoviePerformance(data),
          const SizedBox(height: 20),
          // City breakdown
          _buildCityBreakdown(data),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(_AnalyticsData data) {
    return Row(
      children: [
        Expanded(
          child: _MetricChip(
            label: 'Total Revenue',
            value: '₹${_fmt(data.totalRevenue)}',
            icon: Icons.currency_rupee_rounded,
            color: AdminColors.primary,
          ).animate().fadeIn(duration: 400.ms),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricChip(
            label: 'Total Bookings',
            value: '${data.totalBookings}',
            icon: Icons.confirmation_number_rounded,
            color: AdminColors.info,
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricChip(
            label: 'Avg Occupancy',
            value: '${data.avgOccupancy.round()}%',
            icon: Icons.event_seat_rounded,
            color: AdminColors.success,
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(WidgetRef ref, String period) {
    return Row(
      children: ['Week', 'Month', 'Quarter', 'Year'].map((p) {
        final isSelected = period == p;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => ref.read(_periodProvider.notifier).state = p,
            child: AnimatedContainer(
              duration: 150.ms,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? AdminColors.primary
                    : AdminColors.surface,
                borderRadius:
                    BorderRadius.circular(ShowSnapRadius.pill),
                border: Border.all(
                  color: isSelected
                      ? AdminColors.primary
                      : AdminColors.border,
                ),
              ),
              child: Text(
                p,
                style: TextStyle(
                  color:
                      isSelected ? Colors.black : AdminColors.textSecondary,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRevenueChart(_AnalyticsData data) {
    return _SectionCard(
      title: 'Revenue Trend',
      child: SizedBox(
        height: 200,
        child: data.revenueSpots.every((s) => s.y == 0)
            ? const Center(
                child: Text('No revenue data',
                    style: TextStyle(color: AdminColors.textSecondary)))
            : LineChart(
                LineChartData(
                  backgroundColor: AdminColors.surface,
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.revenueSpots,
                      isCurved: true,
                      color: AdminColors.primary,
                      barWidth: 2,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AdminColors.primary.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AdminColors.border,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, _) => Text(
                          '₹${_fmt(v.toInt())}',
                          style: const TextStyle(
                              fontSize: 9, color: AdminColors.textMuted),
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                ),
              ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
  }

  Widget _buildMoviePerformance(_AnalyticsData data) {
    final sorted = data.movieRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top8 = sorted.take(8).toList();
    final maxVal = top8.isEmpty ? 1 : top8.first.value.toDouble();

    return _SectionCard(
      title: 'Movie Performance (Revenue)',
      child: top8.isEmpty
          ? const StaffEmptyState(
              icon: Icons.movie_outlined,
              message: 'No movie data yet',
            )
          : Column(
              children: top8.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                final pct = entry.value / maxVal;
                final barColors = [
                  AdminColors.primary,
                  AdminColors.info,
                  AdminColors.success,
                  AdminColors.warning,
                ];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                              color: AdminColors.textSecondary,
                              fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.pill),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: AdminColors.border,
                            valueColor: AlwaysStoppedAnimation(
                                barColors[i % barColors.length]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${_fmt(entry.value)}',
                        style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms);
  }

  Widget _buildCityBreakdown(_AnalyticsData data) {
    final sorted = data.cityRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _SectionCard(
      title: 'Revenue by Theater',
      child: sorted.isEmpty
          ? const StaffEmptyState(
              icon: Icons.location_city_outlined,
              message: 'No location data yet',
            )
          : Column(
              children: [
                // Header
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('Theater',
                              style: TextStyle(
                                  color: AdminColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600))),
                      Expanded(
                          flex: 2,
                          child: Text('Revenue',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  color: AdminColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
                const Divider(color: AdminColors.border, height: 1),
                ...sorted.take(8).map((entry) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: AdminColors.border, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                  color: AdminColors.textPrimary,
                                  fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₹${_fmt(entry.value)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: AdminColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
    ).animate().fadeIn(duration: 500.ms, delay: 400.ms);
  }

  String _fmt(int amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return '$amount';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaffSectionHeader(title: title),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          Text(
            label,
            style: const TextStyle(
                color: AdminColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
