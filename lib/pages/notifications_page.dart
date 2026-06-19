import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_notification_model.dart';
import '../models/project_request_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/project_request_service.dart';
import '../widgets/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.onNotificationOpen,
    required this.currentUser,
  });

  final ValueChanged<AppNotification>? onNotificationOpen;
  final UserModel currentUser;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _service = NotificationService();
  final ProjectRequestService _requestService = ProjectRequestService();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _processingRequests = {}; // requestId → isProcessing
  final Map<String, Future<String?>> _requestStatusCache = {};

  Future<String?> _getCachedRequestStatus(String requestId) {
    if (!_requestStatusCache.containsKey(requestId)) {
      _requestStatusCache[requestId] = _loadRequestStatus(requestId);
    }
    return _requestStatusCache[requestId]!;
  }

  String _selectedFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppNotification> _filterNotifications(
    List<AppNotification> notifications,
  ) {
    final keyword = _searchController.text.trim().toLowerCase();

    return notifications.where((notification) {
      final matchesFilter = _selectedFilter == 'all' ||
          (_selectedFilter == 'unread' &&
              !notification.isReadBy(
                _service.currentUserKey,
              )) ||
          (_selectedFilter == 'read' &&
              notification.isReadBy(
                _service.currentUserKey,
              ));

      final matchesSearch = keyword.isEmpty ||
          notification.title.toLowerCase().contains(keyword) ||
          notification.message.toLowerCase().contains(keyword) ||
          notification.projectName.toLowerCase().contains(keyword) ||
          notificationTypeLabel(notification.type)
              .toLowerCase()
              .contains(keyword);

      return matchesFilter && matchesSearch;
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
            border: Border.all(
              color: const Color(0xffe4ebe6),
            ),
          ),
          child: StreamBuilder<List<AppNotification>>(
            stream: _service.watchNotifications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return _buildError(snapshot.error);
              }

              final notifications = snapshot.data ?? <AppNotification>[];
              final filtered = _filterNotifications(notifications);
              final unreadCount = notifications
                  .where(
                    (notification) => !notification.isReadBy(
                      _service.currentUserKey,
                    ),
                  )
                  .length;

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  20,
                  22,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildHeader(
                      notifications: notifications,
                      unreadCount: unreadCount,
                    ),
                    const SizedBox(height: 20),
                    _buildToolbar(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _buildNotificationCard(
                                  filtered[index],
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${filtered.length} thông báo',
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

  Widget _buildHeader({
    required List<AppNotification> notifications,
    required int unreadCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Notification Center',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xff17211b),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              unreadCount == 0
                  ? 'Bạn đã đọc tất cả thông báo.'
                  : 'Bạn có $unreadCount thông báo chưa đọc.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xff748078),
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            if (widget.currentUser.isAdmin)
              ElevatedButton.icon(
                onPressed: _showUpdateRequestDialog,
                icon: const Icon(
                  Icons.edit_note_outlined,
                  size: 18,
                ),
                label: const Text(
                  'Yêu cầu cập nhật',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            OutlinedButton.icon(
              onPressed: unreadCount == 0
                  ? null
                  : () async {
                      await _service.markAllAsRead(
                        notifications,
                      );
                    },
              icon: const Icon(
                Icons.done_all,
                size: 18,
              ),
              label: const Text(
                'Đã đọc tất cả',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: unreadCount == 0
                      ? const Color(0xffd7ded9)
                      : AppColors.primary,
                ),
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title,
              const SizedBox(height: 12),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: title),
            actions,
          ],
        );
      },
    );
  }

  Future<void> _showUpdateRequestDialog() async {
    final contentController = TextEditingController();

    List<String> projectNames = <String>[];
    String selectedProject = 'Không chọn Project';
    bool isSending = false;

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('forest_projects').get();

      projectNames = snapshot.docs
          .map((document) {
            final data = document.data();

            return (data['projectName'] ??
                    data['project'] ??
                    data['name'] ??
                    '')
                .toString()
                .trim();
          })
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    } catch (error) {
      debugPrint(
        'Không thể tải danh sách Project: $error',
      );
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, dialogSetState) {
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
                        'Gửi yêu cầu cập nhật dữ liệu',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          isSending ? null : () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          value: selectedProject,
                          isExpanded: true,
                          menuMaxHeight: 300,
                          decoration: const InputDecoration(
                            labelText: 'Project',
                            border: OutlineInputBorder(),
                          ),
                          items: <String>[
                            'Không chọn Project',
                            ...projectNames,
                          ]
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
                          onChanged: isSending
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
                          controller: contentController,
                          enabled: !isSending,
                          minLines: 4,
                          maxLines: 7,
                          decoration: const InputDecoration(
                            labelText: 'Nội dung cần cập nhật',
                            hintText:
                                'Ví dụ: Bổ sung DBH, chiều cao và số lượng cây cho Plot 01.',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Yêu cầu sẽ được gửi dưới dạng thông báo In-app.',
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
                    onPressed:
                        isSending ? null : () => Navigator.pop(dialogContext),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSending
                        ? null
                        : () async {
                            final content = contentController.text.trim();

                            if (content.isEmpty) {
                              ScaffoldMessenger.of(
                                this.context,
                              ).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Vui lòng nhập nội dung cần cập nhật.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            dialogSetState(
                              () => isSending = true,
                            );

                            final firebaseUser =
                                FirebaseAuth.instance.currentUser;

                            final requesterName =
                                firebaseUser?.displayName?.trim().isNotEmpty ==
                                        true
                                    ? firebaseUser!.displayName!.trim()
                                    : (firebaseUser?.email?.trim().isNotEmpty ==
                                            true
                                        ? firebaseUser!.email!.trim()
                                        : 'Admin Platform');

                            try {
                              await _service.createNotification(
                                title: 'Yêu cầu cập nhật dữ liệu',
                                message:
                                    '$requesterName yêu cầu cập nhật: $content',
                                type: AppNotificationType.updateRequest,
                                projectName:
                                    selectedProject == 'Không chọn Project'
                                        ? ''
                                        : selectedProject,
                              );

                              if (!mounted) return;

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }

                              ScaffoldMessenger.of(
                                this.context,
                              ).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã gửi yêu cầu cập nhật dữ liệu.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (error) {
                              if (!mounted) return;

                              dialogSetState(
                                () => isSending = false,
                              );

                              ScaffoldMessenger.of(
                                this.context,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Không thể gửi yêu cầu: $error',
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 8),
                                ),
                              );
                            }
                          },
                    icon: isSending
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_outlined,
                            size: 18,
                          ),
                    label: Text(
                      isSending ? 'Đang gửi...' : 'Gửi yêu cầu',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      contentController.dispose();
    }
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        final search = SizedBox(
          width: compact ? double.infinity : 320,
          height: 42,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm thông báo...',
              prefixIcon: const Icon(
                Icons.search,
                size: 19,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              filled: true,
              fillColor: const Color(0xfffbfcfb),
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

        final filter = SizedBox(
          width: 160,
          height: 42,
          child: DropdownButtonFormField<String>(
            value: _selectedFilter,
            isExpanded: true,
            decoration: InputDecoration(
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
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(
                value: 'all',
                child: Text('Tất cả'),
              ),
              DropdownMenuItem(
                value: 'unread',
                child: Text('Chưa đọc'),
              ),
              DropdownMenuItem(
                value: 'read',
                child: Text('Đã đọc'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedFilter = value);
            },
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              search,
              const SizedBox(height: 10),
              filter,
            ],
          );
        }

        return Row(
          children: <Widget>[
            search,
            const SizedBox(width: 12),
            filter,
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final isRead = notification.isReadBy(_service.currentUserKey);
    final visual = _notificationVisual(notification.type);

    // Card đặc biệt cho Admin: yêu cầu tạo dự án
    if (notification.type == AppNotificationType.projectApprovalRequest &&
        widget.currentUser.isAdmin) {
      return _buildApprovalCard(notification, isRead, visual);
    }

    return InkWell(
      onTap: () => _openNotification(notification),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xfff3faf5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isRead ? const Color(0xffe4ebe6) : const Color(0xffbfe0c8),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                visual.icon,
                color: visual.foreground,
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isRead ? FontWeight.w700 : FontWeight.w800,
                            color: const Color(0xff263029),
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffe8f7ed),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Mới',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff168a45),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 12.3,
                      height: 1.45,
                      color: Color(0xff5f6c64),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 10,
                    runSpacing: 5,
                    children: <Widget>[
                      _metaItem(
                        Icons.sell_outlined,
                        notificationTypeLabel(notification.type),
                      ),
                      if (notification.projectName.isNotEmpty)
                        _metaItem(
                          Icons.forest_outlined,
                          notification.projectName,
                        ),
                      _metaItem(
                        Icons.schedule,
                        _formatDateTime(notification.createdAt),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn',
              onSelected: (value) async {
                if (value == 'read') {
                  await _service.markAsRead(notification.id);
                } else if (value == 'unread') {
                  await _service.markAsUnread(notification.id);
                } else if (value == 'delete') {
                  await _service.deleteNotification(notification.id);
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                if (!isRead)
                  const PopupMenuItem(
                    value: 'read',
                    child: Text('Đánh dấu đã đọc'),
                  ),
                if (isRead)
                  const PopupMenuItem(
                    value: 'unread',
                    child: Text('Đánh dấu chưa đọc'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Xóa thông báo',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.more_horiz, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card đặc biệt cho yêu cầu duyệt project ─────────────────
  Widget _buildApprovalCard(
    AppNotification notification,
    bool isRead,
    _NotificationVisualData visual,
  ) {
    final requestId = notification.referenceId;
    final isProcessing = _processingRequests[requestId] == true;

    return FutureBuilder<String?>(
      future: _getCachedRequestStatus(requestId),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final status = snapshot.data;
        final isPending = status == 'pending' || (status == null && !isLoading);
        final isApproved = status == 'approved';
        final isRejected = status == 'rejected';

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isRead ? const Color(0xfffdf8ed) : const Color(0xfffff8e1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isApproved
                  ? const Color(0xff86c99a)
                  : isRejected
                      ? const Color(0xfff5a0a0)
                      : const Color(0xffe8b84b),
              width: 1.3,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: visual.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(visual.icon, color: visual.foreground, size: 22),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff3d2c00),
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xfffde68a),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Cần duyệt',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xff92400e),
                                  ),
                                ),
                              ),
                            if (isApproved)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xffe8f7ed),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Đã duyệt',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xff168a45),
                                  ),
                                ),
                              ),
                            if (isRejected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xffffe4e4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Đã từ chối',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xffc53d3d),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: const TextStyle(
                            fontSize: 12.3,
                            height: 1.45,
                            color: Color(0xff5f4a0a),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            _metaItem(Icons.sell_outlined,
                                notificationTypeLabel(notification.type)),
                            if (notification.projectName.isNotEmpty)
                              _metaItem(Icons.forest_outlined,
                                  notification.projectName),
                            _metaItem(Icons.schedule,
                                _formatDateTime(notification.createdAt)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Tùy chọn',
                    onSelected: (value) async {
                      if (value == 'read') {
                        await _service.markAsRead(notification.id);
                      } else if (value == 'unread') {
                        await _service.markAsUnread(notification.id);
                      } else if (value == 'delete') {
                        await _service.deleteNotification(notification.id);
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      if (!isRead)
                        const PopupMenuItem(
                            value: 'read', child: Text('Đánh dấu đã đọc')),
                      if (isRead)
                        const PopupMenuItem(
                            value: 'unread', child: Text('Đánh dấu chưa đọc')),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Xóa thông báo',
                              style: TextStyle(color: Colors.red))),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.more_horiz, size: 20),
                    ),
                  ),
                ],
              ),
              // ── Nút Chấp nhận / Từ chối (chỉ khi còn pending) ──
              if (isLoading) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xffe8d8a0)),
                const SizedBox(height: 12),
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ] else if (isPending && requestId.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xffe8d8a0)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => _handleReject(notification, requestId),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Từ chối'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xffc53d3d),
                        side: const BorderSide(color: Color(0xffc53d3d)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => _handleApprove(notification, requestId),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: Text(isProcessing ? 'Đang xử lý...' : 'Chấp nhận'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<String?> _loadRequestStatus(String requestId) async {
    if (requestId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('project_requests')
          .doc(requestId)
          .get();
      if (!doc.exists) return null;
      return doc.data()?['status']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleApprove(
    AppNotification notification,
    String requestId,
  ) async {
    setState(() => _processingRequests[requestId] = true);
    try {
      // Load request từ Firestore
      final doc = await FirebaseFirestore.instance
          .collection('project_requests')
          .doc(requestId)
          .get();
      if (!doc.exists) throw Exception('Không tìm thấy yêu cầu.');

      final request = ProjectRequest.fromFirestore(doc);
      await _requestService.approveRequest(request);
      _requestStatusCache[requestId] = Future.value('approved');
      await _service.markAsRead(notification.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Đã duyệt — dự án đã được tạo thành công!'),
            backgroundColor: Color(0xff168a45),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi duyệt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingRequests.remove(requestId));
    }
  }

  Future<void> _handleReject(
    AppNotification notification,
    String requestId,
  ) async {
    setState(() => _processingRequests[requestId] = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('project_requests')
          .doc(requestId)
          .get();
      if (!doc.exists) throw Exception('Không tìm thấy yêu cầu.');

      final request = ProjectRequest.fromFirestore(doc);
      await _requestService.rejectRequest(request);
      _requestStatusCache[requestId] = Future.value('rejected');
      await _service.markAsRead(notification.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✗ Đã từ chối yêu cầu tạo dự án.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi từ chối: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingRequests.remove(requestId));
    }
  }

  Widget _metaItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: 14,
          color: const Color(0xff89958d),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10.8,
            color: Color(0xff89958d),
          ),
        ),
      ],
    );
  }

  Future<void> _openNotification(
    AppNotification notification,
  ) async {
    if (!notification.isReadBy(_service.currentUserKey)) {
      await _service.markAsRead(notification.id);
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final visual = _notificationVisual(notification.type);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  visual.icon,
                  color: visual.foreground,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  notification.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Color(0xff3f4b44),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _detailRow(
                    'Loại thông báo',
                    notificationTypeLabel(
                      notification.type,
                    ),
                  ),
                  if (notification.projectName.isNotEmpty)
                    _detailRow(
                      'Project',
                      notification.projectName,
                    ),
                  _detailRow(
                    'Thời gian',
                    _formatDateTime(
                      notification.createdAt,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Đóng'),
            ),
            if (widget.onNotificationOpen != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  widget.onNotificationOpen!(notification);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mở nội dung'),
              ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xff7b877f),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xff2f3b34),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.notifications_off_outlined,
            size: 58,
            color: Color(0xffa2ada6),
          ),
          SizedBox(height: 10),
          Text(
            'Không có thông báo phù hợp.',
            style: TextStyle(
              color: Color(0xff6f7b74),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Không thể đọc thông báo Firebase:\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class _NotificationVisualData {
  final IconData icon;
  final Color foreground;
  final Color background;

  const _NotificationVisualData({
    required this.icon,
    required this.foreground,
    required this.background,
  });
}

_NotificationVisualData _notificationVisual(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.newLogbook:
      return const _NotificationVisualData(
        icon: Icons.menu_book_outlined,
        foreground: Color(0xff1a8f4c),
        background: Color(0xffe8f7ed),
      );
    case AppNotificationType.newFile:
      return const _NotificationVisualData(
        icon: Icons.insert_drive_file_outlined,
        foreground: Color(0xff3678bb),
        background: Color(0xffeaf3fd),
      );
    case AppNotificationType.newProject:
      return const _NotificationVisualData(
        icon: Icons.forest_outlined,
        foreground: Color(0xff168a45),
        background: Color(0xffe7f6eb),
      );
    case AppNotificationType.updateRequest:
      return const _NotificationVisualData(
        icon: Icons.edit_note_outlined,
        foreground: Color(0xffd97706),
        background: Color(0xfffff3df),
      );
    case AppNotificationType.projectApprovalRequest:
      return const _NotificationVisualData(
        icon: Icons.pending_actions_outlined,
        foreground: Color(0xffb45309),
        background: Color(0xfffff0c0),
      );
    case AppNotificationType.projectApproved:
      return const _NotificationVisualData(
        icon: Icons.check_circle_outline,
        foreground: Color(0xff168a45),
        background: Color(0xffe8f7ed),
      );
    case AppNotificationType.projectRejected:
      return const _NotificationVisualData(
        icon: Icons.cancel_outlined,
        foreground: Color(0xffc53d3d),
        background: Color(0xffffe4e4),
      );
    case AppNotificationType.workerCheckin:
      return const _NotificationVisualData(
        icon: Icons.location_on_outlined,
        foreground: Color(0xff2563eb),
        background: Color(0xffeff6ff),
      );
    case AppNotificationType.logbookEntry:
      return const _NotificationVisualData(
        icon: Icons.menu_book_outlined,
        foreground: Color(0xff0ea5e9),
        background: Color(0xfff0f9ff),
      );
    case AppNotificationType.treeData:
      return const _NotificationVisualData(
        icon: Icons.park_outlined,
        foreground: Color(0xff16a34a),
        background: Color(0xfff0fdf4),
      );
    case AppNotificationType.plotUpdate:
      return const _NotificationVisualData(
        icon: Icons.edit_location_alt_outlined,
        foreground: Color(0xffd97706),
        background: Color(0xfffef3c7),
      );
    case AppNotificationType.general:
      return const _NotificationVisualData(
        icon: Icons.notifications_none,
        foreground: Color(0xff6c5bb6),
        background: Color(0xfff0edff),
      );
  }
}
