import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import '../services/ble_service.dart';
import '../services/gps_service.dart';
import '../services/recommender_service.dart';
import '../services/db_service.dart';
import '../models/soil_data.dart';
import '../models/scan_result.dart';
import '../utils/area_calculator.dart';
import '../utils/constants.dart';
import '../widgets/live_map_widget.dart';
import '../widgets/soil_data_card.dart';
import 'results_screen.dart';

enum ScanState { ready, scanning, processing, complete }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  ScanState _scanState = ScanState.ready;
  Timer? _scanTimer;
  int _elapsedSeconds = 0;
  final MapController _mapController = MapController();
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeServices() async {
    final gpsService = context.read<GpsService>();
    await gpsService.initialize();
  }

  void _startScan() async {
    final gpsService = context.read<GpsService>();
    final bleService = context.read<BleService>();

    // Initialize GPS
    if (gpsService.status != GpsStatus.ready && 
        gpsService.status != GpsStatus.tracking) {
      final initialized = await gpsService.initialize();
      if (!initialized) {
        _showError('GPS not available. Please enable location services.');
        return;
      }
    }

    // Clear previous data
    gpsService.clearTrack();
    bleService.clearSamples();

    // Start simulation mode for BLE (for testing without ESP32)
    bleService.startSimulation();

    // Start GPS tracking
    await gpsService.startTracking();

    setState(() {
      _scanState = ScanState.scanning;
      _elapsedSeconds = 0;
    });

    _pulseController.repeat(reverse: true);

    // Start timer
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds++);
      
      // Auto-center map on current location
      final currentLoc = gpsService.currentLocation;
      if (currentLoc != null) {
        _mapController.move(currentLoc, _mapController.camera.zoom);
      }
    });
  }

  Future<void> _stopScan() async {
    _scanTimer?.cancel();
    _pulseController.stop();

    final gpsService = context.read<GpsService>();
    final bleService = context.read<BleService>();

    // Stop tracking
    final points = await gpsService.stopTracking();
    bleService.stopSimulation();

    if (points.length < 3) {
      _showError('Need at least 3 GPS points to calculate area. Please try again.');
      setState(() => _scanState = ScanState.ready);
      return;
    }

    setState(() => _scanState = ScanState.processing);

    // Process data
    await _processResults(points, bleService.soilSamples);
  }

  Future<void> _processResults(List<LatLng> points, List<SoilData> samples) async {
    final recommenderService = context.read<RecommenderService>();
    final dbService = context.read<DatabaseService>();

    // Calculate area
    final areaM2 = AreaCalculator.calculateAreaM2(points);
    final areaHa = AreaCalculator.m2ToHectares(areaM2);

    // Average soil data
    final avgSoil = SoilData.average(samples);

    // Get recommendations
    final recommendations = recommenderService.getRecommendations(avgSoil, areaHa);

    // Create result
    final result = ScanResult(
      soilData: avgSoil,
      areaM2: areaM2,
      areaHa: areaHa,
      gpsPoints: points,
      recommendations: recommendations,
    );

    // Save to database
    await dbService.saveScanResult(result);

    setState(() => _scanState = ScanState.complete);

    // Navigate to results
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(result: result),
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Scan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_scanState == ScanState.scanning)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_elapsedSeconds),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Map section (takes most of the screen)
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // Live map
                Consumer<GpsService>(
                  builder: (context, gpsService, _) {
                    return LiveMapWidget(
                      trackPoints: gpsService.trackPoints,
                      currentLocation: gpsService.currentLocation,
                      isTracking: _scanState == ScanState.scanning,
                      mapController: _mapController,
                    );
                  },
                ),
                
                // Area overlay
                Positioned(
                  top: 16,
                  left: 16,
                  child: Consumer<GpsService>(
                    builder: (context, gps, _) {
                      final points = gps.trackPoints;
                      if (points.length < 3) {
                        return _InfoBadge(
                          icon: Icons.straighten,
                          label: 'Points: ${points.length}',
                        );
                      }
                      final area = AreaCalculator.calculateAreaM2(points);
                      final areaHa = AreaCalculator.m2ToHectares(area);
                      return _InfoBadge(
                        icon: Icons.square_foot,
                        label: areaHa < 1 
                            ? '${area.toStringAsFixed(0)} m²'
                            : '${areaHa.toStringAsFixed(2)} ha',
                      );
                    },
                  ),
                ),
                
                // Processing overlay
                if (_scanState == ScanState.processing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Processing scan data...',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Bottom panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Soil data card
                Consumer<BleService>(
                  builder: (context, bleService, _) {
                    return SoilDataCard(
                      soilData: bleService.latestSample,
                      sampleCount: bleService.sampleCount,
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Control buttons
                Row(
                  children: [
                    // GPS status
                    Consumer<GpsService>(
                      builder: (context, gps, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _getGpsColor(gps.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.gps_fixed,
                                color: _getGpsColor(gps.status),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${gps.pointCount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getGpsColor(gps.status),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Start/Stop button
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scanState == ScanState.scanning 
                                ? _pulseAnimation.value 
                                : 1.0,
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _scanState == ScanState.processing
                                    ? null
                                    : (_scanState == ScanState.scanning
                                        ? _stopScan
                                        : _startScan),
                                icon: Icon(
                                  _scanState == ScanState.scanning
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                  size: 28,
                                ),
                                label: Text(
                                  _scanState == ScanState.scanning
                                      ? 'Stop Scan'
                                      : 'Start Scan',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _scanState == ScanState.scanning
                                      ? Colors.red
                                      : AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                
                // Instructions
                const SizedBox(height: 12),
                Text(
                  _scanState == ScanState.ready
                      ? 'Walk around your field perimeter to measure area'
                      : _scanState == ScanState.scanning
                          ? 'Keep walking... GPS is tracking your path'
                          : 'Processing...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getGpsColor(GpsStatus status) {
    switch (status) {
      case GpsStatus.tracking:
        return Colors.green;
      case GpsStatus.ready:
        return Colors.blue;
      case GpsStatus.disabled:
      case GpsStatus.noPermission:
        return Colors.red;
    }
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}