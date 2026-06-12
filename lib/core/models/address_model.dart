import 'package:uuid/uuid.dart';

enum AddressLabel { home, work, office, college, other }

class AddressModel {
  final String id;
  final AddressLabel label;
  final String fullAddress;
  final String? city;
  final double lat;
  final double lng;
  final int createdAt;

  const AddressModel({
    required this.id,
    required this.label,
    required this.fullAddress,
    this.city,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });

  factory AddressModel.create({
    required AddressLabel label,
    required String fullAddress,
    String? city,
    required double lat,
    required double lng,
  }) {
    return AddressModel(
      id: const Uuid().v4(),
      label: label,
      fullAddress: fullAddress,
      city: city,
      lat: lat,
      lng: lng,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory AddressModel.fromMap(Map<dynamic, dynamic> map) {
    return AddressModel(
      id: map['id']?.toString() ?? '',
      label: AddressLabel.values.firstWhere(
        (e) => e.name == (map['label'] ?? 'other'),
        orElse: () => AddressLabel.other,
      ),
      fullAddress: map['fullAddress']?.toString() ?? '',
      city: map['city']?.toString(),
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label.name,
      'fullAddress': fullAddress,
      'city': city,
      'lat': lat,
      'lng': lng,
      'createdAt': createdAt,
    };
  }

  AddressModel copyWith({
    String? id,
    AddressLabel? label,
    String? fullAddress,
    String? city,
    double? lat,
    double? lng,
    int? createdAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      city: city ?? this.city,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddressModel &&
        other.id == id &&
        other.label == label &&
        other.fullAddress == fullAddress &&
        other.city == city &&
        other.lat == lat &&
        other.lng == lng &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        label.hashCode ^
        fullAddress.hashCode ^
        city.hashCode ^
        lat.hashCode ^
        lng.hashCode ^
        createdAt.hashCode;
  }
}
