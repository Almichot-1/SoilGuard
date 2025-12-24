import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/offline_map_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _downloading = false;
  int _downloaded = 0;

  Future<void> _downloadAddis() async {
    setState(() {
      _downloading = true;
      _downloaded = 0;
    });
    final count = await OfflineMapService.downloadAddisRegion(
      minZoom: 13,
      maxZoom: 16,
    );
    setState(() {
      _downloading = false;
      _downloaded = count;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cached $_downloaded tiles for Addis Ababa')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const addisCenter = LatLng(9.0054, 38.7636);

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Map – Addis Ababa')),
      body: FlutterMap(
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
            maxZoom: 18,
            minZoom: 3,
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
        onPressed: _downloading ? null : _downloadAddis,
        icon: _downloading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download),
        label: Text(_downloading ? 'Downloading…' : 'Download Offline'),
      ),
    );
  }
}
