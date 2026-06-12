import 'seat_status_model.dart';

class ShowModel {
  final String showId;
  final String movieId;
  final String theaterId;
  final String screenId;
  final int startTs;
  final int endTs;
  final Map<String, int> pricing; // 'silver'|'gold'|'platinum' → price in Rs
  final bool bookingOpen;
  final Map<String, SeatStatusModel> seats; // seatId → SeatStatusModel
  final int seatsAvailable;

  const ShowModel({
    required this.showId,
    required this.movieId,
    required this.theaterId,
    required this.screenId,
    required this.startTs,
    required this.endTs,
    this.pricing = const {},
    this.bookingOpen = true,
    this.seats = const {},
    this.seatsAvailable = 0,
  });

  factory ShowModel.fromJson(String showId, Map<dynamic, dynamic> json) {
    final pricing = <String, int>{};
    if (json['pricing'] is Map) {
      (json['pricing'] as Map).forEach((k, v) {
        pricing[k.toString()] = (v as num).toInt();
      });
    }

    final seats = <String, SeatStatusModel>{};
    if (json['seats'] is Map) {
      (json['seats'] as Map).forEach((k, v) {
        if (v is Map) {
          seats[k.toString()] = SeatStatusModel.fromJson(v);
        }
      });
    }

    return ShowModel(
      showId: showId,
      movieId: json['movieId']?.toString() ?? '',
      theaterId: json['theaterId']?.toString() ?? '',
      screenId: json['screenId']?.toString() ?? '',
      startTs: (json['startTs'] as num?)?.toInt() ?? 0,
      endTs: (json['endTs'] as num?)?.toInt() ?? 0,
      pricing: pricing,
      bookingOpen: json['bookingOpen'] as bool? ?? true,
      seats: seats,
      seatsAvailable: (json['seatsAvailable'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    final seatsJson = <String, dynamic>{};
    seats.forEach((k, v) => seatsJson[k] = v.toJson());
    return {
      'movieId': movieId,
      'theaterId': theaterId,
      'screenId': screenId,
      'startTs': startTs,
      'endTs': endTs,
      'pricing': pricing,
      'bookingOpen': bookingOpen,
      'seats': seatsJson,
      'seatsAvailable': seatsAvailable,
    };
  }

  int priceForCategory(String category) => pricing[category] ?? 0;

  bool get isSoldOut => seatsAvailable == 0;

  /// availability percentage 0..1
  double availabilityRatio(int totalSeats) {
    if (totalSeats == 0) return 0;
    return seatsAvailable / totalSeats;
  }
}
