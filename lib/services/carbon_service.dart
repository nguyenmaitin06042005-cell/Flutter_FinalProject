import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calculation_model.dart';

class CarbonService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'carbon_calculations';

  Future<void> addCalculation(CalculationRecord record) async {
    await _db.collection(_collection).add(record.toFirestore());
  }

  Future<void> updateCalculation(CalculationRecord record) async {
    await _db.collection(_collection).doc(record.id).update(record.toFirestore());
  }

  Future<void> deleteCalculation(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  Stream<List<CalculationRecord>> getCalculationsStream() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalculationRecord.fromFirestore(doc))
            .toList());
  }
}
