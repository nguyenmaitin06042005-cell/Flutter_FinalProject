import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityPhoto {
  final String? url;
  final Uint8List? bytes;
  final String? name;
  final String? storagePath;

  const ActivityPhoto({this.url, this.bytes, this.name, this.storagePath});

  factory ActivityPhoto.fromMap(Map<String, dynamic> map) {
    return ActivityPhoto(
      url: map['url'] as String?,
      name: map['name'] as String?,
      storagePath: map['storagePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (url != null) 'url': url,
      if (name != null) 'name': name,
      if (storagePath != null) 'storagePath': storagePath,
    };
  }
}

class ActivityRecord {
  final String id;
  final DateTime date;
  final String activityType;
  final String user;
  final String project;
  final String location;
  final double latitude;
  final double longitude;
  final String description;
  final List<ActivityPhoto> photos;

  const ActivityRecord({
    this.id = '',
    required this.date,
    required this.activityType,
    required this.user,
    required this.project,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.photos,
  });

  ActivityRecord copyWith({
    String? id,
    DateTime? date,
    String? activityType,
    String? user,
    String? project,
    String? location,
    double? latitude,
    double? longitude,
    String? description,
    List<ActivityPhoto>? photos,
  }) {
    return ActivityRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      activityType: activityType ?? this.activityType,
      user: user ?? this.user,
      project: project ?? this.project,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      photos: photos ?? this.photos,
    );
  }

  factory ActivityRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return _empty(doc.id);

    return ActivityRecord(
      id: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      activityType: data['activityType'] ?? 'Unknown',
      user: data['user'] ?? '',
      project: data['project'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      description: data['description'] ?? '',
      photos: (data['photos'] as List<dynamic>?)
              ?.map((e) => ActivityPhoto.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'activityType': activityType,
      'user': user,
      'project': project,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'photos': photos.map((p) => p.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static ActivityRecord _empty(String id) {
    return ActivityRecord(
      id: id,
      date: DateTime.now(),
      activityType: '',
      user: '',
      project: '',
      location: '',
      latitude: 0,
      longitude: 0,
      description: '',
      photos: [],
    );
  }
}
