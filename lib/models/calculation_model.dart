import 'package:cloud_firestore/cloud_firestore.dart';

class CalculationRecord {
  final String id;
  final String code;
  final String project;
  final DateTime date;
  final String method;
  final String species;
  final double diameterCm;
  final double heightM;
  final int quantity;
  final double speciesFactor;
  final double totalBiomassKg;
  final double carbonStockTon;
  final double co2EquivalentTon;
  final String status;

  const CalculationRecord({
    this.id = '',
    required this.code,
    required this.project,
    required this.date,
    required this.method,
    required this.species,
    required this.diameterCm,
    required this.heightM,
    required this.quantity,
    required this.speciesFactor,
    required this.totalBiomassKg,
    required this.carbonStockTon,
    required this.co2EquivalentTon,
    required this.status,
  });

  CalculationRecord copyWith({
    String? id,
    String? code,
    String? project,
    DateTime? date,
    String? method,
    String? species,
    double? diameterCm,
    double? heightM,
    int? quantity,
    double? speciesFactor,
    double? totalBiomassKg,
    double? carbonStockTon,
    double? co2EquivalentTon,
    String? status,
  }) {
    return CalculationRecord(
      id: id ?? this.id,
      code: code ?? this.code,
      project: project ?? this.project,
      date: date ?? this.date,
      method: method ?? this.method,
      species: species ?? this.species,
      diameterCm: diameterCm ?? this.diameterCm,
      heightM: heightM ?? this.heightM,
      quantity: quantity ?? this.quantity,
      speciesFactor: speciesFactor ?? this.speciesFactor,
      totalBiomassKg: totalBiomassKg ?? this.totalBiomassKg,
      carbonStockTon: carbonStockTon ?? this.carbonStockTon,
      co2EquivalentTon: co2EquivalentTon ?? this.co2EquivalentTon,
      status: status ?? this.status,
    );
  }

  factory CalculationRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return _empty(doc.id);

    return CalculationRecord(
      id: doc.id,
      code: data['code'] ?? '',
      project: data['project'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      method: data['method'] ?? '',
      species: data['species'] ?? '',
      diameterCm: (data['diameterCm'] as num?)?.toDouble() ?? 0.0,
      heightM: (data['heightM'] as num?)?.toDouble() ?? 0.0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      speciesFactor: (data['speciesFactor'] as num?)?.toDouble() ?? 0.0,
      totalBiomassKg: (data['totalBiomassKg'] as num?)?.toDouble() ?? 0.0,
      carbonStockTon: (data['carbonStockTon'] as num?)?.toDouble() ?? 0.0,
      co2EquivalentTon: (data['co2EquivalentTon'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'Draft',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'project': project,
      'date': Timestamp.fromDate(date),
      'method': method,
      'species': species,
      'diameterCm': diameterCm,
      'heightM': heightM,
      'quantity': quantity,
      'speciesFactor': speciesFactor,
      'totalBiomassKg': totalBiomassKg,
      'carbonStockTon': carbonStockTon,
      'co2EquivalentTon': co2EquivalentTon,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static CalculationRecord _empty(String id) {
    return CalculationRecord(
      id: id,
      code: '',
      project: '',
      date: DateTime.now(),
      method: '',
      species: '',
      diameterCm: 0,
      heightM: 0,
      quantity: 0,
      speciesFactor: 0,
      totalBiomassKg: 0,
      carbonStockTon: 0,
      co2EquivalentTon: 0,
      status: '',
    );
  }
}
