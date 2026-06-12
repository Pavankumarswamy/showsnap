import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';

class _EmStats {
  final List<EventModel> events;
  final int totalTicketsSold;
  final int totalRevenue;

  const _EmStats({
    this.events = const [],
    this.totalTicketsSold = 0,
    this.totalRevenue = 0,
  });
}

final _emStatsProvider = FutureProvider<_EmStats>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const _EmStats();

  final db = ref.watch(databaseServiceProvider);
  final events = await db.getEventsForManager(uid);
  final eventIds = events.map((e) => e.eventId).toSet();

  final allBookings = await db.getAllBookings();
  final myBookings = allBookings
      .where((b) =>
          eventIds.contains(b.showId) &&
          (b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.redeemed))
      .toList();

  final ticketsSold = myBookings.fold(0, (sum, b) => sum + b.seats.length);
  final revenue = myBookings.fold(0, (sum, b) => sum + b.totalAmount);

  return _EmStats(
    events: events,
    totalTicketsSold: ticketsSold,
    totalRevenue: revenue,
  );
});

class EmDashboardScreen extends ConsumerWidget {
  const EmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_emStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Manager Dashboard'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
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
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go(AppRoutes.login);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ShowSnapColors.primary,
        icon: const Icon(Icons.add, color: Colors.black87),
        label: const Text('Add Event',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.black87)),
        onPressed: () => context.push(AppRoutes.addEvent),
      ).animate().scale(delay: 300.ms, duration: 400.ms, curve: Curves.elasticOut),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_emStatsProvider.future),
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (stats) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
            children: [
              // Stats Cards Grid
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  _StatCard('Events', '${stats.events.length}',
                      Icons.event_outlined, ShowSnapColors.primary)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 50.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                  _StatCard('Tickets Sold', '${stats.totalTicketsSold}',
                      Icons.local_activity_outlined, ShowSnapColors.secondary)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 150.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                  _StatCard('Revenue', '₹${stats.totalRevenue}',
                      Icons.currency_rupee_outlined, Colors.purple)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 250.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                ],
              ),
              const SizedBox(height: 24),
              // Quick Actions
              Text('Quick Actions',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold))
                .animate()
                .fadeIn(duration: 300.ms, delay: 350.ms),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: ShowSnapColors.primaryLighter,
                    child: Icon(Icons.qr_code_scanner_outlined, color: Colors.black87),
                  ),
                  title: const Text('Scan Event Tickets',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Scan QR codes to redeem and check-in attendees'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.eventTicketScanner),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.05, end: 0),
              const SizedBox(height: 24),
              // Events List Header
              Text('My Events',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold))
                .animate()
                .fadeIn(duration: 300.ms, delay: 450.ms),
              const SizedBox(height: 12),
              if (stats.events.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(Icons.event_busy_outlined,
                            size: 64, color: ShowSnapColors.grey300),
                        const SizedBox(height: 16),
                        const Text('No events created yet',
                            style: TextStyle(
                                color: ShowSnapColors.grey600, fontSize: 16)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.addEvent),
                          child: const Text('Create Your First Event'),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 500.ms)
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stats.events.length,
                  itemBuilder: (_, i) {
                    final event = stats.events[i];
                    return _EventItem(event: event)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (500 + i * 50).ms)
                        .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
                  },
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 18,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: ShowSnapColors.grey600)),
          ],
        ),
      ),
    );
  }
}

class _EventItem extends ConsumerWidget {
  final EventModel event;
  const _EventItem({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: event.posterUrl.isNotEmpty
              ? Image.network(
                  event.posterUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _Placeholder(),
                )
              : _Placeholder(),
        ),
        title: Text(event.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${event.venueName} • ${event.city}\n${event.startTs.epochToDateLabel}',
          style: const TextStyle(fontSize: 11),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Event',
              onPressed: () => context.push('/em/edit-event/${event.eventId}'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Event',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
        onTap: () => context.push('/em/event-details/${event.eventId}'),
      ),
    );
  }

  Widget _Placeholder() => Container(
        width: 50,
        height: 50,
        color: ShowSnapColors.primaryLighter,
        child: const Icon(Icons.event_outlined, color: ShowSnapColors.primary),
      );

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ShowSnapColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(databaseServiceProvider).deleteEvent(event.eventId);
      ref.invalidate(_emStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );
      }
    }
  }
}
