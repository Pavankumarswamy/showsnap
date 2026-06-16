import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _allBookingsProvider = FutureProvider<List<BookingModel>>((ref) {
  return ref.watch(databaseServiceProvider).getAllBookings();
});

final _bookingStatusFilterProvider =
    StateProvider<BookingStatus?>((ref) => null);
final _bookingSearchProvider = StateProvider<String>((ref) => '');

class TicketAuditScreen extends ConsumerWidget {
  const TicketAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_allBookingsProvider);
    final statusFilter = ref.watch(_bookingStatusFilterProvider);
    final search = ref.watch(_bookingSearchProvider);

    return PushDrawerLayout(
      backgroundColor: AdminColors.background,
      drawer: AdminDrawer(
        currentRoute: AppRoutes.ticketAudit,
        onNavigateTo: (route) => context.push(route),
        onSignOut: () {},
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
          'Ticket Audit',
          style: TextStyle(
              color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded,
                color: AdminColors.primary),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: StaffSearchBar(
              hint: 'Search by movie, theater, or booking ID',
              onChanged: (v) =>
                  ref.read(_bookingSearchProvider.notifier).state = v,
            ),
          ).animate().fadeIn(duration: 300.ms),
          // Status filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _StatusChip(null, statusFilter, ref),
                ...BookingStatus.values.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _StatusChip(s, statusFilter, ref),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 50.ms),
          // List
          Expanded(
            child: bookingsAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 6,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: StaffShimmerCard(
                    height: 110,
                    baseColor: AdminColors.surface,
                    highlightColor: AdminColors.surfaceElevated,
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: AdminColors.error)),
              ),
              data: (bookings) {
                var filtered = bookings;
                if (statusFilter != null) {
                  filtered = filtered
                      .where((b) => b.status == statusFilter)
                      .toList();
                }
                if (search.isNotEmpty) {
                  final q = search.toLowerCase();
                  filtered = filtered
                      .where((b) =>
                          b.movieTitle.toLowerCase().contains(q) ||
                          b.theaterName.toLowerCase().contains(q) ||
                          b.bookingId.toLowerCase().contains(q))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return StaffEmptyState(
                    icon: Icons.confirmation_number_outlined,
                    message: bookings.isEmpty
                        ? 'No bookings yet'
                        : 'No bookings match your filters',
                  );
                }

                return RefreshIndicator(
                  color: AdminColors.primary,
                  backgroundColor: AdminColors.surface,
                  onRefresh: () =>
                      ref.refresh(_allBookingsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _BookingAuditTile(booking: filtered[i])
                            .animate()
                            .fadeIn(
                                duration: 350.ms,
                                delay: (i % 8 * 40).ms)
                            .slideY(begin: 0.08, end: 0),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final bookings = await ref.read(_allBookingsProvider.future);
    final buffer = StringBuffer();
    buffer.writeln('BookingID,User,Movie,Theater,Date,Seats,Total,Status');
    for (final b in bookings) {
      buffer.writeln(
          '${b.bookingId},${b.uid},${b.movieTitle},${b.theaterName},${b.showStartTs.epochToDateLabel},${b.seats.map((s) => s.label).join(' ')},${b.totalAmount},${b.status.name}');
    }
    await Share.share(buffer.toString(), subject: 'ShowSnap Booking Ledger');
    if (context.mounted) {
      ShowSnapToast.success(context, 'CSV export ready');
    }
  }
}

class _StatusChip extends StatelessWidget {
  final BookingStatus? value;
  final BookingStatus? selected;
  final WidgetRef ref;

  const _StatusChip(this.value, this.selected, this.ref);

  Color _chipColor() {
    if (value == null) return AdminColors.primary;
    switch (value!) {
      case BookingStatus.confirmed:
        return AdminColors.primary;
      case BookingStatus.redeemed:
        return AdminColors.success;
      case BookingStatus.cancelled:
        return AdminColors.error;
      default:
        return AdminColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = value?.label ?? 'All';
    final isSelected = selected == value;
    final color = _chipColor();

    return GestureDetector(
      onTap: () =>
          ref.read(_bookingStatusFilterProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : AdminColors.surface,
          borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
          border: Border.all(
              color: isSelected ? color : AdminColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? Colors.black : AdminColors.textSecondary,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _BookingAuditTile extends ConsumerWidget {
  final BookingModel booking;
  const _BookingAuditTile({required this.booking});

  Color get _statusColor {
    switch (booking.status) {
      case BookingStatus.confirmed:
        return AdminColors.primary;
      case BookingStatus.redeemed:
        return AdminColors.success;
      case BookingStatus.cancelled:
        return AdminColors.error;
      default:
        return AdminColors.info;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.movieTitle,
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StaffBadge(
                label: booking.status.label,
                color: _statusColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${booking.theaterName} · ${booking.showStartTs.epochToDateTimeLabel}',
            style: const TextStyle(
                color: AdminColors.textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Seats: ${booking.seats.map((s) => s.label).join(', ')}',
            style: const TextStyle(
                color: AdminColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '₹${booking.totalAmount}',
                style: const TextStyle(
                    color: AdminColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              const Spacer(),
              if (booking.status == BookingStatus.confirmed)
                GestureDetector(
                  onTap: () async {
                    final ok = await StaffConfirmDialog.show(
                      context,
                      title: 'Mark as Redeemed',
                      message:
                          'Mark this booking as redeemed? This cannot be undone.',
                      confirmLabel: 'Redeem',
                    );
                    if (ok == true) {
                      await ref
                          .read(databaseServiceProvider)
                          .updateBookingStatus(
                              booking.bookingId,
                              BookingStatus.redeemed);
                      ref.invalidate(_allBookingsProvider);
                      if (context.mounted) {
                        ShowSnapToast.success(
                            context, 'Marked as redeemed');
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AdminColors.success.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.pill),
                      border: Border.all(
                          color: AdminColors.success.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Mark Redeemed',
                      style: TextStyle(
                          color: AdminColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
