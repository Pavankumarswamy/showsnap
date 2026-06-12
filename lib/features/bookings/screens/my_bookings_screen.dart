import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';
import '../../../core/widgets/tappable_scale.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _userBookingsProvider =
    StreamProvider.autoDispose<List<BookingModel>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(databaseServiceProvider).streamUserBookings(uid);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(_userBookingsProvider);
    return Scaffold(
      backgroundColor: ShowSnapColors.grey100,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(),
        title: const Text('My Bookings',
            style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: ShowSnapColors.primary,
          unselectedLabelColor: ShowSnapColors.grey600,
          indicatorColor: ShowSnapColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: bookingsAsync.when(
        loading: () => _LoadingShimmer(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bookings) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final upcoming = bookings
              .where((b) =>
                  b.showStartTs > now &&
                  b.status != BookingStatus.cancelled)
              .toList()
            ..sort((a, b) => a.showStartTs.compareTo(b.showStartTs));
          final past = bookings
              .where((b) =>
                  b.showStartTs <= now ||
                  b.status == BookingStatus.cancelled)
              .toList()
            ..sort(
                (a, b) => b.showStartTs.compareTo(a.showStartTs));

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _BookingList(
                bookings: upcoming,
                emptyMsg: 'No upcoming bookings',
                emptyIcon: Icons.event_available_outlined,
                isUpcoming: true,
              ),
              _BookingList(
                bookings: past,
                emptyMsg: 'No past bookings yet',
                emptyIcon: Icons.history_rounded,
                isUpcoming: false,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Booking List ─────────────────────────────────────────────────────────────

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String emptyMsg;
  final IconData emptyIcon;
  final bool isUpcoming;

  const _BookingList({
    required this.bookings,
    required this.emptyMsg,
    required this.emptyIcon,
    required this.isUpcoming,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 80, color: ShowSnapColors.grey300),
            const SizedBox(height: 16),
            Text(emptyMsg,
                style: const TextStyle(
                    color: ShowSnapColors.grey600, fontSize: 16)),
            const SizedBox(height: 12),
            if (isUpcoming)
              ElevatedButton.icon(
                icon: const Icon(Icons.movie_outlined),
                label: const Text('Browse Movies'),
                onPressed: () => context.go('/explore'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (_, i) => _BookingCard(
        booking: bookings[i],
        isUpcoming: isUpcoming,
      )
          .animate()
          .fadeIn(
              duration: ShowSnapDuration.normal,
              delay: Duration(milliseconds: 50 * i))
          .slideY(
              begin: 0.04,
              end: 0,
              delay: Duration(milliseconds: 50 * i)),
    );
  }
}

// ─── Booking Card ─────────────────────────────────────────────────────────────

class _BookingCard extends ConsumerStatefulWidget {
  final BookingModel booking;
  final bool isUpcoming;

  const _BookingCard({required this.booking, required this.isUpcoming});

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _cancelling = false;

  // Countdown ticker for upcoming shows
  Timer? _ticker;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.isUpcoming) {
      _updateCountdown();
      _ticker = Timer.periodic(
          const Duration(seconds: 1), (_) => _updateCountdown());
    }
  }

  void _updateCountdown() {
    final showTime =
        DateTime.fromMillisecondsSinceEpoch(widget.booking.showStartTs);
    final diff = showTime.difference(DateTime.now());
    if (mounted) setState(() => _timeLeft = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _canCancel {
    final twoHoursFromNow =
        DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch;
    return widget.isUpcoming &&
        widget.booking.showStartTs > twoHoursFromNow &&
        widget.booking.status == BookingStatus.confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: ShowSnapColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
        border: booking.status == BookingStatus.cancelled
            ? Border.all(color: ShowSnapColors.error.withOpacity(0.4))
            : null,
      ),
      child: Column(
        children: [
          // Top gradient bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: booking.status == BookingStatus.cancelled
                  ? const LinearGradient(
                      colors: [Colors.red, Colors.redAccent])
                  : ShowSnapTheme.appBarGradient,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(ShowSnapRadius.md)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        booking.movieTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusChip(booking.status),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: ShowSnapColors.grey600),
                    const SizedBox(width: 4),
                    Text(
                      booking.showStartTs.epochToDateTimeLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          color: ShowSnapColors.grey600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.theaters_rounded,
                        size: 13, color: ShowSnapColors.grey600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${booking.theaterName} • ${booking.screenName}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: ShowSnapColors.grey600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.airline_seat_recline_extra,
                        size: 13, color: ShowSnapColors.grey600),
                    const SizedBox(width: 4),
                    Text(
                      booking.seats.map((s) => s.label).join(', '),
                      style: const TextStyle(
                          fontSize: 12, color: ShowSnapColors.grey600),
                    ),
                    const Spacer(),
                    Text(
                      '₹${booking.totalAmount}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ShowSnapColors.primary,
                          fontSize: 14),
                    ),
                  ],
                ),

                // Countdown for upcoming
                if (widget.isUpcoming &&
                    booking.status == BookingStatus.confirmed &&
                    _timeLeft > Duration.zero) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ShowSnapColors.primaryLighter,
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 13, color: ShowSnapColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          _countdownLabel,
                          style: const TextStyle(
                              fontSize: 11,
                              color: ShowSnapColors.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: TappableScale(
                        onTap: () =>
                            context.push('/ticket/${booking.bookingId}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: ShowSnapColors.primary),
                            borderRadius:
                                BorderRadius.circular(ShowSnapRadius.sm),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_rounded,
                                  size: 16,
                                  color: ShowSnapColors.primary),
                              SizedBox(width: 6),
                              Text('View Ticket',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: ShowSnapColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_canCancel) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TappableScale(
                          onTap: () => _showCancelDialog(context),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: ShowSnapColors.error),
                              borderRadius:
                                  BorderRadius.circular(ShowSnapRadius.sm),
                            ),
                            child: _cancelling
                                ? const Center(
                                    child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)))
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cancel_outlined,
                                          size: 16,
                                          color: ShowSnapColors.error),
                                      SizedBox(width: 6),
                                      Text('Cancel',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: ShowSnapColors.error)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                    // Rate button for past confirmed/redeemed bookings
                    if (!widget.isUpcoming &&
                        (booking.status == BookingStatus.redeemed ||
                            booking.status == BookingStatus.confirmed)) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TappableScale(
                          onTap: () =>
                              _showRatingSheet(context, booking.movieId),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: ShowSnapColors.primaryLighter,
                              borderRadius:
                                  BorderRadius.circular(ShowSnapRadius.sm),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 16,
                                    color: ShowSnapColors.primary),
                                SizedBox(width: 6),
                                Text('Rate',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _countdownLabel {
    if (_timeLeft.inDays > 0) {
      return '${_timeLeft.inDays}d ${_timeLeft.inHours.remainder(24)}h';
    }
    if (_timeLeft.inHours > 0) {
      return '${_timeLeft.inHours}h ${_timeLeft.inMinutes.remainder(60)}m';
    }
    return '${_timeLeft.inMinutes}m ${_timeLeft.inSeconds.remainder(60)}s';
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
        title: const Text('Cancel Booking'),
        content: const Text(
            'Are you sure? Refunds are processed within 5–7 business days. Convenience fee is non-refundable.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ShowSnapColors.error),
            onPressed: () async {
              Navigator.pop(context);
              await _cancelBooking();
            },
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking() async {
    setState(() => _cancelling = true);
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateBookingStatus(
          widget.booking.bookingId, BookingStatus.cancelled);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ShowSnapToast.show(context, message: 'Booking cancelled');
      }
    } catch (e) {
      if (mounted) {
        ShowSnapToast.show(context, message: 'Cancel failed: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _showRatingSheet(BuildContext context, String movieId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(ShowSnapRadius.lg)),
      ),
      builder: (_) => _RatingSheet(
        movieId: movieId,
        movieTitle: widget.booking.movieTitle,
      ),
    );
  }
}

// ─── Rating Sheet ─────────────────────────────────────────────────────────────

class _RatingSheet extends ConsumerStatefulWidget {
  final String movieId;
  final String movieTitle;
  const _RatingSheet(
      {required this.movieId, required this.movieTitle});

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  double _rating = 0;
  bool _submitting = false;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          left: 24,
          right: 24,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: ShowSnapColors.grey300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(widget.movieTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          const Text('How would you rate this movie?',
              style: TextStyle(color: ShowSnapColors.grey600)),
          const SizedBox(height: 20),
          if (_done)
            Column(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: ShowSnapColors.secondary, size: 48),
                const SizedBox(height: 8),
                const Text('Thanks for your rating!',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ShowSnapColors.secondary)),
                const SizedBox(height: 16),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done')),
              ],
            )
          else ...[
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              direction: Axis.horizontal,
              itemCount: 5,
              itemSize: 44,
              itemBuilder: (_, __) => const Icon(
                Icons.star_rounded,
                color: ShowSnapColors.primary,
              ),
              onRatingUpdate: (r) => setState(() => _rating = r),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: ShowSnapTheme.primaryButtonDecoration,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md)),
                    disabledBackgroundColor: ShowSnapColors.grey300,
                  ),
                  onPressed: _rating == 0 || _submitting
                      ? null
                      : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                      : const Text('Submit Rating',
                          style:
                              TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) return;
      await ref.read(databaseServiceProvider).submitMovieRating(
          widget.movieId, uid, _rating * 2);
      setState(() {
        _submitting = false;
        _done = true;
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ShowSnapToast.show(context, message: 'Submit failed: $e', type: ToastType.error);
      }
    }
  }
}

// ─── Status Chip ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final BookingStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case BookingStatus.confirmed:
        color = ShowSnapColors.secondary;
        label = 'Confirmed';
        break;
      case BookingStatus.cancelled:
        color = ShowSnapColors.error;
        label = 'Cancelled';
        break;
      case BookingStatus.redeemed:
        color = ShowSnapColors.grey600;
        label = 'Redeemed';
        break;
      default:
        color = ShowSnapColors.grey600;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Loading Shimmer ──────────────────────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Shimmer.fromColors(
          baseColor: ShowSnapColors.grey300,
          highlightColor: ShowSnapColors.grey100,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: ShowSnapColors.grey300,
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            ),
          ),
        ),
      ),
    );
  }
}
