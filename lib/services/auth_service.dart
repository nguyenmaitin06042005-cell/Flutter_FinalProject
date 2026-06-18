// lib/services/auth_service.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ============================================================
  // ĐĂNG NHẬP
  // ============================================================
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      // ============================================================
      // PRE-CHECK: Kiểm tra role từ Firestore TRƯỚC khi sign in
      // → Worker bị chặn trước khi authStateChanges kịp fire
      // → AuthGate không nhận được sự kiện login → không nhấp nháy
      // ============================================================
      final preCheckSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (preCheckSnap.docs.isNotEmpty) {
        final data = preCheckSnap.docs.first.data();
        final role = data['role'] as String?;
        if (role == UserRole.worker.name) {
          return AuthResult.error(
            'Tài khoản Worker không được đăng nhập trên web.\nVui lòng sử dụng ứng dụng di động.',
          );
        }
      }

      // ── Thực hiện đăng nhập Firebase ──────────────────────────
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) return AuthResult.error('Đăng nhập thất bại');

      // Kiểm tra trạng thái tài khoản trong Firestore
      final userModel = await _userService.getUser(user.uid);
      if (userModel == null) {
        await _auth.signOut();
        return AuthResult.error('Không tìm thấy thông tin tài khoản.');
      }

      // Fallback: chặn worker nếu pre-check bị bỏ qua
      if (userModel.role == UserRole.worker) {
        await _auth.signOut();
        return AuthResult.error(
          'Tài khoản Worker không được đăng nhập trên web.\nVui lòng sử dụng ứng dụng di động.',
        );
      }

      if (userModel.status == UserStatus.locked) {
        await _auth.signOut();
        return AuthResult.error(
          'Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.',
        );
      }

      try {
        if (userModel.status != UserStatus.locked) {
          await _userService.updateStatus(user.uid, UserStatus.active);
        }
        await _userService.updateUser(user.uid, {'password': password});
      } catch (e) {
        // Bỏ qua lỗi cập nhật nếu có để không gián đoạn login
      }

      return AuthResult.success(user, userModel);
    } on FirebaseAuthException catch (e) {
      // Phân biệt email chưa đăng ký vs sai mật khẩu
      // → dùng kết quả Firestore pre-check (đã query ở trên)
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password') {
        // Kiểm tra email trong Firestore (đáng tin hơn fetchSignInMethodsForEmail)
        final firestoreSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();

        if (firestoreSnap.docs.isEmpty) {
          // Email không có trong Firestore → chưa tạo tài khoản
          return AuthResult.error(
            'Email này chưa được đăng ký tài khoản.\nVui lòng liên hệ quản trị viên để tạo tài khoản.',
          );
        }
        // Email có trong Firestore → sai mật khẩu
        return AuthResult.error('Mật khẩu không đúng. Vui lòng thử lại.');
      }
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Đã xảy ra lỗi: ${e.toString()}');
    }
  }

  /// Kiểm tra xem email có tồn tại trong Firebase Auth không
  Future<bool> _checkEmailExists(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (_) {
      // Nếu không kiểm tra được, mặc định coi là tồn tại
      return true;
    }
  }


  // ============================================================
  // ĐĂNG KÝ (Người dùng tự đăng ký)
  // ============================================================
  Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final newUser = credential.user;
      if (newUser == null) return AuthResult.error('Không thể tạo tài khoản');

      final userModel = UserModel(
        uid: newUser.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        phone: phone.trim(),
        role: UserRole.owner, // Default role
        status: UserStatus.inactive,
        createdAt: DateTime.now(),
        createdBy: 'self',
      );
      await _userService.createUser(userModel);

      return AuthResult.success(newUser, userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Lỗi tạo tài khoản: ${e.toString()}');
    }
  }

  // ============================================================
  // TẠO TÀI KHOẢN (Chỉ Admin thực hiện)
  // Dùng secondary app để tránh đăng xuất admin hiện tại
  // ============================================================
  Future<AuthResult> adminCreateUser({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    required String adminUid,
  }) async {
    try {
      // Tạo secondary FirebaseAuth instance để không đăng xuất admin
      final secondaryApp = await FirebaseAuth.instanceFor(
        app: FirebaseAuth.instance.app,
      );

      // Dùng REST API của Firebase để tạo user mà không ảnh hưởng session hiện tại
      // Cách đơn giản: tạo trực tiếp bằng Auth nhưng restore lại session
      final currentUser = _auth.currentUser;

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final newUser = credential.user;
      if (newUser == null) return AuthResult.error('Không thể tạo tài khoản');

      // Lưu vào Firestore ngay
      final userModel = UserModel(
        uid: newUser.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        phone: phone.trim(),
        role: role,
        status: UserStatus.inactive,
        createdAt: DateTime.now(),
        createdBy: adminUid,
      );
      await _userService.createUser(userModel);

      // Đăng xuất user mới tạo, đăng nhập lại admin
      await _auth.signOut();

      // Admin cần đăng nhập lại — app sẽ redirect về login
      // Trả về success với thông tin user mới
      return AuthResult.success(newUser, userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Lỗi tạo tài khoản: ${e.toString()}');
    }
  }

  // ============================================================
  // TẠO TÀI KHOẢN BẰNG FIREBASE ADMIN (không logout admin)
  // Sử dụng cách an toàn hơn
  // ============================================================
  Future<AuthResult> createUserByAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    required String adminUid,
    required String adminEmail,
    required String adminPassword,
  }) async {
    try {
      // Lưu credentials admin
      final adminCurrentUser = _auth.currentUser;

      // Tạo user mới
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final newUser = credential.user;
      if (newUser == null) return AuthResult.error('Không thể tạo tài khoản');

      // Lưu Firestore
      final userModel = UserModel(
        uid: newUser.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        phone: phone.trim(),
        role: role,
        status: UserStatus.inactive,
        createdAt: DateTime.now(),
        createdBy: adminUid,
      );
      await _userService.createUser(userModel);

      // Đăng xuất user mới và đăng nhập lại admin
      await _auth.signOut();
      await _auth.signInWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      return AuthResult.success(newUser, userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Lỗi: ${e.toString()}');
    }
  }

  // ============================================================
  // ĐĂNG XUẤT
  // ============================================================
  Future<void> logout() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userModel = await _userService.getUser(user.uid);
      if (userModel != null && userModel.status != UserStatus.locked) {
        await _userService.updateStatus(user.uid, UserStatus.inactive);
      }
    }
    await _auth.signOut();
  }

  // ============================================================
  // XÓA TÀI KHOẢN HOÀN TOÀN TỪ AUTH VÀ FIRESTORE
  // ============================================================
  Future<void> deleteUserAccount(UserModel user) async {
    try {
      if (user.password != null && user.password!.isNotEmpty) {
        final tempApp = await Firebase.initializeApp(
          name: 'TempDeleteApp_${DateTime.now().millisecondsSinceEpoch}',
          options: Firebase.app().options,
        );
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

        try {
          final credential = await tempAuth.signInWithEmailAndPassword(
            email: user.email,
            password: user.password!,
          );
          await credential.user?.delete();
        } catch (e) {
          // Ignored if wrong password or other error
        } finally {
          await tempApp.delete();
        }
      }
    } catch (e) {
      // Ignored
    }

    // Luôn xoá khỏi Firestore
    await _userService.deleteUser(user.uid);
  }

  // ============================================================
  // QUÊN MẬT KHẨU
  // ============================================================
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null, null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('Không thể gửi email: ${e.toString()}');
    }
  }

  // ============================================================
  // LẤY THÔNG TIN USER HIỆN TẠI TỪ FIRESTORE
  // ============================================================
  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await _userService.getUser(user.uid);
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email này chưa được đăng ký tài khoản.\nVui lòng liên hệ quản trị viên để tạo tài khoản.';
      case 'wrong-password':
        return 'Mật khẩu không đúng. Vui lòng thử lại.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng dùng ít nhất 6 ký tự.';
      case 'invalid-email':
        return 'Địa chỉ email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng thử lại sau.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Kiểm tra lại internet.';
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';
      default:
        return 'Đã xảy ra lỗi ($code). Vui lòng thử lại.';
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;
  final UserModel? userModel;

  const AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.user,
    this.userModel,
  });

  factory AuthResult.success(User? user, UserModel? userModel) =>
      AuthResult._(isSuccess: true, user: user, userModel: userModel);

  factory AuthResult.error(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}
