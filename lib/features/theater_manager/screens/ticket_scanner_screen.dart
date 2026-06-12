import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/services/database_service.dart';

class TicketScannerScreen extends ConsumerStatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  ConsumerState<TicketScannerScreen> createState() =>
      _TicketScannerScreenState();
}

class _TicketScannerScreenState extends ConsumerState<TicketScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  BookingModel? _lastScanned;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processQr(String bookingId) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _error = null;
      _lastScanned = null;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      final booking = await db.getBooking(bookingId);

      if (booking == null) {
        setState(() {
          _error = 'Booking not found: $bookingId';
          _isProcessing = false;
        });
        return;
      }

      if (booking.status == BookingStatus.redeemed) {
        setState(() {
          _lastScanned = booking;
          _error = '⚠️ Already redeemed!';
          _isProcessing = false;
        });
        return;
      }

      if (booking.status == BookingStatus.cancelled) {
        setState(() {
          _error = '❌ Booking cancelled';
          _isProcessing = false;
        });
        return;
      }

      if (booking.status != BookingStatus.confirmed) {
        setState(() {
          _error = 'Invalid booking status: ${booking.status.label}';
          _isProcessing = false;
        });
        return;
      }

      // Mark as redeemed
      await db.updateBookingStatus(bookingId, BookingStatus.redeemed);

      setState(() {
        _lastScanned = booking.copyWith(status: BookingStatus.redeemed);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Ticket'),
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;
                final value = barcodes.first.rawValue;
                if (value != null && value.isNotEmpty) {
                  _processQr(value);
                }
              },
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : _lastScanned != null
                      ? _SuccessCard(booking: _lastScanned!)
                      : _error != null
                          ? _ErrorCard(message: _error!)
                          : const Center(
                              child: Text(
                                'Point camera at ticket QR code',
                                style: TextStyle(
                                    color: ShowSnapColors.grey600,
                                    fontSize: 16),
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final BookingModel booking;
  const _SuccessCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ShowSnapColors.secondary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: ShowSnapColors.secondary, size: 28),
                SizedBox(width: 8),
                Text('Valid Ticket',
                    style: TextStyle(
                        color: ShowSnapColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            Text(booking.movieTitle,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            Text('${booking.theaterName} • ${booking.screenName}'),
            Text('Seats: ${booking.seats.map((s) => s.label).join(', ')}'),
            Text('Amount: ₹${booking.totalAmount}'),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ShowSnapColors.error.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: ShowSnapColors.error, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: ShowSnapColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}
