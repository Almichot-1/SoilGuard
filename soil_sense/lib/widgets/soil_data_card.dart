import 'package:flutter/material.dart';
import '../models/soil_data.dart';
import '../utils/constants.dart';

class SoilDataCard extends StatelessWidget {
  final SoilData? soilData;
  final int sampleCount;

  const SoilDataCard({
    super.key,
    this.soilData,
    this.sampleCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Soil Data',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$sampleCount samples',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (soilData == null)
              const Center(
                child: Text(
                  'Waiting for sensor data...',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Row(
                children: [
                  _DataItem(
                    icon: Icons.water_drop,
                    label: 'pH',
                    value: soilData!.ph.toStringAsFixed(1),
                    color: AppColors.phColor,
                  ),
                  _DataItem(
                    icon: Icons.opacity,
                    label: 'Moisture',
                    value: '${soilData!.moisture.toStringAsFixed(0)}%',
                    color: AppColors.moistureColor,
                  ),
                  _DataItem(
                    icon: Icons.thermostat,
                    label: 'Temp',
                    value: '${soilData!.temperature.toStringAsFixed(0)}°C',
                    color: AppColors.tempColor,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DataItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DataItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}