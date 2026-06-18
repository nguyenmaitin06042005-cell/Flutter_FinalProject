import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification_model.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  String get currentUserKey {
    final user = _auth.currentUser;

    if (user == null) return 'guest';
    if (user.uid.trim().isNotEmpty) return user.uid.trim();
    if ((user.email ?? '').trim().isNotEmpty) {
      return user.email!.trim().toLowerCase();
    }

    return 'guest';
  }

  Stream<List<AppNotification>> watchNotifications() {
    final userKey = currentUserKey;

    return _notifications
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final values = snapshot.docs
          .map(AppNotification.fromFirestore)
          .where((notification) => notification.isVisibleTo(userKey))
          .toList();

      values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return values;
    });
  }

  Stream<int> watchUnreadCount() {
    final userKey = currentUserKey;

    return watchNotifications().map(
      (notifications) => notifications
          .where((notification) => !notification.isReadBy(userKey))
          .length,
    );
  }

  Future<void> createNotification({
    required String title,
    required String message,
    required AppNotificationType type,
    String referenceId = '',
    String projectName = '',
    List<String> recipientIds = const <String>[],
  }) async {
    await _notifications.add(<String, dynamic>{
      'title': title.trim(),
      'message': message.trim(),
      'type': notificationTypeToString(type),
      'createdAt': FieldValue.serverTimestamp(),
      'recipientIds': recipientIds,
      'readBy': <String>[],
      'referenceId': referenceId.trim(),
      'projectName': projectName.trim(),
    });
  }

  Future<void> createNewLogbookNotification({
    required String userName,
    required String activityType,
    required String projectName,
    String referenceId = '',
    List<String> recipientIds = const <String>[],
  }) {
    return createNotification(
      title: 'Nhật ký mới',
      message:
          '$userName vừa thêm nhật ký "$activityType" cho $projectName.',
      type: AppNotificationType.newLogbook,
      referenceId: referenceId,
      projectName: projectName,
      recipientIds: recipientIds,
    );
  }

  Future<void> createNewFileNotification({
    required String uploaderName,
    required String fileName,
    required String projectName,
    String referenceId = '',
    List<String> recipientIds = const <String>[],
  }) {
    return createNotification(
      title: 'Hồ sơ mới',
      message:
          '$uploaderName vừa upload "$fileName" cho $projectName.',
      type: AppNotificationType.newFile,
      referenceId: referenceId,
      projectName: projectName,
      recipientIds: recipientIds,
    );
  }

  Future<void> createNewProjectNotification({
    required String creatorName,
    required String projectName,
    String referenceId = '',
    List<String> recipientIds = const <String>[],
  }) {
    return createNotification(
      title: 'Dự án mới',
      message: '$creatorName vừa tạo dự án "$projectName".',
      type: AppNotificationType.newProject,
      referenceId: referenceId,
      projectName: projectName,
      recipientIds: recipientIds,
    );
  }

  Future<void> createUpdateRequestNotification({
    required String requesterName,
    required String content,
    String projectName = '',
    String referenceId = '',
    List<String> recipientIds = const <String>[],
  }) {
    return createNotification(
      title: 'Yêu cầu cập nhật dữ liệu',
      message: '$requesterName yêu cầu cập nhật: $content',
      type: AppNotificationType.updateRequest,
      referenceId: referenceId,
      projectName: projectName,
      recipientIds: recipientIds,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;

    await _notifications.doc(notificationId).update(<String, dynamic>{
      'readBy': FieldValue.arrayUnion(<String>[currentUserKey]),
    });
  }

  Future<void> markAsUnread(String notificationId) async {
    if (notificationId.trim().isEmpty) return;

    await _notifications.doc(notificationId).update(<String, dynamic>{
      'readBy': FieldValue.arrayRemove(<String>[currentUserKey]),
    });
  }

  Future<void> markAllAsRead(
    List<AppNotification> notifications,
  ) async {
    final unread = notifications
        .where(
          (notification) =>
              !notification.isReadBy(currentUserKey),
        )
        .toList();

    if (unread.isEmpty) return;

    const chunkSize = 450;

    for (int start = 0; start < unread.length; start += chunkSize) {
      final end = (start + chunkSize < unread.length)
          ? start + chunkSize
          : unread.length;

      final batch = _firestore.batch();

      for (final notification in unread.sublist(start, end)) {
        batch.update(
          _notifications.doc(notification.id),
          <String, dynamic>{
            'readBy': FieldValue.arrayUnion(
              <String>[currentUserKey],
            ),
          },
        );
      }

      await batch.commit();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    if (notificationId.trim().isEmpty) return;
    await _notifications.doc(notificationId).delete();
  }
}
