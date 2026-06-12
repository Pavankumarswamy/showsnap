import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../movies/providers/booking_provider.dart';
import '../../movies/widgets/seat_map_widget.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/seat_model.dart';
import '../../../core/models/seat_status_model.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/file_save_helper.dart'
    if (dart.library.html) '../../../core/utils/file_save_helper_web.dart'
    if (dart.library.io) '../../../core/utils/file_save_helper_native.dart';
import '../../../core/utils/url_launcher_helper.dart'
    if (dart.library.html) '../../../core/utils/url_launcher_helper_web.dart'
    if (dart.library.io) '../../../core/utils/url_launcher_helper_native.dart';

class TmShowDetailsScreen extends ConsumerStatefulWidget {
  final String showId;
  const TmShowDetailsScreen({super.key, required this.showId});

  @override
  ConsumerState<TmShowDetailsScreen> createState() =>
      _TmShowDetailsScreenState();
}

class _TmShowDetailsScreenState extends ConsumerState<TmShowDetailsScreen> {
  final Set<String> _selectedSeatIds = {};
  final GlobalKey _ticketBoundaryKey = GlobalKey();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _handleSeatTap(SeatModel seat, Map<String, SeatStatusModel> seats) {
    final status = seats[seat.seatId]?.status ?? SeatStatus.available;

    if (status == SeatStatus.booked) {
      context.showSnackbar('This seat is already booked.');
      return;
    }

    setState(() {
      if (_selectedSeatIds.contains(seat.seatId)) {
        _selectedSeatIds.remove(seat.seatId);
      } else {
        _selectedSeatIds.add(seat.seatId);
      }
    });
  }

  void _showBookingDialog(
    ShowModel show,
    ScreenModel screen,
    MovieModel movie,
    TheaterModel theater,
  ) {
    // Generate the Firebase push ID beforehand so the QR code can render it
    final bookingsRef = FirebaseDatabase.instance.ref().child('bookings');
    final bookingId = bookingsRef.push().key ?? 'booking_${DateTime.now().millisecondsSinceEpoch}';

    final dt = DateTime.fromMillisecondsSinceEpoch(show.startTs);
    final formattedDateTime = DateFormat('EEE, d MMM yyyy • h:mm a').format(dt);

    final seatInfos = <BookedSeatInfo>[];
    int subtotal = 0;
    final seatLabels = <String>[];

    for (final seatId in _selectedSeatIds) {
      final seatModel = screen.seatLayout.firstWhere(
        (s) => s.seatId == seatId,
        orElse: () => SeatModel(seatId: seatId, row: '?', number: 0, category: SeatCategory.silver, x: 0, y: 0),
      );
      final price = show.priceForCategory(seatModel.category.name);
      subtotal += price;
      seatLabels.add('${seatModel.row}${seatModel.number}');
      seatInfos.add(BookedSeatInfo(
        seatId: seatId,
        row: seatModel.row,
        number: seatModel.number,
        category: seatModel.category.name,
        price: price,
      ));
    }

    String bookingState = 'input'; // 'input', 'processing', 'success', 'error'
    String statusMessage = '';
    String errorMessage = '';
    String cloudinaryUrl = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 1. Input State
          if (bookingState == 'input') {
            return AlertDialog(
              title: const Text('Confirm Offline Booking'),
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
                          'Verify details below. Confirming will save the booking, download the PNG ticket, and open the WhatsApp send dialog.',
                          style: TextStyle(fontSize: 12, color: ShowSnapColors.grey600),
                        ),
                        const SizedBox(height: 16),
                        RepaintBoundary(
                          key: _ticketBoundaryKey,
                          child: _TicketCard(
                            bookingId: bookingId,
                            movieTitle: movie.title,
                            theaterName: theater.name,
                            screenName: screen.name,
                            formattedDateTime: formattedDateTime,
                            seatLabels: seatLabels,
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
                      // 1. Create booking model
                      final booking = BookingModel(
                        bookingId: bookingId,
                        uid: 'offline_counter',
                        showId: show.showId,
                        movieId: show.movieId,
                        movieTitle: movie.title,
                        theaterId: show.theaterId,
                        theaterName: theater.name,
                        screenId: show.screenId,
                        screenName: screen.name,
                        showStartTs: show.startTs,
                        seats: seatInfos,
                        subtotal: subtotal,
                        convenienceFee: 0,
                        totalAmount: subtotal,
                        status: BookingStatus.confirmed,
                        createdAt: DateTime.now().millisecondsSinceEpoch,
                      );

                      // 2. Save to database
                      await ref
                          .read(databaseServiceProvider)
                          .createBookingWithId(bookingId, booking);

                      setDialogState(() {
                        statusMessage = 'Generating ticket PNG...';
                      });

                      // 3. Render ticket to PNG
                      // Add a small delay to make sure UI is fully settled
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

                      // 4. Download file locally
                      await saveAndDownloadPng(pngBytes, 'ticket_$bookingId.png');

                      setDialogState(() {
                        statusMessage = 'Uploading ticket to cloud...';
                      });

                      // 5. Upload to Cloudinary to get an online link
                      final url = await ref
                          .read(cloudinaryServiceProvider)
                          .uploadImageBytes(
                            pngBytes,
                            'ticket_$bookingId.png',
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

          // 2. Processing State
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

          // 3. Success State
          if (bookingState == 'success') {
            final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
            final phoneWithCountryCode = '91$digits';
            final message = 'Hi! Here is your ShowSnap ticket for *${movie.title}* at *${theater.name}*:\n\n'
                'Seats: *${seatLabels.join(', ')}*\n'
                'Total: *₹$subtotal*\n\n'
                'View Ticket: $cloudinaryUrl';
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
                      style: TextStyle(
                        fontSize: 12,
                        color: ShowSnapColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _phoneController.clear();
                    Navigator.pop(dialogContext); // Close dialog
                    if (mounted) {
                      setState(() {
                        _selectedSeatIds.clear(); // Clear selection
                      });
                    }
                  },
                  child: const Text('CLOSE'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await launchBrowserUrl(whatsappUrl);
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('SEND VIA WHATSAPP'),
                ),
              ],
            );
          }

          // 4. Error State
          return AlertDialog(
            title: const Text('Booking Failed'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: ShowSnapColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: ShowSnapColors.error,
                    ),
                  ),
                ],
              ),
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

  @override
  Widget build(BuildContext context) {
    final showAsync = ref.watch(showStreamProvider(widget.showId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Box Office'),
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
      ),
      body: showAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (show) {
          final screenAsync = ref.watch(screenProvider(show.screenId));
          final movieAsync = ref.watch(movieProvider(show.movieId));
          final theaterAsync = ref.watch(theaterProvider(show.theaterId));

          return screenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading screen layout: $e')),
            data: (screen) {
              if (screen == null) {
                return const Center(child: Text('Screen layout not found'));
              }
              final layout = screen.seatLayout;
              final bookedCount = layout.length - show.seatsAvailable;

              return movieAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading movie: $e')),
                data: (movie) {
                  if (movie == null) {
                    return const Center(child: Text('Movie not found'));
                  }

                  return theaterAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error loading theater: $e')),
                    data: (theater) {
                      if (theater == null) {
                        return const Center(child: Text('Theater not found'));
                      }

                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: ShowSnapColors.grey100,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatCard(label: 'Total Seats', value: '${layout.length}'),
                                _StatCard(
                                    label: 'Booked',
                                    value: '$bookedCount',
                                    color: ShowSnapColors.error),
                                _StatCard(
                                    label: 'Available',
                                    value: '${show.seatsAvailable}',
                                    color: ShowSnapColors.secondary),
                              ],
                            ),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
                          Expanded(
                            child: SeatMapWidget(
                              seatLayout: layout,
                              show: show,
                              selectedSeatIds: _selectedSeatIds,
                              lockingInProgress: const {},
                              currentUid: 'tm_offline', // Special ID to not confuse locks
                              onSeatTap: (seat) => _handleSeatTap(seat, show.seats),
                            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                          ),
                          if (_selectedSeatIds.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: ShowSnapColors.surface,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, -4),
                                  ),
                                ],
                              ),
                              child: SafeArea(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${_selectedSeatIds.length} Seats Selected',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Text(
                                          'Offline Counter Booking',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: ShowSnapColors.grey600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _showBookingDialog(show, screen, movie, theater),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ShowSnapColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                      child: const Text('BOOK SEATS'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color ?? ShowSnapColors.primary)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: ShowSnapColors.grey600)),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  final String bookingId;
  final String movieTitle;
  final String theaterName;
  final String screenName;
  final String formattedDateTime;
  final List<String> seatLabels;
  final int totalAmount;

  const _TicketCard({
    required this.bookingId,
    required this.movieTitle,
    required this.theaterName,
    required this.screenName,
    required this.formattedDateTime,
    required this.seatLabels,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ShowSnap',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: ShowSnapColors.primary,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ShowSnapColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'OFFLINE TICKET',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: ShowSnapColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(thickness: 1, color: ShowSnapColors.grey300),
          const SizedBox(height: 8),
          Text(
            movieTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ShowSnapColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$theaterName • $screenName',
            style: const TextStyle(
              fontSize: 12,
              color: ShowSnapColors.grey600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedDateTime,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ShowSnapColors.secondary,
            ),
          ),
          const SizedBox(height: 16),
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DashedLinePainter(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SEATS',
                    style: TextStyle(
                      fontSize: 10,
                      color: ShowSnapColors.grey600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    seatLabels.join(', '),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TOTAL PRICE',
                    style: TextStyle(
                      fontSize: 10,
                      color: ShowSnapColors.grey600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹$totalAmount',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ShowSnapColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: ShowSnapColors.grey300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: bookingId,
                version: QrVersions.auto,
                size: 140.0,
                gapless: false,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'ID: ${bookingId.length > 12 ? bookingId.substring(bookingId.length - 12).toUpperCase() : bookingId.toUpperCase()}',
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: ShowSnapColors.grey600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 5, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = ShowSnapColors.grey300
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
