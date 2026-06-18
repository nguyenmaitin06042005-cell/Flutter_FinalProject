import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../services/logbook_service.dart';
import '../widgets/app_colors.dart';
import 'dart:async';

class ForestLogbookPage extends StatefulWidget {
  const ForestLogbookPage({super.key});

  @override
  State<ForestLogbookPage> createState() => _ForestLogbookPageState();
}

class _ForestLogbookPageState extends State<ForestLogbookPage> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedProject = 'All Projects';
  String _selectedWeekKey = 'ALL_WEEKS';
  int _currentPage = 1;

  ActivityRecord? _selectedActivity;

  final LogbookService _logbookService = LogbookService();
  StreamSubscription? _subscription;
  List<ActivityRecord> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _subscription = _logbookService.getActivitiesStream().listen(
      (data) {
        if (!mounted) return;

        setState(() {
          _activities = data;

          if (_activities.isEmpty) {
            _selectedActivity = null;
          } else {
            final selectedId = _selectedActivity?.id;
            final selectedIndex = _activities.indexWhere(
              (item) => item.id == selectedId,
            );

            _selectedActivity = selectedIndex >= 0
                ? _activities[selectedIndex]
                : _activities.first;
          }

          _isLoading = false;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Lỗi đọc Forest Logbook Firebase: $error');
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi đọc Firebase: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 10),
            ),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  DateTime _endOfWeek(DateTime date) {
    return _startOfWeek(date).add(const Duration(days: 6));
  }

  String _weekKey(DateTime date) {
    final start = _startOfWeek(date);
    return '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
  }

  String _weekLabelFromStart(DateTime start) {
    final end = _endOfWeek(start);
    return 'Tuần ${_formatDate(start)} - ${_formatDate(end)}';
  }

  List<WeekOption> get _weekOptions {
    final starts = <DateTime>{_startOfWeek(DateTime.now())};

    for (final activity in _activities) {
      starts.add(_startOfWeek(activity.date));
    }

    final sorted = starts.toList()..sort((a, b) => b.compareTo(a));

    return [
      const WeekOption(key: 'ALL_WEEKS', label: 'Tất cả các tuần'),
      ...sorted.map(
        (start) =>
            WeekOption(key: _weekKey(start), label: _weekLabelFromStart(start)),
      ),
    ];
  }

  List<ActivityRecord> get _filteredActivities {
    final keyword = _searchController.text.trim().toLowerCase();

    return _activities.where((activity) {
      final matchesSearch = keyword.isEmpty ||
          activity.user.toLowerCase().contains(keyword) ||
          activity.location.toLowerCase().contains(keyword) ||
          activity.project.toLowerCase().contains(keyword) ||
          activity.activityType.toLowerCase().contains(keyword) ||
          activity.description.toLowerCase().contains(keyword);

      final matchesProject = _selectedProject == 'All Projects' ||
          activity.project == _selectedProject;

      final matchesWeek = _selectedWeekKey == 'ALL_WEEKS' ||
          _weekKey(activity.date) == _selectedWeekKey;

      return matchesSearch && matchesProject && matchesWeek;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f8f6),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 900;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffe4ebe6)),
              ),
              child: stacked
                  ? Column(
                      children: [
                        Expanded(child: _buildLogbookSection()),
                        const Divider(height: 1),
                        SizedBox(height: 560, child: _buildActivityDetail()),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 52, child: _buildLogbookSection()),
                        Container(width: 1, color: const Color(0xffe4ebe6)),
                        Expanded(flex: 48, child: _buildActivityDetail()),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogbookSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forest Logbook',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xff17211b),
            ),
          ),
          const SizedBox(height: 18),
          _buildToolbar(),
          const SizedBox(height: 14),
          Expanded(child: _buildActivityTable()),
          const SizedBox(height: 8),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final weekOptions = _weekOptions;
    final selectedWeekExists = weekOptions.any(
      (option) => option.key == _selectedWeekKey,
    );
    final safeSelectedWeek =
        selectedWeekExists ? _selectedWeekKey : 'ALL_WEEKS';

    final projectOptions = _activities
        .map((activity) => activity.project)
        .toSet()
        .toList()
      ..sort();

    final safeSelectedProject = _selectedProject == 'All Projects' ||
            projectOptions.contains(_selectedProject)
        ? _selectedProject
        : 'All Projects';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 590;

        final search = SizedBox(
          width: compact ? double.infinity : 110,
          height: 38,
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 10.5),
            onChanged: (_) => setState(() => _currentPage = 1),
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: const TextStyle(fontSize: 10.5),
              prefixIcon: const Icon(Icons.search, size: 16),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 34,
                minHeight: 34,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Color(0xffdfe7e2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Color(0xffdfe7e2)),
              ),
            ),
          ),
        );

        // Bộ lọc dự án: luôn có lựa chọn All Projects.
        final projectDropdown = SizedBox(
          width: 150,
          height: 38,
          child: DropdownButtonFormField<String>(
            value: safeSelectedProject,
            isExpanded: true,
            iconSize: 18,
            style: const TextStyle(fontSize: 9.8, color: Color(0xff263029)),
            decoration: _dropdownDecoration(),
            selectedItemBuilder: (context) {
              return <String>['All Projects', ...projectOptions].map((project) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    project,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.8,
                      color: Color(0xff263029),
                    ),
                  ),
                );
              }).toList();
            },
            items: <String>['All Projects', ...projectOptions].map((project) {
              return DropdownMenuItem<String>(
                value: project,
                child: Text(
                  project,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedProject = value;
                _currentPage = 1;
              });
            },
          ),
        );

        // Bộ lọc tuần theo ngày thực tế trong dữ liệu.
        final weekDropdown = SizedBox(
          width: 190,
          height: 38,
          child: DropdownButtonFormField<String>(
            value: safeSelectedWeek,
            isExpanded: true,
            iconSize: 18,
            style: const TextStyle(fontSize: 9, color: Color(0xff263029)),
            decoration: _dropdownDecoration(),
            selectedItemBuilder: (context) {
              return weekOptions.map((option) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xff263029),
                    ),
                  ),
                );
              }).toList();
            },
            items: weekOptions.map((option) {
              return DropdownMenuItem<String>(
                value: option.key,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedWeekKey = value;
                _currentPage = 1;
              });
            },
          ),
        );

        final addButton = SizedBox(
          width: 118,
          height: 38,
          child: ElevatedButton.icon(
            onPressed: () => _showActivityDialog(),
            icon: const Icon(Icons.add, size: 15),
            label: const Text(
              'New Activity',
              maxLines: 1,
              style: TextStyle(fontSize: 9.8, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              search,
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [projectDropdown, weekDropdown, addButton],
              ),
            ],
          );
        }

        return Row(
          children: [
            search,
            const SizedBox(width: 7),
            projectDropdown,
            const SizedBox(width: 7),
            weekDropdown,
            const Spacer(),
            addButton,
          ],
        );
      },
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Color(0xffdfe7e2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Color(0xffdfe7e2)),
      ),
    );
  }

  Widget _buildActivityTable() {
    final rows = _filteredActivities;

    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'Không có nhật ký trong tuần đã chọn.',
          style: TextStyle(
            color: Color(0xff7b877f),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            horizontalMargin: 8,
            columnSpacing: 20,
            headingRowHeight: 46,
            dataRowMinHeight: 62,
            dataRowMaxHeight: 66,
            headingRowColor: MaterialStateProperty.all(const Color(0xfff7faf8)),
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Activity Type')),
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Location')),
              DataColumn(label: Text('Photos')),
              DataColumn(
                label: SizedBox(
                  width: 92,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('Actions'),
                  ),
                ),
              ),
            ],
            rows: rows.map((activity) {
              final selected = identical(activity, _selectedActivity);

              void selectActivity() {
                setState(() => _selectedActivity = activity);
              }

              return DataRow(
                color: MaterialStateProperty.all(
                  selected ? const Color(0xfff0f9f3) : Colors.transparent,
                ),
                cells: [
                  DataCell(
                    Text(_formatDate(activity.date)),
                    onTap: selectActivity,
                  ),
                  DataCell(
                    _activityBadge(activity.activityType),
                    onTap: selectActivity,
                  ),
                  DataCell(
                    SizedBox(
                      width: 105,
                      child: Text(
                        activity.user,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onTap: selectActivity,
                  ),
                  DataCell(
                    SizedBox(
                      width: 82,
                      child: Text(
                        activity.location,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onTap: selectActivity,
                  ),
                  DataCell(
                    _photoPreview(activity.photos),
                    onTap: selectActivity,
                  ),
                  DataCell(
                    SizedBox(
                      width: 92,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<String>(
                          tooltip: 'Actions',
                          onSelected: (value) {
                            setState(() => _selectedActivity = activity);

                            if (value == 'edit') {
                              _showActivityDialog(activity: activity);
                            } else if (value == 'delete') {
                              _deleteActivity(activity);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '+${activity.photos.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.more_horiz, size: 19),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _activityBadge(String type) {
    final style = _activityStyle(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: style.foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  _BadgeStyle _activityStyle(String type) {
    switch (type) {
      case 'Planting':
        return const _BadgeStyle(
          background: Color(0xffe8f7ed),
          foreground: Color(0xff168a45),
        );
      case 'Maintenance':
        return const _BadgeStyle(
          background: Color(0xffeaf4ff),
          foreground: Color(0xff2375b9),
        );
      case 'Fertilizing':
        return const _BadgeStyle(
          background: Color(0xfff4edff),
          foreground: Color(0xff7d46b5),
        );
      case 'Patrol':
        return const _BadgeStyle(
          background: Color(0xfffff0e7),
          foreground: Color(0xffd96820),
        );
      case 'Fire Prevention':
        return const _BadgeStyle(
          background: Color(0xffffe8e8),
          foreground: Color(0xffc43b3b),
        );
      default:
        return const _BadgeStyle(
          background: Color(0xffedf1ef),
          foreground: Color(0xff59645e),
        );
    }
  }

  Widget _photoPreview(List<ActivityPhoto> photos) {
    final visiblePhotos = photos.take(3).toList();

    return SizedBox(
      width: 112,
      child: Row(
        children: [
          for (int i = 0; i < visiblePhotos.length; i++) ...[
            _photoWidget(
              visiblePhotos[i],
              width: 32,
              height: 32,
              borderRadius: 4,
            ),
            if (i < visiblePhotos.length - 1) const SizedBox(width: 5),
          ],
          if (photos.isEmpty)
            const Text(
              'No photo',
              style: TextStyle(color: Color(0xff8b958f), fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityDetail() {
    final selected = _selectedActivity;
    if (selected == null) {
      return const Center(
        child: Text(
          'Chưa có dữ liệu. Vui lòng tạo mới.',
          style:
              TextStyle(color: Color(0xff7b877f), fontWeight: FontWeight.w600),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Detail',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Color(0xff17211b),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imageWidth =
                      constraints.maxWidth >= 580 ? 250.0 : 220.0;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: imageWidth,
                        child: _detailPhotoGallery(selected.photos),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailRow(
                              'Activity Type',
                              selected.activityType,
                            ),
                            _detailRow(
                              'Date',
                              _formatDateTime(selected.date),
                            ),
                            _detailRow('User', selected.user),
                            _detailRow('Project', selected.project),
                            _detailRow('Location', selected.location),
                            _detailRow(
                              'Latitude',
                              selected.latitude.toStringAsFixed(6),
                            ),
                            _detailRow(
                              'Longitude',
                              selected.longitude.toStringAsFixed(6),
                            ),
                            _detailRow(
                              'Description',
                              selected.description,
                            ),
                            _detailRow(
                              'Photos',
                              '${selected.photos.length}/10',
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                _showActivityDialog(activity: selected);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailPhotoGallery(List<ActivityPhoto> photos) {
    if (photos.isEmpty) {
      return Container(
        height: 230,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xffeef3ef),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 54,
            color: Color(0xff9aa69e),
          ),
        ),
      );
    }

    final visible = photos.take(2).toList();

    return Column(
      children: [
        for (int i = 0; i < visible.length; i++) ...[
          _photoWidget(
            visible[i],
            width: double.infinity,
            height: 215,
            borderRadius: 8,
          ),
          if (i < visible.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _photoWidget(
    ActivityPhoto photo, {
    required double width,
    required double height,
    required double borderRadius,
  }) {
    final placeholder = Container(
      width: width,
      height: height,
      color: const Color(0xffe8eee9),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xff8e9a92)),
    );

    Widget image;

    if (photo.bytes != null) {
      image = Image.memory(
        photo.bytes!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else if (photo.url != null) {
      image = Image.network(
        photo.url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      image = placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image,
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xff8a958e), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xff263029),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed:
              _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        _pageButton(1),
        _pageButton(2),
        _pageButton(3),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('...'),
        ),
        _pageButton(8),
        IconButton(
          onPressed: () => setState(() => _currentPage++),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _pageButton(int page) {
    final active = _currentPage == page;

    return InkWell(
      onTap: () => setState(() => _currentPage = page),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            color: active ? Colors.white : const Color(0xff3d4942),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _showActivityDialog({ActivityRecord? activity}) async {
    final isEditing = activity != null;

    String activityType = activity?.activityType ?? 'Planting';
    String project = activity?.project ?? 'Dak Lak Project 01';

    final userController = TextEditingController(text: activity?.user ?? '');
    final locationController = TextEditingController(
      text: activity?.location ?? '',
    );
    final latitudeController = TextEditingController(
      text: activity?.latitude.toStringAsFixed(6) ?? '',
    );
    final longitudeController = TextEditingController(
      text: activity?.longitude.toStringAsFixed(6) ?? '',
    );
    final descriptionController = TextEditingController(
      text: activity?.description ?? '',
    );

    DateTime selectedDate = activity?.date ?? DateTime.now();
    List<ActivityPhoto> selectedPhotos = [...?activity?.photos];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            Future<void> pickPhotos() async {
              if (selectedPhotos.length >= 10) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Mỗi nhật ký chỉ được tối đa 10 ảnh.'),
                  ),
                );
                return;
              }

              final result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: const ['jpg', 'jpeg', 'png'],
                allowMultiple: true,
                withData: true,
              );

              if (result == null || result.files.isEmpty) return;

              final remaining = 10 - selectedPhotos.length;
              final picked = result.files
                  .take(remaining)
                  .where((file) => file.bytes != null)
                  .map(
                    (file) => ActivityPhoto(bytes: file.bytes, name: file.name),
                  )
                  .toList();

              dialogSetState(() {
                selectedPhotos.addAll(picked);
              });

              if (result.files.length > remaining) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Chỉ thêm $remaining ảnh để không vượt quá 10 ảnh.',
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(isEditing ? 'Edit Activity' : 'New Activity'),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: activityType,
                              decoration: const InputDecoration(
                                labelText: 'Activity Type',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Planting',
                                  child: Text('Trồng cây'),
                                ),
                                DropdownMenuItem(
                                  value: 'Maintenance',
                                  child: Text('Chăm sóc cây'),
                                ),
                                DropdownMenuItem(
                                  value: 'Fertilizing',
                                  child: Text('Bón phân'),
                                ),
                                DropdownMenuItem(
                                  value: 'Growth Check',
                                  child: Text('Kiểm tra sinh trưởng'),
                                ),
                                DropdownMenuItem(
                                  value: 'Patrol',
                                  child: Text('Tuần tra'),
                                ),
                                DropdownMenuItem(
                                  value: 'Fire Prevention',
                                  child: Text('Phòng cháy chữa cháy'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                dialogSetState(() => activityType = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: project,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Project',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Dak Lak Project 01',
                                  child: Text('Dak Lak Project 01'),
                                ),
                                DropdownMenuItem(
                                  value: 'Lam Dong Project 02',
                                  child: Text('Lam Dong Project 02'),
                                ),
                                DropdownMenuItem(
                                  value: 'Gia Lai Project 01',
                                  child: Text('Gia Lai Project 01'),
                                ),
                                DropdownMenuItem(
                                  value: 'Quang Tri Project 01',
                                  child: Text('Quang Tri Project 01'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                dialogSetState(() => project = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: userController,
                              decoration: const InputDecoration(
                                labelText: 'User',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: locationController,
                              decoration: const InputDecoration(
                                labelText: 'Location',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final value = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );

                          if (value != null) {
                            dialogSetState(() {
                              selectedDate = DateTime(
                                value.year,
                                value.month,
                                value.day,
                                selectedDate.hour,
                                selectedDate.minute,
                              );
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_month),
                          ),
                          child: Text(_formatDate(selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latitudeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'GPS Latitude',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: longitudeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'GPS Longitude',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: pickPhotos,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload JPG/PNG'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${selectedPhotos.length}/10 ảnh',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (selectedPhotos.isNotEmpty)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (int i = 0; i < selectedPhotos.length; i++)
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _photoWidget(
                                    selectedPhotos[i],
                                    width: 86,
                                    height: 70,
                                    borderRadius: 6,
                                  ),
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: InkWell(
                                      onTap: () {
                                        dialogSetState(() {
                                          selectedPhotos.removeAt(i);
                                        });
                                      },
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final user = userController.text.trim();
                    final location = locationController.text.trim();

                    final latitude = double.tryParse(
                      latitudeController.text.trim().replaceAll(',', '.'),
                    );
                    final longitude = double.tryParse(
                      longitudeController.text.trim().replaceAll(',', '.'),
                    );

                    final description = descriptionController.text.trim();

                    if (user.isEmpty ||
                        location.isEmpty ||
                        latitude == null ||
                        longitude == null ||
                        description.isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng nhập đầy đủ thông tin hợp lệ.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final result = ActivityRecord(
                      id: activity?.id ?? '',
                      date: selectedDate,
                      activityType: activityType,
                      user: user,
                      project: project,
                      location: location,
                      latitude: latitude,
                      longitude: longitude,
                      description: description,
                      photos: List<ActivityPhoto>.from(selectedPhotos),
                    );

                    try {
                      ScaffoldMessenger.of(
                        this.context,
                      ).hideCurrentSnackBar();

                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đang lưu dữ liệu lên Firebase...',
                          ),
                          duration: Duration(seconds: 30),
                        ),
                      );

                      late ActivityRecord savedActivity;

                      if (activity == null) {
                        savedActivity = await _logbookService.addActivity(
                          result,
                        );
                      } else {
                        savedActivity = await _logbookService.updateActivity(
                          result,
                        );
                      }

                      if (!mounted) return;

                      setState(() {
                        _selectedActivity = savedActivity;
                        _selectedWeekKey = 'ALL_WEEKS';
                        _selectedProject = 'All Projects';
                        _currentPage = 1;

                        final index = _activities.indexWhere(
                          (item) => item.id == savedActivity.id,
                        );

                        if (index >= 0) {
                          _activities[index] = savedActivity;
                        } else {
                          _activities.insert(0, savedActivity);
                        }
                      });

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }

                      ScaffoldMessenger.of(
                        this.context,
                      ).hideCurrentSnackBar();

                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            activity == null
                                ? 'Đã thêm hoạt động thành công.'
                                : 'Đã cập nhật hoạt động thành công.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e, stackTrace) {
                      debugPrint('Lỗi lưu hoạt động: $e');
                      debugPrintStack(stackTrace: stackTrace);

                      if (!mounted) return;

                      ScaffoldMessenger.of(
                        this.context,
                      ).hideCurrentSnackBar();

                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Không thể lưu Firebase: $e',
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 10),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEditing ? 'Save Changes' : 'Save Activity'),
                ),
              ],
            );
          },
        );
      },
    );

    userController.dispose();
    locationController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    descriptionController.dispose();
  }

  Future<void> _deleteActivity(ActivityRecord activity) async {
    if (_activities.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phải giữ lại ít nhất một nhật ký.')),
      );
      return;
    }

    try {
      await _logbookService.deleteActivity(activity);
      if (mounted) {
        setState(() {
          if (_selectedActivity?.id == activity.id) {
            _selectedActivity = _activities.firstWhere(
              (a) => a.id != activity.id,
              orElse: () => _activities.first,
            );
          }

          final validWeekKeys = _weekOptions.map((e) => e.key).toSet();
          if (!validWeekKeys.contains(_selectedWeekKey)) {
            _selectedWeekKey = 'ALL_WEEKS';
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class WeekOption {
  final String key;
  final String label;

  const WeekOption({required this.key, required this.label});
}

class _BadgeStyle {
  final Color background;
  final Color foreground;

  const _BadgeStyle({required this.background, required this.foreground});
}
