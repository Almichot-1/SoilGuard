import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/offline_map_service.dart';
import '../services/gps_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _downloading = false;
  double? _progress;
  late final MapController _mapController;
  bool _didAutoCenter = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoCenterToUser();
    });
  }

  Future<void> _autoCenterToUser() async {
    if (!mounted) return;
    if (_didAutoCenter) return;
    _didAutoCenter = true;

    final gps = context.read<GpsService>();
    final ok = await gps.initialize();
    if (!ok || !mounted) return;

    final loc = gps.currentLocation;
    if (loc == null) return;

    // Zoom 16 gives a "you are here" view while staying within offline max native zoom.
    _mapController.move(loc, 16);
  }

  Future<void> _recenterNow() async {
    if (!mounted) return;
    final gps = context.read<GpsService>();
    final ok = await gps.initialize();
    if (!ok || !mounted) return;
    final loc = gps.currentLocation;
    if (loc == null) return;
    _mapController.move(loc, 16);
  }

  Future<void> _importMbtiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mbtiles'],
        // Never load MBTiles into memory (can be 100s of MB).
        withData: false,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() {
        _downloading = true;
        _progress = null;
      });

      final picked = result.files.single;
      bool ok = false;

      if (picked.path != null && picked.path!.isNotEmpty) {
        ok = await OfflineMapService.importMbtilesFromPath(picked.path!);
      } else if (picked.readStream != null) {
        ok = await OfflineMapService.importMbtilesFromStream(
          picked.readStream!,
        );
      }

      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Imported offline map pack'
                : 'Import failed (or file too large). Prefer setting a download URL in AppConstants.bootstrapMbtilesUrl.',
          ),
        ),
      );

      if (ok) {
        // Force rebuild so TileProvider sees the new MBTiles handle.
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Import failed')));
    }
  }

  Future<void> _downloadOfflinePack() async {
    setState(() {
      _downloading = true;
      _progress = null;
    });

    final ok = await OfflineMapService.ensureMbtilesAvailable(
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
    );

    setState(() {
      _downloading = false;
      _progress = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Offline map is ready'
                : 'No offline pack configured. Set AppConstants.bootstrapMbtilesUrl or import an .mbtiles file.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const addisCenter = LatLng(9.0054, 38.7636);
    final showImportMbtiles = !kIsWeb && defaultTargetPlatform != TargetPlatform.android;
    final gps = context.watch<GpsService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Map – Addis Ababa'),
        actions: [
          IconButton(
            tooltip: 'Recenter to my location',
            onPressed: _downloading ? null : _recenterNow,
            icon: const Icon(Icons.my_location),
          ),
          if (showImportMbtiles)
            IconButton(
              tooltip: 'Import .mbtiles',
              onPressed: _downloading ? null : _importMbtiles,
              icon: const Icon(Icons.upload_file),
            ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: addisCenter,
          initialZoom: 13,
          interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            tileProvider: OfflineMapService.tileProvider,
            userAgentPackageName: 'soil_sense',
            retinaMode: false,
            minNativeZoom: 13,
            maxNativeZoom: 16,
            maxZoom: 18,
            minZoom: 3,
          ),
          if (gps.currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: gps.currentLocation!,
                  width: 18,
                  height: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          RichAttributionWidget(
            attributions: const [
              TextSourceAttribution(
                '© OpenStreetMap contributors',
                onTap: null,
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _downloading ? null : _downloadOfflinePack,
        icon: _downloading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download),
        label: Text(
          _downloading
              ? (_progress == null
                    ? 'Downloading…'
                    : 'Downloading ${(100 * _progress!).clamp(0, 100).toStringAsFixed(0)}%')
              : 'Download Offline',
        ),
      ),
    );
  }
}
