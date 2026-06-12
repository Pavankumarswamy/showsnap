enum SeatStatus { available, locked, booked }

extension SeatStatusExt on SeatStatus {
  static SeatStatus fromString(String s) {
    switch (s) {
      case 'locked':
        return SeatStatus.locked;
      case 'booked':
        return SeatStatus.booked;
      default:
        return SeatStatus.available;
    }
  }
}

class SeatStatusModel {
  final SeatStatus status;
  final String lockedBy; // uid
  final int lockedAt; // epoch ms; 0 if not locked

  const SeatStatusModel({
    this.status = SeatStatus.available,
    this.lockedBy = '',
    this.lockedAt = 0,
  });

  factory SeatStatusModel.fromJson(Map<dynamic, dynamic> json) =>
      SeatStatusModel(
        status: SeatStatusExt.fromString(json['status']?.toString() ?? 'available'),
        lockedBy: json['lockedBy']?.toString() ?? '',
        lockedAt: (json['lockedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'lockedBy': lockedBy,
        'lockedAt': lockedAt,
      };

  bool get isExpiredLock {
    if (status != SeatStatus.locked) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - lockedAt > 8 * 60 * 1000;
  }
}
