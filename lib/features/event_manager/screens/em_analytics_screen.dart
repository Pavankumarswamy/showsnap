import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import 'em_dashboard_screen.dart' show EMColors;

// ─── Analytics Data Model ───────────────────────────────────────────────────

class _EmAnalyticsData {
  final int totalEvents;
  final int totalTicketsSold;
  final int totalRevenue;
  final int checkedIn;
  final List<FlSpot> revenueSpots30Days;
  final List<String> dayLabels30Days;
  final Map<String, int> ticketsByTier;
  final Map<String, int> revenueByTier;

  const _EmAnalyticsData({
    this.totalEvents = 0,
    this.totalTicketsSold = 0,
    this.totalRevenue = 0,
    this.checkedIn = 0,
    this.revenueSpots30Days = const [],
    this.dayLabels30Days = const [],
    this.ticketsByTier = const {},
    this.revenueByTier = const {},
  });
}

final _emAnalyticsProvider = FutureProvider<_EmAnalyticsData>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  final db = ref.watch(databaseServiceProvider);

  final events = await db.getEventsForManager(uid);
  final allBookings = await db.getAllBookings();
  final eventIds = events.map((e) => e.eventId).toSet();

  final myBookings = allBookings
      .where((b) =>
          eventIds.contains(b.showId) &&
          (b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.redeemed))
      .toList();

  final ticketsSold = myBookings.fold(0, (sum, b) => sum + b.seats.length);
  final revenue = myBookings.fold(0, (sum, b) => sum + b.totalAmount);
  final checkedIn =
      myBookings.where((b) => b.status == BookingStatus.redeemed).length;

  // Last 30 days revenue
  final today = DateTime.now();
  final dayRevenue = <int, int>{};
  final dayLabels = <String>[];
  for (var i = 29; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    // only show label every 5 days to avoid crowding
    dayLabels.add(i % 5 == 0 ? DateFormat('d MMM').format(day) : '');
    final dayStart =
        DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final dayEnd = dayStart + 86400000;
    final dayRev = myBookings
        .where((b) => b.createdAt >= dayStart && b.createdAt < dayEnd)
        .fold(0, (sum, b) => sum + b.totalAmount);
    dayRevenue[29 - i] = dayRev;
  }
  final spots = List.generate(
    30,
    (i) => FlSpot(i.toDouble(), (dayRevenue[i] ?? 0).toDouble()),
  );

  // By Tier
  final tierCount = <String, int>{};
  final tierRev = <String, int>{};
  for (final b in myBookings) {
    for (final s in b.seats) {
      tierCount[s.category] = (tierCount[s.category] ?? 0) + 1;
      // Approx revenue per seat if we don't have exact ticket price per seat in booking,
      // but we can compute average or if seats have prices.
      // Wait, in booking model, seats have 'row' and 'number' and 'category'.
      // For events, category is the tier name. Let's find the tier price from the event.
      final event = events.firstWhere((e) => e.eventId == b.showId, orElse: () => const EventModel(eventId: '', name: '', venueName: '', city: '', posterUrl: '', description: '', startTs: 0, endTs: 0, ticketTiers: [], managerId: ''));
      final tier = event.ticketTiers.firstWhere((t) => t.name == s.category, orElse: () => const TicketTier(name: 'Unknown', price: 0, totalSeats: 0, availableSeats: 0));
      tierRev[s.category] = (tierRev[s.category] ?? 0) + tier.price;
    }
  }

  return _EmAnalyticsData(
    totalEvents: events.length,
    totalTicketsSold: ticketsSold,
    totalRevenue: revenue,
    checkedIn: checkedIn,
    revenueSpots30Days: spots,
    dayLabels30Days: dayLabels,
    ticketsByTier: tierCount,
    revenueByTier: tierRev,
  );
});

// ─── Analytics Screen ───────────────────────────────────────────────────────

class EmAnalyticsScreen extends ConsumerStatefulWidget {
  const EmAnalyticsScreen({super.key});

  @override
  ConsumerState<EmAnalyticsScreen> createState() => _EmAnalyticsScreenState();
}

class _EmAnalyticsScreenState extends ConsumerState<EmAnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(_emAnalyticsProvider);

    return Scaffold(
      backgroundColor: EMColors.background,
      appBar: AppBar(
        backgroundColor: EMColors.surface,
        title: const Text('Analytics',
            style: TextStyle(color: EMColors.textPrimary)),
        iconTheme: const IconThemeData(color: EMColors.textPrimary),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: EMColors.primary)),
        error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: EMColors.error))),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_emAnalyticsProvider);
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOverallStats(data),
                  const SizedBox(height: 16),
                  _buildFunnel(data),
                  const SizedBox(height: 16),
                  _buildRevenueChart(data),
                  const SizedBox(height: 16),
                  _buildPieCharts(data),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverallStats(_EmAnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overall Performance',
          style: TextStyle(color: EMColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Total Revenue', value: '₹${_formatRevenue(data.totalRevenue)}', icon: Icons.currency_rupee, color: EMColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Total Tickets', value: '${data.totalTicketsSold}', icon: Icons.local_activity, color: EMColors.primary)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Total Events', value: '${data.totalEvents}', icon: Icons.event, color: EMColors.info)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Check-ins', value: '${data.checkedIn}', icon: Icons.check_circle_outline, color: EMColors.warning)),
          ],
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildFunnel(_EmAnalyticsData data) {
    final checkInRate = data.totalTicketsSold == 0 ? 0.0 : (data.checkedIn / data.totalTicketsSold * 100);
    return StaffGlassCard(
      padding: const EdgeInsets.all(16),
      surfaceColor: EMColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Check-in Funnel', style: TextStyle(color: EMColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _FunnelStep(label: 'Sold', value: data.totalTicketsSold, color: EMColors.primary),
              Icon(Icons.arrow_forward_rounded, color: EMColors.textMuted),
              _FunnelStep(label: 'Checked In', value: data.checkedIn, color: EMColors.success),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: data.totalTicketsSold == 0 ? 0 : data.checkedIn / data.totalTicketsSold,
            backgroundColor: EMColors.border,
            valueColor: const AlwaysStoppedAnimation(EMColors.success),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${checkInRate.toStringAsFixed(1)}% Conversion Rate',
              style: const TextStyle(color: EMColors.textSecondary, fontSize: 12),
            ),
          )
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRevenueChart(_EmAnalyticsData data) {
    return StaffGlassCard(
      padding: const EdgeInsets.all(16),
      surfaceColor: EMColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue - Last 30 Days', style: TextStyle(color: EMColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          if (data.revenueSpots30Days.every((s) => s.y == 0))
            const SizedBox(
              height: 160,
              child: Center(child: Text('No revenue in the last 30 days', style: TextStyle(color: EMColors.textSecondary))),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: EMColors.border, strokeWidth: 0.5, dashArray: [4, 4]),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text('₹${_formatRevenue(v.toInt())}', style: const TextStyle(fontSize: 10, color: EMColors.textMuted)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= data.dayLabels30Days.length) return const SizedBox.shrink();
                          final label = data.dayLabels30Days[idx];
                          if (label.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(label, style: const TextStyle(fontSize: 9, color: EMColors.textMuted)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.revenueSpots30Days,
                      isCurved: true,
                      color: EMColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: EMColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPieCharts(_EmAnalyticsData data) {
    if (data.ticketsByTier.isEmpty) return const SizedBox.shrink();

    final colors = [EMColors.primary, EMColors.accent, EMColors.warning, EMColors.success, EMColors.info];
    
    List<PieChartSectionData> ticketSections = [];
    List<PieChartSectionData> revenueSections = [];
    int i = 0;
    
    data.ticketsByTier.forEach((tier, count) {
      final color = colors[i % colors.length];
      ticketSections.add(PieChartSectionData(
        color: color,
        value: count.toDouble(),
        title: '$count',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      
      final rev = data.revenueByTier[tier] ?? 0;
      revenueSections.add(PieChartSectionData(
        color: color,
        value: rev.toDouble(),
        title: '₹${_formatRevenue(rev)}',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });

    return Column(
      children: [
        StaffGlassCard(
          padding: const EdgeInsets.all(16),
          surfaceColor: EMColors.surface,
          child: Column(
            children: [
              const Text('Tickets Sold by Tier', style: TextStyle(color: EMColors.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                height: 160,
                child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 40, sections: ticketSections)),
              ),
              const SizedBox(height: 16),
              _buildLegend(data.ticketsByTier.keys.toList(), colors),
            ],
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 24),
        StaffGlassCard(
          padding: const EdgeInsets.all(16),
          surfaceColor: EMColors.surface,
          child: Column(
            children: [
              const Text('Revenue by Tier', style: TextStyle(color: EMColors.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                height: 160,
                child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 40, sections: revenueSections)),
              ),
              const SizedBox(height: 16),
              _buildLegend(data.ticketsByTier.keys.toList(), colors),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }

  Widget _buildLegend(List<String> tiers, List<Color> colors) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: tiers.asMap().entries.map((e) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(e.value, style: const TextStyle(color: EMColors.textSecondary, fontSize: 12)),
          ],
        );
      }).toList(),
    );
  }

  String _formatRevenue(int amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return '$amount';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return StaffGlassCard(
      padding: const EdgeInsets.all(16),
      surfaceColor: EMColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: EMColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: EMColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FunnelStep extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _FunnelStep({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: EMColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
