import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../auth/providers/auth_provider.dart';

// ─── EM Color Palette ─────────────────────────────────────────────────────────

class EMColors {
  static const background = Color(0xFF0A0C10);
  static const surface = Color(0x66161922);
  static const surfaceElevated = Color(0x881E2230);
  static const border = Color(0x22FFFFFF);

  static const primary = Color(0xFFA6A25A);
  static const primaryGlow = Color(0x33A6A25A);
  static const accent = Color(0xFF7C6FE3);
  static const accentGlow = Color(0x337C6FE3);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  static const textPrimary = Color(0xFFF0F0F0);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF52525B);
}

// ─── Enhanced Data Model ──────────────────────────────────────────────────────

class _EmStats {
  final List<EventModel> events;
  final int totalTicketsSold;
  final int totalRevenue;
  final int checkedIn;
  final int todayTickets;
  final List<FlSpot> revenueSpots;
  final List<String> dayLabels;
  final List<BookingModel> recentBookings;
  final Map<String, int> ticketsByTier;

  const _EmStats({
    this.events = const [],
    this.totalTicketsSold = 0,
    this.totalRevenue = 0,
    this.checkedIn = 0,
    this.todayTickets = 0,
    this.revenueSpots = const [],
    this.dayLabels = const [],
    this.recentBookings = const [],
    this.ticketsByTier = const {},
  });
}

final _emStatsProvider = FutureProvider<_EmStats>((ref) async {
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

  // Today's tickets
  final today = DateTime.now();
  final todayStart =
      DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
  final todayTickets = myBookings
      .where((b) => b.createdAt >= todayStart)
      .fold(0, (sum, b) => sum + b.seats.length);

  // Last 7 days revenue for chart
  final dayRevenue = <int, int>{};
  final dayLabels = <String>[];
  for (var i = 6; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    dayLabels.add(DateFormat('EEE').format(day));
    final dayStart =
        DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final dayEnd = dayStart + 86400000;
    final dayRev = myBookings
        .where((b) => b.createdAt >= dayStart && b.createdAt < dayEnd)
        .fold(0, (sum, b) => sum + b.totalAmount);
    dayRevenue[6 - i] = dayRev;
  }
  final spots = List.generate(
    7,
    (i) => FlSpot(i.toDouble(), (dayRevenue[i] ?? 0).toDouble()),
  );

  // Recent bookings (latest 5)
  final recentBookings = List<BookingModel>.from(myBookings)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Tickets by tier
  final tierCount = <String, int>{};
  for (final b in myBookings) {
    for (final s in b.seats) {
      tierCount[s.category] = (tierCount[s.category] ?? 0) + 1;
    }
  }

  return _EmStats(
    events: events,
    totalTicketsSold: ticketsSold,
    totalRevenue: revenue,
    checkedIn: checkedIn,
    todayTickets: todayTickets,
    revenueSpots: spots,
    dayLabels: dayLabels,
    recentBookings: recentBookings.take(5).toList(),
    ticketsByTier: tierCount,
  );
});

// ─── EM Drawer ────────────────────────────────────────────────────────────────

class EmDrawer extends StatelessWidget {
  final String currentRoute;
  final Function(String) onNavigateTo;
  final VoidCallback? onSignOut;
  final String managerName;

  const EmDrawer({
    required this.currentRoute,
    required this.onNavigateTo,
    this.onSignOut,
    this.managerName = 'Event Manager',
  });

  static const _items = [
    EmNavItem(Icons.dashboard_rounded, 'Dashboard', '/em'),
    EmNavItem(Icons.event_note_rounded, 'My Events', '/em/events'),
    EmNavItem(Icons.analytics_rounded, 'Analytics', '/em/analytics'),
    EmNavItem(Icons.local_offer_rounded, 'Promo Codes', '/em/coupons'),
    EmNavItem(Icons.add_circle_outline_rounded, 'Create Event', '/em/add-event'),
    EmNavItem(Icons.qr_code_scanner_rounded, 'Ticket Scanner', '/em/scanner'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EMColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: EMColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          EMColors.primary.withOpacity(0.3),
                          EMColors.accent.withOpacity(0.2),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.sm),
                    ),
                    child: const Icon(Icons.celebration_rounded,
                        color: EMColors.primary, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    managerName,
                    style: const TextStyle(
                        color: EMColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Event Manager',
                    style: TextStyle(
                        color: EMColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Nav items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final item = _items[i];
                  final isActive = currentRoute == item.route ||
                      (item.route != '/em' &&
                          currentRoute.startsWith(item.route));
                  return EmNavTile(
                    item: item,
                    isActive: isActive,
                    onTap: () async {
                      final pushLayout = context
                          .findAncestorStateOfType<PushDrawerLayoutState>();
                      if (pushLayout != null) {
                        pushLayout.closeDrawer();
                      } else {
                        Navigator.pop(context);
                      }
                      if (!isActive) {
                        await onNavigateTo(item.route);
                      }
                    },
                  );
                },
              ),
            ),
            // Sign out
            const Divider(color: EMColors.border, height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: EMColors.error),
              title: const Text('Sign Out',
                  style: TextStyle(color: EMColors.error)),
              onTap: () {
                final pushLayout = context
                    .findAncestorStateOfType<PushDrawerLayoutState>();
                if (pushLayout != null) {
                  pushLayout.closeDrawer();
                } else {
                  Navigator.pop(context);
                }
                if (onSignOut != null) onSignOut!();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class EmNavItem {
  final IconData icon;
  final String label;
  final String route;
  const EmNavItem(this.icon, this.label, this.route);
}

class EmNavTile extends StatelessWidget {
  final EmNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const EmNavTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? EMColors.primaryGlow : Colors.transparent,
        borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
        border: isActive
            ? const Border(
                left: BorderSide(color: EMColors.primary, width: 3))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(
            item.icon,
            color: isActive ? EMColors.primary : EMColors.textSecondary,
            size: 22,
          ),
          title: Text(
            item.label,
            style: TextStyle(
              color:
                  isActive ? EMColors.primary : EMColors.textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          onTap: onTap,
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
          ),
        ),
      ),
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class EmDashboardScreen extends ConsumerWidget {
  const EmDashboardScreen({super.key});

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
    final statsAsync = ref.watch(_emStatsProvider);
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    final managerName = user?.displayName ?? 'Event Manager';

    return PushDrawerLayout(
      backgroundColor: EMColors.background,
      drawer: EmDrawer(
        currentRoute: AppRoutes.emDashboard,
        managerName: managerName,
        onNavigateTo: (route) async {
          await context.push(route);
          ref.invalidate(_emStatsProvider);
        },
        onSignOut: () => _signOut(context, ref),
      ),
      appBar: _buildAppBar(context, ref),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'em_add_event',
        backgroundColor: EMColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.black87),
        label: const Text('New Event',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.black87)),
        onPressed: () async {
          await context.push(AppRoutes.addEvent);
          ref.invalidate(_emStatsProvider);
        },
      )
          .animate()
          .scale(delay: 400.ms, duration: 500.ms, curve: Curves.elasticOut),
      body: Stack(
        children: [
          // Background glow orbs
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EMColors.primary.withOpacity(0.08),
              ),
            )
                .animate()
                .fadeIn(duration: 2.seconds)
                .scale(begin: const Offset(0.8, 0.8)),
          ),
          Positioned(
            bottom: -40,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EMColors.accent.withOpacity(0.06),
              ),
            )
                .animate()
                .fadeIn(duration: 2.seconds, delay: 300.ms)
                .scale(begin: const Offset(0.8, 0.8)),
          ),
          // Main content
          Positioned.fill(
            child: RefreshIndicator(
              color: EMColors.primary,
              backgroundColor: EMColors.surfaceElevated,
              onRefresh: () async {
                ref.invalidate(_emStatsProvider);
              },
              child: statsAsync.when(
                loading: _buildSkeleton,
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: EMColors.error, size: 48),
                      const SizedBox(height: 12),
                      Text('Error: $e',
                          style:
                              const TextStyle(color: EMColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(_emStatsProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (stats) =>
                    _buildContent(context, ref, stats),
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: EMColors.surface,
      foregroundColor: EMColors.textPrimary,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: EMColors.border),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  EMColors.primary.withOpacity(0.3),
                  EMColors.accent.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.celebration_rounded,
                color: EMColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Event Manager',
            style: TextStyle(
                color: EMColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded,
              color: EMColors.textSecondary),
          tooltip: 'Scan Tickets',
          onPressed: () => context.push(AppRoutes.eventTicketScanner),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => _signOut(context, ref),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: EMColors.primaryGlow,
              child: const Text('EM',
                  style: TextStyle(
                      color: EMColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
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
          childAspectRatio: 1.5,
          children: List.generate(
              4,
              (_) => const StaffShimmerCard(
                  height: 100,
                  baseColor: EMColors.surface,
                  highlightColor: EMColors.surfaceElevated)),
        ),
        const SizedBox(height: 16),
        const StaffShimmerCard(
            height: 220,
            baseColor: EMColors.surface,
            highlightColor: EMColors.surfaceElevated),
        const SizedBox(height: 16),
        const StaffShimmerCard(
            height: 160,
            baseColor: EMColors.surface,
            highlightColor: EMColors.surfaceElevated),
      ],
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, _EmStats stats) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: CustomScrollView(
          slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Greeting ──
              _GreetingHeader(
                eventCount: stats.events.length,
                todayTickets: stats.todayTickets,
              ),
              const SizedBox(height: 20),

              // ── KPI Cards ──
              _buildKpiGrid(stats),
              const SizedBox(height: 24),

              // ── Next Event Countdown ──
              if (stats.events.isNotEmpty)
                _NextEventCountdown(events: stats.events),
              if (stats.events.isNotEmpty) const SizedBox(height: 24),

              // ── Revenue Chart ──
              _buildRevenueChart(stats),
              const SizedBox(height: 24),

              // ── Quick Actions ──
              _buildQuickActions(context),
              const SizedBox(height: 24),

              // ── Recent Activity ──
              if (stats.recentBookings.isNotEmpty) ...[
                _buildRecentActivity(stats),
                const SizedBox(height: 24),
              ],

              // ── My Events ──
              _buildEventsSection(context, ref, stats),
            ]),
          ),
        ),
      ],
    ),
      ),
    );
  }

  // ── Greeting ────────────────────────────────────────────────────────────

  // ── KPI Grid ────────────────────────────────────────────────────────────

  Widget _buildKpiGrid(_EmStats stats) {
    final checkInRate = stats.totalTicketsSold > 0
        ? (stats.checkedIn / stats.totalTicketsSold * 100).round()
        : 0;

    final cards = [
      (
        '${stats.events.length}',
        'Events',
        Icons.event_rounded,
        EMColors.info,
        '${stats.events.where((e) => e.status == 'published').length} active',
        true,
      ),
      (
        '${stats.totalTicketsSold}',
        'Tickets Sold',
        Icons.confirmation_number_rounded,
        EMColors.primary,
        '+${stats.todayTickets} today',
        true,
      ),
      (
        '₹${_formatRevenue(stats.totalRevenue)}',
        'Revenue',
        Icons.currency_rupee_rounded,
        EMColors.success,
        'Lifetime',
        true,
      ),
      (
        '$checkInRate%',
        'Check-in Rate',
        Icons.how_to_reg_rounded,
        EMColors.accent,
        '${stats.checkedIn} scanned',
        checkInRate > 50,
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
      children: cards.asMap().entries.map((entry) {
        final i = entry.key;
        final c = entry.value;
        return _EmKpiCard(
          value: c.$1,
          label: c.$2,
          icon: c.$3,
          accentColor: c.$4,
          delta: c.$5,
          isPositive: c.$6,
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: (i * 80).ms)
            .slideY(
                begin: 0.15, end: 0, curve: Curves.easeOutQuad);
      }).toList(),
        );
      },
    );
  }

  // ── Revenue Chart ───────────────────────────────────────────────────────

  Widget _buildRevenueChart(_EmStats stats) {
    return StaffGlassCard(
      padding: const EdgeInsets.all(16),
      surfaceColor: EMColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: EMColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: EMColors.success, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Revenue — Last 7 Days',
                style: TextStyle(
                    color: EMColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (stats.revenueSpots.every((s) => s.y == 0))
            const SizedBox(
              height: 140,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        color: EMColors.textMuted, size: 36),
                    SizedBox(height: 8),
                    Text('No revenue data yet',
                        style: TextStyle(
                            color: EMColors.textSecondary,
                            fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  backgroundColor: Colors.transparent,
                  barGroups: stats.revenueSpots.map((spot) {
                    return BarChartGroupData(
                      x: spot.x.toInt(),
                      barRods: [
                        BarChartRodData(
                          toY: spot.y,
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              EMColors.primary.withOpacity(0.3),
                              EMColors.primary,
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: EMColors.border,
                      strokeWidth: 0.5,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (v, _) => Text(
                          '₹${_formatRevenue(v.toInt())}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: EMColors.textMuted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 ||
                              idx >= stats.dayLabels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              stats.dayLabels[idx],
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: EMColors.textMuted),
                            ),
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
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => EMColors.surfaceElevated,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '₹${rod.toY.toInt()}',
                          const TextStyle(
                            color: EMColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 350.ms);
  }

  // ── Quick Actions ───────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (Icons.add_circle_outline_rounded, 'Create Event', AppRoutes.addEvent,
          EMColors.primary),
      (Icons.qr_code_scanner_rounded, 'Scan Tickets',
          AppRoutes.eventTicketScanner, EMColors.accent),
      (Icons.local_offer_rounded, 'Promo Codes',
          AppRoutes.emCoupons, EMColors.warning),
      (Icons.share_rounded, 'Share App', 'share_action', EMColors.info),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: EMColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flash_on_rounded,
                  color: EMColors.warning, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Quick Actions',
              style: TextStyle(
                  color: EMColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 64, // Fixed height for each action
              ),
          itemCount: actions.length,
          itemBuilder: (context, i) {
            final a = actions[i];
            return _EmQuickAction(
              icon: a.$1,
              label: a.$2,
              color: a.$4,
              onTap: () async {
                if (a.$3 == 'share_action') {
                  Share.share(
                      'Check out ShowSnap to discover and book the best events and movies! 🎟️✨\nhttps://showsnap.web.app');
                } else {
                  await context.push(a.$3);
                }
              },
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: (450 + i * 60).ms)
                .slideY(begin: 0.1, end: 0);
          },
        );
          },
        ),
      ],
    );
  }

  // ── Recent Activity ─────────────────────────────────────────────────────

  Widget _buildRecentActivity(_EmStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: EMColors.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history_rounded,
                  color: EMColors.info, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Recent Activity',
              style: TextStyle(
                  color: EMColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StaffGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          surfaceColor: EMColors.surface,
          child: Column(
            children: stats.recentBookings.asMap().entries.map((entry) {
              final i = entry.key;
              final booking = entry.value;
              final timeAgo = _timeAgo(booking.createdAt);
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: booking.status ==
                              BookingStatus.redeemed
                          ? EMColors.success.withOpacity(0.15)
                          : EMColors.primary.withOpacity(0.15),
                      child: Icon(
                        booking.status == BookingStatus.redeemed
                            ? Icons.how_to_reg_rounded
                            : Icons.local_activity_rounded,
                        size: 14,
                        color: booking.status == BookingStatus.redeemed
                            ? EMColors.success
                            : EMColors.primary,
                      ),
                    ),
                    title: Text(
                      '${booking.seats.length} ticket${booking.seats.length > 1 ? 's' : ''} — ${booking.movieTitle}',
                      style: const TextStyle(
                          color: EMColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '₹${booking.totalAmount} • $timeAgo',
                      style: const TextStyle(
                          color: EMColors.textMuted, fontSize: 11),
                    ),
                    trailing: StaffBadge(
                      label: booking.status == BookingStatus.redeemed
                          ? 'Checked In'
                          : 'Confirmed',
                      color: booking.status == BookingStatus.redeemed
                          ? EMColors.success
                          : EMColors.primary,
                    ),
                  )
                      .animate()
                      .fadeIn(
                          duration: 300.ms,
                          delay: (550 + i * 50).ms)
                      .slideX(begin: 0.05, end: 0),
                  if (i < stats.recentBookings.length - 1)
                    const Divider(
                        color: EMColors.border,
                        height: 1,
                        indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Events Section ──────────────────────────────────────────────────────

  Widget _buildEventsSection(
      BuildContext context, WidgetRef ref, _EmStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: EMColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event_rounded,
                  color: EMColors.accent, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Recent Events',
              style: TextStyle(
                  color: EMColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            const Spacer(),
            TextButton(
              onPressed: () async {
                await context.push('/em/events');
                ref.invalidate(_emStatsProvider);
              },
              style: TextButton.styleFrom(
                foregroundColor: EMColors.primary,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (stats.events.isEmpty)
          StaffGlassCard(
            surfaceColor: EMColors.surface,
            child: const StaffEmptyState(
              icon: Icons.event_busy_outlined,
              message: 'No events created yet.\nTap + to create your first event!',
              iconColor: EMColors.primary,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms)
        else
          ...stats.events.take(3).toList().asMap().entries.map((entry) {
            final i = entry.key;
            final event = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EmEventCard(
                event: event,
                onDelete: () => _confirmDelete(context, ref, event),
              )
                  .animate()
                  .fadeIn(
                      duration: 400.ms, delay: (600 + i * 60).ms)
                  .slideY(
                      begin: 0.05,
                      end: 0,
                      curve: Curves.easeOutQuad),
            );
          }),
      ],
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, EventModel event) async {
    final ok = await StaffConfirmDialog.show(
      context,
      title: 'Delete Event',
      message:
          'Are you sure you want to delete "${event.name}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDangerous: true,
    );
    if (ok == true) {
      await ref.read(databaseServiceProvider).deleteEvent(event.eventId);
      ref.invalidate(_emStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatRevenue(int amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$amount';
  }

  String _timeAgo(int epochMs) {
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(epochMs));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM')
        .format(DateTime.fromMillisecondsSinceEpoch(epochMs));
  }
}

// ─── Greeting Header ──────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final int eventCount;
  final int todayTickets;
  const _GreetingHeader(
      {required this.eventCount, required this.todayTickets});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting 👋',
          style: const TextStyle(
            color: EMColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          todayTickets > 0
              ? '$todayTickets tickets sold today across $eventCount events'
              : 'Manage your $eventCount event${eventCount != 1 ? 's' : ''} and track performance',
          style: const TextStyle(
              color: EMColors.textSecondary, fontSize: 13),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideX(begin: -0.03, end: 0);
  }
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

class _EmKpiCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String? delta;
  final bool isPositive;

  const _EmKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.delta,
    this.isPositive = true,
  });

  @override
  State<_EmKpiCard> createState() => _EmKpiCardState();
}

class _EmKpiCardState extends State<_EmKpiCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StaffGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      glowColor: widget.accentColor.withOpacity(0.06),
      surfaceColor: EMColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon,
                    color: widget.accentColor, size: 18),
              ),
              const Spacer(),
              if (widget.delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: (widget.isPositive
                            ? EMColors.success
                            : EMColors.error)
                        .withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(ShowSnapRadius.pill),
                  ),
                  child: Text(
                    widget.delta!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: widget.isPositive
                          ? EMColors.success
                          : EMColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: EMColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            widget.label,
            style: const TextStyle(
                fontSize: 11, color: EMColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action ─────────────────────────────────────────────────────────────

class _EmQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _EmQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StaffGlassCard(
      padding: EdgeInsets.zero,
      surfaceColor: EMColors.surface,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        color: EMColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: color.withOpacity(0.6), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Next Event Countdown ─────────────────────────────────────────────────────

class _NextEventCountdown extends StatelessWidget {
  final List<EventModel> events;
  const _NextEventCountdown({required this.events});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final upcoming = events
        .where((e) => e.startTs > now && e.status == 'published')
        .toList()
      ..sort((a, b) => a.startTs.compareTo(b.startTs));

    if (upcoming.isEmpty) return const SizedBox.shrink();

    final next = upcoming.first;
    final diff = Duration(milliseconds: next.startTs - now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    return StaffGlassCard(
      padding: const EdgeInsets.all(16),
      surfaceColor: EMColors.surface,
      glowColor: EMColors.accent.withOpacity(0.05),
      child: Row(
        children: [
          // Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: next.posterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: next.posterUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _posterPlaceholder(),
                  )
                : _posterPlaceholder(),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEXT EVENT',
                  style: TextStyle(
                      color: EMColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  next.name,
                  style: const TextStyle(
                      color: EMColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${next.venueName} • ${next.startTs.epochToDateLabel}',
                  style: const TextStyle(
                      color: EMColors.textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Countdown
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  EMColors.accent.withOpacity(0.2),
                  EMColors.primary.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: EMColors.accent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                if (days > 0) ...[
                  Text(
                    '$days',
                    style: const TextStyle(
                        color: EMColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    days == 1 ? 'day' : 'days',
                    style: const TextStyle(
                        color: EMColors.textMuted, fontSize: 10),
                  ),
                ] else ...[
                  Text(
                    '${hours}h ${minutes}m',
                    style: const TextStyle(
                        color: EMColors.warning,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'left',
                    style: TextStyle(
                        color: EMColors.textMuted, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 300.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _posterPlaceholder() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: EMColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.event_rounded,
            color: EMColors.textMuted, size: 24),
      );
}

// ─── Event Card ───────────────────────────────────────────────────────────────

class EmEventCard extends ConsumerWidget {
  final EventModel event;
  final VoidCallback onDelete;
  const EmEventCard({super.key, required this.event, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isUpcoming = event.startTs > now;
    final isPast = event.startTs < now;

    // Ticket availability
    final totalSeats =
        event.ticketTiers.fold(0, (sum, t) => sum + t.totalSeats);
    final availableSeats =
        event.ticketTiers.fold(0, (sum, t) => sum + t.availableSeats);
    final soldSeats = totalSeats - availableSeats;
    final soldPct =
        totalSeats > 0 ? (soldSeats / totalSeats) : 0.0;

    return StaffGlassCard(
      padding: EdgeInsets.zero,
      surfaceColor: EMColors.surface,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          onTap: () async {
            await context.push('/em/event-details/${event.eventId}');
            ref.invalidate(_emStatsProvider);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: event.posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: event.posterUrl,
                          width: 64,
                          height: 80,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _placeholder(),
                        )
                      : _placeholder(),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status + Category badges
                      Row(
                        children: [
                          StaffBadge(
                            label: isUpcoming
                                ? 'Upcoming'
                                : isPast
                                    ? 'Past'
                                    : 'Live',
                            color: isUpcoming
                                ? EMColors.info
                                : isPast
                                    ? EMColors.textMuted
                                    : EMColors.success,
                          ),
                          if (event.status == 'draft') ...[
                            const SizedBox(width: 6),
                            const StaffBadge(
                              label: 'Draft',
                              color: Colors.grey,
                            ),
                          ] else if (event.status == 'closed') ...[
                            const SizedBox(width: 6),
                            const StaffBadge(
                              label: 'Closed',
                              color: EMColors.error,
                            ),
                          ] else if (!event.isActive) ...[
                            const SizedBox(width: 6),
                            const StaffBadge(
                              label: 'Inactive',
                              color: EMColors.error,
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.name,
                        style: const TextStyle(
                            color: EMColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${event.venueName} • ${event.startTs.epochToDateLabel}',
                        style: const TextStyle(
                            color: EMColors.textSecondary,
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Sales progress
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: soldPct,
                                minHeight: 4,
                                backgroundColor:
                                    EMColors.border,
                                valueColor:
                                    AlwaysStoppedAnimation(
                                  soldPct > 0.8
                                      ? EMColors.warning
                                      : EMColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$soldSeats/$totalSeats sold',
                            style: const TextStyle(
                                color: EMColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Actions
                Column(
                  children: [
                    _MiniIconButton(
                      icon: Icons.edit_outlined,
                      color: EMColors.textSecondary,
                      tooltip: 'Edit',
                      onTap: () => context
                          .push('/em/edit-event/${event.eventId}'),
                    ),
                    _MiniIconButton(
                      icon: Icons.share_outlined,
                      color: EMColors.textSecondary,
                      tooltip: 'Share',
                      onTap: () => _shareEvent(context),
                    ),
                    _MiniIconButton(
                      icon: Icons.delete_outline_rounded,
                      color: EMColors.error.withOpacity(0.7),
                      tooltip: 'Delete',
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _shareEvent(BuildContext context) {
    final message =
        '🎉 Check out *${event.name}*!\n\n'
        '📍 ${event.venueName}, ${event.city}\n'
        '📅 ${event.startTs.epochToDateTimeLabel}\n'
        '🎟️ Tickets from ₹${event.lowestPrice}\n\n'
        'Book now on ShowSnap!';
    Share.share(message);
  }

  Widget _placeholder() => Container(
        width: 64,
        height: 80,
        decoration: BoxDecoration(
          color: EMColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.event_rounded,
            color: EMColors.textMuted, size: 28),
      );
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
