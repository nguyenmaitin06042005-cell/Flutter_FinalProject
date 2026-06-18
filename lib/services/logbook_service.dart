import 'dart:typed_data';
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

  // ============================================================
  // STREAM ALL ACTIVITIES
  // ============================================================
  Stream<List<ActivityRecord>> getActivitiesStream() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityRecord.fromFirestore(doc))
            .toList());
  }
}
