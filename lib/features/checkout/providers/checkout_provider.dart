import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/seat_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';

class CheckoutState {
  final ShowModel? show;
  final ScreenModel? screen;
  final List<BookedSeatInfo> seatInfos;
  final int subtotal;
  final int discount;
  final String? couponCode;
  final String? couponError;
  final String? appliedCoupon;
  final bool couponLoading;
  final int total;

  const CheckoutState({
    this.show,
    this.screen,
    this.seatInfos = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.couponCode,
    this.couponError,
    this.appliedCoupon,
    this.couponLoading = false,
    this.total = 0,
  });

  int get convenienceFee => AppEnv.convenienceFeeRupees;

  CheckoutState copyWith({
    ShowModel? show,
    ScreenModel? screen,
    List<BookedSeatInfo>? seatInfos,
    int? subtotal,
    int? discount,
    String? couponCode,
    String? couponError,
    String? appliedCoupon,
    bool? couponLoading,
    int? total,
    bool clearCouponError = false,
    bool clearAppliedCoupon = false,
  }) =>
      CheckoutState(
        show: show ?? this.show,
        screen: screen ?? this.screen,
        seatInfos: seatInfos ?? this.seatInfos,
        subtotal: subtotal ?? this.subtotal,
        discount: discount ?? this.discount,
        couponCode: couponCode ?? this.couponCode,
        couponError: clearCouponError ? null : couponError ?? this.couponError,
        appliedCoupon:
            clearAppliedCoupon ? null : appliedCoupon ?? this.appliedCoupon,
        couponLoading: couponLoading ?? this.couponLoading,
        total: total ?? this.total,
      );
}

class CheckoutNotifier extends StateNotifier<AsyncValue<CheckoutState>> {
  final DatabaseService _db;
  final String _showId;
  final List<String> _seatIds;
  final String _uid;

  CheckoutNotifier(this._db, this._showId, this._seatIds, this._uid)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final show = await _db.getShow(_showId);
      if (show == null) throw Exception('Show not found');
      final screen = await _db.getScreen(show.screenId);

      final seatInfos = <BookedSeatInfo>[];
      int subtotal = 0;
      if (screen != null) {
        for (final seatId in _seatIds) {
          final seat = screen.seatLayout.firstWhere(
            (s) => s.seatId == seatId,
            orElse: () => throw Exception('Seat $seatId not found'),
          );
          final price = show.priceForCategory(seat.category.name);
          subtotal += price;
          seatInfos.add(BookedSeatInfo(
            seatId: seatId,
            row: seat.row,
            number: seat.number,
            category: seat.category.name,
            price: price,
          ));
        }
      }

      final total =
          subtotal + AppEnv.convenienceFeeRupees;

      state = AsyncValue.data(CheckoutState(
        show: show,
        screen: screen,
        seatInfos: seatInfos,
        subtotal: subtotal,
        total: total,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> applyCoupon(String code) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
        current.copyWith(couponLoading: true, clearCouponError: true));

    try {
      // Determine dominant seat category for validation
      final category = current.seatInfos.isNotEmpty
          ? current.seatInfos.first.category
          : 'silver';
      final discount =
          await _db.validateCoupon(code, current.subtotal, category);

      final newTotal = (current.subtotal + current.convenienceFee - discount)
          .clamp(0, double.maxFinite)
          .toInt();

      state = AsyncValue.data(current.copyWith(
        discount: discount,
        appliedCoupon: code,
        couponLoading: false,
        total: newTotal,
      ));
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        couponLoading: false,
        couponError: e.toString().replaceAll('Exception: ', ''),
        clearAppliedCoupon: true,
      ));
    }
  }

  void removeCoupon() {
    final current = state.valueOrNull;
    if (current == null) return;
    final total = current.subtotal + current.convenienceFee;
    state = AsyncValue.data(current.copyWith(
      discount: 0,
      total: total,
      clearAppliedCoupon: true,
      clearCouponError: true,
    ));
  }

  Future<String> confirmBooking(
      String paymentTxnId, String movieTitle, String theaterName) async {
    final current = state.valueOrNull;
    if (current?.show == null) throw Exception('Checkout data missing');

    final booking = BookingModel(
      bookingId: '',
      uid: _uid,
      showId: _showId,
      movieId: current!.show!.movieId,
      movieTitle: movieTitle,
      theaterId: current.show!.theaterId,
      theaterName: theaterName,
      screenId: current.show!.screenId,
      screenName: current.screen?.name ?? '',
      showStartTs: current.show!.startTs,
      seats: current.seatInfos,
      subtotal: current.subtotal,
      convenienceFee: current.convenienceFee,
      couponCode: current.appliedCoupon ?? '',
      discountApplied: current.discount,
      totalAmount: current.total,
      status: BookingStatus.confirmed,
      paymentTxnId: paymentTxnId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    return _db.createBooking(booking);
  }
}

final checkoutProvider = StateNotifierProvider.autoDispose
    .family<CheckoutNotifier, AsyncValue<CheckoutState>,
        ({String showId, List<String> seatIds})>((ref, args) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  return CheckoutNotifier(
      ref.watch(databaseServiceProvider), args.showId, args.seatIds, uid);
});
