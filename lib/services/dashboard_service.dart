import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DashboardProvinceArea {
  final String province;
  final double areaHa;

  const DashboardProvinceArea({
    required this.province,
    required this.areaHa,
  });
}

class DashboardProjectCarbon {
  final String projectName;
  final double co2eTon;

  const DashboardProjectCarbon({
    required this.projectName,
    required this.co2eTon,
  });
}

class DashboardActivity {
  final DateTime? date;
  final String project;
  final String activityType;
  final String user;
  final String location;
  final int photoCount;

  const DashboardActivity({
    required this.date,
    required this.project,
    required this.activityType,
    required this.user,
    required this.location,
    required this.photoCount,
  });
}

class DashboardProjectPoint {
  final String projectName;
  final double latitude;
  final double longitude;

  const DashboardProjectPoint({
    required this.projectName,
    required this.latitude,
    required this.longitude,
  });
}

class DashboardData {
  final int forestOwners;
  final int forestProjects;
  final double totalAreaHa;
  final int totalTrees;
  final double estimatedCarbonTon;
  final List<DashboardProvinceArea> areaByProvince;
  final List<DashboardProjectCarbon> carbonByProject;
  final List<DashboardActivity> recentActivities;
  final List<DashboardProjectPoint> projectPoints;

  const DashboardData({
    required this.forestOwners,
    required this.forestProjects,
    required this.totalAreaHa,
    required this.totalTrees,
    required this.estimatedCarbonTon,
    required this.areaByProvince,
    required this.carbonByProject,
    required this.recentActivities,
    required this.projectPoints,
  });

  static const DashboardData empty = DashboardData(
    forestOwners: 0,
    forestProjects: 0,
    totalAreaHa: 0,
    totalTrees: 0,
    estimatedCarbonTon: 0,
    areaByProvince: <DashboardProvinceArea>[],
    carbonByProject: <DashboardProjectCarbon>[],
    recentActivities: <DashboardActivity>[],
    projectPoints: <DashboardProjectPoint>[],
  );
}

class DashboardService {
  DashboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<DashboardData> watchDashboard(DateTimeRange range) {
    late StreamController<DashboardData> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];

    List<QueryDocumentSnapshot<Map<String, dynamic>>> owners =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> projects =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> inventory =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> calculations =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    bool cancelled = false;

    void emit() {
      if (cancelled || controller.isClosed) return;

      controller.add(
        _aggregate(
          range: range,
          owners: owners,
          projects: projects,
          inventory: inventory,
          calculations: calculations,
          activities: activities,
        ),
      );
    }

    controller = StreamController<DashboardData>(
      onListen: () {
        subscriptions.add(
          _firestore.collection('forest_owners').snapshots().listen(
            (snapshot) {
              owners = snapshot.docs;
              emit();
            },
            onError: controller.addError,
          ),
        );

        subscriptions.add(
          _firestore.collection('forest_projects').snapshots().listen(
            (snapshot) {
              projects = snapshot.docs;
              emit();
            },
            onError: controller.addError,
          ),
        );

        subscriptions.add(
          _watchFirstAvailableCollection(
            const <String>[
              'forest_inventory',
              'forest_inventory_tree_data',
              'inventory',
              'tree_data',
            ],
          ).listen(
            (snapshot) {
              inventory = snapshot.docs;
              emit();
            },
            onError: controller.addError,
          ),
        );

        subscriptions.add(
          _watchFirstAvailableCollection(
            const <String>[
              'carbon_calculations',
              'calculations',
              'carbonCalculations',
            ],
          ).listen(
            (snapshot) {
              calculations = snapshot.docs;
              emit();
            },
            onError: controller.addError,
          ),
        );

        subscriptions.add(
          _watchFirstAvailableCollection(
            const <String>[
              'forest_activities',
              'activities',
              'forest_logbook',
              'logbook_activities',
            ],
          ).listen(
            (snapshot) {
              activities = snapshot.docs;
              emit();
            },
            onError: controller.addError,
          ),
        );

        emit();
      },
      onCancel: () async {
        cancelled = true;

        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _watchFirstAvailableCollection(
    List<String> collectionNames,
  ) async* {
    for (final collectionName in collectionNames) {
      final initial = await _firestore
          .collection(collectionName)
          .limit(1)
          .get();

      if (initial.docs.isNotEmpty) {
        yield* _firestore.collection(collectionName).snapshots();
        return;
      }
    }

    yield* _firestore
        .collection(collectionNames.first)
        .snapshots();
  }

  DashboardData _aggregate({
    required DateTimeRange range,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> owners,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> projects,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> inventory,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> calculations,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
  }) {
    final filteredOwners = owners.where((document) {
      return _matchesDate(
        document.data(),
        const <String>['createdAt', 'updatedAt', 'date'],
        range,
        includeWhenMissing: true,
      );
    }).toList();

    final filteredProjects = projects.where((document) {
      return _matchesDate(
        document.data(),
        const <String>['createdAt', 'updatedAt', 'date'],
        range,
        includeWhenMissing: true,
      );
    }).toList();

    final filteredInventory = inventory.where((document) {
      return _matchesDate(
        document.data(),
        const <String>[
          'date',
          'inventoryDate',
          'createdAt',
          'updatedAt',
        ],
        range,
        includeWhenMissing: true,
      );
    }).toList();

    final filteredCalculations = calculations.where((document) {
      return _matchesDate(
        document.data(),
        const <String>[
          'date',
          'calculationDate',
          'createdAt',
          'updatedAt',
        ],
        range,
        includeWhenMissing: true,
      );
    }).toList();

    final filteredActivities = activities.where((document) {
      return _matchesDate(
        document.data(),
        const <String>[
          'date',
          'activityDate',
          'createdAt',
          'updatedAt',
        ],
        range,
        includeWhenMissing: true,
      );
    }).toList();

    double totalArea = 0;
    int totalTrees = 0;
    double totalCarbon = 0;

    final provinceTotals = <String, double>{};
    final projectCarbonTotals = <String, double>{};
    final points = <DashboardProjectPoint>[];

    for (final document in filteredProjects) {
      final data = document.data();
      final area = _readDouble(
        data,
        const <String>['areaHa', 'area', 'totalAreaHa'],
      );
      final province = _readString(
        data,
        const <String>['province', 'locationProvince'],
      );

      totalArea += area;

      final provinceName =
          province.isEmpty ? 'Chưa xác định' : province;

      provinceTotals.update(
        provinceName,
        (value) => value + area,
        ifAbsent: () => area,
      );

      final latitude = _readNullableDouble(
        data,
        const <String>[
          'latitude',
          'lat',
          'centerLatitude',
          'centroidLat',
        ],
      );
      final longitude = _readNullableDouble(
        data,
        const <String>[
          'longitude',
          'lng',
          'lon',
          'centerLongitude',
          'centroidLng',
        ],
      );

      if (latitude != null && longitude != null) {
        points.add(
          DashboardProjectPoint(
            projectName: _projectName(data),
            latitude: latitude,
            longitude: longitude,
          ),
        );
      }
    }

    for (final document in filteredInventory) {
      totalTrees += _readInt(
        document.data(),
        const <String>[
          'quantity',
          'treeQuantity',
          'totalTrees',
          'numberOfTrees',
        ],
      );
    }

    for (final document in filteredCalculations) {
      final data = document.data();
      final carbon = _readCarbonValue(data);
      final projectName = _projectName(data);

      totalCarbon += carbon;

      projectCarbonTotals.update(
        projectName.isEmpty ? 'Chưa xác định' : projectName,
        (value) => value + carbon,
        ifAbsent: () => carbon,
      );
    }

    final provinceAreas = provinceTotals.entries
        .map(
          (entry) => DashboardProvinceArea(
            province: entry.key,
            areaHa: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.areaHa.compareTo(a.areaHa));

    final carbonByProject = projectCarbonTotals.entries
        .map(
          (entry) => DashboardProjectCarbon(
            projectName: entry.key,
            co2eTon: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.co2eTon.compareTo(a.co2eTon));

    final recentActivities = filteredActivities.map((document) {
      final data = document.data();

      return DashboardActivity(
        date: _readDate(
          data,
          const <String>[
            'date',
            'activityDate',
            'createdAt',
            'updatedAt',
          ],
        ),
        project: _projectName(data),
        activityType: _readString(
          data,
          const <String>[
            'activityType',
            'type',
            'workType',
            'activity',
          ],
        ),
        user: _readString(
          data,
          const <String>[
            'user',
            'userName',
            'worker',
            'createdBy',
          ],
        ),
        location: _readString(
          data,
          const <String>[
            'location',
            'address',
            'province',
          ],
        ),
        photoCount: _photoCount(data),
      );
    }).toList()
      ..sort((a, b) {
        final aDate =
            a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return DashboardData(
      forestOwners: filteredOwners.length,
      forestProjects: filteredProjects.length,
      totalAreaHa: totalArea,
      totalTrees: totalTrees,
      estimatedCarbonTon: totalCarbon,
      areaByProvince: provinceAreas,
      carbonByProject: carbonByProject.take(6).toList(),
      recentActivities: recentActivities.take(6).toList(),
      projectPoints: points.take(20).toList(),
    );
  }

  bool _matchesDate(
    Map<String, dynamic> data,
    List<String> keys,
    DateTimeRange range, {
    required bool includeWhenMissing,
  }) {
    final date = _readDate(data, keys);

    if (date == null) return includeWhenMissing;

    final value = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );

    return !value.isBefore(start) && !value.isAfter(end);
  }

  String _projectName(Map<String, dynamic> data) {
    final value = _readString(
      data,
      const <String>[
        'projectName',
        'project',
        'name',
      ],
    );

    return value;
  }

  String _readString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  double _readDouble(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    return _readNullableDouble(data, keys) ?? 0;
  }

  double? _readNullableDouble(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is num) return value.toDouble();

      if (value != null) {
        final parsed = double.tryParse(
          value
              .toString()
              .replaceAll(',', '')
              .replaceAll(' ha', '')
              .trim(),
        );

        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  int _readInt(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is int) return value;
      if (value is num) return value.toInt();

      if (value != null) {
        final parsed = int.tryParse(
          value.toString().replaceAll(',', '').trim(),
        );

        if (parsed != null) return parsed;
      }
    }

    return 0;
  }

  double _readCarbonValue(Map<String, dynamic> data) {
    final co2e = _readNullableDouble(
      data,
      const <String>[
        'co2EquivalentTon',
        'co2eTon',
        'totalCo2e',
        'estimatedCarbon',
      ],
    );

    if (co2e != null) return co2e;

    final carbonStock = _readNullableDouble(
      data,
      const <String>[
        'carbonStockTon',
        'carbonTon',
        'totalCarbon',
      ],
    );

    if (carbonStock != null) {
      return carbonStock * 44 / 12;
    }

    return 0;
  }

  DateTime? _readDate(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;

      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }

      if (value is String) {
        final iso = DateTime.tryParse(value);
        if (iso != null) return iso;

        final slashParts = value.split('/');

        if (slashParts.length == 3) {
          final day = int.tryParse(slashParts[0]);
          final month = int.tryParse(slashParts[1]);
          final year = int.tryParse(slashParts[2]);

          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
    }

    return null;
  }

  int _photoCount(Map<String, dynamic> data) {
    const keys = <String>[
      'photos',
      'photoUrls',
      'images',
      'attachments',
    ];

    for (final key in keys) {
      final value = data[key];

      if (value is Iterable) return value.length;
      if (value is String && value.trim().isNotEmpty) return 1;
    }

    return _readInt(
      data,
      const <String>['photoCount', 'numberOfPhotos'],
    );
  }
}
