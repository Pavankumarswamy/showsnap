import 'address_model.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String phone;
  final String city;
  final String avatarUrl;
  final String role; // 'admin' | 'theaterManager' | 'user'
  final List<String> preferredGenres;
  final Map<String, double> affinityScores; // genreId → score
  final Map<String, dynamic> rewards; // rewardId → reward data
  final int totalUniqueMoviesBooked;
  final bool isActive;
  final int createdAt;
  final List<AddressModel> savedAddresses;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.phone = '',
    this.city = '',
    this.avatarUrl = '',
    this.role = 'user',
    this.preferredGenres = const [],
    this.affinityScores = const {},
    this.rewards = const {},
    this.totalUniqueMoviesBooked = 0,
    this.isActive = true,
    this.createdAt = 0,
    this.savedAddresses = const [],
  });

  factory UserModel.fromJson(String uid, Map<dynamic, dynamic> json) {
    final scores = <String, double>{};
    if (json['affinityScores'] is Map) {
      (json['affinityScores'] as Map).forEach((k, v) {
        scores[k.toString()] = (v as num).toDouble();
      });
    }

    final genres = <String>[];
    if (json['preferredGenres'] is List) {
      genres.addAll((json['preferredGenres'] as List).map((e) => e.toString()));
    } else if (json['preferredGenres'] is Map) {
      genres.addAll(
          (json['preferredGenres'] as Map).values.map((e) => e.toString()));
    }

    final addresses = <AddressModel>[];
    if (json['savedAddresses'] is Map) {
      (json['savedAddresses'] as Map).forEach((k, v) {
        if (v is Map) {
          addresses.add(AddressModel.fromMap(v));
        }
      });
    } else if (json['savedAddresses'] is List) {
      for (final v in json['savedAddresses'] as List) {
        if (v is Map) {
          addresses.add(AddressModel.fromMap(v));
        }
      }
    }

    return UserModel(
      uid: uid,
      displayName: json['displayName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      preferredGenres: genres,
      affinityScores: scores,
      rewards: json['rewards'] is Map ? Map<String, dynamic>.from(json['rewards'] as Map) : {},
      totalUniqueMoviesBooked: (json['totalUniqueMoviesBooked'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      savedAddresses: addresses,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'city': city,
        'avatarUrl': avatarUrl,
        'role': role,
        'preferredGenres': preferredGenres,
        'affinityScores': affinityScores,
        'rewards': rewards,
        'totalUniqueMoviesBooked': totalUniqueMoviesBooked,
        'isActive': isActive,
        'createdAt': createdAt,
        'savedAddresses': savedAddresses.map((a) => a.toMap()).toList(),
      };

  UserModel copyWith({
    String? displayName,
    String? phone,
    String? city,
    String? avatarUrl,
    String? role,
    List<String>? preferredGenres,
    Map<String, double>? affinityScores,
    Map<String, dynamic>? rewards,
    int? totalUniqueMoviesBooked,
    bool? isActive,
    List<AddressModel>? savedAddresses,
  }) =>
      UserModel(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email,
        phone: phone ?? this.phone,
        city: city ?? this.city,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        preferredGenres: preferredGenres ?? this.preferredGenres,
        affinityScores: affinityScores ?? this.affinityScores,
        rewards: rewards ?? this.rewards,
        totalUniqueMoviesBooked:
            totalUniqueMoviesBooked ?? this.totalUniqueMoviesBooked,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        savedAddresses: savedAddresses ?? this.savedAddresses,
      );
}
