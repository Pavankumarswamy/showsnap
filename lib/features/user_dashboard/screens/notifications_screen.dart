import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: ShowSnapColors.background,
      appBar: AppBar(
        backgroundColor: ShowSnapColors.surface,
        elevation: 0,
        title: const Text('Notifications'),
      ),
      body: uid == null
          ? const Center(
              child: Text('Please login to view notifications',
                  style: TextStyle(color: Colors.white70)))
          : StreamBuilder<List<NotificationModel>>(
              stream: ref.watch(databaseServiceProvider).watchNotifications(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: ShowSnapColors.primary),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading notifications',
                        style: const TextStyle(color: Colors.redAccent)),
                  );
                }

                final notifications = snapshot.data ?? [];
                if (notifications.isEmpty) {
                  return const Center(
                    child: Text('No new notifications',
                        style: TextStyle(color: Colors.white54, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    final dateStr = DateFormat('MMM d, h:mm a')
                        .format(DateTime.fromMillisecondsSinceEpoch(notif.createdAt));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: notif.isRead
                            ? ShowSnapColors.surface
                            : ShowSnapColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                        border: notif.isRead
                            ? null
                            : Border.all(color: ShowSnapColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        onTap: () {
                          if (!notif.isRead) {
                            ref
                                .read(databaseServiceProvider)
                                .markNotificationAsRead(uid, notif.id);
                          }
                          // Further navigation based on type can be added here
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ShowSnapColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            notif.type == NotificationType.adRequest
                                ? Icons.campaign_rounded
                                : Icons.notifications_rounded,
                            color: ShowSnapColors.primary,
                          ),
                        ),
                        title: Text(
                          notif.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              notif.body,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dateStr,
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: notif.isRead
                            ? null
                            : Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: ShowSnapColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
