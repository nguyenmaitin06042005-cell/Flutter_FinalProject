import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/forest_owner_model.dart';
import '../services/forest_owner_service.dart';
import '../widgets/app_colors.dart';

class ForestOwnersPage extends StatefulWidget {
  const ForestOwnersPage({super.key});

  @override
  State<ForestOwnersPage> createState() => _ForestOwnersPageState();
}

class _ForestOwnersPageState extends State<ForestOwnersPage> {
  static const List<String> _ownerTypes = <String>[
    'Individual',
    'Company',
    'Cooperative',
  ];

  static const List<String> _statuses = <String>[
    'Active',
    'Inactive',
  ];

  static const List<String> _attachmentCategories = <String>[
    'Giấy chứng nhận quyền sử dụng đất',
    'Hợp đồng hợp tác',
    'Hồ sơ pháp lý',
  ];

  final ForestOwnerService _service = ForestOwnerService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedStatus = 'All Status';
  String _selectedType = 'All Types';
  ForestOwner? _selectedOwner;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ForestOwner> _filteredOwners(List<ForestOwner> owners) {
    final keyword = _searchController.text.trim().toLowerCase();

    return owners.where((owner) {
      final matchesSearch = keyword.isEmpty ||
          owner.ownerCode.toLowerCase().contains(keyword) ||
          owner.ownerName.toLowerCase().contains(keyword) ||
          owner.identificationNumber.toLowerCase().contains(keyword) ||
          owner.phone.toLowerCase().contains(keyword) ||
          owner.email.toLowerCase().contains(keyword) ||
          owner.province.toLowerCase().contains(keyword);

      final matchesStatus =
          _selectedStatus == 'All Status' || owner.status == _selectedStatus;
      final matchesType =
          _selectedType == 'All Types' || owner.type == _selectedType;

      return matchesSearch && matchesStatus && matchesType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f8f6),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
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
          child: StreamBuilder<List<ForestOwner>>(
            stream: _service.watchOwners(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildFirebaseError(snapshot.error);
              }

              final owners = snapshot.data ?? <ForestOwner>[];

              if (owners.isNotEmpty) {
                final selectedIndex = owners.indexWhere(
                  (owner) => owner.id == _selectedOwner?.id,
                );
                _selectedOwner =
                    selectedIndex >= 0 ? owners[selectedIndex] : owners.first;
              } else {
                _selectedOwner = null;
              }

              final filtered = _filteredOwners(owners);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 1050;

                  if (stacked) {
                    return Column(
                      children: <Widget>[
                        Expanded(child: _buildOwnersSection(filtered)),
                        const Divider(height: 1),
                        SizedBox(
                          height: 500,
                          child: _buildSummarySection(),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        flex: 76,
                        child: _buildOwnersSection(filtered),
                      ),
                      Container(
                        width: 1,
                        color: const Color(0xffe3eae5),
                      ),
                      Expanded(
                        flex: 24,
                        child: _buildSummarySection(),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOwnersSection(List<ForestOwner> owners) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Forest Owners',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xff17211b),
            ),
          ),
          const SizedBox(height: 20),
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(child: _buildOwnersView(owners)),
          const SizedBox(height: 10),
          Text(
            '${owners.length} owner(s)',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xff7b877f),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        final search = SizedBox(
          width: compact ? double.infinity : 270,
          height: 42,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search owners...',
              prefixIcon: const Icon(Icons.search, size: 19),
              filled: true,
              fillColor: const Color(0xfffbfcfb),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                  color: Color(0xffdfe7e2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                  color: Color(0xffdfe7e2),
                ),
              ),
            ),
          ),
        );

        final statusFilter = SizedBox(
          width: 145,
          height: 42,
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            isExpanded: true,
            decoration: _filterDecoration(),
            items: <String>['All Status', ..._statuses]
                .map(
                  (status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(
                      status,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedStatus = value);
            },
          ),
        );

        final typeFilter = SizedBox(
          width: 155,
          height: 42,
          child: DropdownButtonFormField<String>(
            value: _selectedType,
            isExpanded: true,
            decoration: _filterDecoration(),
            items: <String>['All Types', ..._ownerTypes]
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedType = value);
            },
          ),
        );

        final addButton = SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: () => _showOwnerDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Add Owner',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              search,
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  statusFilter,
                  typeFilter,
                  addButton,
                ],
              ),
            ],
          );
        }

        return Row(
          children: <Widget>[
            search,
            const SizedBox(width: 10),
            statusFilter,
            const SizedBox(width: 10),
            typeFilter,
            const Spacer(),
            addButton,
          ],
        );
      },
    );
  }

  InputDecoration _filterDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      filled: true,
      fillColor: const Color(0xfffbfcfb),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xffdfe7e2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xffdfe7e2)),
      ),
    );
  }

  Widget _buildOwnersView(List<ForestOwner> owners) {
    if (owners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.groups_outlined,
              size: 58,
              color: Color(0xffa2ada6),
            ),
            const SizedBox(height: 10),
            const Text(
              'Chưa có chủ rừng phù hợp.',
              style: TextStyle(
                color: Color(0xff6f7b74),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showOwnerDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm chủ rừng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return ListView.separated(
            itemCount: owners.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildOwnerCard(owners[index]);
            },
          );
        }

        return SingleChildScrollView(
          child: Table(
            border: TableBorder.all(
              color: const Color(0xffe1e8e3),
              width: 0.8,
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const <int, TableColumnWidth>{
              0: FlexColumnWidth(0.85),
              1: FlexColumnWidth(1.25),
              2: FlexColumnWidth(0.88),
              3: FlexColumnWidth(1.10),
              4: FlexColumnWidth(0.90),
              5: FlexColumnWidth(0.90),
              6: FlexColumnWidth(0.75),
              7: FixedColumnWidth(48),
            },
            children: <TableRow>[
              TableRow(
                decoration: const BoxDecoration(
                  color: Color(0xfff4f8f5),
                ),
                children: <Widget>[
                  _tableHeader('Owner Code'),
                  _tableHeader('Owner Name'),
                  _tableHeader('Type'),
                  _tableHeader('CCCD/Business Reg.'),
                  _tableHeader('Phone'),
                  _tableHeader('Province'),
                  _tableHeader('Status'),
                  _tableHeader(''),
                ],
              ),
              ...owners.asMap().entries.map((entry) {
                final index = entry.key;
                final owner = entry.value;
                final selected = _selectedOwner?.id == owner.id;

                return TableRow(
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xffeff8f2)
                        : index.isEven
                            ? Colors.white
                            : const Color(0xfffbfdfc),
                  ),
                  children: <Widget>[
                    _tableCell(
                      owner.ownerCode,
                      bold: true,
                      onTap: () => _selectOwner(owner),
                    ),
                    _tableCell(
                      owner.ownerName,
                      bold: true,
                      onTap: () => _selectOwner(owner),
                    ),
                    _tableCell(
                      owner.type,
                      onTap: () => _selectOwner(owner),
                    ),
                    _tableCell(
                      owner.identificationNumber,
                      onTap: () => _selectOwner(owner),
                    ),
                    _tableCell(
                      owner.phone,
                      onTap: () => _selectOwner(owner),
                    ),
                    _tableCell(
                      owner.province,
                      onTap: () => _selectOwner(owner),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      child: InkWell(
                        onTap: () => _selectOwner(owner),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _statusBadge(owner.status),
                        ),
                      ),
                    ),
                    _actionsCell(owner),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _selectOwner(ForestOwner owner) {
    setState(() => _selectedOwner = owner);
  }

  Widget _tableHeader(String value) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      child: Text(
        value,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9.7,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: Color(0xff56635b),
        ),
      ),
    );
  }

  Widget _tableCell(
    String value, {
    bool bold = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Tooltip(
        message: value,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 10,
          ),
          child: Text(
            value.isEmpty ? '-' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.3,
              height: 1.2,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: const Color(0xff2e3a33),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionsCell(ForestOwner owner) {
    return Center(
      child: PopupMenuButton<String>(
        tooltip: 'Actions',
        onSelected: (value) {
          if (value == 'view') {
            _showOwnerDetail(owner);
          } else if (value == 'edit') {
            _showOwnerDialog(owner: owner);
          } else if (value == 'delete') {
            _confirmDeleteOwner(owner);
          }
        },
        itemBuilder: (_) => const <PopupMenuEntry<String>>[
          PopupMenuItem(
            value: 'view',
            child: Row(
              children: <Widget>[
                Icon(Icons.visibility_outlined, size: 18),
                SizedBox(width: 8),
                Text('View Detail'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: <Widget>[
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ],
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.more_horiz, size: 20),
        ),
      ),
    );
  }

  Widget _buildOwnerCard(ForestOwner owner) {
    return InkWell(
      onTap: () => _selectOwner(owner),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _selectedOwner?.id == owner.id
              ? const Color(0xffeff8f2)
              : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xffe1e9e4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    owner.ownerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _statusBadge(owner.status),
                _actionsCell(owner),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              owner.ownerCode,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xff748078),
                fontWeight: FontWeight.w700,
              ),
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: <Widget>[
                _cardInfo('Type', owner.type),
                _cardInfo('CCCD/GPKD', owner.identificationNumber),
                _cardInfo('Phone', owner.phone),
                _cardInfo('Province', owner.province),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardInfo(String label, String value) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xff849087),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xff2f3b34),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final owner = _selectedOwner;

    if (owner == null) {
      return const Center(
        child: Text(
          'Chọn một chủ rừng để xem thông tin.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xff7b877f),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Owner Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xff17211b),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  _summaryItem('Owner Code', owner.ownerCode),
                  _summaryItem('Owner Name', owner.ownerName),
                  _summaryItem('Type', owner.type),
                  _summaryItem(
                    owner.type == 'Individual' ? 'CCCD' : 'Business Reg.',
                    owner.identificationNumber,
                  ),
                  _summaryItem('Phone', owner.phone),
                  _summaryItem('Email', owner.email),
                  _summaryItem('Province', owner.province),
                  _summaryItem('Address', owner.address),
                  _summaryItem(
                    'Documents',
                    '${owner.attachments.length}',
                  ),
                  StreamBuilder<OwnerProjectStats>(
                    stream: _service.watchOwnerProjectStats(
                      owner.ownerName,
                    ),
                    builder: (context, snapshot) {
                      final stats = snapshot.data ??
                          const OwnerProjectStats(
                            totalProjects: 0,
                            totalAreaHa: 0,
                          );

                      return Column(
                        children: <Widget>[
                          _summaryItem(
                            'Total Projects',
                            '${stats.totalProjects}',
                          ),
                          _summaryItem(
                            'Total Area',
                            '${_formatNumber(stats.totalAreaHa)} ha',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _showOwnerDetail(owner),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text(
                'View Detail',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.3,
                color: Color(0xff8a958e),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xff2d3932),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final active = status == 'Active';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active ? const Color(0xffe8f7ed) : const Color(0xffffe9e9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: active ? const Color(0xff168a45) : const Color(0xffc53d3d),
        ),
      ),
    );
  }

  Future<void> _showOwnerDialog({
    ForestOwner? owner,
  }) async {
    final isEditing = owner != null;
    final formKey = GlobalKey<FormState>();

    final ownerCodeController = TextEditingController(
      text: owner?.ownerCode ?? _generateOwnerCode(),
    );
    final ownerNameController = TextEditingController(
      text: owner?.ownerName ?? '',
    );
    final identificationController = TextEditingController(
      text: owner?.identificationNumber ?? '',
    );
    final addressController = TextEditingController(
      text: owner?.address ?? '',
    );
    final phoneController = TextEditingController(
      text: owner?.phone ?? '',
    );
    final emailController = TextEditingController(
      text: owner?.email ?? '',
    );
    final provinceController = TextEditingController(
      text: owner?.province ?? '',
    );

    String selectedType = owner?.type ?? 'Individual';
    String selectedStatus = owner?.status ?? 'Active';
    bool isSaving = false;

    final pendingFiles = <OwnerUploadFile>[];
    final existingAttachments = List<OwnerAttachment>.from(
      owner?.attachments ?? const <OwnerAttachment>[],
    );

    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, dialogSetState) {
              Future<void> selectFiles(String category) async {
                try {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: const <String>[
                      'pdf',
                      'jpg',
                      'jpeg',
                      'png',
                      'docx',
                    ],
                    allowMultiple: true,
                    withData: true,
                  );

                  if (result == null || result.files.isEmpty) return;

                  for (final file in result.files) {
                    final bytes = file.bytes;
                    if (bytes == null) continue;

                    pendingFiles.add(
                      OwnerUploadFile(
                        bytes: bytes,
                        fileName: file.name,
                        extension: (file.extension ?? file.name.split('.').last)
                            .toLowerCase(),
                        category: category,
                      ),
                    );
                  }

                  dialogSetState(() {});
                } catch (error) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Không thể chọn tệp: $error',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }

              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 820,
                    maxHeight: MediaQuery.of(dialogContext).size.height * 0.88,
                  ),
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          22,
                          18,
                          12,
                          12,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                isEditing
                                    ? 'Edit Forest Owner'
                                    : 'Add Forest Owner',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff17211b),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(
                                        dialogContext,
                                        rootNavigator: true,
                                      ).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: Form(
                          key: formKey,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(22),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final twoColumns = constraints.maxWidth >= 620;
                                final fieldWidth = twoColumns
                                    ? (constraints.maxWidth - 14) / 2
                                    : constraints.maxWidth;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Wrap(
                                      spacing: 14,
                                      runSpacing: 14,
                                      children: <Widget>[
                                        _dialogField(
                                          width: fieldWidth,
                                          controller: ownerCodeController,
                                          label: 'Owner Code',
                                          hint: 'OWN-0001',
                                        ),
                                        _dialogField(
                                          width: fieldWidth,
                                          controller: ownerNameController,
                                          label: 'Owner Name',
                                          hint: 'Nguyễn Văn A',
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child:
                                              DropdownButtonFormField<String>(
                                            value: selectedType,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Type',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: _ownerTypes
                                                .map(
                                                  (type) =>
                                                      DropdownMenuItem<String>(
                                                    value: type,
                                                    child: Text(type),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: isSaving
                                                ? null
                                                : (value) {
                                                    if (value == null) {
                                                      return;
                                                    }

                                                    dialogSetState(
                                                      () =>
                                                          selectedType = value,
                                                    );
                                                  },
                                          ),
                                        ),
                                        _dialogField(
                                          width: fieldWidth,
                                          controller: identificationController,
                                          label: selectedType == 'Individual'
                                              ? 'CCCD'
                                              : 'GPKD / Registration No.',
                                          hint: selectedType == 'Individual'
                                              ? '035xxxxxxxxx'
                                              : 'Business registration',
                                        ),
                                        _dialogField(
                                          width: fieldWidth,
                                          controller: phoneController,
                                          label: 'Phone',
                                          hint: '0912345678',
                                          keyboardType: TextInputType.phone,
                                          validator: (value) {
                                            final phone = value?.trim() ?? '';

                                            if (!RegExp(
                                              r'^[0-9]{9,12}$',
                                            ).hasMatch(phone)) {
                                              return 'Số điện thoại phải có 9-12 chữ số';
                                            }

                                            return null;
                                          },
                                        ),
                                        _dialogField(
                                          width: fieldWidth,
                                          controller: emailController,
                                          label: 'Email',
                                          hint: 'owner@email.com',
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          validator: (value) {
                                            final email = value?.trim() ?? '';

                                            if (!RegExp(
                                              r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                                            ).hasMatch(email)) {
                                              return 'Email không hợp lệ';
                                            }

                                            return null;
                                          },
                                        ),
                                        _dialogField(
                                          width: fieldWidth,
                                          controller: provinceController,
                                          label: 'Province',
                                          hint: 'Lâm Đồng',
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child:
                                              DropdownButtonFormField<String>(
                                            value: selectedStatus,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Status',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: _statuses
                                                .map(
                                                  (status) =>
                                                      DropdownMenuItem<String>(
                                                    value: status,
                                                    child: Text(status),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: isSaving
                                                ? null
                                                : (value) {
                                                    if (value == null) {
                                                      return;
                                                    }

                                                    dialogSetState(
                                                      () => selectedStatus =
                                                          value,
                                                    );
                                                  },
                                          ),
                                        ),
                                        _dialogField(
                                          width: constraints.maxWidth,
                                          controller: addressController,
                                          label: 'Address',
                                          hint: 'Địa chỉ đầy đủ của chủ rừng',
                                          maxLines: 2,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    const Text(
                                      'Hồ sơ đính kèm',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Hỗ trợ PDF, JPG, PNG và DOCX.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xff78847c),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: _attachmentCategories.map(
                                        (category) {
                                          return OutlinedButton.icon(
                                            onPressed: isSaving
                                                ? null
                                                : () => selectFiles(
                                                      category,
                                                    ),
                                            icon: const Icon(
                                              Icons.attach_file,
                                              size: 17,
                                            ),
                                            label: Text(
                                              category,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          );
                                        },
                                      ).toList(),
                                    ),
                                    if (existingAttachments
                                        .isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Tệp đã lưu',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...existingAttachments.map(
                                        (attachment) => _savedAttachmentRow(
                                          owner!,
                                          attachment,
                                          onDeleted: () {
                                            existingAttachments.removeWhere(
                                              (item) =>
                                                  item.storagePath ==
                                                  attachment.storagePath,
                                            );
                                            dialogSetState(() {});
                                          },
                                        ),
                                      ),
                                    ],
                                    if (pendingFiles.isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Tệp sẽ upload',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...pendingFiles.asMap().entries.map(
                                        (entry) {
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.all(
                                              10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xfff5f9f6,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                              border: Border.all(
                                                color: const Color(
                                                  0xffe0e8e2,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: <Widget>[
                                                const Icon(
                                                  Icons.upload_file_outlined,
                                                  size: 20,
                                                  color: Color(
                                                    0xff168a45,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 9,
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: <Widget>[
                                                      Text(
                                                        entry.value.fileName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      Text(
                                                        entry.value.category,
                                                        style: const TextStyle(
                                                          fontSize: 10.5,
                                                          color: Color(
                                                            0xff78847c,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Remove',
                                                  onPressed: isSaving
                                                      ? null
                                                      : () {
                                                          pendingFiles.removeAt(
                                                            entry.key,
                                                          );
                                                          dialogSetState(
                                                            () {},
                                                          );
                                                        },
                                                  icon: const Icon(
                                                    Icons.close,
                                                    size: 18,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          18,
                          12,
                          18,
                          16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(
                                        dialogContext,
                                        rootNavigator: true,
                                      ).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!(formKey.currentState?.validate() ??
                                          false)) {
                                        return;
                                      }

                                      dialogSetState(
                                        () => isSaving = true,
                                      );

                                      final result = ForestOwner(
                                        id: owner?.id ?? '',
                                        ownerCode:
                                            ownerCodeController.text.trim(),
                                        ownerName:
                                            ownerNameController.text.trim(),
                                        type: selectedType,
                                        identificationNumber:
                                            identificationController.text
                                                .trim(),
                                        address: addressController.text.trim(),
                                        phone: phoneController.text.trim(),
                                        email: emailController.text.trim(),
                                        province:
                                            provinceController.text.trim(),
                                        status: selectedStatus,
                                        attachments: existingAttachments,
                                        createdAt: owner?.createdAt,
                                        updatedAt: owner?.updatedAt,
                                      );

                                      try {
                                        final saved = await _service.saveOwner(
                                          owner: result,
                                          newFiles: pendingFiles,
                                        );

                                        if (!mounted) return;

                                        setState(() {
                                          _selectedOwner = saved;
                                        });

                                        if (dialogContext.mounted) {
                                          Navigator.of(
                                            dialogContext,
                                            rootNavigator: true,
                                          ).pop();
                                        }

                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isEditing
                                                  ? 'Đã cập nhật chủ rừng.'
                                                  : 'Đã thêm chủ rừng lên Firebase.',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (error) {
                                        if (!mounted) return;

                                        dialogSetState(
                                          () => isSaving = false,
                                        );

                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Không thể lưu: $error',
                                            ),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(
                                              seconds: 8,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.save_outlined,
                                      size: 18,
                                    ),
                              label: Text(
                                isSaving
                                    ? 'Saving...'
                                    : isEditing
                                        ? 'Save Changes'
                                        : 'Save Owner',
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
      debugPrint('Lỗi mở Add Owner: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể mở cửa sổ Add Owner: $error',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      ownerCodeController.dispose();
      ownerNameController.dispose();
      identificationController.dispose();
      addressController.dispose();
      phoneController.dispose();
      emailController.dispose();
      provinceController.dispose();
    }
  }

  Widget _dialogField({
    required double width,
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator ??
            (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập $label';
              }
              return null;
            },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _savedAttachmentRow(
    ForestOwner owner,
    OwnerAttachment attachment, {
    required VoidCallback onDeleted,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xfffafcfb),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xffe1e8e3),
        ),
      ),
      child: Row(
        children: <Widget>[
          _attachmentIcon(attachment.extension),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  attachment.category,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xff78847c),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open',
            onPressed: () => _openAttachment(attachment),
            icon: const Icon(
              Icons.open_in_new,
              size: 18,
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () async {
              try {
                await _service.deleteAttachment(
                  owner: owner,
                  attachment: attachment,
                );

                if (!mounted) return;
                onDeleted();
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Không thể xóa tệp: $error',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOwnerDetail(
    ForestOwner owner,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Owner Detail - ${owner.ownerCode}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _statusBadge(owner.status),
            ],
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _detailRow('Owner Name', owner.ownerName),
                  _detailRow('Type', owner.type),
                  _detailRow(
                    owner.type == 'Individual' ? 'CCCD' : 'GPKD',
                    owner.identificationNumber,
                  ),
                  _detailRow('Address', owner.address),
                  _detailRow('Phone', owner.phone),
                  _detailRow('Email', owner.email),
                  _detailRow('Province', owner.province),
                  const Divider(height: 28),
                  const Text(
                    'Hồ sơ đính kèm',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (owner.attachments.isEmpty)
                    const Text(
                      'Chưa có tài liệu đính kèm.',
                      style: TextStyle(
                        color: Color(0xff78847c),
                      ),
                    )
                  else
                    ...owner.attachments.map(
                      (attachment) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _attachmentIcon(
                          attachment.extension,
                        ),
                        title: Text(
                          attachment.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${attachment.category} • '
                          '${_formatFileSize(attachment.sizeBytes)}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Open',
                          onPressed: () => _openAttachment(attachment),
                          icon: const Icon(
                            Icons.open_in_new,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showOwnerDialog(owner: owner);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentIcon(String extension) {
    IconData icon;
    Color foreground;
    Color background;

    switch (extension.toLowerCase()) {
      case 'pdf':
        icon = Icons.picture_as_pdf_outlined;
        foreground = const Color(0xffd84949);
        background = const Color(0xffffeded);
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        icon = Icons.image_outlined;
        foreground = const Color(0xff2e8f55);
        background = const Color(0xffeaf7ee);
        break;
      case 'docx':
        icon = Icons.description_outlined;
        foreground = const Color(0xff3477bd);
        background = const Color(0xffeaf3fd);
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
        foreground = const Color(0xff6f7c74);
        background = const Color(0xffeef2ef);
    }

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        icon,
        size: 19,
        color: foreground,
      ),
    );
  }

  Future<void> _openAttachment(
    OwnerAttachment attachment,
  ) async {
    final uri = Uri.tryParse(attachment.downloadUrl);

    if (uri == null || attachment.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tệp không có đường dẫn hợp lệ.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể mở tệp.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteOwner(
    ForestOwner owner,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Forest Owner'),
          content: Text(
            'Bạn có chắc muốn xóa "${owner.ownerName}" '
            'và toàn bộ hồ sơ đính kèm không?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (accepted != true) return;

    try {
      await _service.deleteOwner(owner);

      if (!mounted) return;

      setState(() {
        if (_selectedOwner?.id == owner.id) {
          _selectedOwner = null;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa chủ rừng.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể xóa chủ rừng: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildFirebaseError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              size: 58,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Không thể đọc dữ liệu Firebase.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff6f7b74),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateOwnerCode() {
    final value = DateTime.now().millisecondsSinceEpoch.toString();
    return 'OWN-${value.substring(value.length - 6)}';
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(
      value == value.roundToDouble() ? 0 : 2,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';

    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}
