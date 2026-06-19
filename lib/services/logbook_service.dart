import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/activity_model.dart';

class LogbookService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'logbook_activities';

  // ============================================================
  // UPLOAD PHOTOS AND SAVE ACTIVITY
  // ============================================================
  Future<ActivityRecord> addActivity(ActivityRecord activity) async {
    // 1. Upload photos to Firebase Storage if they have bytes
    List<ActivityPhoto> uploadedPhotos = [];

    for (var photo in activity.photos) {
      if (photo.bytes != null) {
        final ext = photo.name?.split('.').last ?? 'jpg';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${uploadedPhotos.length}.$ext';
        final storagePath = 'logbook_photos/$fileName';
        final ref = _storage.ref().child(storagePath);
        
        // Upload
        final uploadTask = await ref.putData(photo.bytes!);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        uploadedPhotos.add(ActivityPhoto(
          url: downloadUrl,
          name: photo.name,
          storagePath: storagePath,
        ));
      } else {
        // Already uploaded or empty
        uploadedPhotos.add(photo);
      }
    }

    final recordToSave = activity.copyWith(photos: uploadedPhotos);

    // 2. Save to Firestore
    final docRef = await _db.collection(_collection).add(recordToSave.toFirestore());
    
    return recordToSave.copyWith(id: docRef.id);
  }

  // ============================================================
  // UPDATE ACTIVITY
  // ============================================================
  Future<ActivityRecord> updateActivity(ActivityRecord activity) async {
    // Determine which photos need uploading
    List<ActivityPhoto> finalPhotos = [];

    for (var photo in activity.photos) {
      if (photo.bytes != null) {
        final ext = photo.name?.split('.').last ?? 'jpg';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${finalPhotos.length}.$ext';
        final storagePath = 'logbook_photos/$fileName';
        final ref = _storage.ref().child(storagePath);
        
        final uploadTask = await ref.putData(photo.bytes!);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        finalPhotos.add(ActivityPhoto(
          url: downloadUrl,
          name: photo.name,
          storagePath: storagePath,
        ));
      } else {
        finalPhotos.add(photo);
      }
    }

    final recordToSave = activity.copyWith(photos: finalPhotos);

    await _db.collection(_collection).doc(activity.id).update(recordToSave.toFirestore());
    
    return recordToSave;
  }

  // ============================================================
  // DELETE ACTIVITY
  // ============================================================
  Future<void> deleteActivity(ActivityRecord activity) async {
    // 1. Delete photos from Storage
    for (var photo in activity.photos) {
      if (photo.storagePath != null) {
        try {
          await _storage.ref().child(photo.storagePath!).delete();
        } catch (e) {
          // Ignore if already deleted or error
          print('Error deleting photo: $e');
        }
      }
    }

    // 2. Delete from Firestore
    await _db.collection(_collection).doc(activity.id).delete();
  }

  /// Xóa tất cả activities (và ảnh Storage) thuộc về một project (theo tên project).
  /// Được gọi khi xóa forest project để đảm bảo dữ liệu đồng bộ.
  Future<void> deleteActivitiesByProjectName(String projectName) async {
    if (projectName.trim().isEmpty) return;

    final snapshot = await _db
        .collection(_collection)
        .where('project', isEqualTo: projectName.trim())
        .get();

    if (snapshot.docs.isEmpty) return;

    // Xóa ảnh từ Storage trước
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final photos = data['photos'] as List<dynamic>?;
      if (photos != null) {
        for (final photo in photos) {
          final storagePath = (photo as Map<String, dynamic>)['storagePath'] as String?;
          if (storagePath != null && storagePath.isNotEmpty) {
            try {
              await _storage.ref().child(storagePath).delete();
            } catch (e) {
              // Bỏ qua nếu ảnh đã bị xóa hoặc lỗi
              print('Error deleting photo from storage: $e');
            }
          }
        }
      }
    }

    // Xóa documents từ Firestore bằng batch
    WriteBatch batch = _db.batch();
    int operationCount = 0;

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      operationCount++;

      if (operationCount >= 450) {
        await batch.commit();
        batch = _db.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }
  }

  // ============================================================
  // STREAM ALL ACTIVITIES
  // ============================================================
  Stream<List<ActivityRecord>> getActivitiesStream() {
    return _db
        .collection(_collection)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityRecord.fromFirestore(doc))
            .toList());
  }
}
