import 'package:flutter/material.dart';
import '../models/inventory_model.dart';
import '../services/inventory_service.dart';
import '../widgets/app_colors.dart';
import 'dart:async';

class ForestInventoryPage extends StatefulWidget {
  const ForestInventoryPage({super.key});

  @override
  State<ForestInventoryPage> createState() => _ForestInventoryPageState();
}

class _ForestInventoryPageState extends State<ForestInventoryPage> {
  final TextEditingController _searchController = TextEditingController();

  int _selectedTab = 0;
  int _currentPage = 1;
  String _selectedProject = 'All Projects';
  String _selectedStatus = 'All Status';

  PlotModel? _selectedPlot;

  final InventoryService _inventoryService = InventoryService();
  StreamSubscription? _plotsSub;
  StreamSubscription? _treesSub;

  List<PlotModel> _plots = [];
  List<TreeModel> _treeData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _plotsSub = _inventoryService.getPlotsStream().listen((data) {
      if (mounted) {
        setState(() {
          _plots = data;
          if (_plots.isNotEmpty && _selectedPlot == null) {
            _selectedPlot = _plots.first;
          }
          _isLoading = false;
        });
      }
    });

    _treesSub = _inventoryService.getTreesStream().listen((data) {
      if (mounted) {
        setState(() {
          _treeData = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _plotsSub?.cancel();
    _treesSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<PlotModel> get _filteredPlots {
    final keyword = _searchController.text.trim().toLowerCase();

    return _plots.where((plot) {
      final matchesKeyword =
          keyword.isEmpty ||
          plot.code.toLowerCase().contains(keyword) ||
          plot.project.toLowerCase().contains(keyword);

      final matchesProject =
          _selectedProject == 'All Projects' ||
          plot.project == _selectedProject;

      final matchesStatus =
          _selectedStatus == 'All Status' || plot.status == _selectedStatus;

      return matchesKeyword && matchesProject && matchesStatus;
    }).toList();
  }

  List<TreeModel> get _filteredTreeData {
    final keyword = _searchController.text.trim().toLowerCase();

    return _treeData.where((tree) {
      final plot = _plots.firstWhere(
        (item) => item.code == tree.plotCode,
        orElse: () => const PlotModel(code: '', project: '', area: 0, latitude: 0, longitude: 0, elevation: 0, status: ''),
      );

      final matchesKeyword =
          keyword.isEmpty ||
          tree.plotCode.toLowerCase().contains(keyword) ||
          tree.species.toLowerCase().contains(keyword);

      final matchesProject =
          _selectedProject == 'All Projects' ||
          plot.project == _selectedProject;

      return matchesKeyword && matchesProject;
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
        padding: const EdgeInsets.all(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffe5ebe7)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildMainContent()),
              Container(width: 1, color: const Color(0xffe5ebe7)),
              SizedBox(width: 300, child: _buildPlotDetail()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedTab == 0
                ? _buildPlotsTable()
                : _buildTreeDataTable(),
          ),
          const SizedBox(height: 12),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          'Forest Inventory',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: Color(0xff17211b),
          ),
        ),
        const SizedBox(width: 70),
        _tabButton('Plots', 0),
        const SizedBox(width: 12),
        _tabButton('Tree Data', 1),
      ],
    );
  }

  Widget _tabButton(String title, int index) {
    final active = _selectedTab == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _searchController.clear();
          _currentPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 110,
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: active ? AppColors.primary : const Color(0xff5f6b64),
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        final searchBox = SizedBox(
          height: 42,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() => _currentPage = 1),
            decoration: InputDecoration(
              hintText: _selectedTab == 0
                  ? 'Search plots...'
                  : 'Search tree data...',
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

        final projectDropdown = SizedBox(
          width: compact ? 190 : 165,
          height: 42,
          child: DropdownButtonFormField<String>(
            value: _selectedProject,
            isExpanded: true,
            decoration: _dropdownDecoration(),
            items: const [
              DropdownMenuItem(
                value: 'All Projects',
                child: Text(
                  'All Projects',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'Dak Lak Project 01',
                child: Text(
                  'Dak Lak Project 01',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'Lam Dong Project 02',
                child: Text(
                  'Lam Dong Project 02',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'Gia Lai Project 01',
                child: Text(
                  'Gia Lai Project 01',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedProject = value;
                _currentPage = 1;
              });
            },
          ),
        );

        final statusDropdown = SizedBox(
          width: compact ? 145 : 125,
          height: 42,
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            isExpanded: true,
            decoration: _dropdownDecoration(),
            items: const [
              DropdownMenuItem(
                value: 'All Status',
                child: Text(
                  'All Status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedStatus = value;
                _currentPage = 1;
              });
            },
          ),
        );

        final addButton = SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: _selectedTab == 0
                ? _showAddPlotDialog
                : _showAddTreeDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text(_selectedTab == 0 ? 'Add Plot' : 'Add Tree Data'),
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

        if (compact) {
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
                  projectDropdown,
                  if (_selectedTab == 0) statusDropdown,
                  addButton,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchBox),
            const SizedBox(width: 10),
            projectDropdown,
            if (_selectedTab == 0) ...[
              const SizedBox(width: 10),
              statusDropdown,
            ],
            const SizedBox(width: 10),
            addButton,
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

  Widget _buildPlotsTable() {
    final rows = _filteredPlots;

    if (rows.isEmpty) {
      return _emptyState(
        icon: Icons.grid_off_rounded,
        title: 'Không tìm thấy ô mẫu',
      );
    }

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
            headingRowColor: MaterialStateProperty.all(const Color(0xfff7faf8)),
            columns: const [
              DataColumn(label: Text('Plot Code')),
              DataColumn(label: Text('Project')),
              DataColumn(label: Text('Area (m²)')),
              DataColumn(label: Text('Latitude')),
              DataColumn(label: Text('Longitude')),
              DataColumn(label: Text('Elevation (m)')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: rows.map((plot) {
              final selected = plot.code == _selectedPlot?.code;
              void selectPlot() {
                setState(() => _selectedPlot = plot);
              }

              return DataRow(
                color: MaterialStateProperty.all(
                  selected ? const Color(0xfff0f9f3) : Colors.transparent,
                ),
                cells: [
                  DataCell(Text(plot.code), onTap: selectPlot),
                  DataCell(
                    SizedBox(
                      width: 155,
                      child: Text(
                        plot.project,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onTap: selectPlot,
                  ),
                  DataCell(Text(_number(plot.area)), onTap: selectPlot),
                  DataCell(
                    Text(plot.latitude.toStringAsFixed(6)),
                    onTap: selectPlot,
                  ),
                  DataCell(
                    Text(plot.longitude.toStringAsFixed(6)),
                    onTap: selectPlot,
                  ),
                  DataCell(Text(_number(plot.elevation)), onTap: selectPlot),
                  DataCell(_statusBadge(plot.status), onTap: selectPlot),
                  DataCell(
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      onSelected: (value) {
                        setState(() => _selectedPlot = plot);
                        if (value == 'view') {
                          _showPlotDetailDialog(plot);
                        } else if (value == 'delete') {
                          _deletePlot(plot);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'view',
                          child: Text('View detail'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
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

  Widget _buildTreeDataTable() {
    final rows = _filteredTreeData;

    if (rows.isEmpty) {
      return _emptyState(
        icon: Icons.park_outlined,
        title: 'Không tìm thấy dữ liệu cây',
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            horizontalMargin: 8,
            columnSpacing: 54,
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 56,
            headingRowColor: MaterialStateProperty.all(const Color(0xfff7faf8)),
            columns: const [
              DataColumn(label: Text('Plot Code')),
              DataColumn(label: Text('Species')),
              DataColumn(label: Text('Diameter - DBH (cm)')),
              DataColumn(label: Text('Height (m)')),
              DataColumn(label: Text('Quantity')),
              DataColumn(label: Text('Actions')),
            ],
            rows: rows.map((tree) {
              return DataRow(
                cells: [
                  DataCell(
                    InkWell(
                      onTap: () {
                        final plot = _plots.firstWhere(
                          (item) => item.code == tree.plotCode,
                        );
                        setState(() {
                          _selectedPlot = plot;
                          _selectedTab = 0;
                        });
                      },
                      child: Text(
                        tree.plotCode,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(tree.species)),
                  DataCell(Text(_number(tree.dbh))),
                  DataCell(Text(_number(tree.height))),
                  DataCell(Text('${tree.quantity} cây')),
                  DataCell(
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        setState(() => _treeData.remove(tree));
                      },
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
    final active = status == 'Active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xffe9f8ee) : const Color(0xfffff1e6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: active ? const Color(0xff168a45) : const Color(0xffd97706),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 1
              ? () => setState(() => _currentPage--)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        _pageButton(1),
        _pageButton(2),
        _pageButton(3),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('...'),
        ),
        _pageButton(25),
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

  Widget _buildPlotDetail() {
    final selected = _selectedPlot;
    if (selected == null) {
      return const Center(
        child: Text(
          'Chưa có dữ liệu. Vui lòng tạo mới.',
          style: TextStyle(color: Color(0xff7b877f), fontWeight: FontWeight.w600),
        ),
      );
    }

    final trees = _treeData
        .where((tree) => tree.plotCode == selected.code)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plot Detail',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xff17211b),
            ),
          ),
          const SizedBox(height: 28),
          _detailRow('Plot Code', selected.code),
          _detailRow('Project', selected.project),
          _detailRow('Area', '${_number(selected.area)} m²'),
          _detailRow(
            'Coordinates',
            '${selected.latitude.toStringAsFixed(6)}, '
                '${selected.longitude.toStringAsFixed(6)}',
          ),
          _detailRow('Elevation', '${_number(selected.elevation)} m'),
          _detailRow('Status', selected.status),
          _detailRow('Tree records', '${trees.length}'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _showPlotDetailDialog(selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                'View Detail',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
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

  String _number(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0;

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(1);
  }

  Future<void> _showAddPlotDialog() async {
    final codeController = TextEditingController();
    final areaController = TextEditingController(text: '500');
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();
    final elevationController = TextEditingController();

    String project = 'Dak Lak Project 01';
    String status = 'Active';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Add Plot Sampling'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _dialogField(
                        controller: codeController,
                        label: 'Plot Code',
                        hint: 'PLT-0006',
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: project,
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
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          dialogSetState(() => project = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _dialogField(
                              controller: latitudeController,
                              label: 'Latitude',
                              hint: '12.345678',
                              number: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dialogField(
                              controller: longitudeController,
                              label: 'Longitude',
                              hint: '108.234567',
                              number: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _dialogField(
                              controller: areaController,
                              label: 'Area (m²)',
                              hint: '500',
                              number: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dialogField(
                              controller: elevationController,
                              label: 'Elevation (m)',
                              hint: '600',
                              number: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'Inactive',
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          dialogSetState(() => status = value);
                        },
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
                  onPressed: () {
                    final code = codeController.text.trim();
                    final latitude = double.tryParse(
                      latitudeController.text.trim(),
                    );
                    final longitude = double.tryParse(
                      longitudeController.text.trim(),
                    );
                    final area = double.tryParse(areaController.text.trim());
                    final elevation = double.tryParse(
                      elevationController.text.trim(),
                    );

                    if (code.isEmpty ||
                        latitude == null ||
                        longitude == null ||
                        area == null ||
                        elevation == null) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng nhập đầy đủ và đúng định dạng.',
                          ),
                        ),
                      );
                      return;
                    }

                    final newPlot = PlotModel(
                      code: code,
                      project: project,
                      area: area,
                      latitude: latitude,
                      longitude: longitude,
                      elevation: elevation,
                      status: status,
                    );

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Đang lưu dữ liệu...')),
                    );
                    Navigator.pop(dialogContext);

                    _inventoryService.addPlot(newPlot).then((saved) {
                      if (mounted) {
                        setState(() {
                          _selectedPlot = saved;
                        });
                      }
                    });

                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Plot'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    areaController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    elevationController.dispose();
  }

  Future<void> _showAddTreeDialog() async {
    String plotCode = _selectedPlot?.code ?? '';
    final speciesController = TextEditingController(text: 'Keo Lai');
    final dbhController = TextEditingController(text: '18');
    final heightController = TextEditingController(text: '12');
    final quantityController = TextEditingController(text: '150');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Add Tree Data'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: plotCode,
                        decoration: const InputDecoration(
                          labelText: 'Plot Code',
                          border: OutlineInputBorder(),
                        ),
                        items: _plots
                            .map(
                              (plot) => DropdownMenuItem<String>(
                                value: plot.code,
                                child: Text(plot.code),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          dialogSetState(() => plotCode = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      _dialogField(
                        controller: speciesController,
                        label: 'Species',
                        hint: 'Keo Lai',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _dialogField(
                              controller: dbhController,
                              label: 'Diameter - DBH (cm)',
                              hint: '18',
                              number: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dialogField(
                              controller: heightController,
                              label: 'Height (m)',
                              hint: '12',
                              number: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _dialogField(
                        controller: quantityController,
                        label: 'Quantity',
                        hint: '150',
                        number: true,
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
                  onPressed: () {
                    final species = speciesController.text.trim();
                    final dbh = double.tryParse(dbhController.text.trim());
                    final height = double.tryParse(
                      heightController.text.trim(),
                    );
                    final quantity = int.tryParse(
                      quantityController.text.trim(),
                    );

                    if (species.isEmpty ||
                        dbh == null ||
                        height == null ||
                        quantity == null) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng nhập đầy đủ và đúng định dạng.',
                          ),
                        ),
                      );
                      return;
                    }

                    final plotId = _plots.firstWhere((p) => p.code == plotCode).id;
                    final newTree = TreeModel(
                      plotId: plotId,
                      plotCode: plotCode,
                      species: species,
                      dbh: dbh,
                      height: height,
                      quantity: quantity,
                    );

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Đang lưu dữ liệu...')),
                    );
                    Navigator.pop(dialogContext);

                    _inventoryService.addTree(newTree);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Tree Data'),
                ),
              ],
            );
          },
        );
      },
    );

    speciesController.dispose();
    dbhController.dispose();
    heightController.dispose();
    quantityController.dispose();
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  void _showPlotDetailDialog(PlotModel plot) {
    final trees = _treeData
        .where((tree) => tree.plotCode == plot.code)
        .toList();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Plot Detail - ${plot.code}'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogInfo('Project', plot.project),
                  _dialogInfo(
                    'GPS',
                    '${plot.latitude.toStringAsFixed(6)}, '
                        '${plot.longitude.toStringAsFixed(6)}',
                  ),
                  _dialogInfo('Area', '${_number(plot.area)} m²'),
                  _dialogInfo('Elevation', '${_number(plot.elevation)} m'),
                  _dialogInfo('Status', plot.status),
                  const Divider(height: 32),
                  const Text(
                    'Tree Data',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (trees.isEmpty)
                    const Text('Chưa có dữ liệu cây cho ô mẫu này.')
                  else
                    ...trees.map(
                      (tree) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const Icon(Icons.park_outlined),
                          title: Text(tree.species),
                          subtitle: Text(
                            'DBH: ${_number(tree.dbh)} cm  •  '
                            'Height: ${_number(tree.height)} m  •  '
                            'Quantity: ${tree.quantity} cây',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _selectedTab = 1);
                _showAddTreeDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Tree Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xff7a857e)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlot(PlotModel plot) async {
    if (_plots.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phải giữ lại ít nhất một ô mẫu.')),
      );
      return;
    }

    try {
      await _inventoryService.deletePlot(plot.id);
      if (mounted) {
        setState(() {
          if (_selectedPlot?.id == plot.id) {
            _selectedPlot = _plots.firstWhere(
              (p) => p.id != plot.id,
              orElse: () => _plots.first,
            );
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa: $e')),
      );
    }
  }
}
