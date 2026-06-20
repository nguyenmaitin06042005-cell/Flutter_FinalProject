import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

import '../utils/pdf_exporter.dart';
import '../widgets/app_colors.dart';
import '../models/user_model.dart';

enum ReportType {
  forestSummary,
  forestInventory,
  activity,
}

class ReportsPage extends StatefulWidget {
  final UserModel? currentUser;
  const ReportsPage({super.key, this.currentUser});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ReportType _selectedReport = ReportType.forestSummary;
  String _selectedProject = 'All Projects';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isGenerating = false;
  bool _isLoadingProjects = true;

  List<String> _projects = <String>[];
  Map<String, String> _projectOwners = <String, String>{};

  final Map<ReportType, DateTime?> _lastGenerated = <ReportType, DateTime?>{
    ReportType.forestSummary: null,
    ReportType.forestInventory: null,
    ReportType.activity: null,
  };

  static const List<_ReportDefinition> _reportDefinitions = <_ReportDefinition>[
    _ReportDefinition(
      type: ReportType.forestSummary,
      name: 'Forest Summary Report',
      description: 'Diện tích, loại cây và tổng carbon theo dự án',
      icon: Icons.forest_outlined,
    ),
    _ReportDefinition(
      type: ReportType.forestInventory,
      name: 'Forest Inventory Report',
      description: 'Plot, DBH, Height và Quantity',
      icon: Icons.analytics_outlined,
    ),
    _ReportDefinition(
      type: ReportType.activity,
      name: 'Activity Report',
      description: 'Nhật ký hoạt động hiện trường',
      icon: Icons.assignment_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ReportDefinition> get _filteredReports {
    final keyword = _searchController.text.trim().toLowerCase();

    if (keyword.isEmpty) {
      return _reportDefinitions;
    }

    return _reportDefinitions.where((report) {
      return report.name.toLowerCase().contains(keyword) ||
          report.description.toLowerCase().contains(keyword);
    }).toList();
  }

  Future<void> _loadProjects() async {
    try {
      Query query = _firestore.collection('forest_projects');
      if (widget.currentUser?.isOwner == true) {
        query = query.where('ownerUid', isEqualTo: widget.currentUser!.uid);
      }
      final snapshot = await query.get();
      final projects = <String>[];
      final projectOwners = <String, String>{};

      for (var document in snapshot.docs) {
        final data = document.data() as Map<String, dynamic>?;
        if (data != null) {
          final name = _readString(data, <String>['projectName', 'project', 'name']);
          final owner = _readString(data, <String>['owner', 'ownerName']);
          if (name.isNotEmpty) {
            projects.add(name);
            projectOwners[name] = owner;
          }
        }
      }

      final uniqueProjects = projects.toSet().toList()..sort();

      if (!mounted) return;

      setState(() {
        _projects = uniqueProjects;
        _projectOwners = projectOwners;
        _isLoadingProjects = false;

        if (_selectedProject != 'All Projects' &&
            !_projects.contains(_selectedProject)) {
          _selectedProject = 'All Projects';
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingProjects = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải danh sách dự án: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f8f6),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 930;

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffe3eae5)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0a000000),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: stacked
                  ? Column(
                      children: <Widget>[
                        Expanded(child: _buildReportsSection()),
                        const Divider(height: 1),
                        SizedBox(
                          height: 500,
                          child: _buildFilterSection(),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          flex: 70,
                          child: _buildReportsSection(),
                        ),
                        Container(
                          width: 1,
                          color: const Color(0xffe3eae5),
                        ),
                        Expanded(
                          flex: 30,
                          child: _buildFilterSection(),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReportsSection() {
    final reports = _filteredReports;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Reports',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xff17211b),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 290,
            height: 42,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search reports...',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xff9aa59e),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 19,
                  color: Color(0xff7f8b84),
                ),
                filled: true,
                fillColor: const Color(0xfffbfcfb),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xffdfe7e2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xffdfe7e2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: reports.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy báo cáo phù hợp.',
                      style: TextStyle(
                        color: Color(0xff7b877f),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : _buildReportTable(reports),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(List<_ReportDefinition> reports) {
    return SingleChildScrollView(
      child: Table(
        border: const TableBorder(
          horizontalInside: BorderSide(
            color: Color(0xffe8eeea),
            width: 0.8,
          ),
          bottom: BorderSide(
            color: Color(0xffe8eeea),
            width: 0.8,
          ),
        ),
        columnWidths: const <int, TableColumnWidth>{
          0: FlexColumnWidth(1.35),
          1: FlexColumnWidth(1.65),
          2: FlexColumnWidth(1.05),
          3: FixedColumnWidth(92),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: <TableRow>[
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xfff7faf8),
            ),
            children: <Widget>[
              _tableHeader('Report Name'),
              _tableHeader('Description'),
              _tableHeader('Last Generated'),
              _tableHeader('Actions'),
            ],
          ),
          ...reports.map((report) {
            final selected = _selectedReport == report.type;
            final lastGenerated = _lastGenerated[report.type];

            return TableRow(
              decoration: BoxDecoration(
                color: selected ? const Color(0xfff1f9f3) : Colors.white,
              ),
              children: <Widget>[
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedReport = report.type;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 18,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          report.icon,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            report.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.3,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff263029),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _tableValue(
                  report.description,
                  maxLines: 3,
                ),
                _tableValue(
                  lastGenerated == null
                      ? 'Not generated'
                      : _formatDateTime(lastGenerated),
                  maxLines: 2,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 13,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _isGenerating
                          ? null
                          : () {
                              setState(() {
                                _selectedReport = report.type;
                              });
                              _generateSelectedReport(report.type);
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                      ),
                      child: const Text(
                        'Generate',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _tableHeader(String value) {
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        value,
        maxLines: 2,
        style: const TextStyle(
          fontSize: 11.2,
          fontWeight: FontWeight.w800,
          color: Color(0xff66736b),
        ),
      ),
    );
  }

  Widget _tableValue(
    String value, {
    int maxLines = 2,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 18,
      ),
      child: Tooltip(
        message: value,
        child: Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.8,
            height: 1.35,
            color: Color(0xff3b473f),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Report Filters',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xff17211b),
              ),
            ),
            const SizedBox(height: 24),
            _fieldLabel('Report Type'),
            const SizedBox(height: 7),
            DropdownButtonFormField<ReportType>(
              value: _selectedReport,
              isExpanded: true,
              decoration: _filterDecoration(),
              items: _reportDefinitions
                  .map(
                    (report) => DropdownMenuItem<ReportType>(
                      value: report.type,
                      child: Text(
                        report.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isGenerating
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedReport = value;
                      });
                    },
            ),
            const SizedBox(height: 18),
            _fieldLabel('Project'),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              value: _selectedProject,
              isExpanded: true,
              menuMaxHeight: 320,
              decoration: _filterDecoration(),
              items: <String>['All Projects', ..._projects]
                  .map(
                    (project) => DropdownMenuItem<String>(
                      value: project,
                      child: Text(
                        project,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isLoadingProjects || _isGenerating
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedProject = value;
                      });
                    },
            ),
            if (_isLoadingProjects) ...<Widget>[
              const SizedBox(height: 6),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 18),
            _fieldLabel('Date From'),
            const SizedBox(height: 7),
            _dateField(
              value: _dateFrom,
              hint: 'Chọn ngày bắt đầu',
              onTap: _isGenerating ? null : () => _pickDate(isFrom: true),
              onClear: _dateFrom == null || _isGenerating
                  ? null
                  : () => setState(() => _dateFrom = null),
            ),
            const SizedBox(height: 18),
            _fieldLabel('Date To'),
            const SizedBox(height: 7),
            _dateField(
              value: _dateTo,
              hint: 'Chọn ngày kết thúc',
              onTap: _isGenerating ? null : () => _pickDate(isFrom: false),
              onClear: _dateTo == null || _isGenerating
                  ? null
                  : () => setState(() => _dateTo = null),
            ),
            const SizedBox(height: 18),
            _fieldLabel('Format'),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              value: 'PDF',
              isExpanded: true,
              decoration: _filterDecoration(),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'PDF',
                  child: Text('PDF'),
                ),
              ],
              onChanged: null,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isGenerating
                    ? null
                    : () => _generateSelectedReport(_selectedReport),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 19),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Generate Report',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.55),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff4f8f5),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xffe0e9e3)),
              ),
              child: const Text(
                'PDF sẽ lấy dữ liệu từ Firebase theo Project và khoảng ngày đã chọn.',
                style: TextStyle(
                  fontSize: 11.3,
                  height: 1.45,
                  color: Color(0xff6d7971),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String value) {
    return Text(
      value,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xff556159),
      ),
    );
  }

  InputDecoration _filterDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xfffbfcfb),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 13,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xffdfe7e2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xffdfe7e2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _dateField({
    required DateTime? value,
    required String hint,
    required VoidCallback? onTap,
    required VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: _filterDecoration().copyWith(
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (onClear != null)
                IconButton(
                  tooltip: 'Xóa ngày',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 17),
                ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.calendar_month_outlined, size: 19),
              ),
            ],
          ),
        ),
        child: Text(
          value == null ? hint : _formatDate(value),
          style: TextStyle(
            fontSize: 12,
            color: value == null
                ? const Color(0xff9aa59e)
                : const Color(0xff263029),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initialDate = isFrom
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? _dateFrom ?? DateTime.now());

    final value = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (value == null || !mounted) return;

    setState(() {
      if (isFrom) {
        _dateFrom = value;

        if (_dateTo != null && _dateTo!.isBefore(value)) {
          _dateTo = value;
        }
      } else {
        _dateTo = value;

        if (_dateFrom != null && _dateFrom!.isAfter(value)) {
          _dateFrom = value;
        }
      }
    });
  }

  Future<void> _generateSelectedReport(ReportType type) async {
    if (_dateFrom != null && _dateTo != null && _dateFrom!.isAfter(_dateTo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Date From không được lớn hơn Date To.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _selectedReport = type;
      _isGenerating = true;
    });

    try {
      final report = await _buildReportData(type);
      final generatedAt = DateTime.now();

      final pdfBytes = await _createPdf(
        report: report,
        generatedAt: generatedAt,
      );

      await exportPdfFile(
        bytes: pdfBytes,
        fileName: '${report.fileName}.pdf',
      );

      if (!mounted) return;

      setState(() {
        _lastGenerated[type] = generatedAt;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo báo cáo PDF.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Lỗi tạo báo cáo: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tạo báo cáo: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<_PdfReportData> _buildReportData(ReportType type) async {
    switch (type) {
      case ReportType.forestSummary:
        return _buildForestSummaryData();
      case ReportType.forestInventory:
        return _buildInventoryData();
      case ReportType.activity:
        return _buildActivityData();
    }
  }

  Future<_PdfReportData> _buildForestSummaryData() async {
    final projectDocuments =
        await _readFirstNonEmptyCollection(<String>['forest_projects']);

    final carbonDocuments = await _readFirstNonEmptyCollection(
      <String>[
        'carbon_calculations',
        'calculations',
        'carbonCalculations',
      ],
    );

    final carbonByProject = <String, double>{};

    for (final document in carbonDocuments) {
      final project = _readString(
        document,
        <String>['project', 'projectName'],
      );
      final date = _readDate(
        document,
        <String>['date', 'calculationDate', 'createdAt'],
      );

      if (!_matchesProject(project) || !_matchesDate(date)) {
        continue;
      }

      final carbon = _readDouble(
        document,
        <String>[
          'co2EquivalentTon',
          'totalCarbon',
          'carbonTon',
          'carbonStockTon',
        ],
      );

      carbonByProject.update(
        project,
        (value) => value + carbon,
        ifAbsent: () => carbon,
      );
    }

    final rows = <List<String>>[];
    double totalArea = 0;
    double totalCarbon = 0;

    for (final document in projectDocuments) {
      final project = _readString(
        document,
        <String>['projectName', 'project', 'name'],
      );

      if (!_matchesProject(project)) {
        continue;
      }

      final createdAt = _readDate(
        document,
        <String>['createdAt', 'updatedAt', 'date'],
      );

      if (!_matchesDate(createdAt, allowMissingDate: true)) {
        continue;
      }

      final province = _readString(
        document,
        <String>['province'],
      );
      final species = _readString(
        document,
        <String>['treeSpecies', 'species'],
      );
      final area = _readDouble(
        document,
        <String>['areaHa', 'area'],
      );
      final carbon = carbonByProject[project] ??
          _readDouble(
            document,
            <String>[
              'carbon',
              'carbonTon',
              'co2EquivalentTon',
            ],
          );

      totalArea += area;
      totalCarbon += carbon;

      final owner = _projectOwners[project] ?? '-';

      rows.add(<String>[
        owner.isEmpty ? '-' : owner,
        project.isEmpty ? '-' : project,
        province.isEmpty ? '-' : province,
        _formatNumber(area),
        species.isEmpty ? '-' : species,
        _formatNumber(carbon),
      ]);
    }

    return _PdfReportData(
      title: 'Forest Summary Report',
      fileName: 'forest_summary_report',
      columns: const <String>[
        'Owner',
        'Project',
        'Province',
        'Area (ha)',
        'Tree Species',
        'Carbon (tCO2e)',
      ],
      rows: rows,
      summaryItems: <String, String>{
        'Projects': rows.length.toString(),
        'Total Area': '${_formatNumber(totalArea)} ha',
        'Total Carbon': '${_formatNumber(totalCarbon)} tCO2e',
      },
    );
  }

  Future<_PdfReportData> _buildInventoryData() async {
    final documents = await _readFirstNonEmptyCollection(
      <String>[
        'inventory_trees',
        'forest_inventory',
        'forest_inventory_tree_data',
        'inventory',
        'tree_data',
      ],
    );

    final rows = <List<String>>[];
    int totalQuantity = 0;

    for (final document in documents) {
      final project = _readString(
        document,
        <String>['project', 'projectName'],
      );
      final date = _readDate(
        document,
        <String>['date', 'createdAt', 'updatedAt'],
      );

      if (!_matchesProject(project) ||
          !_matchesDate(date, allowMissingDate: true)) {
        continue;
      }

      final plot = _readString(
        document,
        <String>['plotCode', 'code', 'plot'],
      );
      final species = _readString(
        document,
        <String>['species', 'treeSpecies'],
      );
      final dbh = _readDouble(
        document,
        <String>['dbh', 'diameterCm', 'diameter'],
      );
      final height = _readDouble(
        document,
        <String>['height', 'heightM'],
      );
      final quantity = _readInt(
        document,
        <String>['quantity', 'treeQuantity', 'totalTrees'],
      );

      totalQuantity += quantity;

      final owner = _projectOwners[project] ?? '-';

      rows.add(<String>[
        owner.isEmpty ? '-' : owner,
        plot.isEmpty ? '-' : plot,
        project.isEmpty ? '-' : project,
        species.isEmpty ? '-' : species,
        _formatNumber(dbh),
        _formatNumber(height),
        quantity.toString(),
      ]);
    }

    return _PdfReportData(
      title: 'Forest Inventory Report',
      fileName: 'forest_inventory_report',
      columns: const <String>[
        'Owner',
        'Plot',
        'Project',
        'Species',
        'DBH (cm)',
        'Height (m)',
        'Quantity',
      ],
      rows: rows,
      summaryItems: <String, String>{
        'Inventory Rows': rows.length.toString(),
        'Total Quantity': totalQuantity.toString(),
      },
    );
  }

  Future<_PdfReportData> _buildActivityData() async {
    final documents = await _readFirstNonEmptyCollection(
      <String>[
        'logbook_activities',
        'forest_activities',
        'activities',
        'forest_logbook',
      ],
    );

    final rows = <List<String>>[];

    for (final document in documents) {
      final project = _readString(
        document,
        <String>['project', 'projectName'],
      );
      final date = _readDate(
        document,
        <String>['date', 'activityDate', 'createdAt'],
      );

      if (!_matchesProject(project) || !_matchesDate(date)) {
        continue;
      }

      final activityType = _readString(
        document,
        <String>['activityType', 'type', 'workType'],
      );
      final user = _readString(
        document,
        <String>['user', 'userName', 'worker'],
      );
      final location = _readString(
        document,
        <String>['location', 'address'],
      );
      final description = _readString(
        document,
        <String>['description', 'note', 'content'],
      );

      final owner = _projectOwners[project] ?? '-';

      rows.add(<String>[
        date == null ? '-' : _formatDate(date),
        owner.isEmpty ? '-' : owner,
        project.isEmpty ? '-' : project,
        activityType.isEmpty ? '-' : activityType,
        user.isEmpty ? '-' : user,
        location.isEmpty ? '-' : location,
        description.isEmpty ? '-' : description,
      ]);
    }

    return _PdfReportData(
      title: 'Activity Report',
      fileName: 'activity_report',
      columns: const <String>[
        'Date',
        'Owner',
        'Project',
        'Activity',
        'User',
        'Location',
        'Description',
      ],
      rows: rows,
      summaryItems: <String, String>{
        'Activities': rows.length.toString(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> _readFirstNonEmptyCollection(
    List<String> collectionNames,
  ) async {
    for (final collectionName in collectionNames) {
      final snapshot = await _firestore.collection(collectionName).get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((document) => document.data()).toList();
      }
    }

    return <Map<String, dynamic>>[];
  }

  Future<Uint8List> _createPdf({
    required _PdfReportData report,
    required DateTime generatedAt,
  }) async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    final selectedProjectText =
        _selectedProject == 'All Projects' ? 'All Projects' : _selectedProject;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColor.fromInt(0xffdce6df),
                  width: 1,
                ),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      report.title,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xff173b25),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Forest Carbon Management Platform',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        color: PdfColor.fromInt(0xff617067),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Generated: ${_formatDateTime(generatedAt)}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromInt(0xff617067),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 8.5,
                color: PdfColor.fromInt(0xff78857d),
              ),
            ),
          );
        },
        build: (context) {
          return <pw.Widget>[
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xfff3f8f4),
                borderRadius: pw.BorderRadius.circular(5),
                border: pw.Border.all(
                  color: PdfColor.fromInt(0xffdce8df),
                ),
              ),
              child: pw.Wrap(
                spacing: 26,
                runSpacing: 8,
                children: <pw.Widget>[
                  _pdfFilterItem(
                    'Project',
                    selectedProjectText,
                  ),
                  _pdfFilterItem(
                    'Date From',
                    _dateFrom == null ? 'All' : _formatDate(_dateFrom!),
                  ),
                  _pdfFilterItem(
                    'Date To',
                    _dateTo == null ? 'All' : _formatDate(_dateTo!),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            if (report.summaryItems.isNotEmpty)
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: report.summaryItems.entries
                    .map(
                      (entry) => pw.Container(
                        width: 160,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(5),
                          border: pw.Border.all(
                            color: PdfColor.fromInt(0xffdfe7e2),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: <pw.Widget>[
                            pw.Text(
                              entry.key,
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                color: PdfColor.fromInt(0xff738078),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              entry.value,
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xff203127),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            pw.SizedBox(height: 16),
            if (report.rows.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xfffafcfb),
                  border: pw.Border.all(
                    color: PdfColor.fromInt(0xffe1e8e3),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'No data found for the selected filters.',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColor.fromInt(0xff6b776f),
                    ),
                  ),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: report.columns,
                data: report.rows,
                border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xffd9e3dc),
                  width: 0.7,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xffeaf4ed),
                ),
                headerStyle: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xff284033),
                ),
                cellStyle: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColor.fromInt(0xff2e3a33),
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 6,
                ),
                headerAlignment: pw.Alignment.centerLeft,
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xfffbfdfc),
                ),
              ),
          ];
        },
      ),
    );

    return document.save();
  }

  pw.Widget _pdfFilterItem(String label, String value) {
    return pw.SizedBox(
      width: 180,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColor.fromInt(0xff718078),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xff25342b),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesProject(String project) {
    if (_selectedProject == 'All Projects') {
      if (widget.currentUser?.isOwner == true) {
        return _projects.contains(project);
      }
      return true;
    }
    return project == _selectedProject;
  }

  bool _matchesDate(
    DateTime? date, {
    bool allowMissingDate = false,
  }) {
    if (date == null) {
      return allowMissingDate && _dateFrom == null && _dateTo == null;
    }

    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (_dateFrom != null) {
      final from = DateTime(
        _dateFrom!.year,
        _dateFrom!.month,
        _dateFrom!.day,
      );

      if (normalizedDate.isBefore(from)) {
        return false;
      }
    }

    if (_dateTo != null) {
      final to = DateTime(
        _dateTo!.year,
        _dateTo!.month,
        _dateTo!.day,
      );

      if (normalizedDate.isAfter(to)) {
        return false;
      }
    }

    return true;
  }

  static String _readString(
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

  static double _readDouble(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is num) {
        return value.toDouble();
      }

      if (value != null) {
        final parsed = double.tryParse(
          value.toString().replaceAll(',', '').replaceAll(' ha', '').trim(),
        );

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  static int _readInt(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.toInt();
      }

      if (value != null) {
        final parsed = int.tryParse(value.toString().trim());

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  static DateTime? _readDate(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }

      if (value is String) {
        final isoDate = DateTime.tryParse(value);

        if (isoDate != null) {
          return isoDate;
        }

        final parts = value.split('/');

        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);

          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
    }

    return null;
  }

  static String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  static String _formatDateTime(DateTime value) {
    return '${_formatDate(value)} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  static String _formatNumber(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final integer = parts.first;
    final decimal = parts.last;

    final reversed = integer.split('').reversed.toList();
    final buffer = StringBuffer();

    for (int index = 0; index < reversed.length; index++) {
      if (index > 0 && index % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(reversed[index]);
    }

    final formattedInteger = buffer.toString().split('').reversed.join();

    return '$formattedInteger.$decimal';
  }
}

class _ReportDefinition {
  final ReportType type;
  final String name;
  final String description;
  final IconData icon;

  const _ReportDefinition({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class _PdfReportData {
  final String title;
  final String fileName;
  final List<String> columns;
  final List<List<String>> rows;
  final Map<String, String> summaryItems;

  const _PdfReportData({
    required this.title,
    required this.fileName,
    required this.columns,
    required this.rows,
    required this.summaryItems,
  });
}
