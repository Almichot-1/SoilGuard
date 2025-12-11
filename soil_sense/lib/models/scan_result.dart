import 'package:latlong2/latlong.dart';
import 'soil_data.dart';
import 'recommendation.dart';

class ScanResult {
  final int? id;
  final SoilData soilData;
  final double areaM2;
  final double areaHa;
  final List<LatLng> gpsPoints;
  final List<Recommendation> recommendations;
  final DateTime timestamp;

  ScanResult({
    this.id,
    required this.soilData,
    required this.areaM2,
    required this.areaHa,
    required this.gpsPoints,
    required this.recommendations,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toDbMap() => {
    'avg_ph': soilData.ph,
    'avg_moisture': soilData.moisture,
    'avg_temp': soilData.temperature,
    'area_m2': areaM2,
    'area_ha': areaHa,
    'gps_points': gpsPoints.map((p) => '${p.latitude},${p.longitude}').join(';'),
    'timestamp': timestamp.toIso8601String(),
  };

  factory ScanResult.fromDb(Map<String, dynamic> map, List<Recommendation> recs) {
    final gpsString = map['gps_points'] as String? ?? '';
    final points = gpsString.isEmpty 
        ? <LatLng>[]
        : gpsString.split(';').map((s) {
            final parts = s.split(',');
            return LatLng(double.parse(parts[0]), double.parse(parts[1]));
          }).toList();

    return ScanResult(
      id: map['id'] as int?,
      soilData: SoilData(
        ph: map['avg_ph'] as double,
        moisture: map['avg_moisture'] as double,
        temperature: map['avg_temp'] as double,
      ),
      areaM2: map['area_m2'] as double,
      areaHa: map['area_ha'] as double,
      gpsPoints: points,
      recommendations: recs,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}