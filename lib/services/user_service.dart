// lib/services/user_service.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'users';

  // ============================================================
  // TẠO USER MỚI (tự sinh employeeId nếu chưa có)
  // ============================================================
  Future<void> createUser(UserModel user) async {
    final userToSave = user.employeeId != null
        ? user
        : user.copyWith(employeeId: _generateEmployeeId(user.role));
    await _db.collection(_collection).doc(user.uid).set(userToSave.toFirestore());
  }

  /// Sinh mã ID dạng OWN-XXXXXX hoặc WRK-XXXXXX
  String _generateEmployeeId(UserRole role) {
    final prefix = role == UserRole.owner ? 'OWN' : 'WRK';
    final digits = (100000 + Random().nextInt(900000)).toString();
    return '$prefix-$digits';
  }

  // ============================================================
  // LẤY THÔNG TIN 1 USER
  // ============================================================
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection(_collection).doc(uid).get();
    if (doc.exists) {
      final user = UserModel.fromFirestore(doc);
      if (user.employeeId == null) {
        final newId = _generateEmployeeId(user.role);
        final updatedUser = user.copyWith(employeeId: newId);
        await updateUser(updatedUser.uid, updatedUser.toFirestore());
        return updatedUser;
      }
      return user;
    }
    return null;
  }

  // ============================================================
  // LẤY STREAM TẤT CẢ USER
  // ============================================================
  Stream<List<UserModel>> watchUsers() {
    return _db.collection(_collection).snapshots().map((snapshot) {
      final users = snapshot.docs.map(UserModel.fromFirestore).toList();
      // Auto-update any users missing employeeId asynchronously
      for (final u in users) {
        if (u.employeeId == null) {
          final newId = _generateEmployeeId(u.role);
          updateUser(u.uid, {'employeeId': newId});
        }
      }
      return users;
    });
  }

  // ============================================================
  // CẬP NHẬT USER
  // ============================================================
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection(_collection).doc(uid).update(data);
  }

  // ============================================================
  // LẤY DANH SÁCH TẤT CẢ USERS (dành cho admin)
  // ============================================================
  Stream<List<UserModel>> getAllUsers() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      for (final u in users) {
        if (u.employeeId == null) {
          final newId = _generateEmployeeId(u.role);
          updateUser(u.uid, {'employeeId': newId});
        }
      }
      return users;
    });
  }

  // ============================================================
  // LẤY DANH SÁCH WORKER CỦA 1 OWNER CỤ THỂ
  // ============================================================
  Stream<List<UserModel>> getWorkersForOwner(String ownerId) {
    return _db
        .collection(_collection)
        .where('role', isEqualTo: UserRole.worker.name)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
      final users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      for (final u in users) {
        if (u.employeeId == null) {
          final newId = _generateEmployeeId(u.role);
          updateUser(u.uid, {'employeeId': newId});
        }
      }
      return users;
    });
  }

  // ============================================================
  // LẤY DANH SÁCH OWNER
  // ============================================================
  Future<List<UserModel>> getOwners() async {
    final snapshot = await _db
        .collection(_collection)
        .where('role', isEqualTo: UserRole.owner.name)
        .get();
    final users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    for (final u in users) {
      if (u.employeeId == null) {
        final newId = _generateEmployeeId(u.role);
        await updateUser(u.uid, {'employeeId': newId});
      }
    }
    return users;
  }

  // ============================================================
  // LẤY DANH SÁCH ADMIN
  // ============================================================
  Future<List<UserModel>> getAdmins() async {
    final snapshot = await _db
        .collection(_collection)
        .where('role', isEqualTo: UserRole.admin.name)
        .get();
    final users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    for (final u in users) {
      if (u.employeeId == null) {
        final newId = _generateEmployeeId(u.role);
        await updateUser(u.uid, {'employeeId': newId});
      }
    }
    return users;
  }


  // ============================================================
  // CẬP NHẬT ROLE
  // ============================================================
  Future<void> updateRole(String uid, UserRole role) async {
    await updateUser(uid, {'role': role.name});
  }

  // ============================================================
  // CẬP NHẬT STATUS
  // ============================================================
  Future<void> updateStatus(String uid, UserStatus status) async {
    await updateUser(uid, {'status': status.name});
  }

  // ============================================================
  // XÓA USER (chỉ xóa Firestore, không xóa Auth)
  // ============================================================
  Future<void> deleteUser(String uid) async {
    await _db.collection(_collection).doc(uid).delete();
  }

  // ============================================================
  // STREAM 1 USER (theo dõi thay đổi realtime)
  // ============================================================
  Stream<UserModel?> watchUser(String uid) {
    return _db
        .collection(_collection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }
}
