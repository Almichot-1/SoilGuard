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

  /// Build a Recommendation from a DB row.
  /// Expects keys: crop_name, suitability_percent, seed_kg, spacing_cm, plant_count.
  /// spacing_cm format: `row × plant cm`.
  factory Recommendation.fromDb(Map<String, dynamic> row, {double areaHa = 0.0}) {
    final cropName = row['crop_name'] as String? ?? 'Unknown';
    final suitability = (row['suitability_percent'] as num?)?.toDouble() ?? 0.0;
    final seed = (row['seed_kg'] as num?)?.toDouble() ?? 0.0;
    final plants = (row['plant_count'] as num?)?.toInt() ?? 0;
    final spacingStr = (row['spacing_cm'] as String?) ?? '';

    int rowSpacing = 0;
    int plantSpacing = 0;
    try {
      // Parse formats like "75 × 30 cm" or "20 x 5 cm"
      final cleaned = spacingStr.replaceAll('cm', '').trim();
      final parts = cleaned.split(RegExp(r'[×x]'));
      if (parts.length >= 2) {
        rowSpacing = int.tryParse(parts[0].trim()) ?? 0;
        plantSpacing = int.tryParse(parts[1].trim()) ?? 0;
      }
    } catch (_) {}

    // Create a lightweight Crop for display purposes.
    final displayCrop = Crop(
      name: cropName,
      nameAm: cropName,
      phMin: 0,
      phMax: 0,
      phOptimal: 0,
      moistureMin: 0,
      moistureMax: 0,
      moistureOptimal: 0,
      tempMin: 0,
      tempMax: 0,
      tempOptimal: 0,
      seedRateKgPerHa: 0,
      rowSpacingCm: rowSpacing,
      plantSpacingCm: plantSpacing,
      growingDays: 0,
      description: '',
      plantingTips: '',
    );

    return Recommendation(
      crop: displayCrop,
      suitabilityPercent: suitability,
      seedKg: seed,
      plantCount: plants,
      areaHa: areaHa,
    );
  }
}