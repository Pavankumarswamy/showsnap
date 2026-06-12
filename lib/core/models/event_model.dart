class TicketTier {
  final String name;
  final int price;
  final int totalSeats;
  final int availableSeats;

  const TicketTier({
    required this.name,
    required this.price,
    required this.totalSeats,
    required this.availableSeats,
  });

  factory TicketTier.fromJson(Map<dynamic, dynamic> json) => TicketTier(
        name: json['name']?.toString() ?? '',
        price: (json['price'] as num?)?.toInt() ?? 0,
        totalSeats: (json['totalSeats'] as num?)?.toInt() ?? 0,
        availableSeats: (json['availableSeats'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'totalSeats': totalSeats,
        'availableSeats': availableSeats,
      };
}

class EventModel {
  final String eventId;
  final String name;
  final String organizer;
  final String venueId;
  final String venueName;
  final String city;
  final double lat;
  final double lng;
  final int startTs;
  final int endTs;
  final String category; // 'concert' | 'comedy' | 'sports' | 'theatre' | 'other'
  final String description;
  final String posterUrl;
  final List<TicketTier> ticketTiers;
  final bool isActive;

  const EventModel({
    required this.eventId,
    required this.name,
    this.organizer = '',
    this.venueId = '',
    this.venueName = '',
    this.city = '',
    this.lat = 0,
    this.lng = 0,
    required this.startTs,
    required this.endTs,
    this.category = 'other',
    this.description = '',
    this.posterUrl = '',
    this.ticketTiers = const [],
    this.isActive = true,
  });

  factory EventModel.fromJson(String eventId, Map<dynamic, dynamic> json) {
    final tiers = <TicketTier>[];
    if (json['ticketTiers'] is List) {
      for (final t in json['ticketTiers'] as List) {
        if (t is Map) tiers.add(TicketTier.fromJson(t));
      }
    } else if (json['ticketTiers'] is Map) {
      (json['ticketTiers'] as Map).forEach((_, v) {
        if (v is Map) tiers.add(TicketTier.fromJson(v));
      });
    }
    return EventModel(
      eventId: eventId,
      name: json['name']?.toString() ?? '',
      organizer: json['organizer']?.toString() ?? '',
      venueId: json['venueId']?.toString() ?? '',
      venueName: json['venueName']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      startTs: (json['startTs'] as num?)?.toInt() ?? 0,
      endTs: (json['endTs'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? 'other',
      description: json['description']?.toString() ?? '',
      posterUrl: json['posterUrl']?.toString() ?? '',
      ticketTiers: tiers,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'organizer': organizer,
        'venueId': venueId,
        'venueName': venueName,
        'city': city,
        'lat': lat,
        'lng': lng,
        'startTs': startTs,
        'endTs': endTs,
        'category': category,
        'description': description,
        'posterUrl': posterUrl,
        'ticketTiers': ticketTiers.map((t) => t.toJson()).toList(),
        'isActive': isActive,
      };

  int get lowestPrice {
    if (ticketTiers.isEmpty) return 0;
    return ticketTiers.map((t) => t.price).reduce((a, b) => a < b ? a : b);
  }
}
