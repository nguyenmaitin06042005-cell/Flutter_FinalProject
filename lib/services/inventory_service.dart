import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_model.dart';

class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _plotsCollection = 'inventory_plots';
  final String _treesCollection = 'inventory_trees';

  // ============================================================
  // PLOTS
  // ============================================================
  Future<PlotModel> addPlot(PlotModel plot) async {
    final docRef = await _db.collection(_plotsCollection).add(plot.toFirestore());
    return plot.copyWith(id: docRef.id);
  }

  Future<void> updatePlot(PlotModel plot) async {
    await _db.collection(_plotsCollection).doc(plot.id).update(plot.toFirestore());
  }

  Future<void> deletePlot(String plotId) async {
    // 1. Delete all trees in this plot first
    final treesSnapshot = await _db
        .collection(_treesCollection)
        .where('plotId', isEqualTo: plotId)
        .get();
        
    final batch = _db.batch();
    for (var doc in treesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // 2. Delete the plot
    batch.delete(_db.collection(_plotsCollection).doc(plotId));
    
    await batch.commit();
  }

  Stream<List<PlotModel>> getPlotsStream() {
    return _db
        .collection(_plotsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PlotModel.fromFirestore(doc)).toList());
  }

  // ============================================================
  // TREES
  // ============================================================
  Future<void> addTree(TreeModel tree) async {
    await _db.collection(_treesCollection).add(tree.toFirestore());
  }

  Future<void> updateTree(TreeModel tree) async {
    await _db.collection(_treesCollection).doc(tree.id).update(tree.toFirestore());
  }

  Future<void> deleteTree(String treeId) async {
    await _db.collection(_treesCollection).doc(treeId).delete();
  }

  Stream<List<TreeModel>> getTreesStream() {
    return _db
        .collection(_treesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TreeModel.fromFirestore(doc)).toList());
  }
}
