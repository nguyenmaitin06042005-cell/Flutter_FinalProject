import 'package:cloud_firestore/cloud_firestore.dart';

class ManagedFile {
  final String id;
  final String fileName;
  final String extension;
  final String category;
  final String project;
  final String uploadedBy;
  final DateTime uploadedAt;
  final int sizeBytes;
  final String downloadUrl;
  final String storagePath;

  const ManagedFile({
    required this.id,
    required this.fileName,
    required this.extension,
    required this.category,
    required this.project,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.sizeBytes,
    required this.downloadUrl,
    required this.storagePath,
  });

  factory ManagedFile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return ManagedFile(
      id: document.id,
      fileName: (data['fileName'] ?? '').toString(),
      extension: (data['extension'] ?? '').toString().toLowerCase(),
      category: (data['category'] ?? '').toString(),
      project: (data['project'] ?? '').toString(),
      uploadedBy: (data['uploadedBy'] ?? '').toString(),
      uploadedAt: _toDateTime(data['uploadedAt']) ?? DateTime.now(),
      sizeBytes: _toInt(data['sizeBytes']),
      downloadUrl: (data['downloadUrl'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
