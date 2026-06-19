import 'package:flutter/material.dart';
import '../models/calculation_model.dart';
import '../models/user_model.dart';
import '../services/carbon_service.dart';
import '../services/forest_project_service.dart';
import '../widgets/app_colors.dart';
import 'dart:async';

class CarbonCalculationPage extends StatefulWidget {
  final UserModel currentUser;
  const CarbonCalculationPage({super.key, required this.currentUser});

  @override
  State<CarbonCalculationPage> createState() => _CarbonCalculationPageState();
}

class _CarbonCalculationPageState extends State<CarbonCalculationPage> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedProjectFilter = 'All Projects';
  int _currentPage = 1;

  // Danh sách dự án được đọc động từ Firebase Forest Projects.
  final ForestProjectService _forestProjectService = ForestProjectService();
  StreamSubscription? _projectSubscription;
  List<String> _projects = <String>[];
  // Store full project objects for owner (to avoid adding non-owned projects)
  List<String> _ownerProjectNames = <String>[];

  final Map<String, double> _speciesFactors = {
    'Keo': 0.48,
    'Bạch đàn': 0.47,
    'Thông': 0.50,
  };

  CalculationRecord? _selectedRecord;

  final CarbonService _carbonService = CarbonService();
  final int _itemsPerPage = 10;
  StreamSubscription? _subscription;
  List<CalculationRecord> _records = [];
  bool _isLoading = true;

  bool get _isAdmin => widget.currentUser.isAdmin;
  bool get _isOwner => widget.currentUser.isOwner;

  @override
  void initState() {
    super.initState();

    // For owner: only show their own projects; for admin: show all
    final projectStream = _isOwner
        ? _forestProjectService.watchProjectsByOwner(widget.currentUser.uid)
        : _forestProjectService.watchProjects();

    _projectSubscription = projectStream.listen(
      (projects) {
        if (!mounted) return;

        final projectNames = projects
            .map((project) => project.projectName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        setState(() {
          _projects = projectNames;
          _ownerProjectNames = projectNames;

          for (final forestProject in projects) {
            final species = forestProject.treeSpecies.trim();
            if (species.isNotEmpty) {
              _speciesFactors.putIfAbsent(species, () => 0.47);
            }
          }
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Lỗi đọc Forest Projects: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );

    // For owner: only load their own calculations; for admin: load all
    final calcStream = _isOwner
        ? _carbonService.getCalculationsStreamByOwner(widget.currentUser.uid)
        : _carbonService.getCalculationsStream();

    _subscription = calcStream.listen(
      (data) {
        if (!mounted) return;

        setState(() {
          _records = data;

          if (_records.isEmpty) {
            _selectedRecord = null;
          } else {
            final selectedId = _selectedRecord?.id;
            final selectedIndex = _records.indexWhere(
              (record) => record.id == selectedId,
            );

            _selectedRecord =
                selectedIndex >= 0 ? _records[selectedIndex] : _records.first;
          }

          _isLoading = false;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Lỗi đọc Carbon Calculations: $error');
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) return;
        setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _projectSubscription?.cancel();
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _availableProjects {
    final values = <String>{
      ..._projects,
      ..._records
          .map((record) => record.project.trim())
          .where((project) => project.isNotEmpty),
    }.toList()
      ..sort();

    return values;
  }

  List<String> get _availableSpecies {
    final values = <String>{
      ..._speciesFactors.keys,
      ..._records
          .map((record) => record.species.trim())
          .where((species) => species.isNotEmpty),
    }.toList()
      ..sort();

    return values;
  }

  List<CalculationRecord> get _filteredRecords {
    final keyword = _searchController.text.trim().toLowerCase();

    return _records.where((record) {
      final matchesSearch = keyword.isEmpty ||
          record.code.toLowerCase().contains(keyword) ||
          record.project.toLowerCase().contains(keyword) ||
          record.species.toLowerCase().contains(keyword);

      final matchesProject = _selectedProjectFilter == 'All Projects' ||
          record.project == _selectedProjectFilter;

      return matchesSearch && matchesProject;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xfff7f9f8),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 920;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffe5ebe7)),
              ),
              child: stacked
                  ? Column(
                      children: [
                        Expanded(child: _buildCalculationSection()),
                        if (_isOwner) ...[
                          const Divider(height: 1),
                          SizedBox(
                            height: 520,
                            child: _buildSummarySection(),
                          ),
                        ]
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: _isOwner ? 80 : 100,
                          child: _buildCalculationSection(),
                        ),
                        if (_isOwner) ...[
                          Container(
                            width: 1,
                            color: const Color(0xffe5ebe7),
                          ),
                          Expanded(
                            flex: 20,
                            child: _buildSummarySection(),
                          ),
                        ]
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCalculationSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Carbon Calculation',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xff17211b),
            ),
          ),
          const SizedBox(height: 20),
          _buildToolbar(),
          const SizedBox(height: 18),
          Expanded(child: _buildTable()),
          const SizedBox(height: 10),
          _buildPagination(_filteredRecords.length),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final projectOptions = _availableProjects;
        final selectedProject = _selectedProjectFilter == 'All Projects' ||
                projectOptions.contains(_selectedProjectFilter)
            ? _selectedProjectFilter
            : 'All Projects';

        final search = SizedBox(
          width: compact ? double.infinity : 230,
          height: 42,
          child: TextField(
            controller: _searchController,
            onChanged: (_) {
              setState(() {
                _currentPage = 1;
              });
            },
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search calculations...',
              hintStyle: const TextStyle(fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 18),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 38,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
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

        final projectFilter = SizedBox(
          width: compact ? 210 : 205,
          height: 42,
          child: DropdownButtonFormField<String>(
            value: selectedProject,
            isExpanded: true,
            menuMaxHeight: 320,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xff263029),
            ),
            decoration: _dropdownDecoration(),
            selectedItemBuilder: (context) {
              return <String>['All Projects', ...projectOptions].map((value) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: value,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xff263029),
                      ),
                    ),
                  ),
                );
              }).toList();
            },
            items: <String>['All Projects', ...projectOptions]
                .map(
                  (project) => DropdownMenuItem<String>(
                    value: project,
                    child: Tooltip(
                      message: project,
                      child: Text(
                        project,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedProjectFilter = value;
                _currentPage = 1;
              });
            },
          ),
        );

        final configButton = SizedBox(
          height: 42,
          child: OutlinedButton.icon(
            onPressed: _showSpeciesFactorDialog,
            icon: const Icon(Icons.tune, size: 17),
            label: const Text(
              'Species Factors',
              style: TextStyle(fontSize: 12.5),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  projectFilter,
                  configButton,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            search,
            const SizedBox(width: 10),
            projectFilter,
            const SizedBox(width: 10),
            configButton,
            const Spacer(),
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

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: Color(0xff6b7a70),
  );

  Widget _buildTable() {
    final rows = _filteredRecords;

    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy phép tính phù hợp.',
          style: TextStyle(
            color: Color(0xff7b877f),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: SizedBox(
              width: constraints.maxWidth,
              child: Table(
                border: TableBorder.all(
                  color: const Color(0xffdfe7e2),
                  width: 0.75,
                ),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: _isAdmin
                    ? const <int, TableColumnWidth>{
                        0: FlexColumnWidth(1.05),
                        1: FlexColumnWidth(1.55),
                        2: FlexColumnWidth(1.20), // Owner
                        3: FlexColumnWidth(0.95),
                        4: FlexColumnWidth(1.05),
                        5: FlexColumnWidth(0.95),
                        6: FixedColumnWidth(44),
                      }
                    : const <int, TableColumnWidth>{
                        0: FlexColumnWidth(1.05),
                        1: FlexColumnWidth(1.55),
                        2: FlexColumnWidth(0.95),
                        3: FlexColumnWidth(1.05),
                        4: FlexColumnWidth(0.95),
                        5: FixedColumnWidth(44),
                      },
                children: <TableRow>[
                  TableRow(
                    decoration: const BoxDecoration(
                      color: Color(0xfff3f7f4),
                    ),
                    children: <Widget>[
                      _calculationHeaderCell('Calculation Code'),
                      _calculationHeaderCell('Project'),
                      if (_isAdmin) _calculationHeaderCell('Owner'),
                      _calculationHeaderCell('Calculation Date'),
                      _calculationHeaderCell('Method'),
                      _calculationHeaderCell('Total CO₂e'),
                      _calculationHeaderCell(''),
                    ],
                  ),
                  ...rows
                      .skip((_currentPage - 1) * _itemsPerPage)
                      .take(_itemsPerPage)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    final index = entry.key;
                    final record = entry.value;
                    final selected = _selectedRecord?.id == record.id;

                    return TableRow(
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xffedf8f0)
                            : index.isEven
                                ? Colors.white
                                : const Color(0xfffbfdfc),
                      ),
                      children: <Widget>[
                        _calculationDataCell(
                          record.code,
                          bold: true,
                          onTap: () => _selectCalculation(record),
                        ),
                        _calculationDataCell(
                          record.project,
                          maxLines: 2,
                          onTap: () => _selectCalculation(record),
                        ),
                        if (_isAdmin)
                          _calculationDataCell(
                            record.ownerName.isNotEmpty ? record.ownerName : 'N/A',
                            maxLines: 2,
                            onTap: () => _selectCalculation(record),
                          ),
                        _calculationDataCell(
                          _formatDate(record.date),
                          textAlign: TextAlign.center,
                          onTap: () => _selectCalculation(record),
                        ),
                        _calculationDataCell(
                          record.method,
                          maxLines: 2,
                          onTap: () => _selectCalculation(record),
                        ),
                        _calculationDataCell(
                          _formatNumber(record.co2EquivalentTon),
                          textAlign: TextAlign.center,
                          onTap: () => _selectCalculation(record),
                        ),
                        Center(
                          child: PopupMenuButton<String>(
                            tooltip: 'Actions',
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              _selectCalculation(record);

                              if (value == 'view') {
                                _showDetailDialog(record);
                              } else if (value == 'edit') {
                                _showCalculationDialog(record: record);
                              } else if (value == 'delete') {
                                _deleteRecord(record);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Text('View detail'),
                              ),
                              if (_isOwner)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                            ],
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.more_horiz, size: 18),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectCalculation(CalculationRecord record) {
    setState(() => _selectedRecord = record);
  }

  Widget _calculationHeaderCell(String text) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11.5,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: Color(0xff56635b),
        ),
      ),
    );
  }

  Widget _calculationDataCell(
    String text, {
    bool bold = false,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.left,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Tooltip(
        message: text,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          alignment: textAlign == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: const Color(0xff2d3932),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final record = _selectedRecord;

    if (record == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Chưa có dữ liệu. Vui lòng tạo mới.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xff7b877f),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calculation Summary',
            maxLines: 2,
            style: TextStyle(
              fontSize: 19,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Color(0xff17211b),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _summaryRow('Code', record.code),
                  _summaryRow('Project', record.project),
                  _summaryRow('Date', _formatDate(record.date)),
                  _summaryRow('Method', record.method),
                  _summaryRow('Species', record.species),
                  _summaryRow(
                    'DBH',
                    '${_formatNumber(record.diameterCm)} cm',
                  ),
                  _summaryRow(
                    'Height',
                    '${_formatNumber(record.heightM)} m',
                  ),
                  _summaryRow('Quantity', '${record.quantity}'),
                  _summaryRow(
                    'Factor',
                    record.speciesFactor.toStringAsFixed(2),
                  ),
                  _summaryRow(
                    'Biomass',
                    '${_formatNumber(record.totalBiomassKg)} kg',
                  ),
                  _summaryRow(
                    'Carbon',
                    '${_formatNumber(record.carbonStockTon)} tC',
                  ),
                  _summaryRow(
                    'CO₂e',
                    '${_formatNumber(record.co2EquivalentTon)} tCO₂e',
                  ),
                ],
              ),
            ),
          ),
          if (_isOwner) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                onPressed: () => _showDetailDialog(record),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: const Text(
                  'View Detail',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 57,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xff8a958e),
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Tooltip(
              message: value,
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xff263029),
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text) {
    final approved = text == 'Approved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: approved ? const Color(0xffe8f7ed) : const Color(0xfffff3e0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: approved ? const Color(0xff168a45) : const Color(0xfff57c00),
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
          onPressed:
              _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          icon: const Icon(Icons.chevron_left, size: 19),
        ),
        for (int i = 1; i <= totalPages; i++)
          if (i == 1 || i == totalPages || (i >= _currentPage - 1 && i <= _currentPage + 1))
            _pageButton(i)
          else if (i == 2 && _currentPage > 3 || i == totalPages - 1 && _currentPage < totalPages - 2)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('...'),
            ),
        IconButton(
          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          icon: const Icon(Icons.chevron_right, size: 19),
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

  Future<void> _showCalculationDialog({
    CalculationRecord? record,
  }) async {
    const newSpeciesValue = '__NEW_SPECIES__';

    final isEditing = record != null;
    final projectOptions = <String>{
      ..._availableProjects,
      if ((record?.project ?? '').trim().isNotEmpty) record!.project.trim(),
    }.toList()
      ..sort();
    final speciesOptions = <String>{
      ..._availableSpecies,
      if ((record?.species ?? '').trim().isNotEmpty) record!.species.trim(),
    }.toList()
      ..sort();

    String? selectedProject =
        record != null && projectOptions.contains(record.project)
            ? record.project
            : projectOptions.isNotEmpty
                ? projectOptions.first
                : null;
    String selectedSpecies =
        record != null && speciesOptions.contains(record.species)
            ? record.species
            : speciesOptions.isNotEmpty
                ? speciesOptions.first
                : newSpeciesValue;
    String method = record?.method ?? 'IPCC Default';
    String status = record?.status ?? 'Draft';
    DateTime selectedDate = record?.date ?? DateTime.now();
    bool isSaving = false;

    final newSpeciesController = TextEditingController();
    final diameterController = TextEditingController(
      text: record?.diameterCm.toStringAsFixed(1) ?? '18',
    );
    final heightController = TextEditingController(
      text: record?.heightM.toStringAsFixed(1) ?? '12',
    );
    final quantityController = TextEditingController(
      text: record?.quantity.toString() ?? '150',
    );

    double previewBiomass = record?.totalBiomassKg ?? 0;
    double previewCarbon = record?.carbonStockTon ?? 0;
    double previewCo2e = record?.co2EquivalentTon ?? 0;

    String currentSpecies() {
      if (selectedSpecies == newSpeciesValue) {
        return newSpeciesController.text.trim();
      }
      return selectedSpecies;
    }

    void calculatePreview() {
      final diameter = double.tryParse(
            diameterController.text.trim().replaceAll(',', '.'),
          ) ??
          0;
      final height = double.tryParse(
            heightController.text.trim().replaceAll(',', '.'),
          ) ??
          0;
      final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
      final factor = _speciesFactors[currentSpecies()] ?? 0.47;

      previewBiomass = 0.05 * diameter * diameter * height * quantity;
      previewCarbon = previewBiomass / 1000 * factor;
      previewCo2e = previewCarbon * 44 / 12;
    }

    calculatePreview();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, dialogSetState) {
              void refreshPreview() {
                calculatePreview();
                dialogSetState(() {});
              }

              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 760,
                    maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 10, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                isEditing
                                    ? 'Edit Calculation'
                                    : 'New Calculation',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final twoColumns = constraints.maxWidth >= 560;
                              final threeColumns = constraints.maxWidth >= 680;
                              final halfWidth = twoColumns
                                  ? (constraints.maxWidth - 12) / 2
                                  : constraints.maxWidth;
                              final numberWidth = threeColumns
                                  ? (constraints.maxWidth - 24) / 3
                                  : halfWidth;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: halfWidth,
                                        child: DropdownButtonFormField<String>(
                                          value: selectedProject,
                                          isExpanded: true,
                                          menuMaxHeight: 320,
                                          decoration: const InputDecoration(
                                            labelText: 'Project',
                                            border: OutlineInputBorder(),
                                          ),
                                          hint: const Text('Chưa có project'),
                                          items: [
                                            ...projectOptions.map(
                                              (value) => DropdownMenuItem(
                                                value: value,
                                                child: Text(
                                                  value,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: isSaving
                                              ? null
                                              : (value) {
                                                  if (value == null) return;
                                                  dialogSetState(() {
                                                    selectedProject = value;
                                                  });
                                                },
                                        ),
                                      ),
                                      SizedBox(
                                        width: halfWidth,
                                        child: DropdownButtonFormField<String>(
                                          value: selectedSpecies,
                                          isExpanded: true,
                                          menuMaxHeight: 320,
                                          decoration: const InputDecoration(
                                            labelText: 'Loại cây',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: [
                                            ...speciesOptions.map(
                                              (value) => DropdownMenuItem(
                                                value: value,
                                                child: Text(
                                                  value,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            const DropdownMenuItem(
                                              value: newSpeciesValue,
                                              child: Text(
                                                '+ Nhập loại cây mới',
                                              ),
                                            ),
                                          ],
                                          onChanged: isSaving
                                              ? null
                                              : (value) {
                                                  if (value == null) return;
                                                  selectedSpecies = value;
                                                  refreshPreview();
                                                },
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (selectedSpecies == newSpeciesValue) ...[
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: newSpeciesController,
                                      enabled: !isSaving,
                                      onChanged: (_) => refreshPreview(),
                                      decoration: const InputDecoration(
                                        labelText: 'Tên loại cây mới',
                                        hintText: 'Nhập loại cây',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: numberWidth,
                                        child: TextField(
                                          controller: diameterController,
                                          enabled: !isSaving,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          onChanged: (_) => refreshPreview(),
                                          decoration: const InputDecoration(
                                            labelText: 'Đường kính - DBH (cm)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: numberWidth,
                                        child: TextField(
                                          controller: heightController,
                                          enabled: !isSaving,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          onChanged: (_) => refreshPreview(),
                                          decoration: const InputDecoration(
                                            labelText: 'Chiều cao (m)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: numberWidth,
                                        child: TextField(
                                          controller: quantityController,
                                          enabled: !isSaving,
                                          keyboardType: TextInputType.number,
                                          onChanged: (_) => refreshPreview(),
                                          decoration: const InputDecoration(
                                            labelText: 'Số lượng',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: halfWidth,
                                        child: DropdownButtonFormField<String>(
                                          value: method,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Method',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'IPCC Default',
                                              child: Text('IPCC Default'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Custom Formula',
                                              child: Text('Custom Formula'),
                                            ),
                                          ],
                                          onChanged: isSaving
                                              ? null
                                              : (value) {
                                                  if (value == null) return;
                                                  dialogSetState(() {
                                                    method = value;
                                                  });
                                                },
                                        ),
                                      ),
                                      SizedBox(
                                        width: halfWidth,
                                        child: DropdownButtonFormField<String>(
                                          value: status,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Status',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Draft',
                                              child: Text('Draft'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Approved',
                                              child: Text('Approved'),
                                            ),
                                          ],
                                          onChanged: isSaving
                                              ? null
                                              : (value) {
                                                  if (value == null) return;
                                                  dialogSetState(() {
                                                    status = value;
                                                  });
                                                },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: isSaving
                                        ? null
                                        : () async {
                                            final value = await showDatePicker(
                                              context: dialogContext,
                                              initialDate: selectedDate,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2035),
                                            );

                                            if (value != null) {
                                              dialogSetState(() {
                                                selectedDate = value;
                                              });
                                            }
                                          },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Calculation Date',
                                        border: OutlineInputBorder(),
                                        suffixIcon: Icon(Icons.calendar_month),
                                      ),
                                      child: Text(_formatDate(selectedDate)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff3f8f4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xffdfe9e2),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Calculation Preview',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        _dialogResultRow(
                                          'Species Factor',
                                          (_speciesFactors[currentSpecies()] ??
                                                  0.47)
                                              .toStringAsFixed(2),
                                        ),
                                        _dialogResultRow(
                                          'Total Biomass',
                                          '${_formatNumber(previewBiomass)} kg',
                                        ),
                                        _dialogResultRow(
                                          'Carbon Stock',
                                          '${_formatNumber(previewCarbon)} tC',
                                        ),
                                        _dialogResultRow(
                                          'CO₂ Equivalent',
                                          '${_formatNumber(previewCo2e)} tCO₂e',
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
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final project = selectedProject ?? '';
                                      final species =
                                          selectedSpecies == newSpeciesValue
                                              ? newSpeciesController.text.trim()
                                              : selectedSpecies;
                                      final diameter = double.tryParse(
                                        diameterController.text
                                            .trim()
                                            .replaceAll(',', '.'),
                                      );
                                      final height = double.tryParse(
                                        heightController.text
                                            .trim()
                                            .replaceAll(',', '.'),
                                      );
                                      final quantity = int.tryParse(
                                        quantityController.text.trim(),
                                      );

                                      if (project.isEmpty || species.isEmpty) {
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Vui lòng chọn hoặc nhập Project và Loại cây.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (diameter == null ||
                                          diameter <= 0 ||
                                          height == null ||
                                          height <= 0 ||
                                          quantity == null ||
                                          quantity <= 0) {
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Vui lòng nhập đường kính, chiều cao và số lượng hợp lệ.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      dialogSetState(() => isSaving = true);

                                      _speciesFactors.putIfAbsent(
                                        species,
                                        () => 0.47,
                                      );
                                      calculatePreview();

                                      final result = CalculationRecord(
                                        id: record?.id ?? '',
                                        code: record?.code ??
                                            'CAL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                        project: project,
                                        date: selectedDate,
                                        method: method,
                                        species: species,
                                        diameterCm: diameter,
                                        heightM: height,
                                        quantity: quantity,
                                        speciesFactor:
                                            _speciesFactors[species] ?? 0.47,
                                        totalBiomassKg: previewBiomass,
                                        carbonStockTon: previewCarbon,
                                        co2EquivalentTon: previewCo2e,
                                        status: status,
                                        ownerUid: record?.ownerUid ?? widget.currentUser.uid,
                                        ownerName: record?.ownerName ?? widget.currentUser.fullName,
                                      );

                                      try {
                                        if (record == null) {
                                          final newId = await _carbonService
                                              .addCalculation(result);
                                          if (!mounted) return;
                                          setState(() {
                                            _selectedRecord = CalculationRecord(
                                              id: newId,
                                              code: result.code,
                                              project: result.project,
                                              date: result.date,
                                              method: result.method,
                                              species: result.species,
                                              diameterCm: result.diameterCm,
                                              heightM: result.heightM,
                                              quantity: result.quantity,
                                              speciesFactor: result.speciesFactor,
                                              totalBiomassKg: result.totalBiomassKg,
                                              carbonStockTon: result.carbonStockTon,
                                              co2EquivalentTon: result.co2EquivalentTon,
                                              status: result.status,
                                              ownerUid: result.ownerUid,
                                              ownerName: result.ownerName,
                                            );
                                          });
                                        } else {
                                          await _carbonService
                                              .updateCalculation(result);
                                        }

                                        if (!mounted) return;

                                        setState(() {
                                          if (!_projects.contains(project)) {
                                            _projects.add(project);
                                            _projects.sort();
                                          }
                                          _selectedProjectFilter =
                                              'All Projects';
                                          _currentPage = 1;
                                        });

                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }

                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isEditing
                                                  ? 'Đã cập nhật phép tính.'
                                                  : 'Đã lưu phép tính.',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (error) {
                                        if (!mounted) return;
                                        dialogSetState(
                                          () => isSaving = false,
                                        );
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Không thể lưu: $error',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined, size: 17),
                              label: Text(
                                isSaving
                                    ? 'Saving...'
                                    : isEditing
                                        ? 'Save Changes'
                                        : 'Save Calculation',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Không mở được New Calculation: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không mở được New Calculation: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      newSpeciesController.dispose();
      diameterController.dispose();
      heightController.dispose();
      quantityController.dispose();
    }
  }

  Widget _dialogResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xff78837c),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSpeciesFactorDialog() async {
    final controllers = <String, TextEditingController>{
      for (final entry in _speciesFactors.entries)
        entry.key: TextEditingController(
          text: entry.value.toStringAsFixed(2),
        ),
    };

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Configure Species Factors'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: entry.value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: entry.key,
                      border: const OutlineInputBorder(),
                      suffixText: 'factor',
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = <String, double>{};

                for (final entry in controllers.entries) {
                  final value = double.tryParse(entry.value.text.trim());

                  if (value == null || value <= 0 || value > 1) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Hệ số ${entry.key} phải lớn hơn 0 và không vượt quá 1.',
                        ),
                      ),
                    );
                    return;
                  }

                  updated[entry.key] = value;
                }

                setState(() {
                  _speciesFactors
                    ..clear()
                    ..addAll(updated);
                });

                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Factors'),
            ),
          ],
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  void _showDetailDialog(CalculationRecord record) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Calculation Detail - ${record.code}'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _dialogInfo('Project', record.project),
                  _dialogInfo(
                    'Calculation Date',
                    _formatDate(record.date),
                  ),
                  _dialogInfo('Method', record.method),
                  _dialogInfo('Species', record.species),
                  _dialogInfo(
                    'Diameter - DBH',
                    '${_formatNumber(record.diameterCm)} cm',
                  ),
                  _dialogInfo(
                    'Height',
                    '${_formatNumber(record.heightM)} m',
                  ),
                  _dialogInfo(
                    'Quantity',
                    '${record.quantity} cây',
                  ),
                  _dialogInfo(
                    'Species Factor',
                    record.speciesFactor.toStringAsFixed(2),
                  ),
                  const Divider(height: 28),
                  _dialogInfo(
                    'Total Biomass',
                    '${_formatNumber(record.totalBiomassKg)} kg',
                  ),
                  _dialogInfo(
                    'Carbon Stock',
                    '${_formatNumber(record.carbonStockTon)} tC',
                  ),
                  _dialogInfo(
                    'CO₂ Equivalent',
                    '${_formatNumber(record.co2EquivalentTon)} tCO₂e',
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
          ],
        );
      },
    );
  }

  Widget _dialogInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xff7d8881),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(CalculationRecord record) async {
    try {
      await _carbonService.deleteCalculation(record.id);
      if (mounted) {
        setState(() {
          if (_selectedRecord?.id == record.id) {
            final others = _records.where((r) => r.id != record.id);
            _selectedRecord = others.isNotEmpty ? others.first : null;
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

  String _formatNumber(double value) {
    final rounded = value.toStringAsFixed(2);
    final parts = rounded.split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      final remaining = integerPart.length - i;
      buffer.write(integerPart[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return '$buffer.$decimalPart';
  }
}
