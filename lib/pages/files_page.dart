import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/managed_file_model.dart';
import '../services/file_management_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_colors.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  static const List<String> _categories = <String>[
    'Hồ sơ pháp lý',
    'Hồ sơ dự án',
    'Hình ảnh hiện trường',
    'Báo cáo khảo sát',
  ];

  final FileManagementService _service = FileManagementService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'Tất cả danh mục';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            border: Border.all(color: const Color(0xffe4ebe6)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0a000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: StreamBuilder<List<ManagedFile>>(
            stream: _service.watchFiles(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildFirebaseError(snapshot.error);
              }

              final files = snapshot.data ?? <ManagedFile>[];
              final filtered = _filterFiles(files);

              return Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Files',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff17211b),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildToolbar(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildFilesView(filtered),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${filtered.length} file(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff7b877f),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<ManagedFile> _filterFiles(List<ManagedFile> files) {
    final keyword = _searchController.text.trim().toLowerCase();

    return files.where((file) {
      final matchesSearch = keyword.isEmpty ||
          file.fileName.toLowerCase().contains(keyword) ||
          file.category.toLowerCase().contains(keyword) ||
          file.project.toLowerCase().contains(keyword) ||
          file.uploadedBy.toLowerCase().contains(keyword);

      final matchesCategory = _selectedCategory == 'Tất cả danh mục' ||
          file.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        final search = SizedBox(
          width: compact ? double.infinity : 330,
          height: 42,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search files...',
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
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xffdfe7e2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xffdfe7e2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        );

        final categoryFilter = SizedBox(
          width: 205,
          height: 42,
          child: DropdownButtonFormField<String>(
            value: _selectedCategory,
            isExpanded: true,
            decoration: _filterDecoration(),
            items: <String>['Tất cả danh mục', ..._categories]
                .map(
                  (category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedCategory = value);
            },
          ),
        );

        final uploadButton = SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: _showUploadDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Upload File',
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
                  categoryFilter,
                  uploadButton,
                ],
              ),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: search),
            const SizedBox(width: 12),
            categoryFilter,
            const Spacer(),
            uploadButton,
          ],
        );
      },
    );
  }

  InputDecoration _filterDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xfffbfcfb),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xffdfe7e2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xffdfe7e2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _buildFilesView(List<ManagedFile> files) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.folder_open_outlined,
              size: 58,
              color: Color(0xffa2ada6),
            ),
            const SizedBox(height: 10),
            const Text(
              'Chưa có tài liệu phù hợp.',
              style: TextStyle(
                color: Color(0xff6f7b74),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showUploadDialog,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload File'),
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
        if (constraints.maxWidth < 760) {
          return ListView.separated(
            itemCount: files.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _buildFileCard(files[index]),
          );
        }

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
              0: FlexColumnWidth(1.55),
              1: FlexColumnWidth(1.05),
              2: FlexColumnWidth(1.25),
              3: FlexColumnWidth(1.05),
              4: FlexColumnWidth(0.78),
              5: FlexColumnWidth(0.65),
              6: FixedColumnWidth(58),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: <TableRow>[
              TableRow(
                decoration: const BoxDecoration(
                  color: Color(0xfff7faf8),
                ),
                children: <Widget>[
                  _tableHeader('File Name'),
                  _tableHeader('Category'),
                  _tableHeader('Project'),
                  _tableHeader('Uploaded By'),
                  _tableHeader('Date'),
                  _tableHeader('Size'),
                  _tableHeader(''),
                ],
              ),
              ...files.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;

                return TableRow(
                  decoration: BoxDecoration(
                    color:
                        index.isEven ? Colors.white : const Color(0xfffbfdfc),
                  ),
                  children: <Widget>[
                    _fileNameCell(file),
                    _tableValue(file.category),
                    _tableValue(file.project),
                    _tableValue(file.uploadedBy),
                    _tableValue(_formatDate(file.uploadedAt)),
                    _tableValue(_formatFileSize(file.sizeBytes)),
                    _actionsCell(file),
                  ],
                );
              }),
            ],
          ),
        );
      },
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
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xff66736b),
        ),
      ),
    );
  }

  Widget _tableValue(String value) {
    return Tooltip(
      message: value,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          value.isEmpty ? '-' : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.25,
            color: Color(0xff354239),
          ),
        ),
      ),
    );
  }

  Widget _fileNameCell(ManagedFile file) {
    return InkWell(
      onTap: () => _openFile(file),
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: <Widget>[
            _fileIcon(file.extension),
            const SizedBox(width: 9),
            Expanded(
              child: Tooltip(
                message: file.fileName,
                child: Text(
                  file.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff2a372f),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileIcon(String extension) {
    IconData icon;
    Color color;
    Color background;

    switch (extension.toLowerCase()) {
      case 'pdf':
        icon = Icons.picture_as_pdf_outlined;
        color = const Color(0xffd84949);
        background = const Color(0xffffeded);
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        icon = Icons.image_outlined;
        color = const Color(0xff2e8f55);
        background = const Color(0xffeaf7ee);
        break;
      case 'docx':
        icon = Icons.description_outlined;
        color = const Color(0xff3477bd);
        background = const Color(0xffeaf3fd);
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
        color = const Color(0xff6f7c74);
        background = const Color(0xffeef2ef);
    }

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _actionsCell(ManagedFile file) {
    return Center(
      child: PopupMenuButton<String>(
        tooltip: 'Actions',
        onSelected: (value) {
          if (value == 'open') {
            _openFile(file);
          } else if (value == 'delete') {
            _confirmDelete(file);
          }
        },
        itemBuilder: (_) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'open',
            child: Row(
              children: <Widget>[
                Icon(Icons.open_in_new, size: 18),
                SizedBox(width: 8),
                Text('Open'),
              ],
            ),
          ),
          PopupMenuItem<String>(
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

  Widget _buildFileCard(ManagedFile file) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xffe1e9e4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _fileIcon(file.extension),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  file.fileName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff223027),
                  ),
                ),
              ),
              _actionsCell(file),
            ],
          ),
          const Divider(height: 22),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: <Widget>[
              _cardInfo('Category', file.category),
              _cardInfo('Project', file.project),
              _cardInfo('Uploaded By', file.uploadedBy),
              _cardInfo('Date', _formatDate(file.uploadedAt)),
              _cardInfo('Size', _formatFileSize(file.sizeBytes)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardInfo(String label, String value) {
    return SizedBox(
      width: 210,
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

  Future<void> _showUploadDialog() async {
    Uint8List? selectedBytes;
    String selectedFileName = '';
    String selectedExtension = '';
    int selectedSize = 0;
    String selectedCategory = _categories.first;
    String selectedProject = 'Không thuộc dự án';
    bool isUploading = false;

    final currentUser = FirebaseAuth.instance.currentUser;

    final uploadedByController = TextEditingController(
      text: currentUser?.displayName?.trim().isNotEmpty == true
          ? currentUser!.displayName!.trim()
          : '',
    );

    final uploaderEmail = currentUser?.email?.trim() ?? '';

    await showDialog<void>(
      context: context,
      barrierDismissible: !isUploading,
      builder: (dialogContext) {
        return StreamBuilder<List<String>>(
          stream: _service.watchProjectNames(),
          builder: (context, projectSnapshot) {
            final projects = projectSnapshot.data ?? <String>[];
            final projectOptions = <String>[
              'Không thuộc dự án',
              ...projects,
            ];

            if (!projectOptions.contains(selectedProject)) {
              selectedProject = 'Không thuộc dự án';
            }

            return StatefulBuilder(
              builder: (context, dialogSetState) {
                Future<void> pickFile() async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: const <String>[
                      'pdf',
                      'jpg',
                      'jpeg',
                      'png',
                      'docx',
                    ],
                    allowMultiple: false,
                    withData: true,
                  );

                  if (result == null || result.files.isEmpty) return;

                  final file = result.files.single;

                  if (file.bytes == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Không thể đọc dữ liệu của tệp.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final extension =
                      (file.extension ?? file.name.split('.').last)
                          .toLowerCase();

                  dialogSetState(() {
                    selectedBytes = file.bytes;
                    selectedFileName = file.name;
                    selectedExtension = extension;
                    selectedSize = file.size;
                  });
                }

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
                      const Expanded(
                        child: Text(
                          'Upload File',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: isUploading
                            ? null
                            : () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          InkWell(
                            onTap: isUploading ? null : pickFile,
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 24,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xfff6faf7),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: const Color(0xffcfdcd3),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  Icon(
                                    selectedBytes == null
                                        ? Icons.cloud_upload_outlined
                                        : Icons.check_circle_outline,
                                    size: 42,
                                    color: selectedBytes == null
                                        ? AppColors.primary
                                        : Colors.green,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    selectedBytes == null
                                        ? 'Chọn PDF, JPG, PNG hoặc DOCX'
                                        : selectedFileName,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xff2b3830),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    selectedBytes == null
                                        ? 'Nhấn vào đây để chọn tệp'
                                        : _formatFileSize(selectedSize),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff758179),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Nhóm tài liệu',
                              border: OutlineInputBorder(),
                            ),
                            items: _categories
                                .map(
                                  (category) => DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(
                                      category,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: isUploading
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    dialogSetState(
                                      () => selectedCategory = value,
                                    );
                                  },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: selectedProject,
                            isExpanded: true,
                            menuMaxHeight: 300,
                            decoration: const InputDecoration(
                              labelText: 'Project',
                              border: OutlineInputBorder(),
                            ),
                            items: projectOptions
                                .map(
                                  (project) => DropdownMenuItem<String>(
                                    value: project,
                                    child: Text(
                                      project,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: isUploading
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    dialogSetState(
                                      () => selectedProject = value,
                                    );
                                  },
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: uploadedByController,
                            enabled: !isUploading,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Uploaded By',
                              hintText: 'Nhập tên người upload',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              uploaderEmail.isEmpty
                                  ? 'Chưa có email đăng nhập'
                                  : uploaderEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: uploaderEmail.isEmpty
                                    ? Colors.orange
                                    : const Color(0xff263029),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Email được lấy tự động từ tài khoản Firebase '
                            'đang đăng nhập.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xff748078),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: isUploading
                          ? null
                          : () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: isUploading
                          ? null
                          : () async {
                              final uploadedBy =
                                  uploadedByController.text.trim();

                              if (selectedBytes == null ||
                                  selectedFileName.isEmpty ||
                                  selectedExtension.isEmpty) {
                                ScaffoldMessenger.of(
                                  this.context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Vui lòng chọn tệp trước khi upload.',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              if (uploadedBy.isEmpty) {
                                ScaffoldMessenger.of(
                                  this.context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Vui lòng nhập tên người upload.',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              if (uploaderEmail.isEmpty) {
                                ScaffoldMessenger.of(
                                  this.context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Tài khoản hiện tại chưa có email. '
                                      'Vui lòng đăng nhập lại bằng tài khoản '
                                      'có email.',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              dialogSetState(() => isUploading = true);

                              try {
                                final uploadedFile = await _service.uploadFile(
                                  bytes: selectedBytes!,
                                  fileName: selectedFileName,
                                  extension: selectedExtension,
                                  category: selectedCategory,
                                  project: selectedProject,
                                  uploadedBy: uploadedBy,
                                );

                                String? notificationWarning;

                                try {
                                  await _notificationService
                                      .createNewFileNotification(
                                    uploaderName: uploadedBy,
                                    fileName: selectedFileName,
                                    projectName: selectedProject,
                                    referenceId: uploadedFile.id,
                                  );
                                } catch (notificationError) {
                                  notificationWarning =
                                      'Tệp đã upload nhưng chưa tạo được '
                                      'thông báo: $notificationError';
                                  debugPrint(notificationWarning);
                                }

                                if (!mounted) return;

                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }

                                ScaffoldMessenger.of(
                                  this.context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      notificationWarning ??
                                          'Đã upload hồ sơ và tạo thông báo.',
                                    ),
                                    backgroundColor: notificationWarning == null
                                        ? Colors.green
                                        : Colors.orange,
                                    duration: Duration(
                                      seconds:
                                          notificationWarning == null ? 3 : 8,
                                    ),
                                  ),
                                );
                              } catch (error) {
                                if (!mounted) return;

                                dialogSetState(
                                  () => isUploading = false,
                                );

                                ScaffoldMessenger.of(
                                  this.context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Không thể upload: $error',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 8),
                                  ),
                                );
                              }
                            },
                      icon: isUploading
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_file, size: 18),
                      label: Text(
                        isUploading ? 'Uploading...' : 'Upload File',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    uploadedByController.dispose();
  }

  Future<void> _openFile(ManagedFile file) async {
    final uri = Uri.tryParse(file.downloadUrl);

    if (uri == null || file.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tệp không có đường dẫn tải hợp lệ.'),
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

  Future<void> _confirmDelete(ManagedFile file) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete File'),
          content: Text(
            'Bạn có chắc muốn xóa "${file.fileName}" không?',
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
      await _service.deleteFile(file);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa tệp.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xóa tệp: $error'),
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
              style: const TextStyle(color: Color(0xff6f7b74)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kb = bytes / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
