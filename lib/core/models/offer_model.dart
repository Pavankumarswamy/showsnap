enum MilestoneType { uniqueMovies, totalBookings }

extension MilestoneTypeExt on MilestoneType {
  static MilestoneType fromString(String s) =>
      s == 'totalBookings' ? MilestoneType.totalBookings : MilestoneType.uniqueMovies;

  String get label {
    switch (this) {
      case MilestoneType.uniqueMovies:
        return 'Unique Movies';
      case MilestoneType.totalBookings:
        return 'Total Bookings';
    }
  }
}

enum RewardType { freeTicket, percentDiscount, flatDiscount }

extension RewardTypeExt on RewardType {
  static RewardType fromString(String s) {
    switch (s) {
      case 'percentDiscount':
        return RewardType.percentDiscount;
      case 'flatDiscount':
        return RewardType.flatDiscount;
      default:
        return RewardType.freeTicket;
    }
  }

  String get label {
    switch (this) {
      case RewardType.freeTicket:
        return 'Free Ticket';
      case RewardType.percentDiscount:
        return '% Discount';
      case RewardType.flatDiscount:
        return 'Flat Discount';
    }
  }
}

class OfferModel {
  final String offerId;
  final MilestoneType milestoneType;
  final int threshold;
  final RewardType rewardType;
  final double rewardValue;
  final int validityDays;
  final bool isActive;

  const OfferModel({
    required this.offerId,
    this.milestoneType = MilestoneType.uniqueMovies,
    required this.threshold,
    this.rewardType = RewardType.freeTicket,
    this.rewardValue = 0,
    this.validityDays = 30,
    this.isActive = true,
  });

  factory OfferModel.fromJson(String offerId, Map<dynamic, dynamic> json) =>
      OfferModel(
        offerId: offerId,
        milestoneType: MilestoneTypeExt.fromString(
            json['milestoneType']?.toString() ?? 'uniqueMovies'),
        threshold: (json['threshold'] as num?)?.toInt() ?? 1,
        rewardType: RewardTypeExt.fromString(
            json['rewardType']?.toString() ?? 'freeTicket'),
        rewardValue: (json['rewardValue'] as num?)?.toDouble() ?? 0,
        validityDays: (json['validityDays'] as num?)?.toInt() ?? 30,
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'milestoneType': milestoneType.name,
        'threshold': threshold,
        'rewardType': rewardType.name,
        'rewardValue': rewardValue,
        'validityDays': validityDays,
        'isActive': isActive,
      };
}
