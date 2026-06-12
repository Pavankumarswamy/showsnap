import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import 'package:flutter_animate/flutter_animate.dart';

final _allBookingsProvider = FutureProvider<List<BookingModel>>((ref) {
  return ref.watch(databaseServiceProvider).getAllBookings();
});

final _bookingStatusFilterProvider =
    StateProvider<BookingStatus?>((ref) => null);

class TicketAuditScreen extends ConsumerWidget {
  const TicketAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_allBookingsProvider);
    final statusFilter = ref.watch(_bookingStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Audit'),
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
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
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
          ).animate().fadeIn(duration: 300.ms),
          Expanded(
            child: bookingsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (bookings) {
                var filtered = bookings;
                if (statusFilter != null) {
                  filtered = filtered
                      .where((b) => b.status == statusFilter)
                      .toList();
                }
                if (filtered.isEmpty) {
                  return const Center(child: Text('No bookings found'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(_allBookingsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 4),
                    itemBuilder: (_, i) =>
                        _BookingAuditTile(booking: filtered[i])
                          .animate()
                          .fadeIn(duration: 350.ms, delay: (i % 6 * 50).ms)
                          .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
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
    buffer.writeln(
        'BookingID,User,Movie,Theater,Date,Seats,Total,Status');
    for (final b in bookings) {
      buffer.writeln(
          '${b.bookingId},${b.uid},${b.movieTitle},${b.theaterName},${b.showStartTs.epochToDateLabel},${b.seats.map((s) => s.label).join(' ')},${b.totalAmount},${b.status.name}');
    }
    await Share.share(buffer.toString(),
        subject: 'ShowSnap Booking Ledger');
  }
}

class _StatusChip extends StatelessWidget {
  final BookingStatus? value;
  final BookingStatus? selected;
  final WidgetRef ref;

  const _StatusChip(this.value, this.selected, this.ref);

  @override
  Widget build(BuildContext context) {
    final label = value?.label ?? 'All';
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () =>
          ref.read(_bookingStatusFilterProvider.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ShowSnapColors.primary : ShowSnapColors.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? ShowSnapColors.primary
                  : ShowSnapColors.grey300),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.black : ShowSnapColors.grey600,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13)),
      ),
    );
  }
}

class _BookingAuditTile extends ConsumerWidget {
  final BookingModel booking;
  const _BookingAuditTile({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(booking.movieTitle,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${booking.theaterName} • ${booking.showStartTs.epochToDateTimeLabel}'),
            Text('Seats: ${booking.seats.map((s) => s.label).join(', ')}'),
            Text('Amount: ₹${booking.totalAmount}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatusBadge(booking.status),
            if (booking.status == BookingStatus.confirmed) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () async {
                  await ref
                      .read(databaseServiceProvider)
                      .updateBookingStatus(
                          booking.bookingId, BookingStatus.redeemed);
                  ref.invalidate(_allBookingsProvider);
                  if (context.mounted) {
                    context.showSnackbar('Marked as redeemed');
                  }
                },
                child: const Text('Redeem',
                    style: TextStyle(
                        color: ShowSnapColors.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BookingStatus status;
  const _StatusBadge(this.status);

  Color get _color {
    switch (status) {
      case BookingStatus.confirmed:
        return ShowSnapColors.secondary;
      case BookingStatus.redeemed:
        return ShowSnapColors.grey600;
      case BookingStatus.cancelled:
        return ShowSnapColors.error;
      default:
        return ShowSnapColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: _color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}
