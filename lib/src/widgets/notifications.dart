import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../models/dashboard.dart';

class TenantUnreadNotificationBanner extends StatelessWidget {
  const TenantUnreadNotificationBanner(
      {required this.notification, this.onTap, super.key});

  final NotificationItem notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFF4E5),
        child: ListTile(
          leading:
              const Icon(Icons.mark_email_unread, color: IvoryColors.orange),
          title: Text(notification.title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
              '${notification.message}\n${notification.propertyTitle}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          onTap: onTap,
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class NotificationTile extends StatelessWidget {
  const NotificationTile(this.notification, {this.onTap, super.key});

  final NotificationItem notification;

  /// Marks the notification read and opens the related conversation.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(
              notification.isRead
                  ? Icons.notifications_none
                  : Icons.notifications_active,
              color: notification.isRead ? Colors.grey : IvoryColors.orange),
          title: Text(notification.title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
              '${notification.message}\n${notification.propertyTitle}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          onTap: onTap,
          trailing: notification.isRead
              ? null
              : const Icon(Icons.circle, size: 10, color: IvoryColors.orange),
        ),
      );
}
