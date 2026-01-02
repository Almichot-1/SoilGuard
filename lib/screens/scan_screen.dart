import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import '../services/ble_service.dart';
import '../services/classic_bluetooth_service.dart';
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
import '../services/offline_map_service.dart';

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
    _ensureOfflineMap();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeServices() async {
    final gps = context.read<GpsService>();
    final ble = context.read<BleService>();
    final classicBt = context.read<ClassicBluetoothService>();

    await gps.initialize();
    await ble.initialize();
    await classicBt.initialize(autoConnect: true);
  }

  Future<void> _ensureOfflineMap() async {
    final exists = await OfflineMapService.mbtilesFileExists();
    if (exists) return;
    final url = await OfflineMapService.getBootstrapUrl();
    if (url == null || url.isEmpty) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Downloading map…'),
        content: SizedBox(
          width: 240,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 12),
              Text('This may take a few minutes'),
            ],
          ),
        ),
      ),
    );
    final ok = await OfflineMapService.downloadMbtilesFromUrlWithProgress(url);
    if (mounted) Navigator.of(context).pop();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Offline map ready' : 'Failed to download offline map',
        ),
      ),
    );
  }

  Future<void> _startScan() async {
    final gps = context.read<GpsService>();
    final ble = context.read<BleService>();
    final classicBt = context.read<ClassicBluetoothService>();

    await gps.initialize();
    await ble.initialize();
    await classicBt.initialize(autoConnect: true);

    ble.clearSamples();
    classicBt.clearSamples();
    await gps.startTracking();

    setState(() {
      _scanState = ScanState.scanning;
      _elapsedSeconds = 0;
    });
    _pulseController.repeat(reverse: true);
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds += 1);
    });
  }

  Future<void> _stopScan() async {
    if (_scanState != ScanState.scanning) return;
    setState(() => _scanState = ScanState.processing);
    _scanTimer?.cancel();
    _pulseController.stop();

    final gps = context.read<GpsService>();
    final ble = context.read<BleService>();
    final classicBt = context.read<ClassicBluetoothService>();

    final points = await gps.stopTracking();
    final samples = classicBt.isConnected
        ? classicBt.soilSamples
        : ble.soilSamples;

    if (points.length < 3) {
      _showError('Need at least 3 GPS points to compute area.');
      setState(() => _scanState = ScanState.ready);
      return;
    }
    if (samples.isEmpty) {
      _showError('No sensor samples captured.');
      setState(() => _scanState = ScanState.ready);
      return;
    }

    await _processResults(points, samples);
  }

  void _takeSample() {
    final ble = context.read<BleService>();
    final classicBt = context.read<ClassicBluetoothService>();
    final ok = classicBt.isConnected
        ? classicBt.takeSample()
        : ble.takeSample();
    if (!ok) {
      _showError('No sensor reading yet. Please wait and try again.');
      return;
    }

    final count = classicBt.isConnected
        ? classicBt.sampleCount
        : ble.sampleCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sample saved ($count total)'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _processResults(
    List<LatLng> points,
    List<SoilData> samples,
  ) async {
    final recommenderService = context.read<RecommenderService>();
    final dbService = context.read<DatabaseService>();

    final areaM2 = AreaCalculator.calculateAreaM2(points);
    final areaHa = AreaCalculator.m2ToHectares(areaM2);
    final avgSoil = SoilData.average(samples);

    final recommendations = recommenderService.getRecommendations(
      avgSoil,
      areaHa,
    );

    if (mounted && recommendations.isNotEmpty) {
      final top = recommendations.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Top recommendation: ${top.crop.name} • ${top.suitabilityPercent.toStringAsFixed(0)}%',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final result = ScanResult(
      soilData: avgSoil,
      areaM2: areaM2,
      areaHa: areaHa,
      gpsPoints: points,
      recommendations: recommendations,
    );

    await dbService.saveScanResult(result);

    setState(() => _scanState = ScanState.complete);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
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
          IconButton(
            tooltip: 'Offline Map Options',
            icon: const Icon(Icons.download),
            onPressed: _showOfflineMapOptions,
          ),
          Consumer<BleService>(
            builder: (context, ble, _) {
              return IconButton(
                tooltip: ble.isSimulating
                    ? 'Disable Simulation Mode'
                    : 'Enable Simulation Mode',
                icon: Icon(
                  ble.isSimulating ? Icons.science : Icons.science_outlined,
                ),
                onPressed: () {
                  if (ble.isSimulating) {
                    ble.stopSimulation();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Simulation mode disabled')),
                    );
                  } else {
                    ble.startSimulation();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Simulation mode enabled')),
                    );
                  }
                },
              );
            },
          ),
          if (_scanState == ScanState.scanning)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
          Expanded(
            flex: 3,
            child: Stack(
              children: [
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
                Consumer<BleService>(
                  builder: (context, bleService, _) {
                    final classicBt = context.watch<ClassicBluetoothService>();
                    final soilData = classicBt.isConnected
                        ? (classicBt.latestReading ?? classicBt.latestSample)
                        : (bleService.latestReading ?? bleService.latestSample);
                    final sampleCount = classicBt.isConnected
                        ? classicBt.sampleCount
                        : bleService.sampleCount;
                    return SoilDataCard(
                      soilData: soilData,
                      sampleCount: sampleCount,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Consumer<GpsService>(
                      builder: (context, gps, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _getGpsColor(
                              gps.status,
                            ).withValues(alpha: 0.1),
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
                                  backgroundColor:
                                      _scanState == ScanState.scanning
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
                if (_scanState == ScanState.scanning) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _takeSample,
                      icon: const Icon(Icons.add, size: 26),
                      label: const Text(
                        'Take Sample',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                ],
                const SizedBox(height: 12),
                Text(
                  _scanState == ScanState.ready
                      ? 'Walk around your field perimeter to measure area'
                      : _scanState == ScanState.scanning
                      ? 'Keep walking... GPS is tracking your path'
                      : 'Processing...',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineMapOptions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download),
                  title: const Text('Download MBTiles from URL'),
                  subtitle: const Text(
                    'Provide a legal MBTiles URL to store offline',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final url = await _promptForUrl();
                    if (url == null || url.isEmpty) return;
                    await OfflineMapService.setBootstrapUrl(url);
                    double p = 0;
                    if (mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => StatefulBuilder(
                          builder: (ctx, setState) {
                            return AlertDialog(
                              title: const Text('Downloading map…'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LinearProgressIndicator(
                                    value: p > 0 && p < 1 ? p : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${(p * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }
                    final ok =
                        await OfflineMapService.downloadMbtilesFromUrlWithProgress(
                          url,
                          onProgress: (v) {
                            p = v;
                          },
                        );
                    if (mounted) Navigator.of(context).pop();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Offline map downloaded'
                              : 'Failed to download MBTiles',
                        ),
                      ),
                    );
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Import MBTiles from Files'),
                  subtitle: const Text('Pick an .mbtiles file to use offline'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await _pickAndImportMbtiles();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'MBTiles imported'
                              : 'Import cancelled or failed',
                        ),
                      ),
                    );
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('Cache tiles for current view'),
                  subtitle: const Text(
                    'Requires permitted tile server; disabled for default OSM',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (!AppConstants.allowTilePrefetch ||
                        AppConstants.tileUrlTemplate.contains(
                          'tile.openstreetmap.org',
                        )) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Prefetch disabled: configure a permitted tile server first.',
                          ),
                        ),
                      );
                      return;
                    }
                    final bounds = _mapController.camera.visibleBounds;
                    final zoom = _mapController.camera.zoom.round();
                    final count = await OfflineMapService.cacheTilesForBounds(
                      bounds: bounds,
                      zoom: zoom,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cached $count tiles for current view.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _promptForUrl() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Enter MBTiles URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://example.com/addis.mbtiles',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _pickAndImportMbtiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return false;
      final file = res.files.single;
      final path = file.path;
      if ((path != null && !path.toLowerCase().endsWith('.mbtiles')) &&
          (file.name.isNotEmpty &&
              !file.name.toLowerCase().endsWith('.mbtiles'))) {
        return false;
      }
      final bytes = file.bytes;
      return await OfflineMapService.importMbtilesFromPath(
        path ?? '',
        bytes: bytes,
      );
    } catch (_) {
      return false;
    }
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
