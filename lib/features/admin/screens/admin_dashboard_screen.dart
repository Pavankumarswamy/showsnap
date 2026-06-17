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
import '../../../core/widgets/showsnap_toast.dart';
import '../../auth/providers/auth_provider.dart';

// ─── Data Model ───────────────────────────────────────────────────────────────

class _AdminStats {
  final int totalUsers;
  final int totalTheaters;
  final int todayBookings;
  final int totalRevenue;
  final int pendingAdRequests;
  final List<FlSpot> revenueSpots;
  final Map<String, int> revenueByTheater;
  final Map<String, int> ticketStatusCount;

  const _AdminStats({
    this.totalUsers = 0,
    this.totalTheaters = 0,
    this.todayBookings = 0,
    this.totalRevenue = 0,
    this.pendingAdRequests = 0,
    this.revenueSpots = const [],
    this.revenueByTheater = const {},
    this.ticketStatusCount = const {},
  });
}

final _adminStatsProvider = FutureProvider<_AdminStats>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final users = await db.getAllUsers();
  final bookings = await db.getAllBookings();
  final adRequests = await db.getAdRequests();
  final theaters = await db.getAllTheaters();

  final today = DateTime.now();
  final todayStart =
      DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;

  final todayBookings = bookings
      .where((b) =>
          b.createdAt >= todayStart && b.status == BookingStatus.confirmed)
      .length;

  final totalRevenue = bookings
      .where((b) =>
          b.status == BookingStatus.confirmed ||
          b.status == BookingStatus.redeemed)
      .fold(0, (sum, b) => sum + b.totalAmount);

  final pendingAdRequests =
      adRequests.where((r) => r.status.name == 'pending').length;

  // Last 7 days revenue spots
  final dayRevenue = <int, int>{};
  final sevenDaysAgo =
      today.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
  for (final b in bookings.where((b) => b.createdAt >= sevenDaysAgo)) {
    final dayIndex = today
        .difference(
            DateTime.fromMillisecondsSinceEpoch(b.createdAt))
        .inDays;
    final slot = 6 - dayIndex.clamp(0, 6);
    dayRevenue[slot] = (dayRevenue[slot] ?? 0) + b.totalAmount;
  }
  final spots = List.generate(
    7,
    (i) => FlSpot(i.toDouble(), (dayRevenue[i] ?? 0).toDouble()),
  );

  // Revenue by theater (top 5)
  final theaterRevenue = <String, int>{};
  for (final b
      in bookings.where((b) => b.status == BookingStatus.confirmed)) {
    theaterRevenue[b.theaterName] =
        (theaterRevenue[b.theaterName] ?? 0) + b.totalAmount;
  }

  // Ticket status counts
  final statusCount = <String, int>{
    'Confirmed': bookings
        .where((b) => b.status == BookingStatus.confirmed)
        .length,
    'Redeemed': bookings
        .where((b) => b.status == BookingStatus.redeemed)
        .length,
    'Cancelled': bookings
        .where((b) => b.status == BookingStatus.cancelled)
        .length,
  };

  return _AdminStats(
    totalUsers: users.length,
    totalTheaters: theaters.length,
    todayBookings: todayBookings,
    totalRevenue: totalRevenue,
    pendingAdRequests: pendingAdRequests,
    revenueSpots: spots,
    revenueByTheater: theaterRevenue,
    ticketStatusCount: statusCount,
  );
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await StaffConfirmDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDangerous: true,
    );
    if (ok == true && context.mounted) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_adminStatsProvider);

    return PushDrawerLayout(
      backgroundColor: AdminColors.background,
      drawer: AdminDrawer(
        currentRoute: AppRoutes.adminDashboard,
        onNavigateTo: (route) => context.push(route),
      ),
      appBar: _buildAppBar(context, ref),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdminColors.primary.withOpacity(0.15),
              ),
            ).animate().fadeIn(duration: 2.seconds).scale(begin: const Offset(0.8, 0.8)),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdminColors.info.withOpacity(0.1),
              ),
            ).animate().fadeIn(duration: 2.seconds, delay: 500.ms).scale(begin: const Offset(0.8, 0.8)),
          ),
          Positioned.fill(
            child: RefreshIndicator(
              color: AdminColors.primary,
              backgroundColor: AdminColors.surfaceElevated,
              onRefresh: () => ref.refresh(_adminStatsProvider.future),
              child: statsAsync.when(
                loading: _buildSkeleton,
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: AdminColors.error)),
                ),
                data: (stats) => _buildContent(context, stats),
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AdminColors.surface,
      foregroundColor: AdminColors.textPrimary,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AdminColors.border),
      ),
      title: const Text(
        'Admin Dashboard',
        style: TextStyle(
            color: AdminColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: AdminColors.textSecondary),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => _signOut(context, ref),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AdminColors.primaryGlow,
              child: const Text('A',
                  style: TextStyle(
                      color: AdminColors.primary,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: List.generate(
              4,
              (_) => const StaffShimmerCard(
                  height: 100,
                  baseColor: AdminColors.surface,
                  highlightColor: AdminColors.surfaceElevated)),
        ),
        const SizedBox(height: 16),
        const StaffShimmerCard(
            height: 220,
            baseColor: AdminColors.surface,
            highlightColor: AdminColors.surfaceElevated),
      ],
    );
  }

  Widget _buildContent(BuildContext context, _AdminStats stats) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              LayoutBuilder(builder: (_, constraints) {
                final isWide = constraints.maxWidth > 700;
                if (isWide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildKpiGrid(stats, isWideGrid: true),
                              const SizedBox(height: 24),
                              _buildRevenueChart(stats),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 260,
                          child: _buildTicketStatusChart(stats, fillHeight: true),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    _buildKpiGrid(stats, isWideGrid: false),
                    const SizedBox(height: 24),
                    _buildRevenueChart(stats),
                    const SizedBox(height: 16),
                    _buildTicketStatusChart(stats),
                  ],
                );
              }),
              const SizedBox(height: 24),
              // Quick Actions
              _buildQuickActions(context),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(_AdminStats stats, {bool isWideGrid = true}) {
    final cards = [
      (
        '₹${_formatRevenue(stats.totalRevenue)}',
        'Total Revenue',
        Icons.currency_rupee_rounded,
        AdminColors.primary,
        '+12%',
        true,
      ),
      (
        '${stats.totalUsers}',
        'Total Users',
        Icons.people_rounded,
        AdminColors.info,
        '+34 today',
        true,
      ),
      (
        '${stats.todayBookings}',
        "Today's Bookings",
        Icons.confirmation_number_rounded,
        AdminColors.success,
        '+8%',
        true,
      ),
      (
        '${stats.totalTheaters}',
        'Theaters',
        Icons.theaters_rounded,
        AdminColors.warning,
        '${stats.pendingAdRequests} pending ads',
        stats.pendingAdRequests == 0,
      ),
    ];

    final cardWidgets = cards.asMap().entries.map((entry) {
      final i = entry.key;
      final c = entry.value;
      return StaffStatCard(
        value: c.$1,
        label: c.$2,
        icon: c.$3,
        accentColor: c.$4,
        bgColor: AdminColors.surface,
        delta: c.$5,
        isPositive: c.$6,
      )
          .animate()
          .fadeIn(duration: 400.ms, delay: (i * 80).ms)
          .slideY(begin: 0.15, end: 0, curve: Curves.easeOutQuad);
    }).toList();

    if (isWideGrid) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < 4; i++) ...[
              Expanded(child: cardWidgets[i]),
              if (i < 3) const SizedBox(width: 12),
            ]
          ],
        ),
      );
    } else {
      return Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cardWidgets[0]),
                const SizedBox(width: 12),
                Expanded(child: cardWidgets[1]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cardWidgets[2]),
                const SizedBox(width: 12),
                Expanded(child: cardWidgets[3]),
              ],
            ),
          ),
        ],
      );
    }
  }

  String _formatRevenue(int amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$amount';
  }

  Widget _buildRevenueChart(_AdminStats stats) {
    return StaffGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffSectionHeader(title: 'Revenue — Last 7 Days'),
          const SizedBox(height: 16),
          if (stats.revenueSpots.isEmpty ||
              stats.revenueSpots.every((s) => s.y == 0))
            const SizedBox(
              height: 120,
              child: Center(
                child: Text('No revenue data yet',
                    style: TextStyle(color: AdminColors.textSecondary)),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  backgroundColor: AdminColors.surface,
                  lineBarsData: [
                    LineChartBarData(
                      spots: stats.revenueSpots,
                      isCurved: true,
                      color: AdminColors.primary,
                      barWidth: 2.5,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AdminColors.primary.withOpacity(0.3),
                            AdminColors.primary.withOpacity(0.0),
                          ],
                        ),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AdminColors.primary,
                          strokeWidth: 1,
                          strokeColor: AdminColors.background,
                        ),
                      ),
                    ),
                  ],
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: null,
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
                        reservedSize: 48,
                        getTitlesWidget: (v, _) => Text(
                          '₹${_formatRevenue(v.toInt())}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: AdminColors.textMuted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          const days = [
                            'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                          ];
                          final idx = v.toInt();
                          if (idx < 0 || idx >= days.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            days[idx],
                            style: const TextStyle(
                                fontSize: 10,
                                color: AdminColors.textMuted),
                          );
                        },
                      ),
                    ),
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
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 350.ms);
  }

  Widget _buildTopTheatersChart(_AdminStats stats) {
    final sorted = stats.revenueByTheater.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    final maxVal =
        top5.isEmpty ? 1 : top5.first.value.toDouble();

    return StaffGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffSectionHeader(title: 'Top Theaters'),
          const SizedBox(height: 16),
          if (top5.isEmpty)
            const StaffEmptyState(
              icon: Icons.theaters_outlined,
              message: 'No revenue data yet',
            )
          else
            ...top5.map((entry) {
              final pct = entry.value / maxVal;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                                color: AdminColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${_formatRevenue(entry.value)}',
                          style: const TextStyle(
                              color: AdminColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.pill),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: AdminColors.border,
                        valueColor: const AlwaysStoppedAnimation(
                            AdminColors.primary),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 450.ms);
  }

  Widget _buildTicketStatusChart(_AdminStats stats, {bool fillHeight = false}) {
    final statusData = stats.ticketStatusCount;
    final total = statusData.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          border: Border.all(color: AdminColors.border),
        ),
        child: const StaffEmptyState(
          icon: Icons.pie_chart_outline,
          message: 'No ticket data',
        ),
      );
    }

    final colors = [
      AdminColors.primary,
      AdminColors.success,
      AdminColors.error,
    ];
    final sections = statusData.entries.toList().asMap().entries.map((e) {
      final i = e.key;
      final entry = e.value;
      final pct = entry.value / total * 100;
      return PieChartSectionData(
        value: entry.value.toDouble(),
        color: colors[i % colors.length],
        title: '${pct.round()}%',
        radius: 40,
        titleStyle: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.bold),
      );
    }).toList();

    return StaffGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffSectionHeader(title: 'Ticket Status'),
          const SizedBox(height: 16),
          if (fillHeight)
            Expanded(
              child: Center(
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 24,
                    sectionsSpace: 2,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 24,
                  sectionsSpace: 2,
                ),
              ),
            ),
          const SizedBox(height: 12),
          ...statusData.entries.toList().asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                          color: AdminColors.textSecondary,
                          fontSize: 12),
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms);
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (Icons.theaters_rounded, 'Theaters', AppRoutes.adminTheaters),
      (Icons.people_rounded, 'Users', AppRoutes.userManagement),
      (Icons.confirmation_number_rounded, 'Tickets', AppRoutes.ticketAudit),
      (Icons.local_offer_rounded, 'Offers', AppRoutes.adminOffers),
      (Icons.campaign_rounded, 'Ad Requests', AppRoutes.adRequests),
      (Icons.analytics_rounded, 'Analytics', AppRoutes.adminAnalytics),
      (Icons.image_rounded, 'Banners', AppRoutes.adminBanners),
      (Icons.add_business_rounded, 'Add Theater', AppRoutes.addTheater),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StaffSectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (_, constraints) {
          final cols = constraints.maxWidth > 700 ? 4 : (constraints.maxWidth > 400 ? 4 : 2);
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: actions.asMap().entries.map((entry) {
              final i = entry.key;
              final a = entry.value;
              return _QuickActionTile(
                icon: a.$1,
                label: a.$2,
                onTap: () => context.push(a.$3),
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: (550 + i * 40).ms)
                  .slideY(begin: 0.1, end: 0);
            }).toList(),
          );
        }),
      ],
    );
  }
}

// ─── Quick Action Tile ────────────────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StaffGlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AdminColors.primaryGlow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AdminColors.primary, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AdminColors.textMuted, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
