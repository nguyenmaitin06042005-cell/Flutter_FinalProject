import 'package:latlong2/latlong.dart';

/// Bounding box hình chữ nhật cho mỗi tỉnh thành Việt Nam.
/// Dùng để validate xem điểm vẽ có nằm trong tỉnh được chỉ định hay không.
class ProvinceBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const ProvinceBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  /// Tâm của bounding box
  LatLng get center => LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );

  /// Kiểm tra xem một điểm có nằm trong bounding box hay không
  bool contains(LatLng point) {
    return point.latitude >= minLat &&
        point.latitude <= maxLat &&
        point.longitude >= minLng &&
        point.longitude <= maxLng;
  }
}

/// Tra cứu bounding box theo tên tỉnh thành.
/// Hỗ trợ tìm kiếm không phân biệt dấu (normalize).
ProvinceBounds? getProvinceBounds(String provinceName) {
  final normalized = _normalize(provinceName);
  for (final entry in provinceBoundsMap.entries) {
    if (_normalize(entry.key) == normalized) {
      return entry.value;
    }
  }
  // Thử tìm kiếm gần đúng (chứa từ khóa)
  for (final entry in provinceBoundsMap.entries) {
    if (_normalize(entry.key).contains(normalized) ||
        normalized.contains(_normalize(entry.key))) {
      return entry.value;
    }
  }
  return null;
}

String _normalize(String s) {
  return s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      // Bỏ dấu tiếng Việt cơ bản để so sánh
      .replaceAll('đ', 'd')
      .replaceAll('Đ', 'd')
      .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
}

/// Kiểm tra xem một điểm có nằm trong tỉnh được chỉ định hay không
bool isPointInProvince(String provinceName, LatLng point) {
  final bounds = getProvinceBounds(provinceName);
  if (bounds == null) return true; // Không tìm thấy tỉnh → cho phép
  return bounds.contains(point);
}

/// Bounding box cho 63 tỉnh thành Việt Nam (gần đúng)
const Map<String, ProvinceBounds> provinceBoundsMap = {
  // ── Miền Bắc ──
  'Hà Nội': ProvinceBounds(minLat: 20.56, maxLat: 21.39, minLng: 105.28, maxLng: 106.02),
  'Hà Giang': ProvinceBounds(minLat: 22.39, maxLat: 23.39, minLng: 104.34, maxLng: 105.56),
  'Cao Bằng': ProvinceBounds(minLat: 22.39, maxLat: 23.12, minLng: 105.63, maxLng: 106.85),
  'Bắc Kạn': ProvinceBounds(minLat: 21.83, maxLat: 22.73, minLng: 105.42, maxLng: 106.19),
  'Tuyên Quang': ProvinceBounds(minLat: 21.56, maxLat: 22.72, minLng: 104.87, maxLng: 105.65),
  'Lào Cai': ProvinceBounds(minLat: 21.84, maxLat: 22.85, minLng: 103.57, maxLng: 104.64),
  'Điện Biên': ProvinceBounds(minLat: 20.98, maxLat: 22.33, minLng: 102.10, maxLng: 103.48),
  'Lai Châu': ProvinceBounds(minLat: 21.60, maxLat: 22.82, minLng: 102.33, maxLng: 103.60),
  'Sơn La': ProvinceBounds(minLat: 20.56, maxLat: 21.78, minLng: 103.26, maxLng: 105.12),
  'Yên Bái': ProvinceBounds(minLat: 21.33, maxLat: 22.24, minLng: 104.23, maxLng: 105.24),
  'Hoà Bình': ProvinceBounds(minLat: 20.31, maxLat: 21.16, minLng: 104.86, maxLng: 105.83),
  'Thái Nguyên': ProvinceBounds(minLat: 21.36, maxLat: 21.93, minLng: 105.50, maxLng: 106.18),
  'Lạng Sơn': ProvinceBounds(minLat: 21.39, maxLat: 22.27, minLng: 106.11, maxLng: 107.35),
  'Quảng Ninh': ProvinceBounds(minLat: 20.72, maxLat: 21.71, minLng: 106.42, maxLng: 108.10),
  'Bắc Giang': ProvinceBounds(minLat: 21.11, maxLat: 21.60, minLng: 105.89, maxLng: 107.03),
  'Phú Thọ': ProvinceBounds(minLat: 21.03, maxLat: 21.62, minLng: 104.78, maxLng: 105.52),
  'Vĩnh Phúc': ProvinceBounds(minLat: 21.15, maxLat: 21.56, minLng: 105.41, maxLng: 105.84),
  'Bắc Ninh': ProvinceBounds(minLat: 20.97, maxLat: 21.28, minLng: 105.88, maxLng: 106.25),
  'Hải Dương': ProvinceBounds(minLat: 20.73, maxLat: 21.13, minLng: 106.09, maxLng: 106.66),
  'Hải Phòng': ProvinceBounds(minLat: 20.60, maxLat: 21.01, minLng: 106.49, maxLng: 107.05),
  'Hưng Yên': ProvinceBounds(minLat: 20.57, maxLat: 20.93, minLng: 105.87, maxLng: 106.19),
  'Thái Bình': ProvinceBounds(minLat: 20.22, maxLat: 20.67, minLng: 106.10, maxLng: 106.65),
  'Hà Nam': ProvinceBounds(minLat: 20.33, maxLat: 20.66, minLng: 105.70, maxLng: 106.12),
  'Nam Định': ProvinceBounds(minLat: 19.96, maxLat: 20.46, minLng: 105.92, maxLng: 106.48),
  'Ninh Bình': ProvinceBounds(minLat: 19.89, maxLat: 20.43, minLng: 105.53, maxLng: 106.10),

  // ── Miền Trung ──
  'Thanh Hoá': ProvinceBounds(minLat: 19.25, maxLat: 20.67, minLng: 104.42, maxLng: 106.10),
  'Thanh Hóa': ProvinceBounds(minLat: 19.25, maxLat: 20.67, minLng: 104.42, maxLng: 106.10),
  'Nghệ An': ProvinceBounds(minLat: 18.51, maxLat: 20.02, minLng: 103.86, maxLng: 105.80),
  'Hà Tĩnh': ProvinceBounds(minLat: 17.89, maxLat: 18.77, minLng: 105.10, maxLng: 106.49),
  'Quảng Bình': ProvinceBounds(minLat: 17.37, maxLat: 18.10, minLng: 105.57, maxLng: 106.99),
  'Quảng Trị': ProvinceBounds(minLat: 16.33, maxLat: 17.10, minLng: 106.31, maxLng: 107.40),
  'Thừa Thiên Huế': ProvinceBounds(minLat: 15.97, maxLat: 16.61, minLng: 107.01, maxLng: 108.20),
  'Đà Nẵng': ProvinceBounds(minLat: 15.87, maxLat: 16.22, minLng: 107.82, maxLng: 108.35),
  'Quảng Nam': ProvinceBounds(minLat: 14.93, maxLat: 16.07, minLng: 107.16, maxLng: 108.70),
  'Quảng Ngãi': ProvinceBounds(minLat: 14.54, maxLat: 15.40, minLng: 108.04, maxLng: 109.10),
  'Bình Định': ProvinceBounds(minLat: 13.52, maxLat: 14.68, minLng: 108.30, maxLng: 109.39),
  'Phú Yên': ProvinceBounds(minLat: 12.71, maxLat: 13.55, minLng: 108.60, maxLng: 109.47),
  'Khánh Hoà': ProvinceBounds(minLat: 11.81, maxLat: 12.87, minLng: 108.46, maxLng: 109.47),
  'Khánh Hòa': ProvinceBounds(minLat: 11.81, maxLat: 12.87, minLng: 108.46, maxLng: 109.47),
  'Ninh Thuận': ProvinceBounds(minLat: 11.33, maxLat: 12.07, minLng: 108.36, maxLng: 109.14),
  'Bình Thuận': ProvinceBounds(minLat: 10.53, maxLat: 11.50, minLng: 107.39, maxLng: 108.99),

  // ── Tây Nguyên ──
  'Kon Tum': ProvinceBounds(minLat: 13.93, maxLat: 15.42, minLng: 107.35, maxLng: 108.56),
  'Gia Lai': ProvinceBounds(minLat: 13.10, maxLat: 14.56, minLng: 107.44, maxLng: 108.97),
  'Đắk Lắk': ProvinceBounds(minLat: 12.09, maxLat: 13.42, minLng: 107.28, maxLng: 108.95),
  'Đắk Nông': ProvinceBounds(minLat: 11.75, maxLat: 12.60, minLng: 107.24, maxLng: 108.13),
  'Lâm Đồng': ProvinceBounds(minLat: 11.19, maxLat: 12.34, minLng: 107.28, maxLng: 108.73),

  // ── Đông Nam Bộ ──
  'Bình Phước': ProvinceBounds(minLat: 11.22, maxLat: 12.31, minLng: 106.38, maxLng: 107.32),
  'Tây Ninh': ProvinceBounds(minLat: 10.95, maxLat: 11.60, minLng: 105.78, maxLng: 106.54),
  'Bình Dương': ProvinceBounds(minLat: 10.85, maxLat: 11.53, minLng: 106.33, maxLng: 106.97),
  'Đồng Nai': ProvinceBounds(minLat: 10.52, maxLat: 11.47, minLng: 106.54, maxLng: 107.55),
  'Bà Rịa - Vũng Tàu': ProvinceBounds(minLat: 10.05, maxLat: 10.75, minLng: 106.78, maxLng: 107.56),
  'Hồ Chí Minh': ProvinceBounds(minLat: 10.35, maxLat: 11.16, minLng: 106.36, maxLng: 107.03),
  'TP. Hồ Chí Minh': ProvinceBounds(minLat: 10.35, maxLat: 11.16, minLng: 106.36, maxLng: 107.03),

  // ── Đồng bằng sông Cửu Long ──
  'Long An': ProvinceBounds(minLat: 10.24, maxLat: 11.02, minLng: 105.72, maxLng: 106.65),
  'Tiền Giang': ProvinceBounds(minLat: 10.06, maxLat: 10.60, minLng: 105.78, maxLng: 106.68),
  'Bến Tre': ProvinceBounds(minLat: 9.80, maxLat: 10.36, minLng: 106.04, maxLng: 106.81),
  'Trà Vinh': ProvinceBounds(minLat: 9.52, maxLat: 10.08, minLng: 105.89, maxLng: 106.64),
  'Vĩnh Long': ProvinceBounds(minLat: 9.88, maxLat: 10.33, minLng: 105.72, maxLng: 106.20),
  'Đồng Tháp': ProvinceBounds(minLat: 10.10, maxLat: 10.94, minLng: 105.16, maxLng: 105.95),
  'An Giang': ProvinceBounds(minLat: 10.16, maxLat: 10.96, minLng: 104.78, maxLng: 105.63),
  'Kiên Giang': ProvinceBounds(minLat: 9.23, maxLat: 10.56, minLng: 103.43, maxLng: 105.35),
  'Cần Thơ': ProvinceBounds(minLat: 9.88, maxLat: 10.30, minLng: 105.30, maxLng: 105.85),
  'Hậu Giang': ProvinceBounds(minLat: 9.58, maxLat: 10.05, minLng: 105.39, maxLng: 105.92),
  'Sóc Trăng': ProvinceBounds(minLat: 9.20, maxLat: 9.84, minLng: 105.55, maxLng: 106.28),
  'Bạc Liêu': ProvinceBounds(minLat: 9.04, maxLat: 9.63, minLng: 105.25, maxLng: 105.89),
  'Cà Mau': ProvinceBounds(minLat: 8.56, maxLat: 9.35, minLng: 104.72, maxLng: 105.43),

  // ── Alias phổ biến (viết khác dấu) ──
  'Dak Lak': ProvinceBounds(minLat: 12.09, maxLat: 13.42, minLng: 107.28, maxLng: 108.95),
  'Dắk Lắk': ProvinceBounds(minLat: 12.09, maxLat: 13.42, minLng: 107.28, maxLng: 108.95),
  'Đăk Lăk': ProvinceBounds(minLat: 12.09, maxLat: 13.42, minLng: 107.28, maxLng: 108.95),
  'Dak Nong': ProvinceBounds(minLat: 11.75, maxLat: 12.60, minLng: 107.24, maxLng: 108.13),
  'Lam Dong': ProvinceBounds(minLat: 11.19, maxLat: 12.34, minLng: 107.28, maxLng: 108.73),
  'Phu Yen': ProvinceBounds(minLat: 12.71, maxLat: 13.55, minLng: 108.60, maxLng: 109.47),
  'Nghe An': ProvinceBounds(minLat: 18.51, maxLat: 20.02, minLng: 103.86, maxLng: 105.80),
  'Quang Tri': ProvinceBounds(minLat: 16.33, maxLat: 17.10, minLng: 106.31, maxLng: 107.40),
  'Quang Nam': ProvinceBounds(minLat: 14.93, maxLat: 16.07, minLng: 107.16, maxLng: 108.70),
  'Gia Lai ': ProvinceBounds(minLat: 13.10, maxLat: 14.56, minLng: 107.44, maxLng: 108.97),
};
