import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scan_result.dart';
import '../utils/constants.dart';
import '../widgets/crop_recommendation_card.dart';
import '../widgets/live_map_widget.dart';

class ResultsScreen extends StatefulWidget {
  final ScanResult result;

  const ResultsScreen({super.key, required this.result});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  int _expandedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Results'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top recommendation banner
            if (result.recommendations.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Recommendation',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${result.recommendations.first.crop.name} • ${result.recommendations.first.suitabilityPercent.toStringAsFixed(0)}% suitability',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy Summary',
                      icon: const Icon(Icons.copy, color: Colors.green),
                      onPressed: () async {
                        final top = result.recommendations.first;
                        final areaText = result.areaHa < 1
                            ? '${result.areaM2.toStringAsFixed(0)} m²'
                            : '${result.areaHa.toStringAsFixed(3)} ha';
                        final summary =
                            'Field Area: $areaText\nTop Crop: ${top.crop.name} (${top.suitabilityPercent.toStringAsFixed(0)}%)\nSeed: ${top.seedKg.toStringAsFixed(2)} kg\nSpacing: ${top.spacing}\nPlants: ${top.plantCount}';
                        await Clipboard.setData(ClipboardData(text: summary));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Summary copied to clipboard')),
                        );
                      },
                    )
                  ],
                ),
              ),
            // Map preview
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  LiveMapWidget(
                    trackPoints: result.gpsPoints,
                    currentLocation: result.gpsPoints.isNotEmpty 
                        ? result.gpsPoints.first 
                        : null,
                  ),
                  // Area overlay
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.square_foot, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            result.areaHa < 1
                                ? '${result.areaM2.toStringAsFixed(0)} m²'
                                : '${result.areaHa.toStringAsFixed(3)} ha',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Soil data summary
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SoilDataItem(
                    icon: Icons.water_drop,
                    label: 'pH',
                    value: result.soilData.ph.toStringAsFixed(1),
                  ),
                  Container(height: 40, width: 1, color: Colors.white30),
                  _SoilDataItem(
                    icon: Icons.opacity,
                    label: 'Moisture',
                    value: '${result.soilData.moisture.toStringAsFixed(0)}%',
                  ),
                  Container(height: 40, width: 1, color: Colors.white30),
                  _SoilDataItem(
                    icon: Icons.thermostat,
                    label: 'Temp',
                    value: '${result.soilData.temperature.toStringAsFixed(0)}°C',
                  ),
                ],
              ),
            ),
            
            // Recommendations header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.recommend, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Recommended Crops',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Recommendation cards
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: result.recommendations.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CropRecommendationCard(
                    recommendation: result.recommendations[index],
                    rank: index + 1,
                    isExpanded: _expandedIndex == index,
                    onTap: () {
                      setState(() {
                        _expandedIndex = _expandedIndex == index ? -1 : index;
                      });
                    },
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Done button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text(
                    'Done',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoilDataItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SoilDataItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}