import 'seat_model.dart';

class ScreenModel {
  final String screenId;
  final String theaterId;
  final String name;
  final int position;
  final String technology; // '2D' | '3D' | 'IMAX' | '4DX'
  final int totalSeats;
  final List<SeatModel> seatLayout;
  final bool isUnderMaintenance;

  const ScreenModel({
    required this.screenId,
    required this.theaterId,
    required this.name,
    this.position = 1,
    this.technology = '2D',
    this.totalSeats = 0,
    this.seatLayout = const [],
    this.isUnderMaintenance = false,
  });

  factory ScreenModel.fromJson(String screenId, Map<dynamic, dynamic> json) {
    final seats = <SeatModel>[];
    if (json['seatLayout'] is Map) {
      (json['seatLayout'] as Map).forEach((k, v) {
        if (v is Map) seats.add(SeatModel.fromJson(k.toString(), v));
      });
    }
    seats.sort((a, b) {
      final rowCmp = a.row.compareTo(b.row);
      return rowCmp != 0 ? rowCmp : a.number.compareTo(b.number);
    });
    return ScreenModel(
      screenId: screenId,
      theaterId: json['theaterId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      position: (json['position'] as num?)?.toInt() ?? 1,
      technology: json['technology']?.toString() ?? '2D',
      totalSeats: (json['totalSeats'] as num?)?.toInt() ?? seats.length,
      seatLayout: seats,
      isUnderMaintenance: json['isUnderMaintenance'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    final layout = <String, dynamic>{};
    for (final s in seatLayout) {
      layout[s.seatId] = s.toJson();
    }
    return {
      'theaterId': theaterId,
      'name': name,
      'position': position,
      'technology': technology,
      'totalSeats': totalSeats,
      'seatLayout': layout,
      'isUnderMaintenance': isUnderMaintenance,
    };
  }
}
