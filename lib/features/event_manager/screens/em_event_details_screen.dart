import 'dart:convert';
import 'dart:ui' as ui;
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/staff_theme.dart';
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

final _emEventDetailsProvider =
    FutureProvider.family<EventModel?, String>((ref, eventId) async {
  // Retrieve event including inactive ones
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  final db = ref.watch(databaseServiceProvider);
  final events = await db.getEventsForManager(uid);
  return events.cast<EventModel?>().firstWhere(
        (e) => e?.eventId == eventId,
        orElse: () => null,
      );
});

final _emEventBookingsProvider =
    FutureProvider.family<List<BookingModel>, String>((ref, eventId) async {
  final db = ref.watch(databaseServiceProvider);
  final allBookings = await db.getAllBookings();
  return allBookings.where((b) => b.showId == eventId).toList();
});

class EmEventDetailsScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EmEventDetailsScreen({super.key, required this.eventId});

  @override
  ConsumerState<EmEventDetailsScreen> createState() =>
      _EmEventDetailsScreenState();
}

class _EmEventDetailsScreenState extends ConsumerState<EmEventDetailsScreen> {
  final GlobalKey _ticketBoundaryKey = GlobalKey();

  String _searchQuery = '';
  String _filterStatus = 'All'; // 'All', 'Confirmed', 'Redeemed'

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  
  // Selected tier index -> quantity
  final Map<int, int> _bookingQuantities = {};

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showBookingDialog(EventModel event) {
    // Generate booking ID beforehand for QR rendering
    final bookingId = 'evt_bk_${DateTime.now().millisecondsSinceEpoch}';
    final dt = DateTime.fromMillisecondsSinceEpoch(event.startTs);
    final formattedDateTime = DateFormat('EEE, d MMM yyyy • h:mm a').format(dt);

    int subtotal = 0;
    final seatInfos = <BookedSeatInfo>[];
    final tierDetails = <String>[];

    _bookingQuantities.forEach((tierIdx, qty) {
      if (qty > 0 && tierIdx < event.ticketTiers.length) {
        final tier = event.ticketTiers[tierIdx];
        final price = tier.price;
        subtotal += price * qty;
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
              title: const Text('Confirm Box Office Booking'),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Customer WhatsApp Number',
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
                          'Verify event details below. Confirming will save the booking, download the ticket PNG, and open the WhatsApp send dialog.',
                          style: TextStyle(fontSize: 12, color: ShowSnapColors.grey600),
                        ),
                        const SizedBox(height: 16),
                        RepaintBoundary(
                          key: _ticketBoundaryKey,
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
                    if (!_formKey.currentState!.validate()) return;

                    setDialogState(() {
                      bookingState = 'processing';
                      statusMessage = 'Saving booking to database...';
                    });

                    try {
                      final booking = BookingModel(
                        bookingId: bookingId,
                        uid: 'offline_counter',
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
                          .bookEventTickets(booking, event, _bookingQuantities);

                      setDialogState(() {
                        statusMessage = 'Generating ticket PNG...';
                      });

                      await Future.delayed(const Duration(milliseconds: 250));
                      final boundary = _ticketBoundaryKey.currentContext
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
            final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
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
                      'Customer Phone: +91 $digits',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ShowSnapColors.grey600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Click below to open WhatsApp and send the ticket link to the customer.',
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
                      _bookingQuantities.clear();
                      ref.invalidate(_emEventDetailsProvider(widget.eventId));
                      ref.invalidate(_emEventBookingsProvider(widget.eventId));
                    });
                  },
                  child: const Text('CLOSE'),
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

  void _adjustQuantity(int idx, int delta, int maxAvailable) {
    final cur = _bookingQuantities[idx] ?? 0;
    final newVal = (cur + delta).clamp(0, maxAvailable.clamp(0, 6));
    setState(() {
      if (newVal == 0) {
        _bookingQuantities.remove(idx);
      } else {
        _bookingQuantities[idx] = newVal;
      }
    });
  }

  Future<void> _updateEventStatus(EventModel event, String newStatus) async {
    try {
      final db = ref.read(databaseServiceProvider);
      // Wait, db.saveEvent requires EventModel, we can just use db.saveEvent 
      final updatedEvent = EventModel(
        eventId: event.eventId,
        name: event.name,
        organizer: event.organizer,
        venueId: event.venueId,
        venueName: event.venueName,
        city: event.city,
        lat: event.lat,
        lng: event.lng,
        startTs: event.startTs,
        endTs: event.endTs,
        category: event.category,
        description: event.description,
        posterUrl: event.posterUrl,
        ticketTiers: event.ticketTiers,
        managerId: event.managerId,
        status: newStatus,
        isActive: newStatus == 'published',
      );
      await db.saveEvent(updatedEvent);
      if (mounted) {
        ShowSnapToast.success(context, 'Event status updated to $newStatus');
        ref.invalidate(_emEventDetailsProvider(event.eventId));
      }
    } catch (e) {
      if (mounted) ShowSnapToast.error(context, 'Failed to update status: $e');
    }
  }

  Future<void> _exportToCsv(List<BookingModel> bookings, EventModel event) async {
    try {
      final rows = <List<dynamic>>[];
      
      // Header row
      rows.add([
        'Booking ID',
        'Customer UID',
        'Status',
        'Total Amount',
        'Ticket Count',
        'Categories',
        'Booking Time'
      ]);

      // Data rows
      for (final b in bookings) {
        final ticketCount = b.seats.length;
        final categories = b.seats.map((s) => s.category).toSet().join(', ');
        final dt = DateTime.fromMillisecondsSinceEpoch(b.createdAt);
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(dt);

        rows.add([
          b.bookingId,
          b.uid,
          b.status.name,
          b.totalAmount,
          ticketCount,
          categories,
          dateStr,
        ]);
      }

      final String csvData = const ListToCsvConverter().convert(rows);
      final List<int> utf8Bytes = utf8.encode(csvData);
      final Uint8List bytes = Uint8List.fromList(utf8Bytes);

      final filename = 'attendee_manifest_${event.eventId}.csv';
      await saveAndDownloadFile(bytes, filename);

      if (mounted) {
        ShowSnapToast.success(context, 'CSV Exported Successfully');
      }
    } catch (e) {
      if (mounted) {
        ShowSnapToast.error(context, 'Failed to export CSV: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(_emEventDetailsProvider(widget.eventId));
    final bookingsAsync = ref.watch(_emEventBookingsProvider(widget.eventId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Event Details'),
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
            if (eventAsync.value != null) ...[
              IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                tooltip: 'Export Attendee Manifest CSV',
                onPressed: bookingsAsync.value == null 
                  ? null 
                  : () => _exportToCsv(bookingsAsync.value!, eventAsync.value!),
              ),
              if (eventAsync.value!.status == 'draft')
                TextButton(
                  onPressed: () => _updateEventStatus(eventAsync.value!, 'published'),
                  child: const Text('PUBLISH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              else if (eventAsync.value!.status == 'published')
                TextButton(
                  onPressed: () async {
                    final confirm = await StaffConfirmDialog.show(
                      context,
                      title: 'Close Event',
                      message: 'Are you sure you want to close this event? This action cannot be undone.',
                      confirmLabel: 'Yes, Close Event',
                      isDangerous: true,
                    );
                    if (confirm == true) {
                      _updateEventStatus(eventAsync.value!, 'closed');
                    }
                  },
                  child: const Text('CLOSE EVENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ]
          ],
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: 'Sales & Tiers'),
              Tab(text: 'Bookings / Attendees'),
            ],
          ),
        ),
        body: eventAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (event) {
            if (event == null) {
              return const Center(child: Text('Event not found'));
            }
            return TabBarView(
              children: [
                _buildSalesTab(event),
                _buildBookingsTab(bookingsAsync),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSalesTab(EventModel event) {
    final totalSelected = _bookingQuantities.values.fold(0, (s, q) => s + q);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        // Event info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text('${event.venueName} • ${event.city}',
                    style: const TextStyle(color: ShowSnapColors.grey600)),
                Text(event.startTs.epochToDateTimeLabel,
                    style: const TextStyle(color: ShowSnapColors.grey600)),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 16),
        // Ticket Tiers list
        const Text('Ticket Sales & Box Office Booking',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...event.ticketTiers.asMap().entries.map((entry) {
          final idx = entry.key;
          final tier = entry.value;
          final selectedQty = _bookingQuantities[idx] ?? 0;
          final sold = tier.totalSeats - tier.availableSeats;
          final revenue = sold * tier.price;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tier.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          'Price: ₹${tier.price}  •  Sold: $sold/$tier.totalSeats\nRevenue: ₹$revenue',
                          style: const TextStyle(fontSize: 11, color: ShowSnapColors.grey600),
                        ),
                      ],
                    ),
                  ),
                  if (tier.availableSeats > 0)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: selectedQty > 0 ? () => _adjustQuantity(idx, -1, tier.availableSeats) : null,
                        ),
                        Text('$selectedQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: ShowSnapColors.primary),
                          onPressed: selectedQty < 6 ? () => _adjustQuantity(idx, 1, tier.availableSeats) : null,
                        ),
                      ],
                    )
                  else
                    const Text('Sold Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        if (totalSelected > 0)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
            ),
            icon: const Icon(Icons.local_activity_outlined, color: Colors.black87),
            label: Text('Confirm Box Office ($totalSelected Tickets)',
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            onPressed: () => _showBookingDialog(event),
          ).animate().scale(curve: Curves.elasticOut),
      ],
    );
  }

  Widget _buildBookingsTab(AsyncValue<List<BookingModel>> bookingsAsync) {
    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const Center(
            child: Text('No bookings recorded for this event.'),
          );
        }

        final checkedInCount = bookings.where((b) => b.status == BookingStatus.redeemed).length;
        final totalBookings = bookings.length;

        var filteredBookings = bookings.where((b) {
          final q = _searchQuery.toLowerCase();
          final matchesSearch = b.bookingId.toLowerCase().contains(q) ||
              b.uid.toLowerCase().contains(q) ||
              (b.uid == 'offline_counter' && 'offline sale'.contains(q));
          
          if (!matchesSearch) return false;

          if (_filterStatus == 'Confirmed') return b.status == BookingStatus.confirmed;
          if (_filterStatus == 'Redeemed') return b.status == BookingStatus.redeemed;
          return true;
        }).toList();

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: ShowSnapColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$checkedInCount / $totalBookings Checked In',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('COPY LIST'),
                        onPressed: () {
                          // Simple copy to clipboard functionality
                          final list = bookings.map((b) => '${b.bookingId.substring(0,8)} - ${b.uid == 'offline_counter' ? 'Offline' : b.uid} - ${b.status.name}').join('\n');
                          Clipboard.setData(ClipboardData(text: list));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendee list copied!')));
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by Booking ID or Customer...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Confirmed', 'Redeemed'].map((status) {
                        final isSelected = _filterStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(status),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() => _filterStatus = status);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: filteredBookings.length,
                itemBuilder: (_, i) {
                  final b = filteredBookings[i];
                  final cleanPhone = b.uid == 'offline_counter' ? 'Offline Sale' : b.uid;
                  final isRedeemed = b.status == BookingStatus.redeemed;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('Booking #${b.bookingId.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Customer: $cleanPhone'),
                          Text('Tickets: ${b.seats.map((s) => '${s.row} #${s.number}').join(', ')}'),
                          Text('Amount: ₹${b.totalAmount}'),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isRedeemed ? ShowSnapColors.grey600 : Colors.green).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isRedeemed ? ShowSnapColors.grey600 : Colors.green),
                            ),
                            child: Text(
                              isRedeemed ? 'Redeemed' : 'Confirmed',
                              style: TextStyle(
                                color: isRedeemed ? ShowSnapColors.grey600 : Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!isRedeemed) ...[
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _manualCheckIn(b),
                              child: const Text('Check-in', style: TextStyle(color: ShowSnapColors.primary, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                            )
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _manualCheckIn(BookingModel booking) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateBookingStatus(booking.bookingId, BookingStatus.redeemed);
      if (mounted) ShowSnapToast.success(context, 'Checked in booking ${booking.bookingId.substring(0, 8)}');
      ref.invalidate(_emEventBookingsProvider(widget.eventId));
    } catch (e) {
      if (mounted) ShowSnapToast.error(context, 'Check-in failed: $e');
    }
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
        color: ShowSnapColors.surface,
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
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70))),
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
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: QrImageView(
                  data: bookingId,
                  version: QrVersions.auto,
                  size: 70,
                  gapless: false,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
