import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'data/menu_data.dart';
import 'pages/dashboard_page.dart';
import 'pages/forest_owners_page.dart';
import 'pages/forest_projects_page.dart' as forest_projects_page;
import 'pages/map_page.dart';
import 'pages/forest_inventory_page.dart';
import 'pages/forest_logbook_page.dart';
import 'pages/carbon_calculation_page.dart';
import 'pages/reports_page.dart';
import 'pages/files_page.dart';
import 'widgets/sidebar.dart';
import 'widgets/app_colors.dart';
import 'pages/users_page.dart';
import 'pages/notifications_page.dart' as notifications_page;
import 'pages/settings_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/setup_admin_page.dart';
import 'models/user_model.dart';
import 'models/menu_item_model.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ForestCarbonApp());
}

class ForestCarbonApp extends StatelessWidget {
  const ForestCarbonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý Carbon Rừng',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE — Kiểm tra trạng thái hệ thống + đăng nhập
// ============================================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _hasAnyUser() async {
    final snap =
        await FirebaseFirestore.instance.collection('users').limit(1).get();
    return snap.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final currentUser = authSnapshot.data;

        // ── Chưa đăng nhập ────────────────────────────────────
        if (currentUser == null) {
          return FutureBuilder<bool>(
            future: _hasAnyUser(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingScreen();
              }
              final hasUser = snapshot.data ?? false;
              if (!hasUser) return const SetupAdminPage();
              return const LoginPage();
            },
          );
        }

        // ── Đã đăng nhập → kiểm tra userModel ─────────────────
        return _UserModelLoader(uid: currentUser.uid);
      },
    );
  }
}

/// Tách FutureBuilder ra widget riêng để tránh tạo future mới mỗi build
class _UserModelLoader extends StatefulWidget {
  final String uid;
  const _UserModelLoader({required this.uid});

  @override
  State<_UserModelLoader> createState() => _UserModelLoaderState();
}

class _UserModelLoaderState extends State<_UserModelLoader> {
  late Future<UserModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = UserService().getUser(widget.uid);
  }

  @override
  void didUpdateWidget(_UserModelLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _future = UserService().getUser(widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _future,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        if (!userSnapshot.hasData || userSnapshot.data == null) {
          return const LoginPage();
        }
        final userModel = userSnapshot.data!;

        // Fallback an toàn: nếu worker lọt qua (không thể xảy ra bình thường)
        if (userModel.role == UserRole.worker) {
          FirebaseAuth.instance.signOut();
          return const _LoadingScreen();
        }

        return MainLayout(userModel: userModel);
      },
    );
  }
}

// ============================================================
// LOADING SCREEN
// ============================================================
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.forest_rounded,
                size: 48,
                color: AppColors.primary2,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quản lý Carbon Rừng',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MAIN LAYOUT — Sau khi đăng nhập thành công
// ============================================================
class MainLayout extends StatefulWidget {
  final UserModel userModel;
  const MainLayout({super.key, required this.userModel});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int selectedIndex = 0;

  List<MenuItemModel> _filteredMenus = [];
  List<Widget> _filteredPages = [];

  @override
  void initState() {
    super.initState();
    _buildMenuForRole();
  }

  void _openNotificationsPage() {
    final notificationIndex = _filteredMenus.indexWhere(
      (menu) => menu.title == 'Notifications',
    );

    if (notificationIndex < 0 || !mounted) {
      return;
    }

    setState(() {
      selectedIndex = notificationIndex;
    });
  }

  void _buildMenuForRole() {
    // Định nghĩa tất cả các trang
    final allItems = [
      {
        'menu': menus[0],
        'page': DashboardPage(
          currentUser: widget.userModel,
          onOpenNotifications: _openNotificationsPage,
        ),
      }, // Dashboard
      {'menu': menus[1], 'page': const ForestOwnersPage()}, // Forest Owners
      {
        'menu': menus[2],
        'page': forest_projects_page.ForestProjectsPage(
          currentUser: widget.userModel,
        )
      }, // Forest Projects
      {'menu': menus[3], 'page': MapPage(currentUser: widget.userModel)}, // Map
      {
        'menu': menus[4],
        'page': ForestInventoryPage(currentUser: widget.userModel)
      }, // Forest Inventory
      {
        'menu': menus[5],
        'page': ForestLogbookPage(currentUser: widget.userModel),
      }, // Forest Logbook
      {
        'menu': menus[6],
        'page': CarbonCalculationPage(currentUser: widget.userModel)
      }, // Carbon Calculation
      {'menu': menus[7], 'page': ReportsPage(currentUser: widget.userModel)}, // Reports
      {'menu': menus[8], 'page': const FilesPage()}, // Files
      {'menu': menus[9], 'page': const UsersPage()}, // Users
      {
        'menu': menus[10],
        'page': notifications_page.NotificationsPage(
          currentUser: widget.userModel,
        )
      }, // Notifications
      {
        'menu': menus[11],
        'page': SettingsPage(userModel: widget.userModel)
      }, // Settings
    ];

    _filteredMenus.clear();
    _filteredPages.clear();

    for (var item in allItems) {
      final menu = item['menu'] as MenuItemModel;
      final page = item['page'] as Widget;

      // Phân quyền
      if (widget.userModel.role == UserRole.owner) {
        // Owner KHÔNG được xem: Forest Owners
        if (menu.title == 'Forest Owners') {
          continue; // Bỏ qua
        }
      } else if (widget.userModel.role == UserRole.worker) {
        // Worker có thể bị giới hạn nhiều hơn nữa, tạm ẩn giống Owner
        if (menu.title == 'Forest Owners' ||
            menu.title == 'Users' ||
            menu.title == 'Dashboard' ||
            menu.title == 'Reports') {
          continue;
        }
      }

      _filteredMenus.add(menu);
      _filteredPages.add(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            menus: _filteredMenus,
            selectedIndex: selectedIndex,
            onSelected: (index) => setState(() => selectedIndex = index),
            currentUser: widget.userModel,
          ),
          Expanded(child: _filteredPages[selectedIndex]),
        ],
      ),
    );
  }
}
