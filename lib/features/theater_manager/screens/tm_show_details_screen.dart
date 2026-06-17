import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../movies/providers/booking_provider.dart';
import '../../movies/widgets/seat_map_widget.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/staff_theme.dart';
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

  Future<void> _confirmBooking(
    ShowModel show,
    ScreenModel screen,
    MovieModel movie,
    TheaterModel theater,
  ) async {
    // Generate the Firebase push ID beforehand so the QR code can render it
    final bookingsRef = FirebaseDatabase.instance.ref().child('bookings');
    final bookingId = bookingsRef.push().key ?? 'booking_${DateTime.now().millisecondsSinceEpoch}';

    final seatInfos = <BookedSeatInfo>[];
    int subtotal = 0;

    for (final seatId in _selectedSeatIds) {
      final seatModel = screen.seatLayout.firstWhere(
        (s) => s.seatId == seatId,
        orElse: () => SeatModel(seatId: seatId, row: '?', number: 0, category: SeatCategory.silver, x: 0, y: 0),
      );
      final price = show.priceForCategory(seatModel.category.name);
      subtotal += price;
      seatInfos.add(BookedSeatInfo(
        seatId: seatId,
        row: seatModel.row,
        number: seatModel.number,
        category: seatModel.category.name,
        price: price,
      ));
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Confirming booking...'),
          ],
        ),
      ),
    );

    try {
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

      await ref
          .read(databaseServiceProvider)
          .createBookingWithId(bookingId, booking);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        context.push('/ticket/$bookingId');
        setState(() {
          _selectedSeatIds.clear(); // Clear selection after booking
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        context.showSnackbar('Booking failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAsync = ref.watch(showStreamProvider(widget.showId));

    return Scaffold(
      backgroundColor: TMColors.background,
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Box Office', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: showAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: TMColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.error))),
        data: (show) {
          if (show == null) return const Center(child: Text('Show not found', style: TextStyle(color: TMColors.textMuted)));
          final screenAsync = ref.watch(screenProvider(show.screenId));
          final movieAsync = ref.watch(movieProvider(show.movieId));
          final theaterAsync = ref.watch(theaterProvider(show.theaterId));

          return screenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: TMColors.primary)),
            error: (e, _) => Center(child: Text('Error loading screen layout: $e', style: const TextStyle(color: AdminColors.error))),
            data: (screen) {
              if (screen == null) {
                return const Center(child: Text('Screen layout not found', style: TextStyle(color: TMColors.textMuted)));
              }
              final layout = screen.seatLayout;
              final bookedCount = layout.length - show.seatsAvailable;

              return movieAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: TMColors.primary)),
                error: (e, _) => Center(child: Text('Error loading movie: $e', style: const TextStyle(color: AdminColors.error))),
                data: (movie) {
                  if (movie == null) {
                    return const Center(child: Text('Movie not found', style: TextStyle(color: TMColors.textMuted)));
                  }

                  return theaterAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: TMColors.primary)),
                    error: (e, _) => Center(child: Text('Error loading theater: $e', style: const TextStyle(color: AdminColors.error))),
                    data: (theater) {
                      if (theater == null) {
                        return const Center(child: Text('Theater not found', style: TextStyle(color: TMColors.textMuted)));
                      }

                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: TMColors.surfaceElevated,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatCard(label: 'Total Seats', value: '${layout.length}'),
                                _StatCard(
                                    label: 'Booked',
                                    value: '$bookedCount',
                                    color: AdminColors.error),
                                _StatCard(
                                    label: 'Available',
                                    value: '${show.seatsAvailable}',
                                    color: AdminColors.success),
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
                                color: TMColors.surface,
                                border: const Border(top: BorderSide(color: TMColors.border)),
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
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Text(
                                          'Offline Counter Booking',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: TMColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                      ElevatedButton(
                                        onPressed: () => _confirmBooking(show, screen, movie, theater),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: TMColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                        child: const Text('CONFIRM'),
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
                color: color ?? TMColors.primary)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: TMColors.textMuted)),
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
        color: ShowSnapColors.surface,
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
              color: ShowSnapColors.primary,
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
                color: Colors.white,
                border: Border.all(color: ShowSnapColors.grey300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: bookingId,
                version: QrVersions.auto,
                size: 140.0,
                gapless: false,
                backgroundColor: Colors.white,
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
