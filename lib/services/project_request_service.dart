import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification_model.dart';
import '../models/forest_project_model.dart';
import '../models/project_request_model.dart';
import 'forest_project_service.dart';
import 'notification_service.dart';

class ProjectRequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ForestProjectService _projectService = ForestProjectService();
  final NotificationService _notificationService = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('project_requests');

  // ============================================================
  // OWNER: Gửi yêu cầu tạo project
  // ============================================================
  Future<void> submitRequest({
    required ProjectRequest request,
    required List<String> adminUids, // để gửi notification cho admin
  }) async {
    // 1. Lưu request vào Firestore
    final docRef = await _col.add(request.toFirestore());

    // 2. Gửi notification cho tất cả admin
    await _notificationService.createNotification(
      title: 'Yêu cầu tạo dự án mới',
      message:
          '${request.ownerName} (${request.ownerEmail}) đang yêu cầu tạo '
          'dự án "${request.projectName}".',
      type: AppNotificationType.projectApprovalRequest,
      referenceId: docRef.id,
      projectName: request.projectName,
      recipientIds: adminUids,
    );
  }

  // ============================================================
  // ADMIN: Stream danh sách request đang chờ duyệt
  // ============================================================
  Stream<List<ProjectRequest>> watchPendingRequests() {
    return _col
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(ProjectRequest.fromFirestore)
              .toList(),
        );
  }

  // ============================================================
  // ADMIN: Duyệt request → tạo project thật + thông báo owner
  // ============================================================
  Future<void> approveRequest(ProjectRequest request) async {
    // 1. Tạo project thật (kèm ownerUid)
    final project = ForestProject(
      id: '',
      projectId: request.projectId,
      projectName: request.projectName,
      owner: request.owner,
      ownerUid: request.ownerUid,   // <-- gán ownerUid
      province: request.province,
      district: request.district,
      commune: request.commune,
      forestType: request.forestType,
      treeSpecies: request.treeSpecies,
      yearPlanted: request.yearPlanted,
      areaHa: request.areaHa,
      status: 'Draft',
      workerUids: request.workerUids,
    );
    final savedProject = await _projectService.addProject(project);

    // 2. Cập nhật status request → approved
    await _col.doc(request.id).update({'status': 'approved'});

    // 3. Gửi notification cho owner
    await _notificationService.createNotification(
      title: 'Dự án đã được duyệt ✓',
      message:
          'Yêu cầu tạo dự án "${request.projectName}" của bạn đã được '
          'Admin chấp nhận. Dự án đã được tạo thành công!',
      type: AppNotificationType.projectApproved,
      referenceId: savedProject.id,
      projectName: request.projectName,
      recipientIds: [request.ownerUid],
    );
  }

  // ============================================================
  // ADMIN: Từ chối request + thông báo owner
  // ============================================================
  Future<void> rejectRequest(ProjectRequest request) async {
    // 1. Cập nhật status request → rejected
    await _col.doc(request.id).update({'status': 'rejected'});

    // 2. Gửi notification cho owner
    await _notificationService.createNotification(
      title: 'Dự án bị từ chối ✗',
      message:
          'Yêu cầu tạo dự án "${request.projectName}" của bạn đã bị '
          'Admin từ chối. Vui lòng liên hệ Admin để biết thêm chi tiết.',
      type: AppNotificationType.projectRejected,
      referenceId: request.id,
      projectName: request.projectName,
      recipientIds: [request.ownerUid],
    );
  }

  // ============================================================
  // Lấy danh sách request của 1 owner cụ thể (để owner xem status)
  // ============================================================
  Stream<List<ProjectRequest>> watchOwnerRequests(String ownerUid) {
    return _col
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(ProjectRequest.fromFirestore)
              .toList(),
        );
  }
}
