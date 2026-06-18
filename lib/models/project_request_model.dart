import 'package:cloud_firestore/cloud_firestore.dart';

enum ProjectRequestStatus { pending, approved, rejected }

class ProjectRequest {
  final String id;
  final String ownerUid;
  final String ownerEmail;
  final String ownerName;
  final ProjectRequestStatus status;
  final DateTime createdAt;
  final String? adminNote;
  final String? notificationId; // ID của notification gửi cho admin

  // Dữ liệu project
  final String projectId;
  final String projectName;
  final String owner;
  final String province;
  final String district;
  final String commune;
  final String forestType;
  final String treeSpecies;
  final int yearPlanted;
  final double areaHa;
  final List<String> workerUids;

  const ProjectRequest({
    required this.id,
    required this.ownerUid,
    required this.ownerEmail,
    required this.ownerName,
    required this.status,
    required this.createdAt,
    this.adminNote,
    this.notificationId,
    required this.projectId,
    required this.projectName,
    required this.owner,
    required this.province,
    required this.district,
    required this.commune,
    required this.forestType,
    required this.treeSpecies,
    required this.yearPlanted,
    required this.areaHa,
    this.workerUids = const [],
  });

  factory ProjectRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return ProjectRequest(
      id: doc.id,
      ownerUid: (d['ownerUid'] ?? '').toString(),
      ownerEmail: (d['ownerEmail'] ?? '').toString(),
      ownerName: (d['ownerName'] ?? '').toString(),
      status: _parseStatus(d['status']),
      createdAt: _toDateTime(d['createdAt']) ?? DateTime.now(),
      adminNote: d['adminNote']?.toString(),
      notificationId: d['notificationId']?.toString(),
      projectId: (d['projectId'] ?? '').toString(),
      projectName: (d['projectName'] ?? '').toString(),
      owner: (d['owner'] ?? '').toString(),
      province: (d['province'] ?? '').toString(),
      district: (d['district'] ?? '').toString(),
      commune: (d['commune'] ?? '').toString(),
      forestType: (d['forestType'] ?? '').toString(),
      treeSpecies: (d['treeSpecies'] ?? '').toString(),
      yearPlanted: _toInt(d['yearPlanted']),
      areaHa: _toDouble(d['areaHa']),
      workerUids: List<String>.from(d['workerUids'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerUid': ownerUid,
        'ownerEmail': ownerEmail,
        'ownerName': ownerName,
        'status': status.name,
        'createdAt': FieldValue.serverTimestamp(),
        'adminNote': adminNote,
        'notificationId': notificationId,
        'projectId': projectId,
        'projectName': projectName,
        'owner': owner,
        'province': province,
        'district': district,
        'commune': commune,
        'forestType': forestType,
        'treeSpecies': treeSpecies,
        'yearPlanted': yearPlanted,
        'areaHa': areaHa,
        'workerUids': workerUids,
      };

  static ProjectRequestStatus _parseStatus(dynamic value) {
    switch (value?.toString()) {
      case 'approved':
        return ProjectRequestStatus.approved;
      case 'rejected':
        return ProjectRequestStatus.rejected;
      default:
        return ProjectRequestStatus.pending;
    }
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(',', '.') ?? '',
        ) ??
        0;
  }
}
