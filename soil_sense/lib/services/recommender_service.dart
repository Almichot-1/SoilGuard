import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/crop.dart';
import '../models/soil_data.dart';
import '../models/recommendation.dart';

class RecommenderService {
  List<Crop> _crops = [];
  
  List<Crop> get crops => List.unmodifiable(_crops);
  bool get isLoaded => _crops.isNotEmpty;

  /// Load crops from JSON asset
  Future<void> loadCrops() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/crops.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final cropList = jsonData['crops'] as List<dynamic>;
      
      _crops = cropList.map((c) => Crop.fromJson(c as Map<String, dynamic>)).toList();
      // Prefer debugPrint over print in production code
      debugPrint('Loaded ${_crops.length} crops');
    } catch (e) {
      debugPrint('Error loading crops: $e');
      _crops = [];
    }
  }

  /// Calculate suitability score for a crop given soil conditions
  double _calculateScore(Crop crop, SoilData soil) {
    // pH score (40% weight)
    double phScore = _rangeScore(
      soil.ph, 
      crop.phMin, 
      crop.phMax, 
      crop.phOptimal,
    );
    
    // Moisture score (40% weight)
    double moistureScore = _rangeScore(
      soil.moisture,
      crop.moistureMin,
      crop.moistureMax,
      crop.moistureOptimal,
    );
    
    // Temperature score (20% weight)
    double tempScore = _rangeScore(
      soil.temperature,
      crop.tempMin,
      crop.tempMax,
      crop.tempOptimal,
    );
    
    // Weighted average
    return (phScore * 0.4 + moistureScore * 0.4 + tempScore * 0.2) * 100;
  }

  /// Calculate how well a value fits within a range
  double _rangeScore(double value, double min, double max, double optimal) {
    if (value < min || value > max) {
      // Outside range - calculate penalty
      if (value < min) {
        double distance = min - value;
        double range = max - min;
        return math.max(0, 1 - (distance / range));
      } else {
        double distance = value - max;
        double range = max - min;
        return math.max(0, 1 - (distance / range));
      }
    }
    
    // Within range - calculate how close to optimal
    double distanceFromOptimal = (value - optimal).abs();
    double maxDistance = math.max((optimal - min).abs(), (max - optimal).abs());
    
    if (maxDistance == 0) return 1.0;
    
    return 1 - (distanceFromOptimal / maxDistance) * 0.3; // Max 30% penalty for being at edges
  }

  /// Generate recommendations for given soil data and area
  List<Recommendation> getRecommendations(SoilData soil, double areaHa) {
    if (_crops.isEmpty) return [];

    // Calculate scores for all crops
    List<MapEntry<Crop, double>> scored = _crops
        .map((crop) => MapEntry(crop, _calculateScore(crop, soil)))
        .toList();
    
    // Sort by score descending
    scored.sort((a, b) => b.value.compareTo(a.value));
    
    // Take top 3
    return scored.take(3).map((entry) {
      final crop = entry.key;
      final score = entry.value;
      
      // Calculate planting requirements
      final seedKg = crop.seedRateKgPerHa * areaHa;
      final areaM2 = areaHa * 10000;
      final plantSpaceM2 = (crop.rowSpacingCm / 100) * (crop.plantSpacingCm / 100);
      final plantCount = (areaM2 / plantSpaceM2).round();
      
      return Recommendation(
        crop: crop,
        suitabilityPercent: score.clamp(0, 100),
        seedKg: double.parse(seedKg.toStringAsFixed(2)),
        plantCount: plantCount,
        areaHa: areaHa,
      );
    }).toList();
  }
}