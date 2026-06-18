// lib/pages/auth/create_user_page.dart
// Trang dành riêng cho Admin tạo tài khoản mới

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/app_colors.dart';

class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _userService = UserService();

  UserRole _selectedRole = UserRole.owner;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMsg;
  bool _success = false;
  String _createdEmail = '';

  List<UserModel> _owners = [];
  String? _selectedOwnerId;

  @override
  void initState() {
    super.initState();
    _loadOwners();
  }

  Future<void> _loadOwners() async {
    final owners = await _userService.getOwners();
    if (mounted) {
      setState(() => _owners = owners);
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedRole == UserRole.worker && _selectedOwnerId == null) {
      setState(() => _errorMsg = 'Vui lòng chọn Forest Owner quản lý Worker này');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      if (adminUser == null) throw Exception('Không tìm thấy phiên admin');

      final adminUid = adminUser.uid;
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;

      // ==========================================================
      // SỬ DỤNG FIREBASE SECONDARY APP ĐỂ KHÔNG BỊ LOGOUT ADMIN
      // ==========================================================
      FirebaseApp? tempApp;
      try {
        tempApp = Firebase.app('TempAuthApp');
      } catch (e) {
        // Khởi tạo app phụ nếu chưa có
        tempApp = await Firebase.initializeApp(
          name: 'TempAuthApp',
          options: Firebase.app().options,
        );
      }

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      // Tạo user Firebase Auth mới trên app phụ
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );

      final newUser = credential.user!;

      // Lưu Firestore bằng App chính (admin auth)
      final userModel = UserModel(
        uid: newUser.uid,
        email: email,
        fullName: _fullNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _selectedRole,
        status: UserStatus.active,
        createdAt: DateTime.now(),
        createdBy: adminUid,
        password: password, // Lưu mật khẩu vào Firestore
        ownerId: _selectedRole == UserRole.worker ? _selectedOwnerId : null,
      );
      await _userService.createUser(userModel);

      // Đăng xuất app phụ để dọn dẹp
      await tempAuth.signOut();

      _createdEmail = email;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _success = true;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _success ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.lightGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.primary, size: 56),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tạo tài khoản thành công!',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _infoRow(Icons.person_outline, _fullNameCtrl.text),
              const SizedBox(height: 6),
              _infoRow(Icons.email_outlined, _createdEmail),
              const SizedBox(height: 6),
              _infoRow(Icons.badge_outlined, _getRoleLabel(_selectedRole)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đóng',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(color: AppColors.text, fontSize: 13)),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tạo tài khoản mới',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Điền thông tin để tạo tài khoản người dùng',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.muted, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Flexible(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chọn Role
                  const Text(
                    'Phân hệ người dùng *',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildRoleCard(
                        UserRole.owner,
                        Icons.nature_people_outlined,
                        'Forest Owner',
                        'Quản lý dự án rừng',
                        const Color(0xff0d7bc4),
                      ),
                      const SizedBox(width: 10),
                      _buildRoleCard(
                        UserRole.worker,
                        Icons.hiking_outlined,
                        'Forest Worker',
                        'Nhân viên hiện trường',
                        const Color(0xff7b5ea7),
                      ),
                    ],
                  ),
                  
                  if (_selectedRole == UserRole.worker) ...[
                    const SizedBox(height: 16),
                    _buildOwnerSelector(),
                  ],
                  
                  const SizedBox(height: 20),

                  // Họ tên
                  _buildLabel('Họ và tên *'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _fullNameCtrl,
                    hint: 'Nguyễn Văn A',
                    icon: Icons.person_outline,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập họ tên'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Điện thoại
                  _buildLabel('Số điện thoại *'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _phoneCtrl,
                    hint: '0901234567',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 9)
                        ? 'Số điện thoại không hợp lệ'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Email
                  _buildLabel('Email *'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _emailCtrl,
                    hint: 'example@email.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng nhập email';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v))
                        return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Mật khẩu
                  _buildLabel('Mật khẩu tạm thời *'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _passwordCtrl,
                    hint: 'Ít nhất 6 ký tự',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.muted,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mật khẩu ít nhất 6 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // Lỗi
                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade600, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Nút tạo
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.muted,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleCreate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Tạo tài khoản',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard(
    UserRole role,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.08) : AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isSelected ? color : AppColors.muted, size: 22),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? color : AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
          color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: AppColors.muted, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.bg,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Platform Admin';
      case UserRole.worker:
        return 'Forest Worker';
      default:
        return 'Forest Owner';
    }
  }

  Widget _buildOwnerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn Forest Owner quản lý',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedOwnerId,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.business_center_rounded, color: AppColors.muted, size: 18),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          hint: const Text('  -- Chọn Owner --  '),
          items: _owners.map((owner) {
            return DropdownMenuItem(
              value: owner.uid,
              child: Text('${owner.fullName} (${owner.email})', style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedOwnerId = val;
            });
          },
        ),
      ],
    );
  }
}
