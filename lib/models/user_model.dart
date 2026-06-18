// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// 3 phân hệ người dùng
enum UserRole {
  admin,  // Platform Admin — quyền cao nhất, tạo tài khoản
  owner,  // Forest Owner — quản lý dự án, khu rừng
  worker, // Forest Worker — nhân viên hiện trường
}

enum UserStatus { active, inactive, locked }

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;
  final String? createdBy;
  final String? password;
  final String? ownerId;
  final String? employeeId; // Mã ID riêng: OWN-XXXXXX hoặc WRK-XXXXXX

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.status,
    required this.createdAt,
    this.createdBy,
    this.password,
    this.ownerId,
    this.employeeId,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phone: data['phone'] ?? '',
      role: _parseRole(data['role']),
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
      password: data['password'],
      ownerId: data['ownerId'],
      employeeId: data['employeeId']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (password != null) 'password': password,
      if (ownerId != null) 'ownerId': ownerId,
      if (employeeId != null) 'employeeId': employeeId,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    UserStatus? status,
    DateTime? createdAt,
    String? createdBy,
    String? password,
    String? ownerId,
    String? employeeId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      password: password ?? this.password,
      ownerId: ownerId ?? this.ownerId,
      employeeId: employeeId ?? this.employeeId,
    );
  }

  static UserRole _parseRole(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'worker':
        return UserRole.worker;
      default:
        return UserRole.owner;
    }
  }

  static UserStatus _parseStatus(String? value) {
    switch (value) {
      case 'inactive':
        return UserStatus.inactive;
      case 'locked':
        return UserStatus.locked;
      default:
        return UserStatus.active;
    }
  }

  // Labels tiếng Việt
  String get roleLabel {
    switch (role) {
      case UserRole.admin:
        return 'Platform Admin';
      case UserRole.worker:
        return 'Forest Worker';
      default:
        return 'Forest Owner';
    }
  }

  String get roleDescription {
    switch (role) {
      case UserRole.admin:
        return 'Quản lý toàn bộ hệ thống';
      case UserRole.worker:
        return 'Nhân viên hiện trường';
      default:
        return 'Quản lý dự án rừng';
    }
  }

  String get statusLabel {
    switch (status) {
      case UserStatus.inactive:
        return 'Không hoạt động';
      case UserStatus.locked:
        return 'Đã khóa';
      default:
        return 'Hoạt động';
    }
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isOwner => role == UserRole.owner;
  bool get isWorker => role == UserRole.worker;
}
