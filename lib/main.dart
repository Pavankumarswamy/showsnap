import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/router.dart';
import 'core/config/theme.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    const ProviderScope(
      child: ShowSnapApp(),
    ),
  );
}

class ShowSnapApp extends ConsumerWidget {
  const ShowSnapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final notifService = ref.watch(notificationServiceProvider);

    return MaterialApp.router(
      title: 'ShowSnap',
      debugShowCheckedModeBanner: false,
      theme: ShowSnapTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        // Wire up foreground FCM messages as in-app banners
        notifService.handleForegroundMessages((message) {
          final notification = message.notification;
          if (notification != null) {
            final nav = router.routerDelegate.navigatorKey.currentContext;
            if (nav != null) {
              NotificationService.showInAppBanner(
                nav,
                title: notification.title ?? 'ShowSnap',
                body: notification.body ?? '',
              );
            }
          }
        });
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
