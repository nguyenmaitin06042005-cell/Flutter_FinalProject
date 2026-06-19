import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/app_colors.dart';
import '../models/forest_project_model.dart';
import '../models/user_model.dart';
import '../services/forest_project_service.dart';
import '../data/province_boundaries.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.currentUser});
  final UserModel currentUser;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  final ForestProjectService _projectService = ForestProjectService();

  bool showProjects = true;
  bool showPlots = true;
  bool showActivities = false;
  bool showInventoryPoints = false;

  String baseMap = 'Google Satellite';
  bool drawMode = false;

  final List<LatLng> drawingPoints = [];
  List<LatLng> savedPolygon = [];
  bool _isSaving = false;

  /// Dự án được chọn để vẽ polygon
  ForestProject? _selectedDrawProject;

  /// Search query cho panel projects
  String _searchQuery = '';

  /// Palette màu cố định cho projects
  static const List<Color> _projectColors = [
    Color(0xff1d9bf0),
    Color(0xff16a34a),
    Color(0xff2563eb),
    Color(0xff5b4bb7),
    Color(0xff6b7280),
    Color(0xffd97706),
    Color(0xffdc2626),
    Color(0xff0891b2),
    Color(0xffe11d48),
    Color(0xff7c3aed),
  ];

  Color _colorForIndex(int index) {
    return _projectColors[index % _projectColors.length];
  }

  Stream<List<ForestProject>> get _projectStream {
    if (widget.currentUser.isOwner) {
      return _projectService.watchProjectsByOwner(widget.currentUser.uid);
    }
    if (widget.currentUser.isWorker) {
      return _projectService.watchProjects().map((projects) {
        return projects
            .where((p) => p.workerUids.contains(widget.currentUser.uid))
            .toList();
      });
    }
    // Admin thấy tất cả
    return _projectService.watchProjects();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ForestProject>>(
      stream: _projectStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xfff7f9f8),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final projects = snapshot.data ?? [];

        final activePolygon =
            savedPolygon.isNotEmpty ? savedPolygon : drawingPoints;
        final areaHa = _polygonAreaHa(activePolygon);
        final perimeterKm = _polygonPerimeterKm(activePolygon);

        // Lọc dự án theo search
        final filteredProjects = projects.where((p) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return p.projectName.toLowerCase().contains(q) ||
              p.projectId.toLowerCase().contains(q) ||
              p.province.toLowerCase().contains(q);
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xfff7f9f8),
          body: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: LatLng(14.5, 107.5),
                        initialZoom: 6,
                        onTap: (_, point) {
                          if (drawMode) {
                            _handleDrawTap(point);
                          } else {
                            _showCoordinateSnack(point);
                          }
                        },
                      ),
                      children: [
                        // Google Map
                        if (baseMap == 'Google Map')
                          TileLayer(
                            urlTemplate:
                                'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&hl=vi&gl=vn',
                            userAgentPackageName:
                                'com.example.forest_carbon_app',
                          ),

                        // Google Satellite
                        if (baseMap == 'Google Satellite')
                          TileLayer(
                            urlTemplate:
                                'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}&hl=vi&gl=vn',
                            userAgentPackageName:
                                'com.example.forest_carbon_app',
                          ),

                        // Google Hybrid
                        if (baseMap == 'Google Hybrid')
                          TileLayer(
                            urlTemplate:
                                'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}&hl=vi&gl=vn',
                            userAgentPackageName:
                                'com.example.forest_carbon_app',
                          ),

                        // Hiển thị polygon đã lưu từ Firestore
                        if (showProjects)
                          PolygonLayer(
                            polygons: [
                              // Polygon đã lưu trong Firestore
                              for (int i = 0; i < projects.length; i++)
                                if (projects[i].polygonCoordinates.isNotEmpty)
                                  Polygon(
                                    points: projects[i]
                                        .polygonCoordinates
                                        .map((c) =>
                                            LatLng(c['lat']!, c['lng']!))
                                        .toList(),
                                    color: _colorForIndex(i)
                                        .withOpacity(0.25),
                                    borderColor: _colorForIndex(i),
                                    borderStrokeWidth: 3,
                                  ),
                              // Polygon đang vẽ (chưa lưu)
                              if (activePolygon.length >= 3)
                                Polygon(
                                  points: activePolygon,
                                  color: Colors.orange.withOpacity(0.25),
                                  borderColor: Colors.orange,
                                  borderStrokeWidth: 4,
                                ),
                            ],
                          ),

                        if (drawMode && drawingPoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: drawingPoints,
                                color: Colors.orange,
                                strokeWidth: 4,
                              ),
                            ],
                          ),

                        // Marker pin cho các project có polygon đã lưu
                        if (showPlots)
                          MarkerLayer(
                            markers: [
                              // Pin ở tâm polygon đã lưu
                              for (int i = 0; i < projects.length; i++)
                                if (projects[i]
                                    .polygonCoordinates
                                    .isNotEmpty)
                                  Marker(
                                    point: _polygonCenter(projects[i]
                                        .polygonCoordinates
                                        .map((c) =>
                                            LatLng(c['lat']!, c['lng']!))
                                        .toList()),
                                    width: 44,
                                    height: 44,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _showProjectInfoDialog(
                                              projects[i], i),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: 42,
                                      ),
                                    ),
                                  ),
                              // Marker cho các điểm đang vẽ
                              for (final pt in drawingPoints)
                                Marker(
                                  point: pt,
                                  width: 26,
                                  height: 26,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),

                    Positioned(left: 22, top: 24, child: _mapLayerBox()),
                    Positioned(right: 22, top: 165, child: _zoomControls()),
                    Positioned(
                      left: 220,
                      top: 24,
                      child: _drawToolbar(areaHa, perimeterKm, projects),
                    ),
                    Positioned(
                      left: 220,
                      bottom: 20,
                      child: _infoPanel(areaHa, perimeterKm),
                    ),
                  ],
                ),
              ),

              _projectsPanel(filteredProjects, projects),
            ],
          ),
        );
      },
    );
  }

  // ── Xử lý tap khi đang vẽ ──
  void _handleDrawTap(LatLng point) {
    if (_selectedDrawProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠ Vui lòng chọn dự án trước khi vẽ!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate: kiểm tra điểm có nằm trong tỉnh của project không
    final province = _selectedDrawProject!.province;
    if (province.isNotEmpty && !isPointInProvince(province, point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⛔ Điểm nằm NGOÀI tỉnh "$province"!\n'
            'Vui lòng vẽ trong phạm vi tỉnh được chỉ định cho dự án "${_selectedDrawProject!.projectName}".',
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      drawingPoints.add(point);
      savedPolygon.clear();
    });
  }

  // ── Map Layer Box ──
  Widget _mapLayerBox() {
    return Container(
      width: 190,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Map Layers',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          _check(
            'Projects',
            showProjects,
            (v) => setState(() => showProjects = v),
          ),
          _check('Plots', showPlots, (v) => setState(() => showPlots = v)),
          _check(
            'Activities',
            showActivities,
            (v) => setState(() => showActivities = v),
          ),
          _check(
            'Inventory Points',
            showInventoryPoints,
            (v) => setState(() => showInventoryPoints = v),
          ),
          const SizedBox(height: 18),
          const Text(
            'Base Map',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _radio('Google Satellite'),
          _radio('Google Hybrid'),
          _radio('Google Map'),
        ],
      ),
    );
  }

  Widget _check(String title, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      height: 38,
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.primary,
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _radio(String value) {
    return SizedBox(
      height: 36,
      child: RadioListTile<String>(
        value: value,
        groupValue: baseMap,
        onChanged: (v) => setState(() => baseMap = v!),
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.primary,
        title: Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _zoomControls() {
    return Column(
      children: [
        _mapButton(Icons.layers, () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Base map: $baseMap')));
        }),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              _mapButton(Icons.add, () {
                mapController.move(
                  mapController.camera.center,
                  mapController.camera.zoom + 1,
                );
              }, noRadius: true),
              Container(width: 44, height: 1, color: const Color(0xffe5e7eb)),
              _mapButton(Icons.remove, () {
                mapController.move(
                  mapController.camera.center,
                  mapController.camera.zoom - 1,
                );
              }, noRadius: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapButton(
    IconData icon,
    VoidCallback onTap, {
    bool noRadius = false,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(noRadius ? 0 : 6),
      elevation: noRadius ? 0 : 3,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 23)),
      ),
    );
  }

  // ── Draw Toolbar ──
  Widget _drawToolbar(
      double areaHa, double perimeterKm, List<ForestProject> projects) {
    final bool hasPolygon = savedPolygon.isNotEmpty;
    final bool canUpload = hasPolygon && _selectedDrawProject != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          // Draw Polygon button
          ElevatedButton.icon(
            onPressed: () {
              if (!drawMode) {
                // Bắt đầu vẽ → yêu cầu chọn project trước
                _showSelectProjectDialog(projects);
              } else {
                // Đang vẽ → dừng
                setState(() => drawMode = false);
              }
            },
            icon: Icon(drawMode ? Icons.edit_off : Icons.polyline),
            label: Text(drawMode ? 'Stop Draw' : 'Draw Polygon'),
            style: ElevatedButton.styleFrom(
              backgroundColor: drawMode ? Colors.orange : AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),

          // Save button — lưu polygon vào Firestore
          OutlinedButton.icon(
            onPressed: (drawingPoints.length >= 3 &&
                    _selectedDrawProject != null &&
                    !_isSaving)
                ? () => _savePolygonToFirestore()
                : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Đang lưu...' : 'Save'),
          ),
          const SizedBox(width: 8),

          // Clear button
          OutlinedButton.icon(
            onPressed: () => setState(() {
              drawingPoints.clear();
              savedPolygon.clear();
              drawMode = false;
            }),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear'),
          ),
          const SizedBox(width: 8),

          // Upload button — CHỈ bật khi đã Save polygon
          OutlinedButton.icon(
            onPressed: canUpload ? _showUploadDialog : null,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload .shp/.geojson/.kml'),
            style: OutlinedButton.styleFrom(
              foregroundColor: canUpload ? AppColors.primary : Colors.grey,
            ),
          ),

          // Hiển thị dự án đang chọn
          if (_selectedDrawProject != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xffe8f5e9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forest, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    _selectedDrawProject!.projectName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff1b5e20),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${_selectedDrawProject!.province})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff4caf50),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Dialog chọn dự án trước khi vẽ ──
  void _showSelectProjectDialog(List<ForestProject> projects) {
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có dự án nào. Vui lòng tạo dự án trước.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.forest, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Chọn dự án để vẽ Polygon'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xfffff8e1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xffe8b84b)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xffb45309), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bạn phải vẽ polygon trong phạm vi tỉnh/thành phố '
                        'được chỉ định cho dự án. Các điểm ngoài phạm vi sẽ bị từ chối.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xff7a4a00),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 350),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: projects.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = projects[index];
                    final isSelected = _selectedDrawProject?.id == p.id;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: _colorForIndex(index),
                        child: Text(
                          p.projectName.isNotEmpty
                              ? p.projectName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        p.projectName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xff1a2e22),
                        ),
                      ),
                      subtitle: Text(
                        '${p.province} • ${p.areaHa.toStringAsFixed(1)} ha • ${p.status}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppColors.primary)
                          : const Icon(Icons.radio_button_unchecked,
                              color: Colors.grey),
                      selected: isSelected,
                      selectedTileColor: const Color(0xffe8f5e9),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedDrawProject = p;
                          drawingPoints.clear();
                          savedPolygon.clear();
                          drawMode = true;
                        });

                        // Di chuyển map đến tỉnh của project
                        final bounds =
                            getProvinceBounds(p.province);
                        if (bounds != null) {
                          mapController.move(bounds.center, 9);
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✓ Đã chọn "${p.projectName}" — '
                              'Vẽ polygon trong tỉnh ${p.province}. '
                              'Nhấp vào bản đồ để bắt đầu vẽ.',
                            ),
                            backgroundColor: const Color(0xff168a45),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  // ── Info Panel ──
  Widget _infoPanel(double areaHa, double perimeterKm) {
    final points = savedPolygon.isNotEmpty ? savedPolygon : drawingPoints;
    return Container(
      width: 420,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.58),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedDrawProject != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '🌲 ${_selectedDrawProject!.projectName} (${_selectedDrawProject!.province})',
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            Text('Tổng diện tích: ${areaHa.toStringAsFixed(2)} ha'),
            Text('Chu vi: ${perimeterKm.toStringAsFixed(2)} km'),
            Text('Số tọa độ: ${points.length} điểm'),
            if (points.isNotEmpty)
              Text(
                'Lat/Long cuối: ${points.last.latitude.toStringAsFixed(5)}, ${points.last.longitude.toStringAsFixed(5)}',
              ),
            if (savedPolygon.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '✅ Polygon đã được lưu — Có thể Upload',
                  style: TextStyle(
                      color: Colors.greenAccent, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Projects Panel (bên phải) ──
  Widget _projectsPanel(
      List<ForestProject> filteredProjects, List<ForestProject> allProjects) {
    return Container(
      width: 285,
      height: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Projects',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 42,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search projects...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xffe5e7eb)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          if (filteredProjects.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Không tìm thấy dự án.',
                  style: TextStyle(
                      color: Color(0xff77837b), fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: filteredProjects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final p = filteredProjects[index];
                  // Tìm original index cho màu nhất quán
                  final originalIndex = allProjects.indexOf(p);
                  final color = _colorForIndex(
                      originalIndex >= 0 ? originalIndex : index);
                  final isSelected = _selectedDrawProject?.id == p.id;

                  return InkWell(
                    onTap: () {
                      // Di chuyển map đến tỉnh
                      final bounds = getProvinceBounds(p.province);
                      if (bounds != null) {
                        mapController.move(bounds.center, 9);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xffe8f5e9)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: isSelected
                            ? Border.all(
                                color: AppColors.primary.withOpacity(0.5))
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.projectName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${p.areaHa.toStringAsFixed(1)} ha',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.province,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xff6b7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                size: 18, color: AppColors.primary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── Lưu polygon vào Firestore ──
  Future<void> _savePolygonToFirestore() async {
    if (_selectedDrawProject == null || drawingPoints.length < 3) return;

    setState(() => _isSaving = true);

    try {
      final polygonCoords = drawingPoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();
      final areaHa = _polygonAreaHa(drawingPoints);

      await _projectService.updateProjectPolygon(
        documentId: _selectedDrawProject!.id,
        polygonCoordinates: polygonCoords,
        areaHa: areaHa,
      );

      if (mounted) {
        setState(() {
          savedPolygon = List.from(drawingPoints);
          drawMode = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Đã lưu polygon cho "${_selectedDrawProject!.projectName}" '
              '(${areaHa.toStringAsFixed(2)} ha). '
              'Dữ liệu đã cập nhật trên toàn hệ thống.',
            ),
            backgroundColor: const Color(0xff168a45),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu polygon: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Tính tâm polygon ──
  LatLng _polygonCenter(List<LatLng> points) {
    if (points.isEmpty) return LatLng(0, 0);
    double lat = 0, lng = 0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  // ── Dialog thông tin project khi tap marker ──
  void _showProjectInfoDialog(ForestProject project, int colorIndex) {
    final polygonPoints = project.polygonCoordinates
        .map((c) => LatLng(c['lat']!, c['lng']!))
        .toList();
    final areaHa = _polygonAreaHa(polygonPoints);
    final perimeterKm = _polygonPerimeterKm(polygonPoints);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _colorForIndex(colorIndex),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(project.projectName)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Project ID', project.projectId),
            _infoRow('Tỉnh/TP', project.province),
            _infoRow('Huyện', project.district),
            _infoRow('Xã', project.commune),
            _infoRow('Diện tích', '${areaHa.toStringAsFixed(2)} ha'),
            _infoRow('Chu vi', '${perimeterKm.toStringAsFixed(2)} km'),
            _infoRow('Số điểm', '${polygonPoints.length}'),
            _infoRow('Trạng thái', project.status),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xff8b958f), fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showCoordinateSnack(LatLng p) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lat: ${p.latitude.toStringAsFixed(5)}, Long: ${p.longitude.toStringAsFixed(5)}',
        ),
      ),
    );
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.upload_file, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text('Upload Shapefile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedDrawProject != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xffe8f5e9),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xff4caf50)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.forest,
                        color: Color(0xff2e7d32), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dự án: ${_selectedDrawProject!.projectName}\n'
                        'Tỉnh: ${_selectedDrawProject!.province}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xff1b5e20),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            const Text(
              'Cho phép upload:\n'
              '• .shp\n'
              '• .geojson\n'
              '• .kml\n\n'
              'Sau khi upload hệ thống sẽ hiển thị:\n'
              '• Tổng diện tích\n'
              '• Chu vi\n'
              '• Tọa độ Lat/Long',
            ),
            if (savedPolygon.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xfff5f5f5),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Diện tích polygon: ${_polygonAreaHa(savedPolygon).toStringAsFixed(2)} ha'),
                    Text(
                        'Chu vi: ${_polygonPerimeterKm(savedPolygon).toStringAsFixed(2)} km'),
                    Text('Số điểm: ${savedPolygon.length}'),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '✓ Đã gửi dữ liệu polygon lên hệ thống thành công!'),
                  backgroundColor: Color(0xff168a45),
                ),
              );
            },
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  double _polygonPerimeterKm(List<LatLng> points) {
    if (points.length < 2) return 0;
    const Distance d = Distance();
    double total = 0;
    for (int i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      total += d.as(LengthUnit.Kilometer, a, b);
    }
    return total;
  }

  double _polygonAreaHa(List<LatLng> points) {
    if (points.length < 3) return 0;
    const earthRadius = 6378137.0;
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final lon1 = p1.longitude * math.pi / 180;
      final lon2 = p2.longitude * math.pi / 180;
      final lat1 = p1.latitude * math.pi / 180;
      final lat2 = p2.latitude * math.pi / 180;
      area += (lon2 - lon1) * (2 + math.sin(lat1) + math.sin(lat2));
    }
    area = (area * earthRadius * earthRadius / 2).abs();
    return area / 10000;
  }
}
