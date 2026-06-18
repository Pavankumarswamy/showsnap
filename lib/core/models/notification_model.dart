import 'package:flutter/foundation.dart';

enum NotificationType { adRequest, general }

extension NotificationTypeExt on NotificationType {
  static NotificationType fromString(String s) {
    if (s == 'ad_request') return NotificationType.adRequest;
    return NotificationType.general;
  }

  String get nameString {
    switch (this) {
      case NotificationType.adRequest:
        return 'ad_request';
      case NotificationType.general:
        return 'general';
    }
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String relatedId;
  final bool isRead;
  final int createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(String id, Map<dynamic, dynamic> json) {
    return NotificationModel(
      id: id,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: NotificationTypeExt.fromString(json['type']?.toString() ?? 'general'),
      relatedId: json['relatedId']?.toString() ?? '',
      isRead: json['isRead'] == true,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'type': type.nameString,
        'relatedId': relatedId,
        'isRead': isRead,
        'createdAt': createdAt,
      };

  NotificationModel copyWith({
    bool? isRead,
  }) =>
      NotificationModel(
        id: id,
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
