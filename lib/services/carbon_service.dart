import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calculation_model.dart';
import '../models/inventory_model.dart';

class CarbonService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'carbon_calculations';

  /// Tự động tạo CalculationRecord từ TreeModel + PlotModel khi thêm Tree Data.
  /// Công thức:
  ///   Biomass   = 0.05 × DBH² × Height × Quantity  (kg)
  ///   Carbon    = Biomass / 1000 × Factor            (tấn C)
  ///   CO₂e      = Carbon × 44 / 12                   (tấn CO₂e)
  Future<String> autoCalculateFromTree({
    required TreeModel tree,
    required PlotModel plot,
    required String ownerUid,
    required String ownerName,
    required Map<String, double> speciesFactors,
  }) async {
    final factor = speciesFactors[tree.species] ?? 0.47;
    final biomass = 0.05 * tree.dbh * tree.dbh * tree.height * tree.quantity;
    final carbonStock = biomass / 1000 * factor;
    final co2e = carbonStock * 44 / 12;

    final record = CalculationRecord(
      code:
          'CAL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      project: plot.project,
      date: DateTime.now(),
      method: 'IPCC Default',
      species: tree.species,
      diameterCm: tree.dbh,
      heightM: tree.height,
      quantity: tree.quantity,
      speciesFactor: factor,
      totalBiomassKg: biomass,
      carbonStockTon: carbonStock,
      co2EquivalentTon: co2e,
      status: 'Draft',
      ownerUid: ownerUid,
      ownerName: ownerName,
    );

    return addCalculation(record);
  }

  Future<String> addCalculation(CalculationRecord record) async {
    final docRef = await _db.collection(_collection).add(record.toFirestore());
    return docRef.id;
  }

  Future<void> updateCalculation(CalculationRecord record) async {
    await _db.collection(_collection).doc(record.id).update(record.toFirestore());
  }

  Future<void> deleteCalculation(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  /// Xóa tất cả carbon calculations thuộc về một project (theo tên project).
  /// Được gọi khi xóa forest project để đảm bảo dữ liệu đồng bộ.
  Future<void> deleteCalculationsByProjectName(String projectName) async {
    if (projectName.trim().isEmpty) return;

    final snapshot = await _db
        .collection(_collection)
        .where('project', isEqualTo: projectName.trim())
        .get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// All calculations — for admin view (read-only)
  Stream<List<CalculationRecord>> getCalculationsStream() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalculationRecord.fromFirestore(doc))
            .toList());
  }

  /// Only calculations belonging to a specific owner — for owner view
  Stream<List<CalculationRecord>> getCalculationsStreamByOwner(String ownerUid) {
    return _db
        .collection(_collection)
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => CalculationRecord.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }
}
