import 'dart:math';
import 'package:latlong2/latlong.dart';

class AreaCalculator {
  /// Calculate area using Shoelace formula
  /// Returns area in square meters
  static double calculateAreaM2(List<LatLng> points) {
    if (points.length < 3) return 0.0;

    // Convert to meters using approximate conversion
    // 1 degree latitude ≈ 111,320 meters
    // 1 degree longitude ≈ 111,320 * cos(latitude) meters
    
    final centerLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final latToM = 111320.0;
    final lngToM = 111320.0 * cos(centerLat * pi / 180);

    // Convert points to meters from first point
    final metersPoints = points.map((p) => [
      (p.latitude - points[0].latitude) * latToM,
      (p.longitude - points[0].longitude) * lngToM,
    ]).toList();

    // Shoelace formula
    double area = 0.0;
    for (int i = 0; i < metersPoints.length; i++) {
      int j = (i + 1) % metersPoints.length;
      area += metersPoints[i][0] * metersPoints[j][1];
      area -= metersPoints[j][0] * metersPoints[i][1];
    }

    return (area.abs() / 2.0);
  }

  /// Convert square meters to hectares
  static double m2ToHectares(double m2) {
    return m2 / 10000.0;
  }

  /// Calculate perimeter in meters
  static double calculatePerimeter(List<LatLng> points) {
    if (points.length < 2) return 0.0;

    const distance = Distance();
    double perimeter = 0.0;

    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;
      perimeter += distance.as(LengthUnit.Meter, points[i], points[j]);
    }

    return perimeter;
  }
}