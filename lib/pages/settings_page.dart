import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_colors.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class SettingsPage extends StatefulWidget {
  final UserModel userModel;
  const SettingsPage({super.key, required this.userModel});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPwd = _currentPwdCtrl.text;
    final newPwd = _newPwdCtrl.text;

    if (currentPwd.isEmpty || newPwd.isEmpty) {
      _showSnack('Vui lòng nhập đầy đủ thông tin.', isError: true);
      return;
    }

    if (newPwd.length < 6) {
      _showSnack('Mật khẩu mới phải có ít nhất 6 ký tự.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Xác thực lại bằng mật khẩu hiện tại
        final cred = EmailAuthProvider.credential(
            email: user.email!, password: currentPwd);
        await user.reauthenticateWithCredential(cred);

        // Đổi mật khẩu Firebase Auth
        await user.updatePassword(newPwd);
        
        // Lưu mật khẩu vào Firestore theo yêu cầu
        await UserService().updateUser(user.uid, {'password': newPwd});

        if (mounted) {
          _showSnack('Cập nhật mật khẩu thành công!', isError: false);
          _currentPwdCtrl.clear();
          _newPwdCtrl.clear();
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Lỗi đổi mật khẩu.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Mật khẩu hiện tại không đúng.';
      }
      _showSnack(msg, isError: true);
    } catch (e) {
      _showSnack('Lỗi: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cài đặt & Hồ sơ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff17211b),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quản lý thông tin cá nhân và bảo mật tài khoản',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.muted.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 30),
            
            // Grid layout for large screens
            Wrap(
              spacing: 32,
              runSpacing: 32,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                // PHẦN 1: THÔNG TIN TÀI KHOẢN
                _buildCard(
                  title: 'Thông tin cá nhân',
                  icon: Icons.badge_rounded,
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.person_rounded, 'Họ tên', widget.userModel.fullName),
                      const Divider(height: 32, color: AppColors.border),
                      if (widget.userModel.role != UserRole.admin) ...[
                        _buildInfoRow(Icons.badge_outlined, 'Mã ID', widget.userModel.employeeId ?? 'Chưa cập nhật'),
                        const Divider(height: 32, color: AppColors.border),
                      ],
                      _buildInfoRow(Icons.email_rounded, 'Email', widget.userModel.email),
                      const Divider(height: 32, color: AppColors.border),
                      _buildInfoRow(Icons.phone_rounded, 'Số điện thoại', widget.userModel.phone),
                      const Divider(height: 32, color: AppColors.border),
                      _buildInfoRow(Icons.admin_panel_settings_rounded, 'Vai trò', _getRoleLabel(widget.userModel.role)),
                    ],
                  ),
                ),

                // PHẦN 2: ĐỔI MẬT KHẨU
                _buildCard(
                  title: 'Bảo mật',
                  icon: Icons.shield_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _currentPwdCtrl,
                        label: 'Mật khẩu hiện tại',
                        icon: Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _newPwdCtrl,
                        label: 'Mật khẩu mới',
                        icon: Icons.lock_reset_rounded,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading 
                              ? const SizedBox(
                                  width: 24, 
                                  height: 24, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                                )
                              : const Text(
                                  'Cập nhật mật khẩu', 
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: 480,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(32),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.muted.withValues(alpha: 0.6)),
        const SizedBox(width: 16),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(color: AppColors.muted.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'Chưa cập nhật',
            style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.8)),
        prefixIcon: Icon(icon, color: AppColors.muted.withValues(alpha: 0.6), size: 20),
        filled: true,
        fillColor: AppColors.bg.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Platform Admin';
      case UserRole.owner:
        return 'Forest Owner';
      case UserRole.worker:
        return 'Forest Worker';
    }
  }
}
