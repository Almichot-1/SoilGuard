class Crop {
  final String name;
  final String nameAm;
  final double phMin;
  final double phMax;
  final double phOptimal;
  final double moistureMin;
  final double moistureMax;
  final double moistureOptimal;
  final double tempMin;
  final double tempMax;
  final double tempOptimal;
  final double seedRateKgPerHa;
  final int rowSpacingCm;
  final int plantSpacingCm;
  final int growingDays;
  final String description;
  final String plantingTips;

  Crop({
    required this.name,
    required this.nameAm,
    required this.phMin,
    required this.phMax,
    required this.phOptimal,
    required this.moistureMin,
    required this.moistureMax,
    required this.moistureOptimal,
    required this.tempMin,
    required this.tempMax,
    required this.tempOptimal,
    required this.seedRateKgPerHa,
    required this.rowSpacingCm,
    required this.plantSpacingCm,
    required this.growingDays,
    required this.description,
    required this.plantingTips,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      name: json['name'] as String,
      nameAm: json['name_am'] as String? ?? json['name'] as String,
      phMin: (json['ph_min'] as num).toDouble(),
      phMax: (json['ph_max'] as num).toDouble(),
      phOptimal: (json['ph_optimal'] as num).toDouble(),
      moistureMin: (json['moisture_min'] as num).toDouble(),
      moistureMax: (json['moisture_max'] as num).toDouble(),
      moistureOptimal: (json['moisture_optimal'] as num).toDouble(),
      tempMin: (json['temp_min'] as num).toDouble(),
      tempMax: (json['temp_max'] as num).toDouble(),
      tempOptimal: (json['temp_optimal'] as num).toDouble(),
      seedRateKgPerHa: (json['seed_rate_kg_per_ha'] as num).toDouble(),
      rowSpacingCm: json['row_spacing_cm'] as int,
      plantSpacingCm: json['plant_spacing_cm'] as int,
      growingDays: json['growing_days'] as int,
      description: json['description'] as String? ?? '',
      plantingTips: json['planting_tips'] as String? ?? '',
    );
  }
}