import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/managed_file_model.dart';

class FileManagementService {
  FileManagementService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _files =>
      _firestore.collection('forest_files');

  Stream<List<ManagedFile>> watchFiles() {
    return _files.snapshots().map((snapshot) {
      final files = snapshot.docs
          .map(ManagedFile.fromFirestore)
          .toList();

      files.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return files;
    });
  }

  Stream<List<String>> watchProjectNames() {
    return _firestore.collection('forest_projects').snapshots().map(
      (snapshot) {
        final names = snapshot.docs
            .map((document) {
              final data = document.data();
              return (data['projectName'] ??
                      data['project'] ??
                      data['name'] ??
                      '')
                  .toString()
                  .trim();
            })
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        return names;
      },
    );
  }

  Future<ManagedFile> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String extension,
    required String category,
    required String project,
    required String uploadedBy,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Tệp đã chọn không có dữ liệu.');
    }

    final normalizedExtension = extension.toLowerCase();
    const allowed = <String>{'pdf', 'jpg', 'jpeg', 'png', 'docx'};

    if (!allowed.contains(normalizedExtension)) {
      throw Exception('Chỉ cho phép PDF, JPG, PNG và DOCX.');
    }

    final safeName = _sanitizeFileName(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'forest_files/${timestamp}_$safeName';
    final reference = _storage.ref(storagePath);

    final metadata = SettableMetadata(
      contentType: _contentType(normalizedExtension),
      customMetadata: <String, String>{
        'category': category,
        'project': project,
        'uploadedBy': uploadedBy,
      },
    );

    await reference.putData(bytes, metadata);
    final downloadUrl = await reference.getDownloadURL();

    final document = _files.doc();
    final now = DateTime.now();

    await document.set(<String, dynamic>{
      'fileName': fileName,
      'extension': normalizedExtension,
      'category': category,
      'project': project,
      'uploadedBy': uploadedBy,
      'uploadedAt': FieldValue.serverTimestamp(),
      'sizeBytes': bytes.length,
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
    });

    return ManagedFile(
      id: document.id,
      fileName: fileName,
      extension: normalizedExtension,
      category: category,
      project: project,
      uploadedBy: uploadedBy,
      uploadedAt: now,
      sizeBytes: bytes.length,
      downloadUrl: downloadUrl,
      storagePath: storagePath,
    );
  }

  Future<void> deleteFile(ManagedFile file) async {
    if (file.storagePath.isNotEmpty) {
      try {
        await _storage.ref(file.storagePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') {
          rethrow;
        }
      }
    }

    await _files.doc(file.id).delete();
  }

  String _sanitizeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^\w.\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return cleaned.isEmpty ? 'file' : cleaned;
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
