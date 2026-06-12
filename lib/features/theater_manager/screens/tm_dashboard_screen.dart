import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/ad_request_model.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/showsnap_toast.dart';

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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No theater assigned to your account.\nContact an admin to assign you a theater.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_tmStatsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
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
                ),
                const SizedBox(height: 16),
                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _StatCard("Today's Shows",
                          '${stats.todayShows}',
                          Icons.movie_outlined,
                          ShowSnapColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard('Seats Sold',
                          '${stats.todaySeatsSold}',
                          Icons.event_seat_outlined,
                          ShowSnapColors.secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _StatCard('Today\'s Revenue', '₹${stats.todayRevenue}',
                    Icons.currency_rupee_outlined, Colors.purple),
                const SizedBox(height: 20),
                // Quick actions
                Text('Quick Actions',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
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
                ),
                const SizedBox(height: 20),
                // ── Promote My Theater ────────────────────────────────────
                Card(
                  color: ShowSnapColors.primaryLighter,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.md)),
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(ShowSnapRadius.md),
                    onTap: () => _showPromoDialog(
                        context, ref, stats.theater!, ref.read(authStateProvider).valueOrNull?.uid ?? ''),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ShowSnapColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.campaign_outlined,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Promote My Theater',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: ShowSnapColors.primary)),
                                const SizedBox(height: 2),
                                Text(
                                  'Submit a promotion request to ShowSnap admin',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: ShowSnapColors.primary
                                          .withOpacity(0.7)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: ShowSnapColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _showPromoDialog(
    BuildContext context, WidgetRef ref, TheaterModel theater, String uid) {
  final campaignCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String budgetRange = 'Under ₹10,000';
  const budgets = [
    'Under ₹10,000',
    '₹10,000 – ₹50,000',
    '₹50,000 – ₹1,00,000',
    'Above ₹1,00,000',
  ];

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Promote My Theater'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Theater: ${theater.name}',
                  style: const TextStyle(
                      fontSize: 12, color: ShowSnapColors.grey600)),
              const SizedBox(height: 14),
              TextField(
                controller: campaignCtrl,
                decoration: const InputDecoration(
                    labelText: 'Campaign Title *',
                    hintText: 'e.g. Grand Opening Discount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText:
                        'Tell us more about the promotion you want…'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: budgetRange,
                decoration: const InputDecoration(labelText: 'Budget Range'),
                items: budgets
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => budgetRange = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = campaignCtrl.text.trim();
              if (title.isEmpty) return;
              final request = AdRequestModel(
                requestId: '',
                uid: uid,
                requestType: AdRequestType.theater,
                brandName: theater.name,
                campaignTitle: title,
                description: descCtrl.text.trim(),
                budgetRange: budgetRange,
                createdAt: DateTime.now().millisecondsSinceEpoch,
              );
              await ref.read(databaseServiceProvider).submitAdRequest(request);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ShowSnapToast.show(context,
                    message: 'Promotion request submitted!');
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
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
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: ShowSnapColors.grey600),
            ],
          ),
        ),
      ),
    );
  }
}
