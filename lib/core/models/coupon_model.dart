enum DiscountType { percentage, flat }

extension DiscountTypeExt on DiscountType {
  static DiscountType fromString(String s) =>
      s == 'flat' ? DiscountType.flat : DiscountType.percentage;
}

class CouponModel {
  final String code;
  final DiscountType discountType;
  final double discountValue; // % or ₹ flat
  final int maxUses;
  final int currentUses;
  final int expiryTs; // epoch ms
  final int minOrderValue;
  final List<String> eligibleCategories; // ['silver','gold','platinum'] or empty = all
  final bool isActive;
  final String managerId; // Which Event Manager owns this coupon (empty if global)

  const CouponModel({
    required this.code,
    this.discountType = DiscountType.percentage,
    required this.discountValue,
    this.maxUses = 100,
    this.currentUses = 0,
    this.expiryTs = 0,
    this.minOrderValue = 0,
    this.eligibleCategories = const [],
    this.isActive = true,
    this.managerId = '',
  });

  factory CouponModel.fromJson(String code, Map<dynamic, dynamic> json) {
    List<String> _list(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is Map) return v.values.map((e) => e.toString()).toList();
      return [];
    }

    return CouponModel(
      code: code,
      discountType: DiscountTypeExt.fromString(
          json['discountType']?.toString() ?? 'percentage'),
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
      maxUses: (json['maxUses'] as num?)?.toInt() ?? 100,
      currentUses: (json['currentUses'] as num?)?.toInt() ?? 0,
      expiryTs: (json['expiryTs'] as num?)?.toInt() ?? 0,
      minOrderValue: (json['minOrderValue'] as num?)?.toInt() ?? 0,
      eligibleCategories: _list(json['eligibleCategories']),
      isActive: json['isActive'] as bool? ?? true,
      managerId: json['managerId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'discountType': discountType.name,
        'discountValue': discountValue,
        'maxUses': maxUses,
        'currentUses': currentUses,
        'expiryTs': expiryTs,
        'minOrderValue': minOrderValue,
        'eligibleCategories': eligibleCategories,
        'isActive': isActive,
        'managerId': managerId,
      };

  bool get isExpired =>
      expiryTs > 0 && DateTime.now().millisecondsSinceEpoch > expiryTs;

  bool get isExhausted => maxUses > 0 && currentUses >= maxUses;

  bool get isValid => isActive && !isExpired && !isExhausted;

  int calculateDiscount(int orderValue) {
    if (!isValid) return 0;
    if (orderValue < minOrderValue) return 0;
    if (discountType == DiscountType.percentage) {
      return ((orderValue * discountValue) / 100).floor();
    }
    return discountValue.floor();
  }
}
