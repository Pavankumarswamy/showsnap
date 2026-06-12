class BannerModel {
  final String bannerId;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String ctaText;
  final String ctaRoute;
  final int order;
  final bool isActive;

  const BannerModel({
    required this.bannerId,
    this.title = '',
    this.subtitle = '',
    this.imageUrl = '',
    this.ctaText = '',
    this.ctaRoute = '',
    this.order = 0,
    this.isActive = true,
  });

  factory BannerModel.fromJson(String id, Map<dynamic, dynamic> json) =>
      BannerModel(
        bannerId: id,
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString() ?? '',
        ctaText: json['ctaText']?.toString() ?? '',
        ctaRoute: json['ctaRoute']?.toString() ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'ctaText': ctaText,
        'ctaRoute': ctaRoute,
        'order': order,
        'isActive': isActive,
      };
}
