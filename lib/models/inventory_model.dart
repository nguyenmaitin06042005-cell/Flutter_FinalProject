import 'package:cloud_firestore/cloud_firestore.dart';

class PlotModel {
  final String id;
  final String code;
  final String project;
  final double area;
  final double latitude;
  final double longitude;
  final double elevation;
  final String status;

  const PlotModel({
    this.id = '',
    required this.code,
    required this.project,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.status,
  });

  PlotModel copyWith({
    String? id,
    String? code,
    String? project,
    double? area,
    double? latitude,
    double? longitude,
    double? elevation,
    String? status,
  }) {
    return PlotModel(
      id: id ?? this.id,
      code: code ?? this.code,
      project: project ?? this.project,
      area: area ?? this.area,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevation: elevation ?? this.elevation,
      status: status ?? this.status,
    );
  }

  factory PlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return _empty(doc.id);

    return PlotModel(
      id: doc.id,
      code: data['code'] ?? '',
      project: data['project'] ?? '',
      area: (data['area'] as num?)?.toDouble() ?? 0.0,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      elevation: (data['elevation'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'Draft',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'project': project,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
      'elevation': elevation,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static PlotModel _empty(String id) {
    return PlotModel(
      id: id,
      code: '',
      project: '',
      area: 0,
      latitude: 0,
      longitude: 0,
      elevation: 0,
      status: '',
    );
  }
}

class TreeModel {
  final String id;
  final String plotId; // Reference to PlotModel.id
  final String plotCode; // Denormalized for easier querying/display
  final String species;
  final double dbh;
  final double height;
  final int quantity;

  const TreeModel({
    this.id = '',
    required this.plotId,
    required this.plotCode,
    required this.species,
    required this.dbh,
    required this.height,
    required this.quantity,
  });

  TreeModel copyWith({
    String? id,
    String? plotId,
    String? plotCode,
    String? species,
    double? dbh,
    double? height,
    int? quantity,
  }) {
    return TreeModel(
      id: id ?? this.id,
      plotId: plotId ?? this.plotId,
      plotCode: plotCode ?? this.plotCode,
      species: species ?? this.species,
      dbh: dbh ?? this.dbh,
      height: height ?? this.height,
      quantity: quantity ?? this.quantity,
    );
  }

  factory TreeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return _empty(doc.id);

    return TreeModel(
      id: doc.id,
      plotId: data['plotId'] ?? '',
      plotCode: data['plotCode'] ?? '',
      species: data['species'] ?? '',
      dbh: (data['dbh'] as num?)?.toDouble() ?? 0.0,
      height: (data['height'] as num?)?.toDouble() ?? 0.0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'plotId': plotId,
      'plotCode': plotCode,
      'species': species,
      'dbh': dbh,
      'height': height,
      'quantity': quantity,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static TreeModel _empty(String id) {
    return TreeModel(
      id: id,
      plotId: '',
      plotCode: '',
      species: '',
      dbh: 0,
      height: 0,
      quantity: 0,
    );
  }
}
