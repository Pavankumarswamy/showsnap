enum BookingStatus { pending, confirmed, cancelled, redeemed }

extension BookingStatusExt on BookingStatus {
  static BookingStatus fromString(String s) {
    switch (s) {
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'redeemed':
        return BookingStatus.redeemed;
      default:
        return BookingStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.redeemed:
        return 'Redeemed';
    }
  }
}

class BookedSeatInfo {
  final String seatId;
  final String row;
  final int number;
  final String category;
  final int price;

  const BookedSeatInfo({
    required this.seatId,
    required this.row,
    required this.number,
    required this.category,
    required this.price,
  });

  factory BookedSeatInfo.fromJson(Map<dynamic, dynamic> json) =>
      BookedSeatInfo(
        seatId: json['seatId']?.toString() ?? '',
        row: json['row']?.toString() ?? '',
        number: (json['number'] as num?)?.toInt() ?? 0,
        category: json['category']?.toString() ?? 'silver',
        price: (json['price'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'seatId': seatId,
        'row': row,
        'number': number,
        'category': category,
        'price': price,
      };

  String get label => '$row$number';
}

class BookingModel {
  final String bookingId;
  final String uid;
  final String showId;
  final String movieId;
  final String movieTitle;
  final String theaterId;
  final String theaterName;
  final String screenId;
  final String screenName;
  final int showStartTs;
  final List<BookedSeatInfo> seats;
  final int subtotal;
  final int convenienceFee;
  final String couponCode;
  final int discountApplied;
  final int totalAmount;
  final BookingStatus status;
  final String eTicketUrl;
  final String paymentTxnId;
  final int createdAt;
  final String locationUrl;

  const BookingModel({
    required this.bookingId,
    required this.uid,
    required this.showId,
    required this.movieId,
    required this.movieTitle,
    required this.theaterId,
    required this.theaterName,
    required this.screenId,
    required this.screenName,
    required this.showStartTs,
    required this.seats,
    required this.subtotal,
    this.convenienceFee = 20,
    this.couponCode = '',
    this.discountApplied = 0,
    required this.totalAmount,
    this.status = BookingStatus.pending,
    this.eTicketUrl = '',
    this.paymentTxnId = '',
    required this.createdAt,
    this.locationUrl = '',
  });

  factory BookingModel.fromJson(
      String bookingId, Map<dynamic, dynamic> json) {
    final seats = <BookedSeatInfo>[];
    if (json['seats'] is List) {
      for (final s in json['seats'] as List) {
        if (s is Map) seats.add(BookedSeatInfo.fromJson(s));
      }
    } else if (json['seats'] is Map) {
      (json['seats'] as Map).forEach((_, v) {
        if (v is Map) seats.add(BookedSeatInfo.fromJson(v));
      });
    }
    return BookingModel(
      bookingId: bookingId,
      uid: json['uid']?.toString() ?? '',
      showId: json['showId']?.toString() ?? '',
      movieId: json['movieId']?.toString() ?? '',
      movieTitle: json['movieTitle']?.toString() ?? '',
      theaterId: json['theaterId']?.toString() ?? '',
      theaterName: json['theaterName']?.toString() ?? '',
      screenId: json['screenId']?.toString() ?? '',
      screenName: json['screenName']?.toString() ?? '',
      showStartTs: (json['showStartTs'] as num?)?.toInt() ?? 0,
      seats: seats,
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      convenienceFee: (json['convenienceFee'] as num?)?.toInt() ?? 20,
      couponCode: json['couponCode']?.toString() ?? '',
      discountApplied: (json['discountApplied'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
      status: BookingStatusExt.fromString(json['status']?.toString() ?? 'pending'),
      eTicketUrl: json['eTicketUrl']?.toString() ?? '',
      paymentTxnId: json['paymentTxnId']?.toString() ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      locationUrl: json['locationUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'showId': showId,
        'movieId': movieId,
        'movieTitle': movieTitle,
        'theaterId': theaterId,
        'theaterName': theaterName,
        'screenId': screenId,
        'screenName': screenName,
        'showStartTs': showStartTs,
        'seats': seats.map((s) => s.toJson()).toList(),
        'subtotal': subtotal,
        'convenienceFee': convenienceFee,
        'couponCode': couponCode,
        'discountApplied': discountApplied,
        'totalAmount': totalAmount,
        'status': status.name,
        'eTicketUrl': eTicketUrl,
        'paymentTxnId': paymentTxnId,
        'createdAt': createdAt,
        'locationUrl': locationUrl,
      };

  BookingModel copyWith({BookingStatus? status, String? eTicketUrl, String? paymentTxnId, String? locationUrl}) =>
      BookingModel(
        bookingId: bookingId,
        uid: uid,
        showId: showId,
        movieId: movieId,
        movieTitle: movieTitle,
        theaterId: theaterId,
        theaterName: theaterName,
        screenId: screenId,
        screenName: screenName,
        showStartTs: showStartTs,
        seats: seats,
        subtotal: subtotal,
        convenienceFee: convenienceFee,
        couponCode: couponCode,
        discountApplied: discountApplied,
        totalAmount: totalAmount,
        status: status ?? this.status,
        eTicketUrl: eTicketUrl ?? this.eTicketUrl,
        paymentTxnId: paymentTxnId ?? this.paymentTxnId,
        createdAt: createdAt,
      );
}
