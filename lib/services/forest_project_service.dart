import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/forest_project_model.dart';

class ForestProjectService {
  ForestProjectService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _projects =>
      _firestore.collection('forest_projects');

  Stream<List<ForestProject>> watchProjects() {
    return _projects.snapshots().map((snapshot) {
      final projects = snapshot.docs.map(ForestProject.fromFirestore).toList();
      projects.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return projects;
    });
  }

  Stream<List<ForestProject>> watchProjectsByOwner(String ownerUid) {
    return _projects
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snapshot) {
      final projects = snapshot.docs.map(ForestProject.fromFirestore).toList();
      projects.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return projects;
    });
  }

  Future<ForestProject> addProject(ForestProject project) async {
    final duplicate = await _projects
        .where('projectId', isEqualTo: project.projectId)
        .limit(1)
        .get();

    if (duplicate.docs.isNotEmpty) {
      throw Exception('Project ID "${project.projectId}" đã tồn tại.');
    }

    final document = _projects.doc();
    final now = DateTime.now();

    await document.set(<String, dynamic>{
      ...project.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return project.copyWith(
      id: document.id,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<ForestProject> updateProject(ForestProject project) async {
    if (project.id.isEmpty) {
      throw Exception('Không tìm thấy mã tài liệu Firebase để cập nhật.');
    }

    final duplicate = await _projects
        .where('projectId', isEqualTo: project.projectId)
        .limit(2)
        .get();

    final hasAnotherDocument = duplicate.docs.any(
      (document) => document.id != project.id,
    );

    if (hasAnotherDocument) {
      throw Exception('Project ID "${project.projectId}" đã tồn tại.');
    }

    final now = DateTime.now();

    await _projects.doc(project.id).update(<String, dynamic>{
      ...project.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return project.copyWith(updatedAt: now);
  }

  Future<void> deleteProject(String documentId) async {
    if (documentId.isEmpty) {
      throw Exception('Không tìm thấy mã tài liệu Firebase để xóa.');
    }

    await _projects.doc(documentId).delete();
  }

  /// Lưu polygon đã vẽ + cập nhật diện tích cho project.
  /// Dữ liệu polygon và diện tích sẽ tự động đồng bộ sang mọi trang khác
  /// thông qua StreamBuilder (watchProjects).
  Future<void> updateProjectPolygon({
    required String documentId,
    required List<Map<String, double>> polygonCoordinates,
    required double areaHa,
  }) async {
    if (documentId.isEmpty) {
      throw Exception('Không tìm thấy mã tài liệu Firebase để cập nhật polygon.');
    }

    await _projects.doc(documentId).update(<String, dynamic>{
      'polygonCoordinates': polygonCoordinates
          .map((c) => <String, dynamic>{'lat': c['lat'], 'lng': c['lng']})
          .toList(),
      'areaHa': areaHa,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
