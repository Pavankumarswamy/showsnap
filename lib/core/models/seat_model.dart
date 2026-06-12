enum SeatCategory { silver, gold, platinum }

extension SeatCategoryExt on SeatCategory {
  String get name {
    switch (this) {
      case SeatCategory.silver:
        return 'silver';
      case SeatCategory.gold:
        return 'gold';
      case SeatCategory.platinum:
        return 'platinum';
    }
  }

  String get label {
    switch (this) {
      case SeatCategory.silver:
        return 'Silver';
      case SeatCategory.gold:
        return 'Gold';
      case SeatCategory.platinum:
        return 'Platinum';
    }
  }

  static SeatCategory fromString(String s) {
    switch (s.toLowerCase()) {
      case 'gold':
        return SeatCategory.gold;
      case 'platinum':
        return SeatCategory.platinum;
      default:
        return SeatCategory.silver;
    }
  }
}

class SeatModel {
  final String seatId;
  final String row;
  final int number;
  final SeatCategory category;
  final int x;
  final int y;
  final bool isAccessible;

  const SeatModel({
    required this.seatId,
    required this.row,
    required this.number,
    required this.category,
    required this.x,
    required this.y,
    this.isAccessible = false,
  });

  factory SeatModel.fromJson(String seatId, Map<dynamic, dynamic> json) =>
      SeatModel(
        seatId: seatId,
        row: json['row']?.toString() ?? 'A',
        number: (json['number'] as num?)?.toInt() ?? 1,
        category:
            SeatCategoryExt.fromString(json['category']?.toString() ?? 'silver'),
        x: (json['x'] as num?)?.toInt() ?? 0,
        y: (json['y'] as num?)?.toInt() ?? 0,
        isAccessible: json['isAccessible'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'row': row,
        'number': number,
        'category': category.name,
        'x': x,
        'y': y,
        'isAccessible': isAccessible,
      };

  String get label => '$row$number';

  SeatModel copyWith({
    String? seatId,
    String? row,
    int? number,
    SeatCategory? category,
    int? x,
    int? y,
    bool? isAccessible,
  }) {
    return SeatModel(
      seatId: seatId ?? this.seatId,
      row: row ?? this.row,
      number: number ?? this.number,
      category: category ?? this.category,
      x: x ?? this.x,
      y: y ?? this.y,
      isAccessible: isAccessible ?? this.isAccessible,
    );
  }
}
