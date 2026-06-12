import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../providers/checkout_provider.dart';
import '../../../core/config/env.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';

class OrderSummaryScreen extends ConsumerStatefulWidget {
  final String showId;
  final List<String> selectedSeatIds;

  const OrderSummaryScreen({
    super.key,
    required this.showId,
    required this.selectedSeatIds,
  });

  @override
  ConsumerState<OrderSummaryScreen> createState() =>
      _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends ConsumerState<OrderSummaryScreen>
    with SingleTickerProviderStateMixin {
  late Razorpay _razorpay;
  final _couponCtrl = TextEditingController();
  bool _paymentInProgress = false;
  // Coupon shake
  late AnimationController _shakeCtrl;

  // Seat lock countdown (8 min = 480 s)
  late int _secondsLeft;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = AppConstants.seatLockMinutes * 60;
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _startLockTimer();
  }

  void _startLockTimer() {
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _lockTimer?.cancel();
        if (mounted) {
          _showLockExpiredDialog();
        }
      }
    });
  }

  void _showLockExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Seat Lock Expired'),
        content: const Text(
            'Your seat reservation has expired. Please select seats again.'),
        actions: [
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    _couponCtrl.dispose();
    _shakeCtrl.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  void _onPaymentSuccess(PaymentSuccessResponse resp) async {
    final args = (showId: widget.showId, seatIds: widget.selectedSeatIds);
    final notifier = ref.read(checkoutProvider(args).notifier);
    final checkoutData = ref.read(checkoutProvider(args)).valueOrNull;
    if (checkoutData == null) return;

    try {
      final show = checkoutData.show!;
      final db = ref.read(databaseServiceProvider);
      final movie = await db.getMovie(show.movieId);
      final theater = await db.getTheater(show.theaterId);

      final bookingId = await notifier.confirmBooking(
        resp.paymentId ?? '',
        movie?.title ?? '',
        theater?.name ?? '',
      );

      _lockTimer?.cancel();
      setState(() => _paymentInProgress = false);

      if (mounted) context.go('/ticket/$bookingId');
    } catch (e) {
      if (mounted) {
        setState(() => _paymentInProgress = false);
        ShowSnapToast.show(context, message: 'Booking failed: $e', type: ToastType.error);
      }
    }
  }

  void _onPaymentError(PaymentFailureResponse resp) async {
    setState(() => _paymentInProgress = false);
    final db = ref.read(databaseServiceProvider);
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    await db.unlockSeats(widget.showId, widget.selectedSeatIds, uid);
    if (mounted) {
      ShowSnapToast.show(context,
          message: 'Payment failed: ${resp.message ?? "Unknown error"}',
          type: ToastType.error);
    }
  }

  void _onExternalWallet(ExternalWalletResponse resp) {}

  void _initiatePayment(int totalAmount, String email, String contact) {
    setState(() => _paymentInProgress = true);
    final options = {
      'key': AppEnv.razorpayKeyId,
      'amount': totalAmount * 100,
      'name': 'ShowSnap',
      'description': 'Movie Ticket Booking',
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

  String get _lockTimerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _timerColor =>
      _secondsLeft < 60 ? ShowSnapColors.error : ShowSnapColors.secondary;

  @override
  Widget build(BuildContext context) {
    final args = (showId: widget.showId, seatIds: widget.selectedSeatIds);
    final checkoutAsync = ref.watch(checkoutProvider(args));
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
        actions: [
          // Seat lock countdown
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: _timerColor),
                const SizedBox(width: 4),
                Text(
                  _lockTimerLabel,
                  style: TextStyle(
                    color: _timerColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: checkoutAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (checkout) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Timer warning
            if (_secondsLeft < 120)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ShowSnapColors.error.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(ShowSnapRadius.md),
                  border:
                      Border.all(color: ShowSnapColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: ShowSnapColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hurry! Seats expire in $_lockTimerLabel',
                        style: const TextStyle(
                            color: ShowSnapColors.error,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(duration: const Duration(milliseconds: 800)),

            // Show info
            _SectionCard(
              title: 'Show Details',
              child: Column(
                children: [
                  if (checkout.show != null) ...[
                    _Row('Date/Time',
                        checkout.show!.startTs.epochToDateTimeLabel),
                    _Row('Screen', checkout.screen?.name ?? ''),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Seats
            _SectionCard(
              title: 'Seats',
              child: Column(
                children: checkout.seatInfos
                    .map((s) => Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  '${s.label} (${s.category.toUpperCase()})'),
                              Text('₹${s.price}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Coupon
            _SectionCard(
              title: 'Coupon',
              child: checkout.appliedCoupon != null
                  ? Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${checkout.appliedCoupon} applied — saved ₹${checkout.discount}',
                            style: const TextStyle(
                                color: Colors.green),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(checkoutProvider(args).notifier)
                              .removeCoupon(),
                          child: const Text('Remove'),
                        ),
                      ],
                    )
                  : _CouponInput(
                      ctrl: _couponCtrl,
                      loading: checkout.couponLoading,
                      error: checkout.couponError,
                      onApply: () async {
                        final code =
                            _couponCtrl.text.trim().toUpperCase();
                        await ref
                            .read(checkoutProvider(args).notifier)
                            .applyCoupon(code);
                        // Shake if still has error after apply
                        final updated =
                            ref.read(checkoutProvider(args)).valueOrNull;
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
                  _Row('Convenience Fee',
                      '₹${checkout.convenienceFee}'),
                  if (checkout.discount > 0)
                    _Row('Discount', '− ₹${checkout.discount}',
                        valueColor: Colors.green),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold)),
                      Text('₹${checkout.total}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
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
            const SizedBox(height: 12),

            // Cancellation policy
            _CancellationPolicy(),
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
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md)),
                  ),
                  onPressed: _paymentInProgress
                      ? null
                      : () => _initiatePayment(
                            checkout.total,
                            user?.email ?? '',
                            user?.phone ?? '',
                          ),
                  child: _paymentInProgress
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                      : Text('Pay ₹${checkout.total}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Coupon Input with shake ──────────────────────────────────────────────────

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
        final sineValue = shakeCtrl.isAnimating
            ? math.sin(shakeCtrl.value * 8 * math.pi) * 8
            : 0.0;
        return Transform.translate(
          offset: Offset(sineValue, 0),
          child: child,
        );
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
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ShowSnapRadius.sm)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: loading ? null : onApply,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

// ─── Cancellation Policy ──────────────────────────────────────────────────────

class _CancellationPolicy extends StatefulWidget {
  @override
  State<_CancellationPolicy> createState() => _CancellationPolicyState();
}

class _CancellationPolicyState extends State<_CancellationPolicy> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: ShowSnapColors.grey600, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Cancellation Policy',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: ShowSnapColors.grey600,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                const Text(
                  '• Cancellation is allowed up to 2 hours before show time.\n'
                  '• Refunds will be credited to your original payment method within 5–7 business days.\n'
                  '• Convenience fee is non-refundable.\n'
                  '• Tickets cannot be cancelled after the show starts.',
                  style: TextStyle(
                      fontSize: 12,
                      color: ShowSnapColors.grey600,
                      height: 1.6),
                ),
              ],
            ],
          ),
        ),
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
          Text(label,
              style: const TextStyle(color: ShowSnapColors.grey600)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w500, color: valueColor)),
        ],
      ),
    );
  }
}
