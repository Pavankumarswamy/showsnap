import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/services/database_service.dart';
import '../../auth/providers/auth_provider.dart';

class _AdminStats {
  final int totalUsers;
  final int todayBookings;
  final int totalRevenue;
  final int pendingAdRequests;
  final List<FlSpot> bookingSpots; // last 30 days
  final Map<String, int> revenueByTheater;

  const _AdminStats({
    this.totalUsers = 0,
    this.todayBookings = 0,
    this.totalRevenue = 0,
    this.pendingAdRequests = 0,
    this.bookingSpots = const [],
    this.revenueByTheater = const {},
  });
}

final _adminStatsProvider = FutureProvider<_AdminStats>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final users = await db.getAllUsers();
  final bookings = await db.getAllBookings();
  final adRequests = await db.getAdRequests();

  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day)
      .millisecondsSinceEpoch;

  final todayBookings = bookings
      .where((b) =>
          b.createdAt >= todayStart &&
          b.status == BookingStatus.confirmed)
      .length;

  final totalRevenue = bookings
      .where((b) => b.status == BookingStatus.confirmed ||
          b.status == BookingStatus.redeemed)
      .fold(0, (sum, b) => sum + b.totalAmount);

  final pendingAdRequests =
      adRequests.where((r) => r.status.name == 'pending').length;

  // Build last 30 days booking count spots
  final dayCount = <int, int>{};
  final thirtyDaysAgo = today
      .subtract(const Duration(days: 30))
      .millisecondsSinceEpoch;
  for (final b in bookings.where((b) => b.createdAt >= thirtyDaysAgo)) {
    final day = DateTime.fromMillisecondsSinceEpoch(b.createdAt).day;
    dayCount[day] = (dayCount[day] ?? 0) + 1;
  }
  final spots = dayCount.entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
      .toList()
    ..sort((a, b) => a.x.compareTo(b.x));

  // Revenue by theater
  final theaterRevenue = <String, int>{};
  for (final b in bookings.where(
      (b) => b.status == BookingStatus.confirmed)) {
    theaterRevenue[b.theaterName] =
        (theaterRevenue[b.theaterName] ?? 0) + b.totalAmount;
  }

  return _AdminStats(
    totalUsers: users.length,
    todayBookings: todayBookings,
    totalRevenue: totalRevenue,
    pendingAdRequests: pendingAdRequests,
    bookingSpots: spots,
    revenueByTheater: theaterRevenue,
  );
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_adminStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go(AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_adminStatsProvider.future),
        child: statsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (stats) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            children: [
              // Stats grid
              LayoutBuilder(builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                return GridView.count(
                  crossAxisCount: isDesktop ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isDesktop ? 2.5 : 1.6,
                  children: [
                  _StatCard('Total Users', '${stats.totalUsers}',
                      Icons.people_outlined, ShowSnapColors.primary)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 50.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                  _StatCard("Today's Bookings",
                      '${stats.todayBookings}',
                      Icons.confirmation_number_outlined,
                      ShowSnapColors.secondary)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 150.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                  _StatCard('Total Revenue', '₹${stats.totalRevenue}',
                      Icons.currency_rupee_outlined, Colors.purple)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 250.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                  _StatCard('Pending Ads',
                      '${stats.pendingAdRequests}',
                      Icons.campaign_outlined, Colors.orange)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 350.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                ],
              );
              }),
              const SizedBox(height: 20),
              // Bookings chart
              if (stats.bookingSpots.isNotEmpty) ...[
                Text('Bookings — Last 30 Days',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold))
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 400.ms),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: stats.bookingSpots,
                          isCurved: true,
                          color: ShowSnapColors.primary,
                          belowBarData: BarAreaData(
                              show: true,
                              color: ShowSnapColors.primary.withOpacity(0.2)),
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 450.ms),
                const SizedBox(height: 20),
              ],
              // Quick actions
              Text('Quick Actions',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold))
                .animate()
                .fadeIn(duration: 300.ms, delay: 500.ms),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                return GridView.count(
                  crossAxisCount: isDesktop ? 6 : (constraints.maxWidth > 500 ? 4 : 2),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isDesktop ? 3.0 : 2.2,
                  children: [
                  _ActionButton('Users',
                      Icons.people_outlined,
                      () => context.push(AppRoutes.userManagement))
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 550.ms)
                    .slideY(begin: 0.1, end: 0),
                  _ActionButton('Tickets',
                      Icons.confirmation_number_outlined,
                      () => context.push(AppRoutes.ticketAudit))
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 600.ms)
                    .slideY(begin: 0.1, end: 0),
                  _ActionButton('Offers',
                      Icons.local_offer_outlined,
                      () => context.push(AppRoutes.adminOffers))
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 650.ms)
                    .slideY(begin: 0.1, end: 0),
                  _ActionButton('Ad Requests',
                      Icons.campaign_outlined,
                      () => context.push(AppRoutes.adRequests))
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 700.ms)
                    .slideY(begin: 0.1, end: 0),
                  _ActionButton('Add Theater',
                      Icons.add_business_outlined,
                      () => context.push(AppRoutes.addTheater))
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 750.ms)
                    .slideY(begin: 0.1, end: 0),
                  _ActionButton('Banners',
                      Icons.image_outlined,
                      () => context.push(AppRoutes.adminBanners))
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 800.ms)
                    .slideY(begin: 0.1, end: 0),
                ],
              );
              }),
              const SizedBox(height: 32),
            ],
          ),
        ),
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
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: ShowSnapColors.grey600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionButton(this.label, this.icon, this.onTap);

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
              Icon(icon, color: ShowSnapColors.primary, size: 22),
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
