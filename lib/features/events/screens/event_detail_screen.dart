import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/file_save_helper.dart'
    if (dart.library.html) '../../../core/utils/file_save_helper_web.dart'
    if (dart.library.io) '../../../core/utils/file_save_helper_native.dart';
import '../../../core/utils/url_launcher_helper.dart'
    if (dart.library.html) '../../../core/utils/url_launcher_helper_web.dart'
    if (dart.library.io) '../../../core/utils/url_launcher_helper_native.dart';
import '../../../core/widgets/showsnap_toast.dart';
import '../../../core/widgets/tappable_scale.dart';


// ─── Provider ─────────────────────────────────────────────────────────────────

final _eventDetailProvider =
    FutureProvider.family<EventModel?, String>((ref, eventId) async {
  final events = await ref.watch(databaseServiceProvider).getAllEvents();
  return events.cast<EventModel?>().firstWhere(
    (e) => e?.eventId == eventId,
    orElse: () => null,
  );
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  // Map: tier index → quantity selected
  final Map<int, int> _tierQuantities = {};
  bool _booking = false;

  int get _totalTickets =>
      _tierQuantities.values.fold(0, (s, q) => s + q);

  int _totalPrice(EventModel event) {
    int sum = 0;
    for (final entry in _tierQuantities.entries) {
      if (entry.key < event.ticketTiers.length) {
        sum += event.ticketTiers[entry.key].price * entry.value;
      }
    }
    return sum;
  }

  void _adjustQuantity(int tierIndex, int delta, int maxAvailable) {
    final current = _tierQuantities[tierIndex] ?? 0;
    final newVal = (current + delta).clamp(0, maxAvailable.clamp(0, 6));
    setState(() {
      if (newVal == 0) {
        _tierQuantities.remove(tierIndex);
      } else {
        _tierQuantities[tierIndex] = newVal;
      }
    });
    if (delta > 0) HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(_eventDetailProvider(widget.eventId));
    return eventAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (event) {
        if (event == null) {
          return const Scaffold(
              body: Center(child: Text('Event not found')));
        }
        return _buildContent(event);
      },
    );
  }

  Widget _buildContent(EventModel event) {
    final total = _totalPrice(event);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(event.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4)
                      ])),
              background: event.posterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: event.posterUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: ShowSnapColors.primary),
                    )
                  : Container(color: ShowSnapColors.primary),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date/time/venue
                  _InfoCard(event: event),

                  const SizedBox(height: 16),

                  // Description
                  if (event.description.isNotEmpty) ...[
                    Text('About',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(event.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                color: ShowSnapColors.grey600,
                                height: 1.6)),
                    const SizedBox(height: 20),
                  ],

                  // Ticket tiers
                  Text('Select Tickets',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  if (event.ticketTiers.isEmpty)
                    const Text('No ticket tiers available',
                        style: TextStyle(color: ShowSnapColors.grey600))
                  else
                    ...event.ticketTiers.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final tier = entry.value;
                      final qty = _tierQuantities[idx] ?? 0;
                      return _TierRow(
                        tier: tier,
                        quantity: qty,
                        onAdd: tier.availableSeats > 0
                            ? () => _adjustQuantity(
                                idx, 1, tier.availableSeats)
                            : null,
                        onRemove: qty > 0
                            ? () => _adjustQuantity(idx, -1,
                                tier.availableSeats)
                            : null,
                      )
                          .animate()
                          .fadeIn(
                              duration: ShowSnapDuration.normal,
                              delay: Duration(milliseconds: 50 * idx))
                          .slideX(
                              begin: 0.05,
                              end: 0,
                              delay: Duration(milliseconds: 50 * idx));
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _totalTickets > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TappableScale(
                  onTap: _booking ? null : () => _handleBook(event),
                  child: Container(
                    height: 56,
                    decoration: ShowSnapTheme.primaryButtonDecoration,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md),
                        onTap: _booking ? null : () => _handleBook(event),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_booking)
                              const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                            else ...[
                              const Icon(Icons.local_activity_outlined,
                                  color: Colors.black87),
                              const SizedBox(width: 8),
                              Text(
                                'Book $_totalTickets Ticket${_totalTickets > 1 ? 's' : ''} — ₹$total',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.local_activity_outlined),
                  label: const Text('Select Tickets Above'),
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md)),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _handleBook(EventModel event) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      ShowSnapToast.show(context, message: 'Please log in first', type: ToastType.error);
      return;
    }

    final ticketBoundaryKey = GlobalKey();
    final formKey = GlobalKey<FormState>();

    final initialPhone = ref.read(currentUserModelProvider).valueOrNull?.phone ?? '';
    // Strip prefix like +91 if present
    final cleanPhone = initialPhone.replaceAll(RegExp(r'^\+91'), '').replaceAll(RegExp(r'\D'), '');
    final phoneController = TextEditingController(text: cleanPhone);

    final bookingId = 'evt_bk_${DateTime.now().millisecondsSinceEpoch}';
    final dt = DateTime.fromMillisecondsSinceEpoch(event.startTs);
    final formattedDateTime = DateFormat('EEE, d MMM yyyy • h:mm a').format(dt);

    int subtotal = _totalPrice(event);
    final seatInfos = <BookedSeatInfo>[];
    final tierDetails = <String>[];

    _tierQuantities.forEach((tierIdx, qty) {
      if (qty > 0 && tierIdx < event.ticketTiers.length) {
        final tier = event.ticketTiers[tierIdx];
        final price = tier.price;
        tierDetails.add('${tier.name} x$qty');
        
        for (var idx = 0; idx < qty; idx++) {
          seatInfos.add(BookedSeatInfo(
            seatId: '${tier.name}_$idx',
            row: tier.name,
            number: idx + 1,
            category: tier.name,
            price: price,
          ));
        }
      }
    });

    String bookingState = 'input'; // 'input', 'processing', 'success', 'error'
    String statusMessage = '';
    String errorMessage = '';
    String cloudinaryUrl = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (bookingState == 'input') {
            return AlertDialog(
              title: const Text('Confirm Your Booking'),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'WhatsApp Number for Ticket Delivery',
                            prefixText: '+91 ',
                            hintText: '10-digit number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a phone number';
                            }
                            final clean = value.replaceAll(RegExp(r'\D'), '');
                            if (clean.length != 10) {
                              return 'Please enter a valid 10-digit number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Verify event details below. Confirming will save your booking, download the ticket PNG, and open the WhatsApp send dialog.',
                          style: TextStyle(fontSize: 12, color: ShowSnapColors.grey600),
                        ),
                        const SizedBox(height: 16),
                        RepaintBoundary(
                          key: ticketBoundaryKey,
                          child: _EventTicketCard(
                            bookingId: bookingId,
                            eventName: event.name,
                            venueName: event.venueName,
                            city: event.city,
                            formattedDateTime: formattedDateTime,
                            ticketDetails: tierDetails,
                            totalAmount: subtotal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    setDialogState(() {
                      bookingState = 'processing';
                      statusMessage = 'Saving booking to database...';
                    });

                    try {
                      final booking = BookingModel(
                        bookingId: bookingId,
                        uid: uid,
                        showId: event.eventId,
                        movieId: event.eventId,
                        movieTitle: event.name,
                        theaterId: event.venueId,
                        theaterName: event.venueName,
                        screenId: 'Event',
                        screenName: event.category,
                        showStartTs: event.startTs,
                        seats: seatInfos,
                        subtotal: subtotal,
                        convenienceFee: 0,
                        totalAmount: subtotal,
                        status: BookingStatus.confirmed,
                        createdAt: DateTime.now().millisecondsSinceEpoch,
                      );

                      // Save and update seat counts
                      await ref
                          .read(databaseServiceProvider)
                          .bookEventTickets(booking, event, _tierQuantities);

                      setDialogState(() {
                        statusMessage = 'Generating ticket PNG...';
                      });

                      await Future.delayed(const Duration(milliseconds: 250));
                      final boundary = ticketBoundaryKey.currentContext
                          ?.findRenderObject() as RenderRepaintBoundary?;
                      if (boundary == null) {
                        throw Exception('Ticket render boundary not found');
                      }
                      final image = await boundary.toImage(pixelRatio: 3.0);
                      final byteData =
                          await image.toByteData(format: ui.ImageByteFormat.png);
                      if (byteData == null) {
                        throw Exception('Failed to convert image to bytes');
                      }
                      final pngBytes = byteData.buffer.asUint8List();

                      setDialogState(() {
                        statusMessage = 'Downloading ticket file...';
                      });

                      await saveAndDownloadPng(pngBytes, 'event_ticket_$bookingId.png');

                      setDialogState(() {
                        statusMessage = 'Uploading ticket to cloud...';
                      });

                      final url = await ref
                          .read(cloudinaryServiceProvider)
                          .uploadImageBytes(
                            pngBytes,
                            'event_ticket_$bookingId.png',
                            AppConstants.cloudinaryEtickets,
                          );

                      setDialogState(() {
                        bookingState = 'success';
                        cloudinaryUrl = url;
                      });

                      // Automatic redirection to WhatsApp
                      final digits = phoneController.text.replaceAll(RegExp(r'\D'), '');
                      final phoneWithCountryCode = '91$digits';
                      final message = 'Hi! Here is your ticket for *${event.name}* at *${event.venueName}*:\n\n'
                          'Tickets: *${tierDetails.join(', ')}*\n'
                          'Total: *₹$subtotal*\n\n'
                          'View E-Ticket: $url';
                      final whatsappUrl = 'https://wa.me/$phoneWithCountryCode?text=${Uri.encodeComponent(message)}';
                      
                      await launchBrowserUrl(whatsappUrl);
                    } catch (e) {
                      setDialogState(() {
                        bookingState = 'error';
                        errorMessage = e.toString();
                      });
                    }
                  },
                  child: const Text('CONFIRM & DOWNLOAD'),
                ),
              ],
            );
          }

          if (bookingState == 'processing') {
            return AlertDialog(
              title: const Text('Processing Booking'),
              content: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: ShowSnapColors.onBackground,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (bookingState == 'success') {
            final digits = phoneController.text.replaceAll(RegExp(r'\D'), '');
            final phoneWithCountryCode = '91$digits';
            final message = 'Hi! Here is your ticket for *${event.name}* at *${event.venueName}*:\n\n'
                'Tickets: *${tierDetails.join(', ')}*\n'
                'Total: *₹$subtotal*\n\n'
                'View E-Ticket: $cloudinaryUrl';
            final whatsappUrl = 'https://wa.me/$phoneWithCountryCode?text=${Uri.encodeComponent(message)}';

            return AlertDialog(
              title: const Text(
                'Booking Confirmed!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: ShowSnapColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 40,
                      ),
                    ).animate().scale(
                          duration: 400.ms,
                          curve: Curves.elasticOut,
                        ),
                    const SizedBox(height: 24),
                    const Text(
                      'Ticket has been generated and downloaded successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: ShowSnapColors.onBackground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Phone Number: +91 $digits',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ShowSnapColors.grey600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Click below to open WhatsApp and send the ticket link, or view it directly in your bookings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: ShowSnapColors.grey600),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    setState(() {
                      _tierQuantities.clear();
                    });
                    // Navigate to the ticket page
                    context.go('/ticket/$bookingId');
                  },
                  child: const Text('VIEW TICKET'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShowSnapColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text('SEND TO WHATSAPP'),
                  onPressed: () async {
                    await launchBrowserUrl(whatsappUrl);
                  },
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Booking Failed'),
            content: Text(
              'An error occurred:\n$errorMessage',
              style: const TextStyle(color: Colors.red),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('CLOSE'),
              ),
              ElevatedButton(
                onPressed: () {
                  setDialogState(() {
                    bookingState = 'input';
                  });
                },
                child: const Text('RETRY'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EventTicketCard extends StatelessWidget {
  final String bookingId;
  final String eventName;
  final String venueName;
  final String city;
  final String formattedDateTime;
  final List<String> ticketDetails;
  final int totalAmount;

  const _EventTicketCard({
    required this.bookingId,
    required this.eventName,
    required this.venueName,
    required this.city,
    required this.formattedDateTime,
    required this.ticketDetails,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShowSnapColors.grey300),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ShowSnapColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'EVENT TICKET',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              Text(
                '#${bookingId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ShowSnapColors.grey600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(eventName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: ShowSnapColors.grey600),
              const SizedBox(width: 4),
              Expanded(
                child: Text('$venueName, $city',
                    style: const TextStyle(fontSize: 11, color: ShowSnapColors.grey600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: ShowSnapColors.grey600),
              const SizedBox(width: 4),
              Text(formattedDateTime,
                  style: const TextStyle(fontSize: 11, color: ShowSnapColors.grey600)),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          const Text('TICKETS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ShowSnapColors.grey600)),
          const SizedBox(height: 4),
          ...ticketDetails.map((detail) => Text(detail,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87))),
          const Divider(height: 24, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL AMOUNT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ShowSnapColors.grey600)),
                  Text('₹$totalAmount',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ShowSnapColors.primary)),
                ],
              ),
              QrImageView(
                data: bookingId,
                version: QrVersions.auto,
                size: 70,
                gapless: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final EventModel event;
  const _InfoCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        children: [
          _Row(Icons.calendar_today_outlined,
              event.startTs.epochToDateTimeLabel),
          if (event.venueName.isNotEmpty)
            _Row(Icons.location_on_outlined, event.venueName),
          if (event.organizer.isNotEmpty)
            _Row(Icons.business_outlined,
                'Organized by ${event.organizer}'),
          _Row(Icons.category_outlined,
              event.category[0].toUpperCase() +
                  event.category.substring(1)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Row(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: ShowSnapColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ─── Tier Row ─────────────────────────────────────────────────────────────────

class _TierRow extends StatefulWidget {
  final TicketTier tier;
  final int quantity;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  const _TierRow({
    required this.tier,
    required this.quantity,
    this.onAdd,
    this.onRemove,
  });

  @override
  State<_TierRow> createState() => _TierRowState();
}

class _TierRowState extends State<_TierRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _onAdd() {
    widget.onAdd?.call();
    _bounceCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isSoldOut = widget.tier.availableSeats <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
        border: widget.quantity > 0
            ? Border.all(color: ShowSnapColors.primary)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.tier.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  isSoldOut
                      ? 'Sold Out'
                      : '${widget.tier.availableSeats} available',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSoldOut
                        ? ShowSnapColors.error
                        : ShowSnapColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          Text('₹${widget.tier.price}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: ShowSnapColors.primary)),
          const SizedBox(width: 12),
          // Stepper
          if (isSoldOut)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ShowSnapColors.grey300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Sold Out',
                  style: TextStyle(
                      fontSize: 11, color: ShowSnapColors.grey600)),
            )
          else
            Row(
              children: [
                _StepBtn(
                  icon: Icons.remove,
                  onTap: widget.onRemove,
                  enabled: widget.quantity > 0,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.3)
                        .chain(CurveTween(curve: Curves.elasticOut))
                        .animate(_bounceCtrl),
                    child: Text(
                      '${widget.quantity}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                _StepBtn(
                  icon: Icons.add,
                  onTap: _onAdd,
                  enabled: widget.onAdd != null &&
                      widget.quantity < 6,
                  isPrimary: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isPrimary;
  const _StepBtn({
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: ShowSnapDuration.fast,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? (isPrimary
                  ? ShowSnapColors.primary
                  : ShowSnapColors.grey100)
              : ShowSnapColors.grey300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? (isPrimary ? Colors.black87 : Colors.black87)
              : ShowSnapColors.grey600,
        ),
      ),
    );
  }
}
