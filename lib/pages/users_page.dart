// lib/pages/users_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_colors.dart';
import '../widgets/app_header.dart';
import 'auth/create_user_page.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _UsersPageContent();
  }
}

class _UsersPageContent extends StatefulWidget {
  const _UsersPageContent();

  @override
  State<_UsersPageContent> createState() => _UsersPageContentState();
}

class _UsersPageContentState extends State<_UsersPageContent> {
  final _userService = UserService();
  final _authService = AuthService();
  String _searchQuery = '';
  UserModel? _currentUserModel;
  bool _loadingCurrentUser = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final model = await _authService.getCurrentUserModel();
    if (mounted) {
      setState(() {
        _currentUserModel = model;
        _loadingCurrentUser = false;
      });
    }
  }

  bool get _isAdmin => _currentUserModel?.isAdmin ?? false;

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: _loadingCurrentUser
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isAdmin ? 'Quản lý Tài khoản' : 'Nhân sự của tôi',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff17211b),
                            ),
                          ),
                          // Optional: keep logout logic inside AppHeader previously, 
                          // but wait, logout was in top bar. 
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildTopBar(),
                      const SizedBox(height: 16),
                      Expanded(child: _buildUserTable()),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        // Search
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm theo tên, email, điện thoại...',
              hintStyle: TextStyle(
                  color: AppColors.muted.withValues(alpha: 0.6), fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.muted, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Nút tạo tài khoản (chỉ admin)
        if (_isAdmin) ...[
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _openCreateUser,
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Tạo tài khoản'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openCreateUser() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateUserPage(),
    );
    // Reload current user state sau khi dialog đóng (vì có thể bị signout)
    _loadCurrentUser();
  }

  Widget _buildUserTable() {
    return StreamBuilder<List<UserModel>>(
      stream: _isAdmin 
          ? _userService.getAllUsers() 
          : _userService.getWorkersForOwner(_currentUserModel!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (snapshot.hasError) {
          return _buildError('${snapshot.error}');
        }

        final allUsers = snapshot.data ?? [];
        final users = _searchQuery.isEmpty
            ? allUsers
            : allUsers.where((u) {
                final q = _searchQuery.toLowerCase();
                return u.fullName.toLowerCase().contains(q) ||
                    u.email.toLowerCase().contains(q) ||
                    u.phone.contains(q);
              }).toList();

        if (users.isEmpty) {
          return _buildEmpty();
        }

        return Column(
          children: [
            _buildTableHeader(),
            Expanded(
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) => _buildUserRow(users[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: const Row(
        children: [
          Expanded(flex: 3, child: _HeaderCell('Họ và tên')),
          Expanded(flex: 3, child: _HeaderCell('Email')),
          Expanded(flex: 2, child: _HeaderCell('Điện thoại')),
          Expanded(flex: 2, child: _HeaderCell('Phân hệ')),
          Expanded(flex: 2, child: _HeaderCell('Trạng thái')),
          SizedBox(width: 60, child: _HeaderCell('...')),
        ],
      ),
    );
  }

  Widget _buildUserRow(UserModel user) {
    final isCurrentUser =
        user.uid == FirebaseAuth.instance.currentUser?.uid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Tên + Avatar
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _buildAvatar(user),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isCurrentUser)
                        const Text(
                          'Tài khoản của bạn',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Email
          Expanded(
            flex: 3,
            child: Text(
              user.email,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Phone
          Expanded(
            flex: 2,
            child: Text(user.phone,
                style:
                    const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),

          // Role badge
          Expanded(flex: 2, child: _buildRoleBadge(user.role)),

          // Status
          Expanded(flex: 2, child: _buildStatusBadge(user)),

          // Actions
          SizedBox(
            width: 60,
            child:
                (_isAdmin && !isCurrentUser) ? _buildActions(user) : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    Color avatarColor;
    switch (user.role) {
      case UserRole.admin:
        avatarColor = const Color(0xffe8f5e9);
        break;
      case UserRole.worker:
        avatarColor = const Color(0xffede7f6);
        break;
      default:
        avatarColor = const Color(0xffe3f2fd);
    }

    Color textColor;
    switch (user.role) {
      case UserRole.admin:
        textColor = AppColors.primary;
        break;
      case UserRole.worker:
        textColor = const Color(0xff7b5ea7);
        break;
      default:
        textColor = const Color(0xff0d7bc4);
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: avatarColor,
      child: Text(
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
        style: TextStyle(
            color: textColor, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    late Color bg, fg;
    late IconData icon;
    late String label;

    switch (role) {
      case UserRole.admin:
        bg = const Color(0xffe8f5e9);
        fg = AppColors.primary;
        icon = Icons.admin_panel_settings_outlined;
        label = 'Admin';
        break;
      case UserRole.worker:
        bg = const Color(0xffede7f6);
        fg = const Color(0xff7b5ea7);
        icon = Icons.hiking_outlined;
        label = 'Worker';
        break;
      default:
        bg = const Color(0xffe3f2fd);
        fg = const Color(0xff0d7bc4);
        icon = Icons.nature_people_outlined;
        label = 'Owner';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(UserModel user) {
    Color bg, fg;
    IconData icon;

    switch (user.status) {
      case UserStatus.locked:
        bg = Colors.red.shade50;
        fg = Colors.red.shade600;
        icon = Icons.lock_outline;
        break;
      case UserStatus.inactive:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        icon = Icons.pause_circle_outline;
        break;
      default:
        bg = AppColors.lightGreen;
        fg = AppColors.primary;
        icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            user.statusLabel,
            style: TextStyle(
                color: fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(UserModel user) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded,
          color: AppColors.muted, size: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (value) async {
        switch (value) {
          case 'lock':
            await _userService.updateStatus(user.uid, UserStatus.locked);
            break;
          case 'unlock':
            await _userService.updateStatus(user.uid, UserStatus.active);
            break;
          case 'delete':
            // Show confirmation dialog before deleting
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Xóa tài khoản'),
                content: Text('Bạn có chắc chắn muốn xóa tài khoản ${user.email}?\nHành động này không thể hoàn tác.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Xóa'),
                  ),
                ],
              ),
            );
            
            if (confirm == true) {
              await _authService.deleteUserAccount(user);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa tài khoản thành công')),
                );
              }
            }
            break;
          case 'promote_owner':
            await _userService.updateRole(user.uid, UserRole.owner);
            break;
          case 'promote_worker':
            await _userService.updateRole(user.uid, UserRole.worker);
            break;
        }
      },
      itemBuilder: (_) => [
        // Role actions
        if (user.role != UserRole.owner)
          const PopupMenuItem(
            value: 'promote_owner',
            child: Row(children: [
              Icon(Icons.nature_people_outlined,
                  size: 16, color: Color(0xff0d7bc4)),
              SizedBox(width: 8),
              Text('Đổi → Forest Owner'),
            ]),
          ),
        if (user.role != UserRole.worker)
          const PopupMenuItem(
            value: 'promote_worker',
            child: Row(children: [
              Icon(Icons.hiking_outlined,
                  size: 16, color: Color(0xff7b5ea7)),
              SizedBox(width: 8),
              Text('Đổi → Forest Worker'),
            ]),
          ),
        const PopupMenuDivider(),
        // Status actions
        if (user.status != UserStatus.locked)
          PopupMenuItem(
            value: 'lock',
            child: Row(children: [
              Icon(Icons.lock_outline, size: 16, color: Colors.red.shade500),
              const SizedBox(width: 8),
              const Text('Khóa tài khoản'),
            ]),
          ),
        if (user.status == UserStatus.locked)
          const PopupMenuItem(
            value: 'unlock',
            child: Row(children: [
              Icon(Icons.lock_open_rounded,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Mở khóa'),
            ]),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 16, color: Colors.red),
            SizedBox(width: 8),
            Text('Xóa tài khoản', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
          const SizedBox(height: 16),
          Text('Lỗi: $msg',
              style: TextStyle(color: Colors.red.shade600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              color: AppColors.muted.withValues(alpha: 0.4), size: 64),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'Chưa có tài khoản nào'
                : 'Không tìm thấy kết quả',
            style: const TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          if (_searchQuery.isEmpty && _isAdmin) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openCreateUser,
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Tạo tài khoản đầu tiên'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}
