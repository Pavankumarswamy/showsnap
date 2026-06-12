class TheaterModel {
  final String theaterId;
  final String name;
  final String city;
  final String address;
  final double lat;
  final double lng;
  final String logoUrl;
  final String contactPhone;
  final String managerId;
  final bool isActive;

  const TheaterModel({
    required this.theaterId,
    required this.name,
    required this.city,
    required this.address,
    this.lat = 0,
    this.lng = 0,
    this.logoUrl = '',
    this.contactPhone = '',
    this.managerId = '',
    this.isActive = true,
  });

  factory TheaterModel.fromJson(String theaterId, Map<dynamic, dynamic> json) =>
      TheaterModel(
        theaterId: theaterId,
        name: json['name']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        logoUrl: json['logoUrl']?.toString() ?? '',
        contactPhone: json['contactPhone']?.toString() ?? '',
        managerId: json['managerId']?.toString() ?? '',
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'city': city,
        'address': address,
        'lat': lat,
        'lng': lng,
        'logoUrl': logoUrl,
        'contactPhone': contactPhone,
        'managerId': managerId,
        'isActive': isActive,
      };

  double distanceTo(double userLat, double userLng) {
    // Simple Euclidean approximation for sorting; use geolocator for real distance
    final dlat = lat - userLat;
    final dlng = lng - userLng;
    return (dlat * dlat + dlng * dlng);
  }
}
