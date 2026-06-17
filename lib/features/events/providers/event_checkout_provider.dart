import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';

class EventCheckoutState {
  final EventModel? event;
  final Map<int, int> tierQuantities;
  final List<BookedSeatInfo> seatInfos;
  final int subtotal;
  final int convenienceFee;
  final String? appliedCoupon;
  final int discount;
  final int total;
  final bool couponLoading;
  final String? couponError;
  final bool isProcessing;
  final String? error;

  const EventCheckoutState({
    this.event,
    this.tierQuantities = const {},
    this.seatInfos = const [],
    this.subtotal = 0,
    this.convenienceFee = 0, // No convenience fee for events by default
    this.appliedCoupon,
    this.discount = 0,
    this.total = 0,
    this.couponLoading = false,
    this.couponError,
    this.isProcessing = false,
    this.error,
  });

  EventCheckoutState copyWith({
    EventModel? event,
    Map<int, int>? tierQuantities,
    List<BookedSeatInfo>? seatInfos,
    int? subtotal,
    int? convenienceFee,
    String? appliedCoupon,
    int? discount,
    int? total,
    bool? couponLoading,
    String? couponError,
    bool? isProcessing,
    String? error,
    bool clearCoupon = false,
  }) {
    return EventCheckoutState(
      event: event ?? this.event,
      tierQuantities: tierQuantities ?? this.tierQuantities,
      seatInfos: seatInfos ?? this.seatInfos,
      subtotal: subtotal ?? this.subtotal,
      convenienceFee: convenienceFee ?? this.convenienceFee,
      appliedCoupon: clearCoupon ? null : appliedCoupon ?? this.appliedCoupon,
      discount: clearCoupon ? 0 : discount ?? this.discount,
      total: total ?? this.total,
      couponLoading: couponLoading ?? this.couponLoading,
      couponError: clearCoupon ? null : couponError ?? this.couponError,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error ?? this.error,
    );
  }
}

class EventCheckoutNotifier extends StateNotifier<AsyncValue<EventCheckoutState>> {
  final DatabaseService _db;
  final String _eventId;
  final Map<int, int> _tierQuantities;
  final String _uid;

  EventCheckoutNotifier(this._db, this._eventId, this._tierQuantities, this._uid)
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final event = await _db.getEvent(_eventId);
      if (event == null) throw Exception('Event not found');

      final seatInfos = <BookedSeatInfo>[];
      int subtotal = 0;

      _tierQuantities.forEach((tierIdx, qty) {
        if (qty > 0 && tierIdx < event.ticketTiers.length) {
          final tier = event.ticketTiers[tierIdx];
          subtotal += tier.price * qty;
          for (var i = 0; i < qty; i++) {
            seatInfos.add(BookedSeatInfo(
              seatId: '${tier.name}_$i',
              row: tier.name,
              number: i + 1,
              category: tier.name,
              price: tier.price,
            ));
          }
        }
      });

      final total = subtotal;

      state = AsyncValue.data(EventCheckoutState(
        event: event,
        tierQuantities: _tierQuantities,
        seatInfos: seatInfos,
        subtotal: subtotal,
        total: total,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> applyCoupon(String code) async {
    final currentState = state.valueOrNull;
    if (currentState == null || currentState.event == null) return;

    state = AsyncValue.data(currentState.copyWith(
      couponLoading: true,
      couponError: null,
      clearCoupon: true,
    ));

    try {
      // Basic mock coupon logic matching checkout_provider.dart
      await Future.delayed(const Duration(seconds: 1));
      if (code.isEmpty) throw Exception('Enter a valid code');
      if (code == 'INVALID') throw Exception('Invalid coupon code');

      final discount = (currentState.subtotal * 0.1).toInt().clamp(0, 150);

      state = AsyncValue.data(currentState.copyWith(
        couponLoading: false,
        appliedCoupon: code,
        discount: discount,
        total: currentState.subtotal + currentState.convenienceFee - discount,
      ));
    } catch (e) {
      state = AsyncValue.data(currentState.copyWith(
        couponLoading: false,
        couponError: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  void removeCoupon() {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(
      clearCoupon: true,
      total: currentState.subtotal + currentState.convenienceFee,
    ));
  }

  Future<String> confirmBooking(String paymentTxnId) async {
    final currentState = state.valueOrNull;
    if (currentState == null || currentState.event == null) throw Exception('State error');

    final bookingId = 'evt_bk_${DateTime.now().millisecondsSinceEpoch}';
    final booking = BookingModel(
      bookingId: bookingId,
      uid: _uid,
      showId: currentState.event!.eventId, // Use eventId as showId
      movieId: currentState.event!.eventId,
      movieTitle: currentState.event!.name,
      theaterId: currentState.event!.venueId,
      theaterName: currentState.event!.venueName,
      screenId: 'Event',
      screenName: currentState.event!.category,
      showStartTs: currentState.event!.startTs,
      seats: currentState.seatInfos,
      subtotal: currentState.subtotal,
      convenienceFee: currentState.convenienceFee,
      couponCode: currentState.appliedCoupon ?? '',
      discountApplied: currentState.discount,
      totalAmount: currentState.total,
      status: BookingStatus.confirmed,
      paymentTxnId: paymentTxnId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.bookEventTickets(booking, currentState.event!, _tierQuantities);
    return bookingId;
  }
}

typedef EventCheckoutArgs = ({String eventId, Map<int, int> tierQuantities});

final eventCheckoutProvider = StateNotifierProvider.autoDispose
    .family<EventCheckoutNotifier, AsyncValue<EventCheckoutState>, EventCheckoutArgs>(
        (ref, args) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  final db = ref.watch(databaseServiceProvider);
  return EventCheckoutNotifier(db, args.eventId, args.tierQuantities, uid);
});
