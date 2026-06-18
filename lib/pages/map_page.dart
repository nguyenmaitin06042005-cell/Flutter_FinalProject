import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/app_colors.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();

  bool showProjects = true;
  bool showPlots = true;
  bool showActivities = false;
  bool showInventoryPoints = false;

  String baseMap = 'Google Satellite';
  bool drawMode = false;

  final List<LatLng> drawingPoints = [];
  List<LatLng> savedPolygon = [];

  final List<Map<String, dynamic>> projects = [
    {
      'name': 'Dak Lak Project 01',
      'area': '1,250.50 ha',
      'color': const Color(0xff1d9bf0),
      'point': LatLng(12.7100, 108.2378),
      'polygon': [
        LatLng(12.86, 108.04),
        LatLng(12.98, 108.15),
        LatLng(12.95, 108.34),
        LatLng(12.78, 108.42),
        LatLng(12.63, 108.27),
        LatLng(12.66, 108.10),
      ],
    },
    {
      'name': 'Lam Dong Project 02',
      'area': '980.75 ha',
      'color': const Color(0xff16a34a),
      'point': LatLng(11.9404, 108.4583),
      'polygon': [
        LatLng(12.92, 108.48),
        LatLng(13.02, 108.66),
        LatLng(12.91, 108.84),
        LatLng(12.72, 108.78),
        LatLng(12.66, 108.58),
      ],
    },
    {
      'name': 'Gia Lai Project 01',
      'area': '1,530.30 ha',
      'color': const Color(0xff2563eb),
      'point': LatLng(13.0500, 108.6200),
      'polygon': [
        LatLng(12.42, 108.43),
        LatLng(12.55, 108.62),
        LatLng(12.45, 108.87),
        LatLng(12.23, 108.83),
        LatLng(12.15, 108.55),
      ],
    },
    {
      'name': 'Quang Tri Project 01',
      'area': '760.40 ha',
      'color': const Color(0xff5b4bb7),
      'point': LatLng(12.3600, 108.6500),
      'polygon': null,
    },
    {
      'name': 'Quang Nam Project 01',
      'area': '660.20 ha',
      'color': const Color(0xff6b7280),
      'point': LatLng(12.5200, 107.8400),
      'polygon': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final activePolygon = savedPolygon.isNotEmpty
        ? savedPolygon
        : drawingPoints;
    final areaHa = _polygonAreaHa(activePolygon);
    final perimeterKm = _polygonPerimeterKm(activePolygon);

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
                    initialCenter: LatLng(12.7, 108.35),
                    initialZoom: 8,
                    onTap: (_, point) {
                      if (drawMode) {
                        setState(() {
                          drawingPoints.add(point);
                          savedPolygon.clear();
                        });
                      } else {
                        _showCoordinateSnack(point);
                      }
                    },
                  ),
                  children: [
                    // Google Map: bản đồ đường phố (Google Maps Roadmap)
                    if (baseMap == 'Google Map')
                      TileLayer(
                        urlTemplate:
                            'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&hl=vi&gl=vn',
                        userAgentPackageName: 'com.example.forest_carbon_app',
                      ),

                    // Google Satellite: bản đồ vệ tinh (Google Maps Satellite)
                    if (baseMap == 'Google Satellite')
                      TileLayer(
                        urlTemplate:
                            'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}&hl=vi&gl=vn',
                        userAgentPackageName: 'com.example.forest_carbon_app',
                      ),

                    // Google Hybrid: vệ tinh + đường/địa danh (Google Maps Hybrid)
                    if (baseMap == 'Google Hybrid')
                      TileLayer(
                        urlTemplate:
                            'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}&hl=vi&gl=vn',
                        userAgentPackageName: 'com.example.forest_carbon_app',
                      ),

                    if (showProjects)
                      PolygonLayer(
                        polygons: [
                          for (final p in projects)
                            if (p['polygon'] != null)
                              Polygon(
                                points: List<LatLng>.from(p['polygon']),
                                color: (p['color'] as Color).withOpacity(0.25),
                                borderColor: p['color'] as Color,
                                borderStrokeWidth: 3,
                              ),
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

                    if (showPlots)
                      MarkerLayer(
                        markers: [
                          for (final p in projects)
                            Marker(
                              point: p['point'] as LatLng,
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () {
                                  _showProjectDialog(p);
                                },
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 42,
                                ),
                              ),
                            ),
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
                  child: _drawToolbar(areaHa, perimeterKm),
                ),
                Positioned(
                  left: 220,
                  bottom: 20,
                  child: _infoPanel(areaHa, perimeterKm),
                ),
              ],
            ),
          ),

          _projectsPanel(),
        ],
      ),
    );
  }

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

  Widget _drawToolbar(double areaHa, double perimeterKm) {
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
          ElevatedButton.icon(
            onPressed: () => setState(() => drawMode = !drawMode),
            icon: Icon(drawMode ? Icons.edit_off : Icons.polyline),
            label: Text(drawMode ? 'Stop Draw' : 'Draw Polygon'),
            style: ElevatedButton.styleFrom(
              backgroundColor: drawMode ? Colors.orange : AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: drawingPoints.length >= 3
                ? () => setState(() {
                    savedPolygon = List.from(drawingPoints);
                    drawMode = false;
                  })
                : null,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
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
          OutlinedButton.icon(
            onPressed: _showUploadDialog,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload .shp/.geojson/.kml'),
          ),
        ],
      ),
    );
  }

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
            Text('Tổng diện tích: ${areaHa.toStringAsFixed(2)} ha'),
            Text('Chu vi: ${perimeterKm.toStringAsFixed(2)} km'),
            Text('Số tọa độ: ${points.length} điểm'),
            if (points.isNotEmpty)
              Text(
                'Lat/Long cuối: ${points.last.latitude.toStringAsFixed(5)}, ${points.last.longitude.toStringAsFixed(5)}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _projectsPanel() {
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
          Expanded(
            child: ListView.separated(
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final p = projects[index];
                return InkWell(
                  onTap: () => mapController.move(p['point'] as LatLng, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: p['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              p['area'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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

  void _showProjectDialog(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p['name']),
        content: Text(
          'Area: ${p['area']}\nLat: ${(p['point'] as LatLng).latitude}\nLong: ${(p['point'] as LatLng).longitude}',
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

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Upload Shapefile'),
        content: const Text(
          'Cho phép upload:\n'
          '• .shp\n'
          '• .geojson\n'
          '• .kml\n\n'
          'Sau khi upload hệ thống sẽ hiển thị:\n'
          '• Tổng diện tích\n'
          '• Chu vi\n'
          '• Tọa độ Lat/Long',
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
