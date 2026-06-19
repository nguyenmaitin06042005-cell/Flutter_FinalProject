import 'package:cloud_firestore/cloud_firestore.dart';

class ForestProject {
  final String id;
  final String projectId;
  final String projectName;
  final String owner;
  final String ownerUid;   // UID của owner tạo project
  final String province;
  final String district;
  final String commune;
  final String forestType;
  final String treeSpecies;
  final int yearPlanted;
  final double areaHa;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> workerUids;
  final List<Map<String, double>> polygonCoordinates;

  const ForestProject({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.owner,
    this.ownerUid = '',
    required this.province,
    required this.district,
    required this.commune,
    required this.forestType,
    required this.treeSpecies,
    required this.yearPlanted,
    required this.areaHa,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.workerUids = const [],
    this.polygonCoordinates = const [],
  });

  factory ForestProject.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return ForestProject(
      id: document.id,
      projectId: (data['projectId'] ?? '').toString(),
      projectName: (data['projectName'] ?? '').toString(),
      owner: (data['owner'] ?? '').toString(),
      ownerUid: (data['ownerUid'] ?? '').toString(),
      province: (data['province'] ?? '').toString(),
      district: (data['district'] ?? '').toString(),
      commune: (data['commune'] ?? '').toString(),
      forestType: (data['forestType'] ?? '').toString(),
      treeSpecies: (data['treeSpecies'] ?? '').toString(),
      yearPlanted: _toInt(data['yearPlanted']),
      areaHa: _toDouble(data['areaHa']),
      status: (data['status'] ?? 'Draft').toString(),
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      workerUids: List<String>.from(data['workerUids'] ?? []),
      polygonCoordinates: _toPolygonCoords(data['polygonCoordinates']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'projectId': projectId,
      'projectName': projectName,
      'owner': owner,
      'ownerUid': ownerUid,
      'province': province,
      'district': district,
      'commune': commune,
      'forestType': forestType,
      'treeSpecies': treeSpecies,
      'yearPlanted': yearPlanted,
      'areaHa': areaHa,
      'status': status,
      'workerUids': workerUids,
      'polygonCoordinates': polygonCoordinates
          .map((c) => <String, dynamic>{'lat': c['lat'], 'lng': c['lng']})
          .toList(),
    };
  }

  ForestProject copyWith({
    String? id,
    String? projectId,
    String? projectName,
    String? owner,
    String? ownerUid,
    String? province,
    String? district,
    String? commune,
    String? forestType,
    String? treeSpecies,
    int? yearPlanted,
    double? areaHa,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? workerUids,
    List<Map<String, double>>? polygonCoordinates,
  }) {
    return ForestProject(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      owner: owner ?? this.owner,
      ownerUid: ownerUid ?? this.ownerUid,
      province: province ?? this.province,
      district: district ?? this.district,
      commune: commune ?? this.commune,
      forestType: forestType ?? this.forestType,
      treeSpecies: treeSpecies ?? this.treeSpecies,
      yearPlanted: yearPlanted ?? this.yearPlanted,
      areaHa: areaHa ?? this.areaHa,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      workerUids: workerUids ?? this.workerUids,
      polygonCoordinates: polygonCoordinates ?? this.polygonCoordinates,
    );
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

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<Map<String, double>> _toPolygonCoords(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.map<Map<String, double>>((item) {
      if (item is Map) {
        return {
          'lat': _toDouble(item['lat']),
          'lng': _toDouble(item['lng']),
        };
      }
      return {'lat': 0.0, 'lng': 0.0};
    }).toList();
  }
}
