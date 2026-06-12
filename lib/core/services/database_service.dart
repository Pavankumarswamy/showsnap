import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/address_model.dart';
import '../models/booking_model.dart';
import '../models/coupon_model.dart';
import '../models/event_model.dart';
import '../models/movie_model.dart';
import '../models/offer_model.dart';
import '../models/screen_model.dart';
import '../models/seat_status_model.dart';
import '../models/show_model.dart';
import '../models/theater_model.dart';
import '../models/user_model.dart';
import '../models/ad_request_model.dart';
import '../models/banner_model.dart';

class DatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ─── Shows ───────────────────────────────────────────────────────────────

  Stream<ShowModel> streamShow(String showId) {
    return _db
        .ref('${AppConstants.showsPath}/$showId')
        .onValue
        .map((e) => ShowModel.fromJson(showId, e.snapshot.value as Map));
  }

  Stream<List<ShowModel>> streamShowsForTheater(String theaterId) {
    return _db
        .ref(AppConstants.showsPath)
        .orderByChild('theaterId')
        .equalTo(theaterId)
        .onValue
        .map((e) {
          if (!e.snapshot.exists || e.snapshot.value == null) return [];
          final map = e.snapshot.value as Map;
          return map.entries
              .map((entry) => ShowModel.fromJson(entry.key.toString(), entry.value as Map))
              .toList();
        });
  }

  Future<List<ShowModel>> getShowsForTheater(String theaterId) async {
    final snap = await _db
        .ref(AppConstants.showsPath)
        .orderByChild('theaterId')
        .equalTo(theaterId)
        .get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((entry) => ShowModel.fromJson(entry.key.toString(), entry.value as Map))
        .toList();
  }

  Future<ShowModel?> getShow(String showId) async {
    final snap = await _db.ref('${AppConstants.showsPath}/$showId').get();
    if (!snap.exists || snap.value == null) return null;
    return ShowModel.fromJson(showId, snap.value as Map);
  }

  Future<List<ShowModel>> getShowsForMovie(
      String movieId, String theaterId) async {
    final snap = await _db
        .ref(AppConstants.showsPath)
        .orderByChild('movieId')
        .equalTo(movieId)
        .get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .where((e) {
          final v = e.value as Map?;
          return v?['theaterId'] == theaterId;
        })
        .map((e) => ShowModel.fromJson(e.key.toString(), e.value as Map))
        .toList();
  }

  Future<List<ShowModel>> getShowsForTheaterScreen(
      String theaterId, String screenId) async {
    final snap = await _db
        .ref(AppConstants.showsPath)
        .orderByChild('screenId')
        .equalTo(screenId)
        .get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .where((e) => (e.value as Map?)?['theaterId'] == theaterId)
        .map((e) => ShowModel.fromJson(e.key.toString(), e.value as Map))
        .toList();
  }

  Future<String> createShow(ShowModel show) async {
    final ref = _db.ref(AppConstants.showsPath).push();
    await ref.set(show.toJson());
    return ref.key!;
  }

  Future<void> updateShow(String showId, Map<String, dynamic> updates) =>
      _db.ref('${AppConstants.showsPath}/$showId').update(updates);

  // ─── Seat Locking ─────────────────────────────────────────────────────────

  /// RTDB transaction-based optimistic seat lock.
  /// Returns true if lock succeeded.
  Future<bool> lockSeat(String showId, String seatId, String uid) async {
    final ref =
        _db.ref('${AppConstants.showsPath}/$showId/seats/$seatId');
    final now = DateTime.now().millisecondsSinceEpoch;
    TransactionResult result = await ref.runTransaction((current) {
      if (current == null) {
        return Transaction.success({
          'status': 'locked',
          'lockedBy': uid,
          'lockedAt': now,
        });
      }
      final map = Map<String, dynamic>.from(current as Map);
      final status = map['status']?.toString() ?? 'available';
      if (status == 'booked') return Transaction.abort();
      if (status == 'locked') {
        final lockedAt = (map['lockedAt'] as num?)?.toInt() ?? 0;
        final isExpired = now - lockedAt > AppConstants.seatLockMinutes * 60000;
        if (!isExpired && map['lockedBy'] != uid) return Transaction.abort();
      }
      return Transaction.success({
        'status': 'locked',
        'lockedBy': uid,
        'lockedAt': now,
      });
    });
    return result.committed;
  }

  Future<void> unlockSeat(String showId, String seatId, String uid) async {
    final ref =
        _db.ref('${AppConstants.showsPath}/$showId/seats/$seatId');
    await ref.runTransaction((current) {
      if (current == null) return Transaction.success(null);
      final map = Map<String, dynamic>.from(current as Map);
      if (map['lockedBy'] != uid) return Transaction.abort();
      return Transaction.success({
        'status': 'available',
        'lockedBy': '',
        'lockedAt': 0,
      });
    });
  }

  Future<void> unlockSeats(
      String showId, List<String> seatIds, String uid) async {
    await Future.wait(seatIds.map((id) => unlockSeat(showId, id, uid)));
  }

  // ─── Bookings ─────────────────────────────────────────────────────────────

  Future<String> createBooking(BookingModel booking) async {
    final ref = _db.ref(AppConstants.bookingsPath).push();
    final bookingId = ref.key!;

    // Atomic: write booking, mark seats booked, decrement seatsAvailable
    final updates = <String, dynamic>{};
    updates['${AppConstants.bookingsPath}/$bookingId'] = booking.toJson()
      ..['bookingId'] = bookingId;
    for (final seat in booking.seats) {
      updates['${AppConstants.showsPath}/${booking.showId}/seats/${seat.seatId}'] =
          SeatStatusModel(status: SeatStatus.booked).toJson();
    }
    updates['${AppConstants.showsPath}/${booking.showId}/seatsAvailable'] =
        ServerValue.increment(-booking.seats.length);

    await _db.ref().update(updates);
    return bookingId;
  }

  Future<void> createBookingWithId(String bookingId, BookingModel booking) async {
    final updates = <String, dynamic>{};
    updates['${AppConstants.bookingsPath}/$bookingId'] = booking.toJson()
      ..['bookingId'] = bookingId;
    for (final seat in booking.seats) {
      updates['${AppConstants.showsPath}/${booking.showId}/seats/${seat.seatId}'] =
          SeatStatusModel(status: SeatStatus.booked).toJson();
    }
    updates['${AppConstants.showsPath}/${booking.showId}/seatsAvailable'] =
        ServerValue.increment(-booking.seats.length);

    await _db.ref().update(updates);
  }

  Future<void> bookCounterSeats(String showId, List<String> seatIds) async {
    // Atomic: mark seats booked, decrement seatsAvailable
    final updates = <String, dynamic>{};
    for (final seatId in seatIds) {
      updates['${AppConstants.showsPath}/$showId/seats/$seatId'] =
          const SeatStatusModel(status: SeatStatus.booked).toJson();
    }
    updates['${AppConstants.showsPath}/$showId/seatsAvailable'] =
        ServerValue.increment(-seatIds.length);

    await _db.ref().update(updates);
  }

  Future<void> updateBookingStatus(
      String bookingId, BookingStatus status) async {
    await _db
        .ref('${AppConstants.bookingsPath}/$bookingId/status')
        .set(status.name);
  }

  Future<void> updateBookingPayment(
      String bookingId, String paymentTxnId) async {
    await _db.ref('${AppConstants.bookingsPath}/$bookingId').update({
      'paymentTxnId': paymentTxnId,
      'status': BookingStatus.confirmed.name,
    });
  }

  Future<BookingModel?> getBooking(String bookingId) async {
    final snap =
        await _db.ref('${AppConstants.bookingsPath}/$bookingId').get();
    if (!snap.exists || snap.value == null) return null;
    return BookingModel.fromJson(bookingId, snap.value as Map);
  }

  Future<List<BookingModel>> getUserBookings(String uid) async {
    final snap = await _db
        .ref(AppConstants.bookingsPath)
        .orderByChild('uid')
        .equalTo(uid)
        .get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => BookingModel.fromJson(e.key.toString(), e.value as Map))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<BookingModel>> getAllBookings() async {
    final snap = await _db.ref(AppConstants.bookingsPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => BookingModel.fromJson(e.key.toString(), e.value as Map))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Stream<List<BookingModel>> streamUserBookings(String uid) {
    return _db
        .ref(AppConstants.bookingsPath)
        .orderByChild('uid')
        .equalTo(uid)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];
      final map = event.snapshot.value as Map;
      return map.entries
          .map((e) =>
              BookingModel.fromJson(e.key.toString(), e.value as Map))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  // ─── Movies ───────────────────────────────────────────────────────────────

  Future<List<MovieModel>> getAllMovies() async {
    final snap = await _db.ref(AppConstants.moviesPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => MovieModel.fromJson(e.key.toString(), e.value as Map))
        .toList();
  }

  Future<MovieModel?> getMovie(String movieId) async {
    final snap = await _db.ref('${AppConstants.moviesPath}/$movieId').get();
    if (!snap.exists || snap.value == null) return null;
    return MovieModel.fromJson(movieId, snap.value as Map);
  }

  Future<String> createMovie(MovieModel movie) async {
    final ref = _db.ref(AppConstants.moviesPath).push();
    await ref.set(movie.toJson());
    return ref.key!;
  }

  Future<void> updateMovie(String movieId, Map<String, dynamic> updates) =>
      _db.ref('${AppConstants.moviesPath}/$movieId').update(updates);

  // ─── Theaters ─────────────────────────────────────────────────────────────

  Future<List<TheaterModel>> getAllTheaters() async {
    final snap = await _db.ref(AppConstants.theatersPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => TheaterModel.fromJson(e.key.toString(), e.value as Map))
        .toList();
  }

  Future<TheaterModel?> getTheater(String theaterId) async {
    final snap =
        await _db.ref('${AppConstants.theatersPath}/$theaterId').get();
    if (!snap.exists || snap.value == null) return null;
    return TheaterModel.fromJson(theaterId, snap.value as Map);
  }

  Future<String> createTheater(TheaterModel theater) async {
    final ref = _db.ref(AppConstants.theatersPath).push();
    await ref.set(theater.toJson());
    return ref.key!;
  }

  Future<void> updateTheater(
          String theaterId, Map<String, dynamic> updates) =>
      _db.ref('${AppConstants.theatersPath}/$theaterId').update(updates);

  // ─── Screens ──────────────────────────────────────────────────────────────

  Future<List<ScreenModel>> getScreensForTheater(String theaterId) async {
    final snap = await _db
        .ref(AppConstants.screensPath)
        .orderByChild('theaterId')
        .equalTo(theaterId)
        .get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => ScreenModel.fromJson(e.key.toString(), e.value as Map))
        .toList();
  }

  Future<ScreenModel?> getScreen(String screenId) async {
    final snap = await _db.ref('${AppConstants.screensPath}/$screenId').get();
    if (!snap.exists || snap.value == null) return null;
    return ScreenModel.fromJson(screenId, snap.value as Map);
  }

  Stream<ScreenModel?> streamScreen(String screenId) {
    return _db
        .ref('${AppConstants.screensPath}/$screenId')
        .onValue
        .map((e) {
          if (!e.snapshot.exists || e.snapshot.value == null) return null;
          return ScreenModel.fromJson(screenId, e.snapshot.value as Map);
        });
  }

  Future<String> createScreen(ScreenModel screen) async {
    final ref = _db.ref(AppConstants.screensPath).push();
    await ref.set(screen.toJson());
    return ref.key!;
  }

  Future<void> updateScreen(String screenId, Map<String, dynamic> updates) =>
      _db.ref('${AppConstants.screensPath}/$screenId').update(updates);

  // ─── Coupons ──────────────────────────────────────────────────────────────

  Future<CouponModel?> getCoupon(String code) async {
    final snap =
        await _db.ref('${AppConstants.couponsPath}/$code').get();
    if (!snap.exists || snap.value == null) return null;
    return CouponModel.fromJson(code, snap.value as Map);
  }

  Future<List<CouponModel>> getAllCoupons() async {
    final snap = await _db.ref(AppConstants.couponsPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => CouponModel.fromJson(e.key.toString(), e.value as Map))
        .toList();
  }

  Future<void> saveCoupon(CouponModel coupon) =>
      _db.ref('${AppConstants.couponsPath}/${coupon.code}').set(coupon.toJson());

  Future<int> validateCoupon(
      String code, int orderValue, String category) async {
    final coupon = await getCoupon(code);
    if (coupon == null) throw Exception('Coupon not found');
    if (!coupon.isValid) throw Exception('Coupon is expired or exhausted');
    if (coupon.eligibleCategories.isNotEmpty &&
        !coupon.eligibleCategories.contains(category)) {
      throw Exception('Coupon not valid for $category seats');
    }
    if (orderValue < coupon.minOrderValue) {
      throw Exception(
          'Minimum order value ₹${coupon.minOrderValue} required');
    }
    return coupon.calculateDiscount(orderValue);
  }

  // ─── Offers ───────────────────────────────────────────────────────────────

  Future<List<OfferModel>> getAllOffers() async {
    final snap = await _db.ref(AppConstants.offersPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => OfferModel.fromJson(e.key.toString(), e.value as Map))
        .toList();
  }

  Future<void> saveOffer(OfferModel offer) =>
      _db.ref('${AppConstants.offersPath}/${offer.offerId}').set(offer.toJson());

  // ─── Events ───────────────────────────────────────────────────────────────

  Future<List<EventModel>> getAllEvents() async {
    final snap = await _db.ref(AppConstants.eventsPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => EventModel.fromJson(e.key.toString(), e.value as Map))
        .where((e) => e.isActive)
        .toList();
  }

  Future<List<EventModel>> getEventsForManager(String managerId) async {
    final snap = await _db.ref(AppConstants.eventsPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => EventModel.fromJson(e.key.toString(), e.value as Map))
        .where((e) => e.managerId == managerId)
        .toList();
  }

  Future<String> saveEvent(EventModel event) async {
    if (event.eventId.isEmpty) {
      final ref = _db.ref(AppConstants.eventsPath).push();
      await ref.set(event.toJson());
      return ref.key!;
    }
    await _db
        .ref('${AppConstants.eventsPath}/${event.eventId}')
        .set(event.toJson());
    return event.eventId;
  }

  Future<void> deleteEvent(String eventId) =>
      _db.ref('${AppConstants.eventsPath}/$eventId').remove();

  Future<void> bookEventTickets(
      BookingModel booking, EventModel event, Map<int, int> tierQuantities) async {
    final bookingId = booking.bookingId;
    final updates = <String, dynamic>{};
    
    updates['${AppConstants.bookingsPath}/$bookingId'] = booking.toJson()
      ..['bookingId'] = bookingId;
    
    final updatedTiers = List<TicketTier>.from(event.ticketTiers);
    tierQuantities.forEach((tierIdx, qty) {
      if (tierIdx >= 0 && tierIdx < updatedTiers.length) {
        final tier = updatedTiers[tierIdx];
        updatedTiers[tierIdx] = TicketTier(
          name: tier.name,
          price: tier.price,
          totalSeats: tier.totalSeats,
          availableSeats: (tier.availableSeats - qty).clamp(0, tier.totalSeats),
        );
      }
    });
    
    updates['${AppConstants.eventsPath}/${event.eventId}/ticketTiers'] =
        updatedTiers.map((t) => t.toJson()).toList();

    await _db.ref().update(updates);
  }

  // ─── Ad Requests ──────────────────────────────────────────────────────────

  Future<String> submitAdRequest(AdRequestModel request) async {
    final ref = _db.ref(AppConstants.adRequestsPath).push();
    final id = ref.key!;
    await ref.set(request.toJson()..['adRequestId'] = id);
    return id;
  }

  Future<String> createAdRequest(AdRequestModel request) =>
      submitAdRequest(request);

  Future<List<AdRequestModel>> getAdRequests({AdRequestStatus? status}) async {
    final snap = await _db.ref(AppConstants.adRequestsPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    final all = map.entries
        .map((e) =>
            AdRequestModel.fromJson(e.key.toString(), e.value as Map))
        .toList();
    if (status != null) return all.where((r) => r.status == status).toList();
    return all;
  }

  Stream<List<AdRequestModel>> streamUserAdRequests(String uid) {
    return _db
        .ref(AppConstants.adRequestsPath)
        .orderByChild('uid')
        .equalTo(uid)
        .onValue
        .map((e) {
      if (!e.snapshot.exists || e.snapshot.value == null) return [];
      final map = e.snapshot.value as Map;
      return map.entries
          .map((entry) =>
              AdRequestModel.fromJson(entry.key.toString(), entry.value as Map))
          .toList();
    });
  }

  Future<List<AdRequestModel>> getUserAdRequests(String uid) async {
    final snap = await _db
        .ref(AppConstants.adRequestsPath)
        .orderByChild('uid')
        .equalTo(uid)
        .get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) =>
            AdRequestModel.fromJson(e.key.toString(), e.value as Map))
        .toList();
  }

  Future<void> updateAdRequest(
          String requestId, Map<String, dynamic> updates) =>
      _db
          .ref('${AppConstants.adRequestsPath}/$requestId')
          .update(updates);

  // ─── Banners ─────────────────────────────────────────────────────────────

  Future<List<BannerModel>> getBanners() async {
    final snap = await _db.ref(AppConstants.bannersPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    final list = map.entries
        .map((e) => BannerModel.fromJson(e.key.toString(), e.value as Map))
        .where((b) => b.isActive)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Future<List<BannerModel>> getAllBanners() async {
    final snap = await _db.ref(AppConstants.bannersPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => BannerModel.fromJson(e.key.toString(), e.value as Map))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<String> saveBanner(BannerModel banner) async {
    if (banner.bannerId.isEmpty) {
      final ref = _db.ref(AppConstants.bannersPath).push();
      await ref.set(banner.toJson());
      return ref.key!;
    }
    await _db
        .ref('${AppConstants.bannersPath}/${banner.bannerId}')
        .set(banner.toJson());
    return banner.bannerId;
  }

  Future<void> deleteBanner(String bannerId) =>
      _db.ref('${AppConstants.bannersPath}/$bannerId').remove();

  // ─── Users ────────────────────────────────────────────────────────────────

  Future<List<UserModel>> getAllUsers() async {
    final snap = await _db.ref(AppConstants.usersPath).get();
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries
        .map((e) => UserModel.fromJson(e.key.toString(), e.value as Map))
        .toList();
  }

  Future<void> updateUser(String uid, Map<String, dynamic> updates) =>
      _db.ref('${AppConstants.usersPath}/$uid').update(updates);

  Future<void> addSavedAddress(String uid, AddressModel address) async {
    final ref = _db.ref('${AppConstants.usersPath}/$uid/savedAddresses').push();
    await ref.set(address.toMap());
  }

  Future<void> updateAffinityScores(
      String uid, Map<String, double> scores) async {
    final updates = <String, dynamic>{};
    scores.forEach((genre, score) {
      updates['affinityScores/$genre'] = score;
    });
    await _db.ref('${AppConstants.usersPath}/$uid').update(updates);
  }

  // ─── Movie Ratings ────────────────────────────────────────────────────────

  Future<double> getUserMovieRating(String movieId, String uid) async {
    final snap = await _db
        .ref('${AppConstants.moviesPath}/$movieId/ratings/$uid')
        .get();
    if (!snap.exists) return 0;
    return (snap.value as num?)?.toDouble() ?? 0;
  }

  Future<void> submitMovieRating(
      String movieId, String uid, double rating) async {
    await _db
        .ref('${AppConstants.moviesPath}/$movieId/ratings/$uid')
        .set(rating);
    // Recompute average
    final ratingsSnap =
        await _db.ref('${AppConstants.moviesPath}/$movieId/ratings').get();
    if (ratingsSnap.exists && ratingsSnap.value != null) {
      final ratingsMap = ratingsSnap.value as Map;
      final vals = ratingsMap.values
          .map((v) => (v as num).toDouble())
          .toList();
      final avg = vals.reduce((a, b) => a + b) / vals.length;
      await _db
          .ref('${AppConstants.moviesPath}/$movieId')
          .update({'rating': double.parse(avg.toStringAsFixed(1))});
    }
  }

  // ─── Wishlist ─────────────────────────────────────────────────────────────

  Future<Map<String, String>> getWishlist(String uid) async {
    final snap =
        await _db.ref('${AppConstants.usersPath}/$uid/wishlist').get();
    if (!snap.exists || snap.value == null) return {};
    final map = snap.value as Map;
    return Map<String, String>.fromEntries(
      map.entries.map((e) => MapEntry(
            e.key.toString(),
            e.value?.toString() ?? 'movie',
          )),
    );
  }

  Stream<Map<String, String>> streamWishlist(String uid) {
    return _db
        .ref('${AppConstants.usersPath}/$uid/wishlist')
        .onValue
        .map((e) {
      if (!e.snapshot.exists || e.snapshot.value == null) return {};
      final map = e.snapshot.value as Map;
      return Map<String, String>.fromEntries(
        map.entries.map((entry) => MapEntry(
              entry.key.toString(),
              entry.value?.toString() ?? 'movie',
            )),
      );
    });
  }

  Future<void> addToWishlist(
      String uid, String itemId, String type) async {
    await _db
        .ref('${AppConstants.usersPath}/$uid/wishlist/$itemId')
        .set(type);
  }

  Future<void> removeFromWishlist(String uid, String itemId) async {
    await _db
        .ref('${AppConstants.usersPath}/$uid/wishlist/$itemId')
        .remove();
  }

  Future<bool> isInWishlist(String uid, String itemId) async {
    final snap = await _db
        .ref('${AppConstants.usersPath}/$uid/wishlist/$itemId')
        .get();
    return snap.exists;
  }

  // ─── Notification Preferences ─────────────────────────────────────────────

  Stream<Map<String, bool>> streamNotifPrefs(String uid) {
    return _db
        .ref('${AppConstants.usersPath}/$uid/notificationPrefs')
        .onValue
        .map((e) {
      if (!e.snapshot.exists || e.snapshot.value == null) {
        return {
          'bookingUpdates': true,
          'newMovies': true,
          'offers': true,
          'eventReminders': true,
          'adRequests': true,
        };
      }
      final map = e.snapshot.value as Map;
      return Map<String, bool>.fromEntries(
        map.entries.map((entry) => MapEntry(
              entry.key.toString(),
              entry.value as bool? ?? true,
            )),
      );
    });
  }

  Future<void> updateNotifPref(
      String uid, String key, bool value) async {
    await _db
        .ref('${AppConstants.usersPath}/$uid/notificationPrefs/$key')
        .set(value);
  }

  // ─── Referral ─────────────────────────────────────────────────────────────

  Future<int> getReferralCount(String uid) async {
    final snap =
        await _db.ref('referrals/$uid/count').get();
    if (!snap.exists) return 0;
    return (snap.value as num?)?.toInt() ?? 0;
  }
}

final databaseServiceProvider =
    Provider<DatabaseService>((ref) => DatabaseService());
