import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/forest_owner_model.dart';

class OwnerUploadFile {
  final Uint8List bytes;
  final String fileName;
  final String extension;
  final String category;

  const OwnerUploadFile({
    required this.bytes,
    required this.fileName,
    required this.extension,
    required this.category,
  });
}

class ForestOwnerService {
  ForestOwnerService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _owners =>
      _firestore.collection('forest_owners');

  Stream<List<ForestOwner>> watchOwners() {
    return _owners.snapshots().map((snapshot) {
      final owners =
          snapshot.docs.map(ForestOwner.fromFirestore).toList();

      owners.sort((a, b) {
        final aDate =
            a.updatedAt ?? a.createdAt ?? DateTime(2000);
        final bDate =
            b.updatedAt ?? b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      return owners;
    });
  }

  Stream<OwnerProjectStats> watchOwnerProjectStats(
    String ownerName,
  ) {
    if (ownerName.trim().isEmpty) {
      return Stream<OwnerProjectStats>.value(
        const OwnerProjectStats(
          totalProjects: 0,
          totalAreaHa: 0,
        ),
      );
    }

    return _firestore
        .collection('forest_projects')
        .where('owner', isEqualTo: ownerName.trim())
        .snapshots()
        .map((snapshot) {
      double totalArea = 0;

      for (final document in snapshot.docs) {
        final value = document.data()['areaHa'];

        if (value is num) {
          totalArea += value.toDouble();
        } else {
          totalArea += double.tryParse(
                value?.toString().replaceAll(',', '.') ?? '',
              ) ??
              0;
        }
      }

      return OwnerProjectStats(
        totalProjects: snapshot.docs.length,
        totalAreaHa: totalArea,
      );
    });
  }

  Future<ForestOwner> saveOwner({
    required ForestOwner owner,
    required List<OwnerUploadFile> newFiles,
  }) async {
    final duplicate = await _owners
        .where('ownerCode', isEqualTo: owner.ownerCode)
        .limit(2)
        .get();

    final hasAnotherOwner = duplicate.docs.any(
      (document) => document.id != owner.id,
    );

    if (hasAnotherOwner) {
      throw Exception(
        'Owner Code "${owner.ownerCode}" đã tồn tại.',
      );
    }

    final document =
        owner.id.isEmpty ? _owners.doc() : _owners.doc(owner.id);

    final uploadedAttachments = <OwnerAttachment>[];

    for (final file in newFiles) {
      uploadedAttachments.add(
        await _uploadAttachment(
          ownerDocumentId: document.id,
          file: file,
        ),
      );
    }

    final attachments = <OwnerAttachment>[
      ...owner.attachments,
      ...uploadedAttachments,
    ];

    final now = DateTime.now();
    final data = <String, dynamic>{
      ...owner.copyWith(attachments: attachments).toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (owner.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await document.set(data, SetOptions(merge: true));

    return owner.copyWith(
      id: document.id,
      attachments: attachments,
      createdAt: owner.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> deleteAttachment({
    required ForestOwner owner,
    required OwnerAttachment attachment,
  }) async {
    if (attachment.storagePath.isNotEmpty) {
      try {
        await _storage.ref(attachment.storagePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }

    final updatedAttachments = owner.attachments
        .where(
          (item) => item.storagePath != attachment.storagePath,
        )
        .toList();

    await _owners.doc(owner.id).update(<String, dynamic>{
      'attachments':
          updatedAttachments.map((item) => item.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteOwner(ForestOwner owner) async {
    for (final attachment in owner.attachments) {
      if (attachment.storagePath.isEmpty) continue;

      try {
        await _storage.ref(attachment.storagePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }

    await _owners.doc(owner.id).delete();
  }

  Future<OwnerAttachment> _uploadAttachment({
    required String ownerDocumentId,
    required OwnerUploadFile file,
  }) async {
    const allowedExtensions = <String>{
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'docx',
    };

    final extension = file.extension.toLowerCase();

    if (!allowedExtensions.contains(extension)) {
      throw Exception(
        'Chỉ cho phép PDF, JPG, PNG và DOCX.',
      );
    }

    if (file.bytes.isEmpty) {
      throw Exception(
        'Tệp "${file.fileName}" không có dữ liệu.',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _sanitizeFileName(file.fileName);
    final storagePath =
        'forest_owner_documents/$ownerDocumentId/'
        '${timestamp}_$safeName';

    final reference = _storage.ref(storagePath);

    await reference.putData(
      file.bytes,
      SettableMetadata(
        contentType: _contentType(extension),
        customMetadata: <String, String>{
          'category': file.category,
          'ownerDocumentId': ownerDocumentId,
        },
      ),
    );

    final downloadUrl = await reference.getDownloadURL();

    return OwnerAttachment(
      category: file.category,
      fileName: file.fileName,
      extension: extension,
      sizeBytes: file.bytes.length,
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      uploadedAt: DateTime.now(),
    );
  }

  String _sanitizeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^\w.\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return cleaned.isEmpty ? 'document' : cleaned;
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}
