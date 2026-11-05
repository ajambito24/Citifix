import 'package:latlong2/latlong.dart' show LatLng;

/// Returns true when [point] is inside [polygon] (ray casting).
/// Works with the closed rings used in sampaloc_boundary.dart.
bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;

  final x = point.longitude;
  final y = point.latitude;
  var inside = false;

  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude;
    final yi = polygon[i].latitude;
    final xj = polygon[j].longitude;
    final yj = polygon[j].latitude;

    final crosses = (yi > y) != (yj > y) &&
        x < (xj - xi) * (y - yi) / (yj - yi) + xi;

    if (crosses) inside = !inside;
  }

  return inside;
}