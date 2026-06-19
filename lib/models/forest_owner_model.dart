import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerAttachment {
  final String category;
  final String fileName;
  final String extension;
  final int sizeBytes;
  final String downloadUrl;
  final String storagePath;
  final DateTime uploadedAt;

  const OwnerAttachment({
    required this.category,
    required this.fileName,
    required this.extension,
    required this.sizeBytes,
    required this.downloadUrl,
    required this.storagePath,
    required this.uploadedAt,
  });

  factory OwnerAttachment.fromMap(Map<String, dynamic> data) {
    return OwnerAttachment(
      category: (data['category'] ?? '').toString(),
      fileName: (data['fileName'] ?? '').toString(),
      extension: (data['extension'] ?? '').toString().toLowerCase(),
      sizeBytes: _toInt(data['sizeBytes']),
      downloadUrl: (data['downloadUrl'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
      uploadedAt: _toDateTime(data['uploadedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'category': category,
        'fileName': fileName,
        'extension': extension,
        'sizeBytes': sizeBytes,
        'downloadUrl': downloadUrl,
        'storagePath': storagePath,
        'uploadedAt': uploadedAt,
      };

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class ForestOwner {
  final String id;
  final String ownerCode;
  final String ownerName;
  final String type;
  final String identificationNumber;
  final String address;
  final String phone;
  final String email;
  final String province;
  final String status;
  final List<OwnerAttachment> attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ForestOwner({
    required this.id,
    required this.ownerCode,
    required this.ownerName,
    required this.type,
    required this.identificationNumber,
    required this.address,
    required this.phone,
    required this.email,
    required this.province,
    required this.status,
    required this.attachments,
    this.createdAt,
    this.updatedAt,
  });

  factory ForestOwner.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final rawAttachments = data['attachments'];

    return ForestOwner(
      id: document.id,
      ownerCode: (data['ownerCode'] ?? '').toString(),
      ownerName: (data['ownerName'] ?? '').toString(),
      type: (data['type'] ?? 'Individual').toString(),
      identificationNumber: (data['identificationNumber'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      province: (data['province'] ?? '').toString(),
      status: (data['status'] ?? 'Active').toString(),
      attachments: rawAttachments is Iterable
          ? rawAttachments
              .whereType<Map>()
              .map(
                (value) => OwnerAttachment.fromMap(
                  Map<String, dynamic>.from(value),
                ),
              )
              .toList()
          : <OwnerAttachment>[],
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerCode': ownerCode,
        'ownerName': ownerName,
        'type': type,
        'identificationNumber': identificationNumber,
        'address': address,
        'phone': phone,
        'email': email,
        'province': province,
        'status': status,
        'attachments':
            attachments.map((attachment) => attachment.toMap()).toList(),
      };

  ForestOwner copyWith({
    String? id,
    String? ownerCode,
    String? ownerName,
    String? type,
    String? identificationNumber,
    String? address,
    String? phone,
    String? email,
    String? province,
    String? status,
    List<OwnerAttachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ForestOwner(
      id: id ?? this.id,
      ownerCode: ownerCode ?? this.ownerCode,
      ownerName: ownerName ?? this.ownerName,
      type: type ?? this.type,
      identificationNumber: identificationNumber ?? this.identificationNumber,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      province: province ?? this.province,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class OwnerProjectStats {
  final int totalProjects;
  final double totalAreaHa;

  const OwnerProjectStats({
    required this.totalProjects,
    required this.totalAreaHa,
  });
}
