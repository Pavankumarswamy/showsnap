import 'dart:io';
import 'dart:ui' as ui;
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeline_tile/timeline_tile.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';
import '../../../core/widgets/tappable_scale.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _bookingProvider =
    FutureProvider.family<BookingModel?, String>((ref, bookingId) {
  return ref.watch(databaseServiceProvider).getBooking(bookingId);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class TicketScreen extends ConsumerWidget {
  final String bookingId;
  const TicketScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(_bookingProvider(bookingId));
    return Scaffold(
      backgroundColor: ShowSnapColors.grey100,
      appBar: AppBar(
        title: const Text('Your Ticket'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Booking not found'));
          }
          return _TicketContent(booking: booking);
        },
      ),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _TicketContent extends StatefulWidget {
  final BookingModel booking;
  const _TicketContent({required this.booking});

  @override
  State<_TicketContent> createState() => _TicketContentState();
}

class _TicketContentState extends State<_TicketContent> {
  final _repaintKey = GlobalKey();
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),

            // Ticket card
            RepaintBoundary(
              key: _repaintKey,
              child: _TicketCard(booking: widget.booking),
            )
                .animate()
                .slideY(
                  begin: 1.0,
                  end: 0,
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.download_outlined,
                    label: 'Download',
                    color: ShowSnapColors.primary,
                    onTap: () => _saveTicket(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    color: ShowSnapColors.secondary,
                    onTap: () => _shareTicket(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendar',
                    color: Colors.deepPurple,
                    onTap: () => _addToCalendar(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Journey timeline
            _JourneyTimeline(booking: widget.booking),

            const SizedBox(height: 32),
          ],
        ),
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            colors: const [
              ShowSnapColors.primary,
              ShowSnapColors.secondary,
              Colors.white,
              ShowSnapColors.primaryLight,
            ],
            numberOfParticles: 40,
            gravity: 0.1,
          ),
        ),
      ],
    );
  }

  Future<void> _addToCalendar(BuildContext context) async {
    try {
      final start =
          DateTime.fromMillisecondsSinceEpoch(widget.booking.showStartTs);
      final end = start.add(const Duration(hours: 3));
      final event = Event(
        title: widget.booking.movieTitle,
        description:
            'ShowSnap Booking — ${widget.booking.theaterName}',
        location: widget.booking.theaterName,
        startDate: start,
        endDate: end,
        iosParams: const IOSParams(reminder: Duration(hours: 1)),
        androidParams: const AndroidParams(emailInvites: []),
      );
      await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      if (context.mounted) {
        ShowSnapToast.show(context,
            message: 'Could not add to calendar', type: ToastType.error);
      }
    }
  }

  Future<void> _saveTicket(BuildContext context) async {
    try {
      final bytes = await _captureImage();
      final dir = await getApplicationDocumentsDirectory();
      final file =
          File('${dir.path}/ticket_${widget.booking.bookingId}.png');
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        ShowSnapToast.show(context, message: 'Ticket saved!');
      }
    } catch (e) {
      if (context.mounted) {
        ShowSnapToast.show(context, message: 'Failed to save: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _shareTicket(BuildContext context) async {
    try {
      final bytes = await _captureImage();
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/ticket_${widget.booking.bookingId}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            '${widget.booking.movieTitle} — ${widget.booking.showStartTs.epochToDateTimeLabel}',
      );
    } catch (e) {
      if (context.mounted) {
        ShowSnapToast.show(context, message: 'Failed to share: $e', type: ToastType.error);
      }
    }
  }

  Future<List<int>> _captureImage() async {
    final boundary = _repaintKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asInt8List();
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TappableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          boxShadow: ShowSnapShadow.card,
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─── Journey Timeline ─────────────────────────────────────────────────────────

class _JourneyTimeline extends StatelessWidget {
  final BookingModel booking;
  const _JourneyTimeline({required this.booking});

  @override
  Widget build(BuildContext context) {
    final showTime =
        DateTime.fromMillisecondsSinceEpoch(booking.showStartTs);
    final arriveTime = showTime.subtract(const Duration(minutes: 30));
    final endTime = showTime.add(const Duration(hours: 3));

    final steps = [
      _JourneyStep(
        icon: Icons.confirmation_number_rounded,
        title: 'Booking Confirmed',
        subtitle: 'Booking ID: ${booking.bookingId.substring(0, 8)}...',
        time: null,
        isDone: true,
      ),
      _JourneyStep(
        icon: Icons.directions_walk_rounded,
        title: 'Arrive at Theater',
        subtitle: booking.theaterName,
        time: arriveTime,
        isDone: false,
      ),
      _JourneyStep(
        icon: Icons.theaters_rounded,
        title: 'Show Starts',
        subtitle:
            '${booking.screenName} • ${booking.seats.map((s) => s.label).join(', ')}',
        time: showTime,
        isDone: false,
      ),
      _JourneyStep(
        icon: Icons.star_rounded,
        title: 'Show Ends — Rate It!',
        subtitle: 'Tell us how it was',
        time: endTime,
        isDone: false,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Journey',
            style:
                TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((e) {
          final step = e.value;
          final isFirst = e.key == 0;
          final isLast = e.key == steps.length - 1;
          return TimelineTile(
            isFirst: isFirst,
            isLast: isLast,
            alignment: TimelineAlign.manual,
            lineXY: 0.1,
            indicatorStyle: IndicatorStyle(
              width: 36,
              height: 36,
              indicator: Container(
                decoration: BoxDecoration(
                  color: step.isDone
                      ? ShowSnapColors.secondary
                      : ShowSnapColors.primaryLighter,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: step.isDone
                        ? ShowSnapColors.secondary
                        : ShowSnapColors.primary,
                    width: 2,
                  ),
                ),
                child: Icon(
                  step.icon,
                  size: 16,
                  color: step.isDone
                      ? Colors.white
                      : ShowSnapColors.primary,
                ),
              ),
            ),
            beforeLineStyle: const LineStyle(
              color: ShowSnapColors.grey300,
              thickness: 2,
            ),
            endChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: step.isDone
                              ? ShowSnapColors.secondary
                              : Colors.black87,
                        ),
                      ),
                      if (step.time != null)
                        Text(
                          _timeLabel(step.time!),
                          style: const TextStyle(
                              fontSize: 11,
                              color: ShowSnapColors.grey600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: ShowSnapColors.grey600),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _timeLabel(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $ampm';
  }
}

class _JourneyStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime? time;
  final bool isDone;
  const _JourneyStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.time,
    required this.isDone,
  });
}

// ─── Ticket Card ──────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final BookingModel booking;
  const _TicketCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final isRedeemed = booking.status == BookingStatus.redeemed;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            boxShadow: ShowSnapShadow.elevated,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: ShowSnapTheme.appBarGradient,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(ShowSnapRadius.md)),
                ),
                child: Column(
                  children: [
                    Text(
                      booking.movieTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.showStartTs.epochToDateTimeLabel,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.xs),
                      ),
                      child: QrImageView(
                        data: booking.bookingId,
                        version: QrVersions.auto,
                        size: 130,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              _TicketDivider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _InfoChip(
                                'Theater', booking.theaterName)),
                        const SizedBox(width: 12),
                        Expanded(
                            child:
                                _InfoChip('Screen', booking.screenName)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoChip(
                            'Seats',
                            booking.seats.map((s) => s.label).join(', '),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _InfoChip(
                                'Amount', '₹${booking.totalAmount}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Booking ID:',
                            style: TextStyle(
                                fontSize: 11,
                                color: ShowSnapColors.grey600)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            booking.bookingId,
                            style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: ShowSnapColors.grey600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Opacity(
                        opacity: 0.2,
                        child: Text(
                          'ShowSnap',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ShowSnapColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Redeemed overlay
        if (isRedeemed)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius:
                    BorderRadius.circular(ShowSnapRadius.md),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: -0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: ShowSnapColors.secondary, width: 3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'REDEEMED',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: ShowSnapColors.secondary,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TicketDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(
              30,
              (i) => Expanded(
                child: Container(
                  height: 1.5,
                  color: i.isEven
                      ? ShowSnapColors.grey300
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        ),
        Positioned(
            left: -12,
            top: -12,
            child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: ShowSnapColors.grey100,
                    shape: BoxShape.circle))),
        Positioned(
            right: -12,
            top: -12,
            child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: ShowSnapColors.grey100,
                    shape: BoxShape.circle))),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ShowSnapColors.grey100,
        borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: ShowSnapColors.grey600)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
