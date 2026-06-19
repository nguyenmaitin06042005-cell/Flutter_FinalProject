import 'package:flutter/material.dart';

import '../models/app_notification_model.dart';
import '../services/notification_service.dart';
import '../widgets/app_colors.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    this.onOpenAll,
    this.onNotificationTap,
    this.iconSize = 24,
  });

  final VoidCallback? onOpenAll;
  final ValueChanged<AppNotification>? onNotificationTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();

    return StreamBuilder<int>(
      stream: service.watchUnreadCount(),
      initialData: 0,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 0,
              child: IconButton(
                tooltip: 'Thông báo',
                onPressed: () {
                  _showNotificationPopup(
                    context,
                    service,
                  );
                },
                icon: Icon(
                  Icons.notifications_none_rounded,
                  size: iconSize,
                  color: const Color(0xff17211b),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -3,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 19,
                    minHeight: 19,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xffef4444),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showNotificationPopup(
    BuildContext context,
    NotificationService service,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notification Center',
      barrierColor: Colors.black.withOpacity(0.12),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(
                top: 58,
                right: 18,
                left: 18,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 420,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xffe2e9e4),
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: StreamBuilder<List<AppNotification>>(
                    stream: service.watchNotifications(),
                    builder: (context, snapshot) {
                      final notifications =
                          snapshot.data ?? <AppNotification>[];
                      final latest = notifications.take(6).toList();
                      final unreadCount = notifications
                          .where(
                            (notification) => !notification.isReadBy(
                              service.currentUserKey,
                            ),
                          )
                          .length;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              18,
                              14,
                              10,
                              12,
                            ),
                            child: Row(
                              children: <Widget>[
                                const Expanded(
                                  child: Text(
                                    'Thông báo',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xff17211b),
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  TextButton(
                                    onPressed: () async {
                                      await service.markAllAsRead(
                                        notifications,
                                      );
                                    },
                                    child: const Text(
                                      'Đã đọc tất cả',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'Đóng',
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    size: 19,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData)
                            const Padding(
                              padding: EdgeInsets.all(28),
                              child: CircularProgressIndicator(),
                            )
                          else if (latest.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 36,
                              ),
                              child: Column(
                                children: <Widget>[
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 42,
                                    color: Color(0xff9aa69e),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Chưa có thông báo.',
                                    style: TextStyle(
                                      color: Color(0xff718078),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: latest.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  indent: 66,
                                ),
                                itemBuilder: (context, index) {
                                  final notification = latest[index];
                                  final isRead = notification.isReadBy(
                                    service.currentUserKey,
                                  );

                                  return _PopupNotificationTile(
                                    notification: notification,
                                    isRead: isRead,
                                    onTap: () async {
                                      if (!isRead) {
                                        await service.markAsRead(
                                          notification.id,
                                        );
                                      }

                                      onNotificationTap?.call(notification);
                                    },
                                  );
                                },
                              ),
                            ),
                          const Divider(height: 1),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                onOpenAll?.call();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Xem tất cả thông báo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.96,
              end: 1,
            ).animate(animation),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }
}

class _PopupNotificationTile extends StatelessWidget {
  const _PopupNotificationTile({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _notificationVisual(notification.type);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead ? Colors.white : const Color(0xfff3faf5),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                style.icon,
                size: 19,
                color: style.foreground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isRead ? FontWeight.w600 : FontWeight.w800,
                            color: const Color(0xff263029),
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xffef4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.3,
                      height: 1.35,
                      color: Color(0xff6d7971),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xff8a958e),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationVisual {
  final IconData icon;
  final Color foreground;
  final Color background;

  const NotificationVisual({
    required this.icon,
    required this.foreground,
    required this.background,
  });
}

NotificationVisual _notificationVisual(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.newLogbook:
      return const NotificationVisual(
        icon: Icons.menu_book_outlined,
        foreground: Color(0xff1a8f4c),
        background: Color(0xffe8f7ed),
      );
    case AppNotificationType.newFile:
      return const NotificationVisual(
        icon: Icons.insert_drive_file_outlined,
        foreground: Color(0xff3678bb),
        background: Color(0xffeaf3fd),
      );
    case AppNotificationType.newProject:
      return const NotificationVisual(
        icon: Icons.forest_outlined,
        foreground: Color(0xff168a45),
        background: Color(0xffe7f6eb),
      );
    case AppNotificationType.updateRequest:
      return const NotificationVisual(
        icon: Icons.edit_note_outlined,
        foreground: Color(0xffd97706),
        background: Color(0xfffff3df),
      );
    case AppNotificationType.projectApprovalRequest:
      return const NotificationVisual(
        icon: Icons.pending_actions_outlined,
        foreground: Color(0xffb45309),
        background: Color(0xfffff0c0),
      );
    case AppNotificationType.projectApproved:
      return const NotificationVisual(
        icon: Icons.check_circle_outline,
        foreground: Color(0xff168a45),
        background: Color(0xffe8f7ed),
      );
    case AppNotificationType.projectRejected:
      return const NotificationVisual(
        icon: Icons.cancel_outlined,
        foreground: Color(0xffc53d3d),
        background: Color(0xffffe4e4),
      );
    case AppNotificationType.workerCheckin:
      return const NotificationVisual(
        icon: Icons.location_on_outlined,
        foreground: Color(0xff2563eb),
        background: Color(0xffeff6ff),
      );
    case AppNotificationType.logbookEntry:
      return const NotificationVisual(
        icon: Icons.menu_book_outlined,
        foreground: Color(0xff0ea5e9),
        background: Color(0xfff0f9ff),
      );
    case AppNotificationType.treeData:
      return const NotificationVisual(
        icon: Icons.park_outlined,
        foreground: Color(0xff16a34a),
        background: Color(0xfff0fdf4),
      );
    case AppNotificationType.plotUpdate:
      return const NotificationVisual(
        icon: Icons.edit_location_alt_outlined,
        foreground: Color(0xffd97706), // Amber-600
        background: Color(0xfffef3c7), // Amber-100
      );
    case AppNotificationType.general:
      return const NotificationVisual(
        icon: Icons.notifications_none,
        foreground: Color(0xff6c5bb6),
        background: Color(0xfff0edff),
      );
  }
}

String _timeAgo(DateTime value) {
  final difference = DateTime.now().difference(value);

  if (difference.inMinutes < 1) return 'Vừa xong';
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} phút trước';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} giờ trước';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} ngày trước';
  }

  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}
