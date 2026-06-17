import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../providers/event_checkout_provider.dart';
import '../../../core/config/env.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/file_save_helper.dart'
    if (dart.library.html) '../../../core/utils/file_save_helper_web.dart'
    if (dart.library.io) '../../../core/utils/file_save_helper_native.dart';
import '../../../core/utils/url_launcher_helper.dart'
    if (dart.library.html) '../../../core/utils/url_launcher_helper_web.dart'
    if (dart.library.io) '../../../core/utils/url_launcher_helper_native.dart';
import '../../../core/widgets/showsnap_toast.dart';

class EventOrderSummaryScreen extends ConsumerStatefulWidget {
  final String eventId;
  final Map<int, int> tierQuantities;

  const EventOrderSummaryScreen({
    super.key,
    required this.eventId,
    required this.tierQuantities,
  });

  @override
  ConsumerState<EventOrderSummaryScreen> createState() =>
      _EventOrderSummaryScreenState();
}

class _EventOrderSummaryScreenState extends ConsumerState<EventOrderSummaryScreen>
    with SingleTickerProviderStateMixin {
  late Razorpay _razorpay;
  final _couponCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _ticketBoundaryKey = GlobalKey();
  
  bool _paymentInProgress = false;
  late AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialPhone = ref.read(currentUserModelProvider).valueOrNull?.phone ?? '';
      final cleanPhone = initialPhone.replaceAll(RegExp(r'^\+91'), '').replaceAll(RegExp(r'\D'), '');
      _phoneCtrl.text = cleanPhone;
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    _couponCtrl.dispose();
    _phoneCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onPaymentSuccess(PaymentSuccessResponse resp) async {
    final args = (eventId: widget.eventId, tierQuantities: widget.tierQuantities);
    final notifier = ref.read(eventCheckoutProvider(args).notifier);
    final checkoutData = ref.read(eventCheckoutProvider(args)).valueOrNull;
    if (checkoutData == null || checkoutData.event == null) return;

    try {
      // 1. Confirm booking in DB
      final bookingId = await notifier.confirmBooking(resp.paymentId ?? '');

      setState(() => _paymentInProgress = false);

      // 2. Generate and upload ticket
      if (mounted) {
        _showProcessingDialog('Generating ticket PNG...');
      }

      await Future.delayed(const Duration(milliseconds: 500)); // wait for boundary to render
      final boundary = _ticketBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Ticket render boundary not found');
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to convert image to bytes');
      
      final pngBytes = byteData.buffer.asUint8List();

      if (mounted) {
        Navigator.pop(context); // close processing dialog
        _showProcessingDialog('Downloading ticket...');
      }

      await saveAndDownloadPng(pngBytes, 'event_ticket_$bookingId.png');

      if (mounted) {
        Navigator.pop(context);
        _showProcessingDialog('Uploading to cloud...');
      }

      final url = await ref.read(cloudinaryServiceProvider).uploadImageBytes(
            pngBytes,
            'event_ticket_$bookingId.png',
            AppConstants.cloudinaryEtickets,
          );

      if (mounted) {
        Navigator.pop(context);
      }

      // 3. Show Success Dialog
      final event = checkoutData.event!;
      final dt = DateTime.fromMillisecondsSinceEpoch(event.startTs);
      final formattedDateTime = DateFormat('EEE, d MMM yyyy • h:mm a').format(dt);
      
      final tierDetails = <String>[];
      widget.tierQuantities.forEach((tierIdx, qty) {
        if (qty > 0 && tierIdx < event.ticketTiers.length) {
          tierDetails.add('${event.ticketTiers[tierIdx].name} x$qty');
        }
      });

      final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      final phoneWithCountryCode = '91$digits';
      final message = 'Hi! Here is your ticket for *${event.name}* at *${event.venueName}*:\n\n'
          'Tickets: *${tierDetails.join(', ')}*\n'
          'Total: *₹${checkoutData.total}*\n\n'
          'View E-Ticket: $url';
      final whatsappUrl = 'https://wa.me/$phoneWithCountryCode?text=${Uri.encodeComponent(message)}';

      if (mounted) {
        _showSuccessDialog(bookingId, whatsappUrl, digits);
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // clear any dialogs
        setState(() => _paymentInProgress = false);
        ShowSnapToast.show(context, message: 'Booking completed but ticket generation failed: $e', type: ToastType.error);
        context.go('/my-bookings');
      }
    }
  }

  void _onPaymentError(PaymentFailureResponse resp) {
    setState(() => _paymentInProgress = false);
    ShowSnapToast.show(context,
        message: 'Payment failed: ${resp.message ?? "Unknown error"}',
        type: ToastType.error);
  }

  void _onExternalWallet(ExternalWalletResponse resp) {}

  void _initiatePayment(int totalAmount, String email, String contact) {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _paymentInProgress = true);
    final options = {
      'key': AppEnv.razorpayKeyId,
      'amount': totalAmount * 100,
      'name': 'ShowSnap Events',
      'description': 'Event Ticket Booking',
      'prefill': {'email': email, 'contact': contact},
      'external': {
        'wallets': ['paytm']
      },
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _paymentInProgress = false);
      ShowSnapToast.show(context,
          message: 'Payment initialization failed', type: ToastType.error);
    }
  }

  void _showProcessingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
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
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String bookingId, String whatsappUrl, String digits) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
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
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              const Text(
                'Ticket has been generated and downloaded successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Phone Number: +91 $digits',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ShowSnapColors.grey600),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = (eventId: widget.eventId, tierQuantities: widget.tierQuantities);
    final checkoutAsync = ref.watch(eventCheckoutProvider(args));
    final user = ref.watch(currentUserModelProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Summary'),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
        ),
        flexibleSpace: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
          child: Container(
            decoration: BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
          ),
        ),
      ),
      body: checkoutAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (checkout) {
          if (checkout.event == null) return const Center(child: Text('Event not found'));

          final event = checkout.event!;
          final dt = DateTime.fromMillisecondsSinceEpoch(event.startTs);
          final formattedDateTime = DateFormat('EEE, d MMM yyyy • h:mm a').format(dt);
          final tierDetails = <String>[];
          widget.tierQuantities.forEach((tierIdx, qty) {
            if (qty > 0 && tierIdx < event.ticketTiers.length) {
              tierDetails.add('${event.ticketTiers[tierIdx].name} x$qty');
            }
          });

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Event Details
                  _SectionCard(
                    title: 'Event Details',
                    child: Column(
                      children: [
                        _Row('Event', event.name),
                        _Row('Date/Time', formattedDateTime),
                        _Row('Venue', '${event.venueName}, ${event.city}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tickets
                  _SectionCard(
                    title: 'Tickets',
                    child: Column(
                      children: tierDetails.map((detail) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.local_activity, size: 16, color: ShowSnapColors.primary),
                            const SizedBox(width: 8),
                            Text(detail, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // WhatsApp Delivery Number
                  _SectionCard(
                    title: 'Ticket Delivery',
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'We will generate a WhatsApp link to easily share this ticket.',
                            style: TextStyle(fontSize: 12, color: ShowSnapColors.grey600),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp Number',
                              prefixText: '+91 ',
                              hintText: '10-digit number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter a phone number';
                              final clean = value.replaceAll(RegExp(r'\D'), '');
                              if (clean.length != 10) return 'Please enter a valid 10-digit number';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Coupon
                  _SectionCard(
                    title: 'Coupon',
                    child: checkout.appliedCoupon != null
                        ? Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${checkout.appliedCoupon} applied — saved ₹${checkout.discount}',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ),
                              TextButton(
                                onPressed: () => ref.read(eventCheckoutProvider(args).notifier).removeCoupon(),
                                child: const Text('Remove'),
                              ),
                            ],
                          )
                        : _CouponInput(
                            ctrl: _couponCtrl,
                            loading: checkout.couponLoading,
                            error: checkout.couponError,
                            onApply: () async {
                              final code = _couponCtrl.text.trim().toUpperCase();
                              await ref.read(eventCheckoutProvider(args).notifier).applyCoupon(code);
                              final updated = ref.read(eventCheckoutProvider(args)).valueOrNull;
                              if (updated?.couponError != null) {
                                _shakeCtrl.forward(from: 0);
                              }
                            },
                            shakeCtrl: _shakeCtrl,
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Price breakdown
                  _SectionCard(
                    title: 'Price Breakdown',
                    child: Column(
                      children: [
                        _Row('Subtotal', '₹${checkout.subtotal}'),
                        if (checkout.convenienceFee > 0)
                          _Row('Convenience Fee', '₹${checkout.convenienceFee}'),
                        if (checkout.discount > 0)
                          _Row('Discount', '− ₹${checkout.discount}', valueColor: Colors.green),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text('₹${checkout.total}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: ShowSnapColors.primary,
                                    ))
                                .animate(key: ValueKey(checkout.total))
                                .scale(
                                    begin: const Offset(0.8, 0.8),
                                    end: const Offset(1, 1),
                                    duration: ShowSnapDuration.fast,
                                    curve: Curves.elasticOut),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pay button
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: ShowSnapTheme.primaryButtonDecoration,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
                        ),
                        onPressed: _paymentInProgress
                            ? null
                            : () => _initiatePayment(
                                  checkout.total,
                                  user?.email ?? '',
                                  user?.phone ?? '',
                                ),
                        child: _paymentInProgress
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text('Pay ₹${checkout.total}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),

              // Hidden RepaintBoundary for generating the ticket PNG
              Positioned(
                left: -2000,
                top: -2000,
                child: RepaintBoundary(
                  key: _ticketBoundaryKey,
                  child: _EventTicketCard(
                    bookingId: 'MOCK_ID', // Will be replaced by actual logic if drawn dynamically, but here we just render the event details
                    eventName: event.name,
                    venueName: event.venueName,
                    city: event.city,
                    formattedDateTime: formattedDateTime,
                    ticketDetails: tierDetails,
                    totalAmount: checkout.total,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Coupon Input ─────────────────────────────────────────────────────────────

class _CouponInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final String? error;
  final Future<void> Function() onApply;
  final AnimationController shakeCtrl;

  const _CouponInput({
    required this.ctrl,
    required this.loading,
    this.error,
    required this.onApply,
    required this.shakeCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shakeCtrl,
      builder: (_, child) {
        final sineValue = shakeCtrl.isAnimating ? math.sin(shakeCtrl.value * 8 * math.pi) * 8 : 0.0;
        return Transform.translate(offset: Offset(sineValue, 0), child: child);
      },
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: ctrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter coupon code',
                errorText: error,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ShowSnapRadius.sm)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: loading ? null : onApply,
            child: loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

// ─── Row ──────────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ShowSnapColors.grey600)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: valueColor)),
        ],
      ),
    );
  }
}

// ─── Event Ticket Card for PNG Generation ──────────────────────────────────────

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
                child: const Text('EVENT TICKET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              Text('#EVENT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ShowSnapColors.grey600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(eventName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: ShowSnapColors.grey600),
              const SizedBox(width: 4),
              Expanded(child: Text('$venueName, $city', style: const TextStyle(fontSize: 11, color: ShowSnapColors.grey600))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: ShowSnapColors.grey600),
              const SizedBox(width: 4),
              Text(formattedDateTime, style: const TextStyle(fontSize: 11, color: ShowSnapColors.grey600)),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          const Text('TICKETS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ShowSnapColors.grey600)),
          const SizedBox(height: 4),
          ...ticketDetails.map((detail) => Text(detail, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70))),
          const Divider(height: 24, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL AMOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ShowSnapColors.grey600)),
                  Text('₹$totalAmount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ShowSnapColors.primary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                child: QrImageView(
                  data: 'EVENT_TICKET_PAID',
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
