import 'crop.dart';

class Recommendation {
  final Crop crop;
  final double suitabilityPercent;
  final double seedKg;
  final int plantCount;
  final double areaHa;

  Recommendation({
    required this.crop,
    required this.suitabilityPercent,
    required this.seedKg,
    required this.plantCount,
    required this.areaHa,
  });

  String get spacing => '${crop.rowSpacingCm} × ${crop.plantSpacingCm} cm';

  Map<String, dynamic> toJson() => {
    'crop_name': crop.name,
    'suitability_percent': suitabilityPercent.round(),
    'seed_kg': seedKg,
    'spacing_cm': spacing,
    'plant_count': plantCount,
  };
}