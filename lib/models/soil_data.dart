class SoilData {
  final double ph;
  final double moisture;
  final double temperature;
  final DateTime timestamp;

  SoilData({
    required this.ph,
    required this.moisture,
    required this.temperature,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SoilData.fromJson(Map<String, dynamic> json) {
    return SoilData(
      ph: (json['ph'] as num).toDouble(),
      moisture: (json['moisture'] as num).toDouble(),
      temperature: (json['temp'] ?? json['temperature'] as num).toDouble(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ph': ph,
    'moisture': moisture,
    'temp': temperature,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Calculate average of multiple soil samples
  static SoilData average(List<SoilData> samples) {
    if (samples.isEmpty) {
      return SoilData(ph: 0, moisture: 0, temperature: 0);
    }
    
    double totalPh = 0;
    double totalMoisture = 0;
    double totalTemp = 0;
    
    for (final sample in samples) {
      totalPh += sample.ph;
      totalMoisture += sample.moisture;
      totalTemp += sample.temperature;
    }
    
    final count = samples.length;
    return SoilData(
      ph: double.parse((totalPh / count).toStringAsFixed(2)),
      moisture: double.parse((totalMoisture / count).toStringAsFixed(1)),
      temperature: double.parse((totalTemp / count).toStringAsFixed(1)),
    );
  }

  @override
  String toString() => 'SoilData(pH: $ph, Moisture: $moisture%, Temp: $temperature°C)';
}