import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'em_dashboard_screen.dart'; // For EMColors, EmDrawer, EmEventCard

final _emEventsScreenProvider = FutureProvider.autoDispose<List<EventModel>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  final db = ref.watch(databaseServiceProvider);
  return await db.getEventsForManager(uid);
});

class EmEventsScreen extends ConsumerWidget {
  const EmEventsScreen({super.key});

  void _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await StaffConfirmDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDangerous: true,
    );
    if (ok == true) {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) {
        context.go('/auth');
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, EventModel event) async {
    final ok = await StaffConfirmDialog.show(
      context,
      title: 'Delete Event',
      message: 'Are you sure you want to delete "${event.name}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDangerous: true,
    );
    if (ok == true) {
      await ref.read(databaseServiceProvider).deleteEvent(event.eventId);
      ref.invalidate(_emEventsScreenProvider);
      // Also invalidate dashboard so it syncs up
      ref.invalidate(databaseServiceProvider);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    final managerName = user?.displayName ?? 'Manager';
    final eventsAsync = ref.watch(_emEventsScreenProvider);

    return PushDrawerLayout(
      backgroundColor: EMColors.background,
      drawer: EmDrawer(
        currentRoute: '/em/events',
        managerName: managerName,
        onNavigateTo: (route) async {
          await context.push(route);
          ref.invalidate(_emEventsScreenProvider);
        },
        onSignOut: () => _signOut(context, ref),
      ),
      appBar: AppBar(
        backgroundColor: EMColors.background,
        elevation: 0,
        title: const Text(
          'My Events',
          style: TextStyle(
            color: EMColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: EMColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: EMColors.primary,
        child: const Icon(Icons.add, color: Colors.black87),
        onPressed: () async {
          await context.push(AppRoutes.addEvent);
          ref.invalidate(_emEventsScreenProvider);
        },
      ),
      body: RefreshIndicator(
        color: EMColors.primary,
        backgroundColor: EMColors.surfaceElevated,
        onRefresh: () async {
          ref.invalidate(_emEventsScreenProvider);
        },
        child: eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  StaffGlassCard(
                    surfaceColor: EMColors.surface,
                    child: const StaffEmptyState(
                      icon: Icons.event_busy_outlined,
                      message: 'No events created yet.\nTap + to create your first event!',
                      iconColor: EMColors.primary,
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                ],
              );
            }
            
            // Sort events by start date descending
            final sortedEvents = List<EventModel>.from(events)
              ..sort((a, b) => b.startTs.compareTo(a.startTs));

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: sortedEvents.length,
              itemBuilder: (context, index) {
                final event = sortedEvents[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EmEventCard(
                    event: event,
                    onDelete: () => _confirmDelete(context, ref, event),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (100 + index * 50).ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: EMColors.primary),
          ),
          error: (e, s) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: EMColors.error, size: 48),
                const SizedBox(height: 16),
                Text('Error loading events: $e',
                    style: const TextStyle(color: EMColors.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(_emEventsScreenProvider),
                  style: ElevatedButton.styleFrom(backgroundColor: EMColors.primary),
                  child: const Text('Retry', style: TextStyle(color: Colors.black87)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
