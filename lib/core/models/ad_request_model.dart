enum AdRequestStatus { pending, approved, rejected }

extension AdRequestStatusExt on AdRequestStatus {
  static AdRequestStatus fromString(String s) {
    switch (s) {
      case 'approved':
        return AdRequestStatus.approved;
      case 'rejected':
        return AdRequestStatus.rejected;
      default:
        return AdRequestStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case AdRequestStatus.pending:
        return 'Pending';
      case AdRequestStatus.approved:
        return 'Approved';
      case AdRequestStatus.rejected:
        return 'Rejected';
    }
  }
}

class AdRequestModel {
  final String requestId;
  final String uid;
  final String brandName;
  final String campaignTitle;
  final String description;
  final List<String> targetTheaters;
  final List<String> targetScreens;
  final List<String> creativeUrls; // Cloudinary URLs
  final int startDateTs;
  final int endDateTs;
  final String budgetRange; // e.g. '10000-50000'
  final AdRequestStatus status;
  final String adminNote;
  final int createdAt;

  const AdRequestModel({
    required this.requestId,
    required this.uid,
    required this.brandName,
    required this.campaignTitle,
    this.description = '',
    this.targetTheaters = const [],
    this.targetScreens = const [],
    this.creativeUrls = const [],
    this.startDateTs = 0,
    this.endDateTs = 0,
    this.budgetRange = '',
    this.status = AdRequestStatus.pending,
    this.adminNote = '',
    required this.createdAt,
  });

  factory AdRequestModel.fromJson(
      String requestId, Map<dynamic, dynamic> json) {
    List<String> _list(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is Map) return v.values.map((e) => e.toString()).toList();
      return [];
    }

    return AdRequestModel(
      requestId: requestId,
      uid: json['uid']?.toString() ?? '',
      brandName: json['brandName']?.toString() ?? '',
      campaignTitle: json['campaignTitle']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      targetTheaters: _list(json['targetTheaters']),
      targetScreens: _list(json['targetScreens']),
      creativeUrls: _list(json['creativeUrls']),
      startDateTs: (json['startDateTs'] as num?)?.toInt() ?? 0,
      endDateTs: (json['endDateTs'] as num?)?.toInt() ?? 0,
      budgetRange: json['budgetRange']?.toString() ?? '',
      status: AdRequestStatusExt.fromString(
          json['status']?.toString() ?? 'pending'),
      adminNote: json['adminNote']?.toString() ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'brandName': brandName,
        'campaignTitle': campaignTitle,
        'description': description,
        'targetTheaters': targetTheaters,
        'targetScreens': targetScreens,
        'creativeUrls': creativeUrls,
        'startDateTs': startDateTs,
        'endDateTs': endDateTs,
        'budgetRange': budgetRange,
        'status': status.name,
        'adminNote': adminNote,
        'createdAt': createdAt,
      };

  AdRequestModel copyWith({AdRequestStatus? status, String? adminNote}) =>
      AdRequestModel(
        requestId: requestId,
        uid: uid,
        brandName: brandName,
        campaignTitle: campaignTitle,
        description: description,
        targetTheaters: targetTheaters,
        targetScreens: targetScreens,
        creativeUrls: creativeUrls,
        startDateTs: startDateTs,
        endDateTs: endDateTs,
        budgetRange: budgetRange,
        status: status ?? this.status,
        adminNote: adminNote ?? this.adminNote,
        createdAt: createdAt,
      );
}
