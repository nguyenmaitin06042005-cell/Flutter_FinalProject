import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/forest_project_model.dart';
import '../models/project_request_model.dart';
import '../models/user_model.dart';
import '../services/forest_project_service.dart';
import '../services/notification_service.dart';
import '../services/project_request_service.dart';
import '../services/user_service.dart';
import '../widgets/app_colors.dart';

class ForestProjectsPage extends StatefulWidget {
  const ForestProjectsPage({super.key, required this.currentUser});
  final UserModel currentUser;

  @override
  State<ForestProjectsPage> createState() => _ForestProjectsPageState();
}

class _ForestProjectsPageState extends State<ForestProjectsPage> {
  final ForestProjectService _service = ForestProjectService();
  final NotificationService _notificationService = NotificationService();
  final ProjectRequestService _requestService = ProjectRequestService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _projectTableScrollController = ScrollController();

  String _statusFilter = 'All Status';
  String _provinceFilter = 'All Provinces';
  ForestProject? _selectedProject;

  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  static const List<String> _statuses = [
    'All Status', 'Draft', 'Surveying', 'Active', 'Suspended',
  ];

  @override
  void dispose() {
    _projectTableScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  List<ForestProject> _filter(List<ForestProject> all) {
    return all.where((p) {
      final q = _searchQuery;
      final matchSearch = q.isEmpty ||
          p.projectName.toLowerCase().contains(q) ||
          p.projectId.toLowerCase().contains(q) ||
          p.owner.toLowerCase().contains(q) ||
          p.province.toLowerCase().contains(q);
      final matchStatus =
          _statusFilter == 'All Status' || p.status == _statusFilter;
      final matchProvince =
          _provinceFilter == 'All Provinces' || p.province == _provinceFilter;
      return matchSearch && matchStatus && matchProvince;
    }).toList();
  }

  List<String> _provinces(List<ForestProject> all) {
    final provinces = all.map((p) => p.province).where((p) => p.isNotEmpty).toSet().toList()..sort();
    return ['All Provinces', ...provinces];
  }

  String _generateProjectId() {
    final now = DateTime.now();
    return 'PRJ-${now.year}${now.millisecond.toString().padLeft(3, '0')}${now.microsecond.toString().padLeft(3, '0')}';
  }

  Stream<List<ForestProject>> get _projectStream {
    if (widget.currentUser.isOwner) {
      return _service.watchProjectsByOwner(widget.currentUser.uid);
    }
    if (widget.currentUser.isWorker) {
      return _service.watchProjects().map((projects) {
        return projects.where((p) => p.workerUids.contains(widget.currentUser.uid)).toList();
      });
    }
    return _service.watchProjects();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ForestProject>>(
      stream: _projectStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xfff5f8f6),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xfff5f8f6),
            body: Center(child: Text('Lỗi: ${snap.error}')),
          );
        }

        final allProjects = snap.data ?? [];
        final filtered = _filter(allProjects);
        final provinces = _provinces(allProjects);

        // Auto-select first project if nothing is selected and we have projects
        if (_selectedProject == null && filtered.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedProject == null) {
              setState(() => _selectedProject = filtered.first);
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xfff5f8f6),
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffe5ebe7)),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildMainContent(filtered, provinces)),
                  Container(width: 1, color: const Color(0xffe5ebe7)),
                  SizedBox(
                    width: 320,
                    child: _buildSidePanel(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(List<ForestProject> filtered, List<String> provinces) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildToolbar(provinces),
          const SizedBox(height: 16),
          Expanded(child: _buildTable(filtered)),
          const SizedBox(height: 12),
          _buildPagination(filtered.length),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: const [
        Text(
          'Forest Projects',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: Color(0xff17211b),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(List<String> provinces) {
    final searchBox = SizedBox(
      height: 42,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() => _currentPage = 1),
        decoration: InputDecoration(
          hintText: 'Search projects...',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 19),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
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

    final provinceDropdown = SizedBox(
      width: 165,
      height: 42,
      child: DropdownButtonFormField<String>(
        value: _provinceFilter,
        isExpanded: true,
        decoration: _dropdownDecoration(),
        items: provinces
            .map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _provinceFilter = value;
            _currentPage = 1;
          });
        },
      ),
    );

    final statusDropdown = SizedBox(
      width: 125,
      height: 42,
      child: DropdownButtonFormField<String>(
        value: _statusFilter,
        isExpanded: true,
        decoration: _dropdownDecoration(),
        items: _statuses
            .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _statusFilter = value;
            _currentPage = 1;
          });
        },
      ),
    );

    final addButton = SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: widget.currentUser.isOwner ? _showNewProjectDialog : null,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Project'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: double.infinity, child: searchBox),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  provinceDropdown,
                  statusDropdown,
                  if (widget.currentUser.isOwner) addButton,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchBox),
            const SizedBox(width: 10),
            provinceDropdown,
            const SizedBox(width: 10),
            statusDropdown,
            if (widget.currentUser.isOwner) ...[
              const SizedBox(width: 10),
              addButton,
            ],
          ],
        );
      },
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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

  Widget _buildTable(List<ForestProject> filtered) {
    if (filtered.isEmpty) {
      return _emptyState(
        icon: Icons.forest_outlined,
        title: 'Không tìm thấy dự án',
      );
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, filtered.length);
    final currentRows = filtered.sublist(startIndex, endIndex);

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            horizontalMargin: 8,
            columnSpacing: 28,
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 56,
            headingRowColor: WidgetStateProperty.all(const Color(0xfff7faf8)),
            columns: const [
              DataColumn(label: Text('Project ID')),
              DataColumn(label: Text('Project Name')),
              DataColumn(label: Text('Owner')),
              DataColumn(label: Text('Province')),
              DataColumn(label: Text('Area (ha)')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: currentRows.map((p) {
              final selected = p.id == _selectedProject?.id;
              void selectProject() {
                setState(() => _selectedProject = p);
              }

              return DataRow(
                color: WidgetStateProperty.all(
                  selected ? const Color(0xfff0f9f3) : Colors.transparent,
                ),
                cells: [
                  DataCell(Text(p.projectId), onTap: selectProject),
                  DataCell(
                    SizedBox(
                      width: 155,
                      child: Text(p.projectName, overflow: TextOverflow.ellipsis),
                    ),
                    onTap: selectProject,
                  ),
                  DataCell(
                    SizedBox(
                      width: 120,
                      child: Text(p.owner, overflow: TextOverflow.ellipsis),
                    ),
                    onTap: selectProject,
                  ),
                  DataCell(Text(p.province), onTap: selectProject),
                  DataCell(Text(p.areaHa.toStringAsFixed(1)), onTap: selectProject),
                  DataCell(_statusBadge(p.status), onTap: selectProject),
                  DataCell(
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'view', child: Text('View detail')),
                        if (widget.currentUser.isOwner)
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                      onSelected: (value) async {
                        setState(() => _selectedProject = p);
                        if (value == 'edit' && widget.currentUser.isOwner) {
                          _showEditDialog(p);
                        } else if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xóa dự án?'),
                              content: Text('Bạn có chắc chắn muốn xóa dự án "${p.projectName}" không? Thao tác này không thể hoàn tác.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && mounted) {
                            try {
                              await _service.deleteProject(p.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✓ Đã xóa dự án.'), backgroundColor: Color(0xff168a45)),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        }
                      },
                      child: const Icon(Icons.more_horiz, size: 20),
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

  Widget _tableHeaderCell(String text) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 8,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9.4,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: Color(0xff46534b),
        ),
      ),
    );
  }

  Widget _tableDataCell(
    String text, {
    bool bold = false,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Tooltip(
      message: text,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        alignment: textAlign == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 9,
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 9.8,
            height: 1.2,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: const Color(0xff2d3932),
          ),
        ),
      ),
    );
  }

  Widget _emptyState({required IconData icon, required String title}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: const Color(0xff9ca9a1)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xff77837b),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'Active':
        bg = const Color(0xffe9f8ee);
        fg = const Color(0xff168a45);
        break;
      case 'Surveying':
        bg = const Color(0xffe0f2fe);
        fg = const Color(0xff0284c7);
        break;
      case 'Suspended':
        bg = const Color(0xfffee2e2);
        fg = const Color(0xffdc2626);
        break;
      default:
        bg = const Color(0xfffff1e6);
        fg = const Color(0xffd97706);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPagination(int totalItems) {
    final totalPages = (totalItems / _itemsPerPage).ceil();
    if (totalPages <= 1) return const SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        for (int i = 1; i <= totalPages; i++)
          if (i == 1 || i == totalPages || (i >= _currentPage - 1 && i <= _currentPage + 1))
            _pageButton(i)
          else if (i == 2 || i == totalPages - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('...'),
            ),
        IconButton(
          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
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
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 4),
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

  // ── SIDE PANEL ────────────────────────────────
  Widget _buildSidePanel() {
    final selected = _selectedProject;
    if (selected == null) {
      return const Center(
        child: Text(
          'Chưa có dữ liệu. Vui lòng tạo mới.',
          style: TextStyle(color: Color(0xff7b877f), fontWeight: FontWeight.w600),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Detail',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xff17211b),
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Project ID', selected.projectId),
                  _detailRow('Project Name', selected.projectName),
                  _detailRow('Owner', selected.owner),
                  _detailRow('Province', selected.province),
                  _detailRow('District', selected.district),
                  _detailRow('Commune', selected.commune),
                  _detailRow('Forest Type', selected.forestType),
                  _detailRow('Tree Species', selected.treeSpecies),
                  _detailRow('Year Planted', selected.yearPlanted.toString()),
                  _detailRow('Area (ha)', selected.areaHa.toStringAsFixed(2)),
                  _detailRow('Status', selected.status),
                  
                  // Load Owner Details + Workers Details later via another component or FutureBuilder
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xffe5ebe7)),
                  const SizedBox(height: 20),
                  const Text('Owner & Workers',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xff17211b))),
                  const SizedBox(height: 16),
                  _OwnerWorkersInfo(
                    project: selected,
                    userService: _userService,
                  ),
                ],
              ),
            ),
          ),
          if (widget.currentUser.isOwner) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _showEditDialog(selected),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Project', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xff8b958f), fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xff253029),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewProjectDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _NewProjectDialog(
        currentUser: widget.currentUser,
        userService: _userService,
        requestService: _requestService,
        generateProjectId: _generateProjectId,
      ),
    );
  }

  Future<void> _showEditDialog(ForestProject project) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditProjectDialog(
        project: project,
        service: _service,
        userService: _userService,
        onUpdated: (updated) {
          setState(() {
            if (_selectedProject?.id == project.id) {
              _selectedProject = updated;
            }
          });
        },
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: TextStyle(
        fontSize: 14,
        color: readOnly ? const Color(0xff6b7280) : null,
      ),
      validator: validator ??
          (v) {
            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập $label';
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 14),
        filled: readOnly,
        fillColor: readOnly ? const Color(0xfff3f4f6) : null,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

// ── Additional Widget to load Owner + Workers Info ──
class _OwnerWorkersInfo extends StatefulWidget {
  final ForestProject project;
  final UserService userService;

  const _OwnerWorkersInfo({required this.project, required this.userService});

  @override
  State<_OwnerWorkersInfo> createState() => _OwnerWorkersInfoState();
}

class _OwnerWorkersInfoState extends State<_OwnerWorkersInfo> {
  UserModel? _ownerModel;
  List<UserModel> _workers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant _OwnerWorkersInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUids = oldWidget.project.workerUids;
    final newUids = widget.project.workerUids;
    bool uidsChanged = oldUids.length != newUids.length || !oldUids.every((uid) => newUids.contains(uid));

    if (oldWidget.project.ownerUid != widget.project.ownerUid || uidsChanged) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    if (widget.project.ownerUid.isNotEmpty) {
      final owner = await widget.userService.getUser(widget.project.ownerUid);
      final allWorkers = await widget.userService.getWorkersForOwner(widget.project.ownerUid).first;
      final assignedWorkers = allWorkers.where((w) => widget.project.workerUids.contains(w.uid)).toList();
      if (mounted) {
        setState(() {
          _ownerModel = owner;
          _workers = assignedWorkers;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOwnerCard(),
        const SizedBox(height: 12),
        const Text('Workers', style: TextStyle(fontSize: 13, color: Color(0xff8b958f))),
        const SizedBox(height: 8),
        if (_workers.isEmpty)
          const Text('No workers assigned.', style: TextStyle(fontSize: 13, color: Color(0xff5f6b64)))
        else
          ..._workers.map((w) => _buildWorkerCard(w)),
      ],
    );
  }

  Widget _buildOwnerCard() {
    final name = _ownerModel?.fullName.isNotEmpty == true ? _ownerModel!.fullName : widget.project.owner;
    final empId = _ownerModel?.employeeId ?? '—';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff0f9f3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffd4ead9)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'O',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xff1a2e22))),
                Text(empId, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(UserModel w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xfff5f8f6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffe2e9e4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xff3b82f6),
            child: Text(
              w.fullName.isNotEmpty ? w.fullName[0].toUpperCase() : 'W',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xff1a2e22))),
                Text(w.employeeId ?? '—', style: const TextStyle(fontSize: 11, color: Color(0xff3b82f6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── DIALOG CLASSES TO PREVENT CONTEXT / DISPOSE ISSUES ──

class _NewProjectDialog extends StatefulWidget {
  final UserModel currentUser;
  final UserService userService;
  final ProjectRequestService requestService;
  final String Function() generateProjectId;

  const _NewProjectDialog({
    required this.currentUser,
    required this.userService,
    required this.requestService,
    required this.generateProjectId,
  });

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController projectIdCtrl;
  final nameCtrl = TextEditingController();
  final provinceCtrl = TextEditingController();
  final districtCtrl = TextEditingController();
  final communeCtrl = TextEditingController();
  final forestTypeCtrl = TextEditingController();
  final treeSpeciesCtrl = TextEditingController();
  final yearCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  List<String> _selectedWorkers = [];
  bool _isSaving = false;
  late final Stream<List<UserModel>> _workersStream;

  @override
  void initState() {
    super.initState();
    projectIdCtrl = TextEditingController(text: widget.generateProjectId());
    _workersStream = widget.userService.getWorkersForOwner(widget.currentUser.uid);
  }

  @override
  void dispose() {
    projectIdCtrl.dispose();
    nameCtrl.dispose();
    provinceCtrl.dispose();
    districtCtrl.dispose();
    communeCtrl.dispose();
    forestTypeCtrl.dispose();
    treeSpeciesCtrl.dispose();
    yearCtrl.dispose();
    areaCtrl.dispose();
    super.dispose();
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      validator: validator ??
          (v) {
            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập $label';
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 14),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yêu cầu tạo dự án'),
      content: SizedBox(
        width: 900,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff8e1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xffe8b84b)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xffb45309), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Yêu cầu sẽ được gửi Admin xem xét. Bạn sẽ nhận thông báo khi được xử lý.',
                          style: TextStyle(fontSize: 13, color: Color(0xff7a4a00), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 32) / 3;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(width: itemWidth, child: _dialogField(controller: projectIdCtrl, label: 'Project ID', hint: 'PRJ-0001')),
                        SizedBox(width: itemWidth, child: _dialogField(controller: nameCtrl, label: 'Tên dự án', hint: 'Forest A')),
                        SizedBox(width: itemWidth, child: _dialogField(controller: provinceCtrl, label: 'Tỉnh/Thành phố', hint: 'Đắk Lắk')),
                        SizedBox(width: itemWidth, child: _dialogField(controller: districtCtrl, label: 'Huyện', hint: 'Buôn Đôn')),
                        SizedBox(width: itemWidth, child: _dialogField(controller: communeCtrl, label: 'Xã', hint: 'Ea Huar')),
                        SizedBox(width: itemWidth, child: _dialogField(controller: forestTypeCtrl, label: 'Loại rừng', hint: 'Rừng sản xuất')),
                        SizedBox(width: itemWidth, child: _dialogField(controller: treeSpeciesCtrl, label: 'Loài cây', hint: 'Keo lai')),
                        SizedBox(width: itemWidth, child: _dialogField(
                          controller: yearCtrl,
                          label: 'Năm trồng',
                          hint: '2022',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final y = int.tryParse(v?.trim() ?? '');
                            if (y == null || y < 1900 || y > DateTime.now().year + 1) return 'Năm không hợp lệ';
                            return null;
                          },
                        )),
                        SizedBox(width: itemWidth, child: _dialogField(
                          controller: areaCtrl,
                          label: 'Diện tích (ha)',
                          hint: '1250.50',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            final a = double.tryParse(v?.trim().replaceAll(',', '.') ?? '');
                            if (a == null || a < 0) return 'Diện tích không hợp lệ';
                            return null;
                          },
                        )),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildWorkerSelection(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  setState(() => _isSaving = true);
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(context);
                  try {
                    final admins = await widget.userService.getAdmins();
                    final adminUids = admins.map((a) => a.uid).toList();
                    final ownerName = widget.currentUser.fullName.trim().isNotEmpty
                        ? widget.currentUser.fullName
                        : widget.currentUser.email;
                    final request = ProjectRequest(
                      id: '',
                      ownerUid: widget.currentUser.uid,
                      ownerEmail: widget.currentUser.email,
                      ownerName: ownerName,
                      status: ProjectRequestStatus.pending,
                      createdAt: DateTime.now(),
                      projectId: projectIdCtrl.text.trim(),
                      projectName: nameCtrl.text.trim(),
                      owner: ownerName,
                      province: provinceCtrl.text.trim(),
                      district: districtCtrl.text.trim(),
                      commune: communeCtrl.text.trim(),
                      forestType: forestTypeCtrl.text.trim(),
                      treeSpecies: treeSpeciesCtrl.text.trim(),
                      yearPlanted: int.parse(yearCtrl.text.trim()),
                      areaHa: double.parse(areaCtrl.text.trim().replaceAll(',', '.')),
                      workerUids: _selectedWorkers,
                    );
                    await widget.requestService.submitRequest(request: request, adminUids: adminUids);
                    if (mounted) {
                      nav.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('✓ Yêu cầu đã gửi đến Admin.'),
                          backgroundColor: Color(0xff168a45),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isSaving = false);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Gửi yêu cầu'),
        ),
      ],
    );
  }

  Widget _buildWorkerSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chọn nhân viên tham gia dự án:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<UserModel>>(
          stream: _workersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('Không có nhân viên nào.');
            }
            final workers = snapshot.data!;
            return Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(5),
              ),
              child: ListView.builder(
                itemCount: workers.length,
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  final isSelected = _selectedWorkers.contains(worker.uid);
                  return CheckboxListTile(
                    title: Text(worker.fullName.isNotEmpty ? worker.fullName : worker.email),
                    subtitle: Text(worker.employeeId ?? ''),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedWorkers.add(worker.uid);
                        } else {
                          _selectedWorkers.remove(worker.uid);
                        }
                      });
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EditProjectDialog extends StatefulWidget {
  final ForestProject project;
  final ForestProjectService service;
  final UserService userService;
  final Function(ForestProject) onUpdated;

  const _EditProjectDialog({
    required this.project,
    required this.service,
    required this.userService,
    required this.onUpdated,
  });

  @override
  State<_EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<_EditProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController projectIdCtrl;
  late final TextEditingController nameCtrl;
  late final TextEditingController provinceCtrl;
  late final TextEditingController districtCtrl;
  late final TextEditingController communeCtrl;
  late final TextEditingController forestTypeCtrl;
  late final TextEditingController treeSpeciesCtrl;
  late final TextEditingController yearCtrl;
  late final TextEditingController areaCtrl;
  late String _selectedStatus;
  List<String> _selectedWorkers = [];
  bool _isSaving = false;
  late final Stream<List<UserModel>> _workersStream;

  @override
  void initState() {
    super.initState();
    projectIdCtrl = TextEditingController(text: widget.project.projectId);
    nameCtrl = TextEditingController(text: widget.project.projectName);
    provinceCtrl = TextEditingController(text: widget.project.province);
    districtCtrl = TextEditingController(text: widget.project.district);
    communeCtrl = TextEditingController(text: widget.project.commune);
    forestTypeCtrl = TextEditingController(text: widget.project.forestType);
    treeSpeciesCtrl = TextEditingController(text: widget.project.treeSpecies);
    yearCtrl = TextEditingController(text: widget.project.yearPlanted.toString());
    areaCtrl = TextEditingController(text: widget.project.areaHa.toString());
    _selectedStatus = widget.project.status;
    _selectedWorkers = List.from(widget.project.workerUids);
    _workersStream = widget.userService.getWorkersForOwner(widget.project.ownerUid);
  }

  @override
  void dispose() {
    projectIdCtrl.dispose();
    nameCtrl.dispose();
    provinceCtrl.dispose();
    districtCtrl.dispose();
    communeCtrl.dispose();
    forestTypeCtrl.dispose();
    treeSpeciesCtrl.dispose();
    yearCtrl.dispose();
    areaCtrl.dispose();
    super.dispose();
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      validator: validator ??
          (v) {
            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập $label';
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 14),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa dự án'),
      content: SizedBox(
        width: 900,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 32) / 3;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(width: itemWidth, child: _dialogField(controller: projectIdCtrl, label: 'Project ID', hint: 'PRJ-0001')),
                    SizedBox(width: itemWidth, child: _dialogField(controller: nameCtrl, label: 'Tên dự án', hint: 'Forest A')),
                    SizedBox(width: itemWidth, child: _dialogField(controller: provinceCtrl, label: 'Tỉnh/Thành phố', hint: 'Đắk Lắk')),
                    SizedBox(width: itemWidth, child: _dialogField(controller: districtCtrl, label: 'Huyện', hint: 'Buôn Đôn')),
                    SizedBox(width: itemWidth, child: _dialogField(controller: communeCtrl, label: 'Xã', hint: 'Ea Huar')),
                    SizedBox(width: itemWidth, child: _dialogField(controller: forestTypeCtrl, label: 'Loại rừng', hint: 'Rừng sản xuất')),
                    SizedBox(width: itemWidth, child: _dialogField(controller: treeSpeciesCtrl, label: 'Loài cây', hint: 'Keo lai')),
                    SizedBox(width: itemWidth, child: _dialogField(
                      controller: yearCtrl,
                      label: 'Năm trồng',
                      hint: '2022',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final y = int.tryParse(v?.trim() ?? '');
                        if (y == null || y < 1900 || y > DateTime.now().year + 1) return 'Năm không hợp lệ';
                        return null;
                      },
                    )),
                    SizedBox(width: itemWidth, child: _dialogField(
                      controller: areaCtrl,
                      label: 'Diện tích (ha)',
                      hint: '1250.50',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final a = double.tryParse(v?.trim().replaceAll(',', '.') ?? '');
                        if (a == null || a < 0) return 'Diện tích không hợp lệ';
                        return null;
                      },
                    )),
                    SizedBox(
                      width: itemWidth,
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: const ['Draft', 'Surveying', 'Active', 'Suspended']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedStatus = v ?? _selectedStatus),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _buildWorkerSelection(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  setState(() => _isSaving = true);
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(context);
                  try {
                    final updated = widget.project.copyWith(
                      projectId: projectIdCtrl.text.trim(),
                      projectName: nameCtrl.text.trim(),
                      province: provinceCtrl.text.trim(),
                      district: districtCtrl.text.trim(),
                      commune: communeCtrl.text.trim(),
                      forestType: forestTypeCtrl.text.trim(),
                      treeSpecies: treeSpeciesCtrl.text.trim(),
                      yearPlanted: int.parse(yearCtrl.text.trim()),
                      areaHa: double.parse(areaCtrl.text.trim().replaceAll(',', '.')),
                      status: _selectedStatus,
                      workerUids: _selectedWorkers,
                    );
                    await widget.service.updateProject(updated);
                    if (mounted) {
                      widget.onUpdated(updated);
                      nav.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('✓ Đã cập nhật dự án.'),
                          backgroundColor: Color(0xff168a45),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isSaving = false);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Lưu thay đổi'),
        ),
      ],
    );
  }

  Widget _buildWorkerSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chọn nhân viên tham gia dự án:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<UserModel>>(
          stream: _workersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('Không có nhân viên nào.');
            }
            final workers = snapshot.data!;
            return Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(5),
              ),
              child: ListView.builder(
                itemCount: workers.length,
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  final isSelected = _selectedWorkers.contains(worker.uid);
                  return CheckboxListTile(
                    title: Text(worker.fullName.isNotEmpty ? worker.fullName : worker.email),
                    subtitle: Text(worker.employeeId ?? ''),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedWorkers.add(worker.uid);
                        } else {
                          _selectedWorkers.remove(worker.uid);
                        }
                      });
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
