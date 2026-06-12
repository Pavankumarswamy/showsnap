import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages handled automatically by FCM
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final token = await _fcm.getToken();
    debugPrint('FCM Token: $token');
  }

  Future<void> subscribeToTopic(String topic) =>
      _fcm.subscribeToTopic(topic);

  Future<void> unsubscribeFromTopic(String topic) =>
      _fcm.unsubscribeFromTopic(topic);

  Future<String?> getToken() => _fcm.getToken();

  void handleForegroundMessages(
      void Function(RemoteMessage message) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  void handleMessageOpenedApp(
      void Function(RemoteMessage message) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  Future<RemoteMessage?> getInitialMessage() =>
      _fcm.getInitialMessage();

  /// Show an in-app overlay banner that slides down from top.
  /// Call this from handleForegroundMessages inside main.dart.
  static void showInAppBanner(
    BuildContext context, {
    required String title,
    required String body,
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _InAppBanner(
        title: title,
        body: body,
        onTap: () {
          entry.remove();
          onTap?.call();
        },
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }
}

// ─── In-App Notification Banner ───────────────────────────────────────────────

class _InAppBanner extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppBanner({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).viewPadding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
              boxShadow: ShowSnapShadow.elevated,
              border: const Border(
                left: BorderSide(color: ShowSnapColors.primary, width: 4),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ShowSnapColors.primaryLighter,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_active_outlined,
                      color: ShowSnapColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShowSnapColors.grey600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close,
                      size: 16, color: ShowSnapColors.grey600),
                ),
              ],
            ),
          )
              .animate()
              .slideY(
                begin: -1.0,
                end: 0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              )
              .fadeIn(duration: const Duration(milliseconds: 200)),
        ),
      ),
    );
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
