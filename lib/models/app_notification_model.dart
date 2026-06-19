import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  newLogbook,
  newFile,
  newProject,
  updateRequest,
  projectApprovalRequest, // Admin nhận: owner yêu cầu tạo project
  projectApproved,        // Owner nhận: admin đã duyệt
  projectRejected,        // Owner nhận: admin từ chối
  workerCheckin,
  logbookEntry,
  treeData,
  plotUpdate,
  general,
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final AppNotificationType type;
  final DateTime createdAt;
  final List<String> recipientIds;
  final List<String> readBy;
  final String referenceId;
  final String projectName;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.recipientIds,
    required this.readBy,
    required this.referenceId,
    required this.projectName,
  });

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return AppNotification(
      id: document.id,
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      type: notificationTypeFromString(
        (data['type'] ?? 'general').toString(),
      ),
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      recipientIds: _toStringList(data['recipientIds']),
      readBy: _toStringList(data['readBy']),
      referenceId: (data['referenceId'] ?? '').toString(),
      projectName: (data['projectName'] ?? '').toString(),
    );
  }

  bool isReadBy(String userKey) => readBy.contains(userKey);

  bool isVisibleTo(String userKey) {
    return recipientIds.isEmpty || recipientIds.contains(userKey);
  }

  static List<String> _toStringList(dynamic value) {
    if (value is! Iterable) return <String>[];

    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }
}

String notificationTypeToString(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.newLogbook:
      return 'new_logbook';
    case AppNotificationType.newFile:
      return 'new_file';
    case AppNotificationType.newProject:
      return 'new_project';
    case AppNotificationType.updateRequest:
      return 'update_request';
    case AppNotificationType.projectApprovalRequest:
      return 'project_approval_request';
    case AppNotificationType.projectApproved:
      return 'project_approved';
    case AppNotificationType.projectRejected:
      return 'project_rejected';
    case AppNotificationType.workerCheckin:
      return 'worker_checkin';
    case AppNotificationType.logbookEntry:
      return 'logbook_entry';
    case AppNotificationType.treeData:
      return 'tree_data';
    case AppNotificationType.plotUpdate:
      return 'plot_update';
    case AppNotificationType.general:
      return 'general';
  }
}

AppNotificationType notificationTypeFromString(String value) {
  switch (value) {
    case 'new_logbook':
      return AppNotificationType.newLogbook;
    case 'new_file':
      return AppNotificationType.newFile;
    case 'new_project':
      return AppNotificationType.newProject;
    case 'update_request':
      return AppNotificationType.updateRequest;
    case 'project_approval_request':
      return AppNotificationType.projectApprovalRequest;
    case 'project_approved':
      return AppNotificationType.projectApproved;
    case 'project_rejected':
      return AppNotificationType.projectRejected;
    case 'worker_checkin':
      return AppNotificationType.workerCheckin;
    case 'logbook_entry':
      return AppNotificationType.logbookEntry;
    case 'tree_data':
      return AppNotificationType.treeData;
    case 'plot_update':
      return AppNotificationType.plotUpdate;
    default:
      return AppNotificationType.general;
  }
}

String notificationTypeLabel(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.newLogbook:
      return 'Nhật ký mới';
    case AppNotificationType.newFile:
      return 'Hồ sơ mới';
    case AppNotificationType.newProject:
      return 'Dự án mới';
    case AppNotificationType.updateRequest:
      return 'Yêu cầu cập nhật';
    case AppNotificationType.projectApprovalRequest:
      return 'Yêu cầu tạo dự án';
    case AppNotificationType.projectApproved:
      return 'Dự án được duyệt';
    case AppNotificationType.projectRejected:
      return 'Dự án bị từ chối';
    case AppNotificationType.workerCheckin:
      return 'Check-in vị trí';
    case AppNotificationType.logbookEntry:
      return 'Nhật ký công việc';
    case AppNotificationType.treeData:
      return 'Dữ liệu điều tra rừng';
    case AppNotificationType.plotUpdate:
      return 'Cập nhật tọa độ ô mẫu';
    case AppNotificationType.general:
      return 'Thông báo';
  }
}
