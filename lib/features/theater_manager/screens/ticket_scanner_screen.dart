import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';

enum _ScanState { idle, processing, valid, redeemed, invalid }

class TicketScannerScreen extends ConsumerStatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  ConsumerState<TicketScannerScreen> createState() =>
      _TicketScannerScreenState();
}

class _TicketScannerScreenState extends ConsumerState<TicketScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  _ScanState _state = _ScanState.idle;
  BookingModel? _booking;
  String? _errorMessage;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _processQr(String bookingId) async {
    if (_state == _ScanState.processing) return;
    setState(() {
      _state = _ScanState.processing;
      _booking = null;
      _errorMessage = null;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      final booking = await db.getBooking(bookingId);

      if (booking == null) {
        setState(() {
          _state = _ScanState.invalid;
          _errorMessage = 'Booking not found';
        });
        return;
      }

      if (booking.status == BookingStatus.redeemed) {
        setState(() {
          _state = _ScanState.redeemed;
          _booking = booking;
        });
        return;
      }

      if (booking.status == BookingStatus.cancelled) {
        setState(() {
          _state = _ScanState.invalid;
          _errorMessage = 'Booking cancelled';
        });
        return;
      }

      if (booking.status != BookingStatus.confirmed) {
        setState(() {
          _state = _ScanState.invalid;
          _errorMessage = 'Invalid status: ${booking.status.label}';
        });
        return;
      }

      await db.updateBookingStatus(bookingId, BookingStatus.redeemed);
      setState(() {
        _state = _ScanState.valid;
        _booking = booking.copyWith(status: BookingStatus.redeemed);
      });
    } catch (e) {
      setState(() {
        _state = _ScanState.invalid;
        _errorMessage = 'Error: $e';
      });
    }
  }

  void _resetScan() {
    setState(() {
      _state = _ScanState.idle;
      _booking = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushDrawerLayout(
      backgroundColor: TMColors.background,
      drawer: TMDrawer(
        currentRoute: AppRoutes.ticketScanner,
        onNavigateTo: (route) => context.push(route),
        theaterName: 'My Theater',
      ),
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        foregroundColor: TMColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Scan Ticket',
          style: TextStyle(
              color: TMColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined, color: TMColors.primary),
            tooltip: 'Toggle Flash',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_outlined,
                color: TMColors.textSecondary),
            tooltip: 'Flip Camera',
            onPressed: () => _controller.switchCamera(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Camera viewport
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final value = barcodes.first.rawValue;
                    if (value != null && value.isNotEmpty) {
                      _processQr(value);
                    }
                  },
                ).animate().fadeIn(duration: 500.ms),
                // Scan frame overlay
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) {
                      final opacity = _state == _ScanState.idle
                          ? 0.4 + _pulseController.value * 0.5
                          : 1.0;
                      final borderColor = _state == _ScanState.valid
                          ? TMColors.primary
                          : _state == _ScanState.redeemed
                              ? const Color(0xFFFFC107)
                              : _state == _ScanState.invalid
                                  ? const Color(0xFFEF5350)
                                  : TMColors.primary;
                      return Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor, width: 2.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: CustomPaint(
                            painter: _CornerPainter(color: borderColor),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Status overlay when not scanning
                if (_state == _ScanState.processing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: TMColors.primary, strokeWidth: 3),
                    ),
                  ),
              ],
            ),
          ),

          // Result panel
          AnimatedContainer(
            duration: 350.ms,
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 200),
            color: TMColors.background,
            padding: const EdgeInsets.all(16),
            child: _buildResultPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    switch (_state) {
      case _ScanState.idle:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner_rounded,
                color: TMColors.textMuted, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Point camera at ticket QR code',
              style: TextStyle(color: TMColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(duration: 400.ms);

      case _ScanState.processing:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: TMColors.primary, strokeWidth: 3),
            SizedBox(height: 12),
            Text('Verifying ticket…',
                style: TextStyle(color: TMColors.textSecondary)),
          ],
        );

      case _ScanState.valid:
        return _buildSuccessPanel().animate().fadeIn(duration: 300.ms).scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.0, 1.0),
            );

      case _ScanState.redeemed:
        return _buildAlreadyRedeemedPanel()
            .animate()
            .fadeIn(duration: 300.ms)
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.0, 1.0),
            );

      case _ScanState.invalid:
        return _buildInvalidPanel()
            .animate()
            .fadeIn(duration: 300.ms)
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.0, 1.0),
            );
    }
  }

  Widget _buildSuccessPanel() {
    final booking = _booking!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TMColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: TMColors.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: TMColors.primary, size: 28),
              const SizedBox(width: 10),
              const Text(
                'Valid Ticket — Admitted!',
                style: TextStyle(
                    color: TMColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
          const Divider(color: TMColors.border, height: 20),
          Text(booking.movieTitle,
              style: const TextStyle(
                  color: TMColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            '${booking.theaterName} · ${booking.screenName}',
            style: const TextStyle(color: TMColors.textSecondary, fontSize: 13),
          ),
          Text(
            'Show: ${booking.showStartTs.epochToDateTimeLabel}',
            style: const TextStyle(color: TMColors.textSecondary, fontSize: 13),
          ),
          Text(
            'Seats: ${booking.seats.map((s) => s.label).join(', ')}',
            style: const TextStyle(color: TMColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Scan Next'),
              style: OutlinedButton.styleFrom(
                foregroundColor: TMColors.primary,
                side: const BorderSide(color: TMColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
              ),
              onPressed: _resetScan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyRedeemedPanel() {
    final booking = _booking!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.1),
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFFC107), size: 28),
              SizedBox(width: 10),
              Text(
                'Already Redeemed',
                style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
          const Divider(color: TMColors.border, height: 20),
          Text(booking.movieTitle,
              style: const TextStyle(
                  color: TMColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Seats: ${booking.seats.map((s) => s.label).join(', ')}',
            style: const TextStyle(color: TMColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Scan Next'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFC107),
                side: const BorderSide(color: Color(0xFFFFC107)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
              ),
              onPressed: _resetScan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvalidPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350).withOpacity(0.1),
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Color(0xFFEF5350), size: 28),
              SizedBox(width: 10),
              Text(
                'Invalid Ticket',
                style: TextStyle(
                    color: Color(0xFFEF5350),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'This ticket is not valid.',
            style: const TextStyle(color: TMColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF5350),
                side: const BorderSide(color: Color(0xFFEF5350)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
              ),
              onPressed: _resetScan,
            ),
          ),
        ],
      ),
    );
  }
}

// Corner bracket painter for scan frame
class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(Offset.zero, Offset(len, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, len), paint);
    // Top-right
    canvas.drawLine(Offset(w, 0), Offset(w - len, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - len), paint);
    // Bottom-right
    canvas.drawLine(Offset(w, h), Offset(w - len, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}
