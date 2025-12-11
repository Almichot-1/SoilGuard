import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/constants.dart';

class LiveMapWidget extends StatelessWidget {
  final List<LatLng> trackPoints;
  final LatLng? currentLocation;
  final bool isTracking;
  final MapController? mapController;

  const LiveMapWidget({
    super.key,
    required this.trackPoints,
    this.currentLocation,
    this.isTracking = false,
    this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    final center = currentLocation ?? 
        (trackPoints.isNotEmpty ? trackPoints.last : const LatLng(9.0, 38.75)); // Default: Addis Ababa

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 18.0,
        maxZoom: 22.0,
        minZoom: 10.0,
      ),
      children: [
        // OpenStreetMap tiles
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.soil_sense',
          maxZoom: 22,
        ),
        
        // Polygon fill (if we have enough points)
        if (trackPoints.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: trackPoints,
                color: AppColors.primary.withValues(alpha: 0.2),
                borderColor: AppColors.primary,
                borderStrokeWidth: 3,
                // 'isFilled' deprecated; setting color enables filling
                // Remove deprecated property
              ),
            ],
          ),
        
        // Track line
        if (trackPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: trackPoints,
                color: AppColors.primary,
                strokeWidth: 4,
              ),
            ],
          ),
        
        // Track points markers
        MarkerLayer(
          markers: [
            // Start point (green)
            if (trackPoints.isNotEmpty)
              Marker(
                point: trackPoints.first,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            
            // Intermediate points (only when we have at least 3 points)
            ...(trackPoints.length > 2
                ? trackPoints
                    .skip(1)
                    .take(trackPoints.length - 2)
                    .map<Marker>(
                      (point) => Marker(
                        point: point,
                        width: 16,
                        height: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    )
                : const <Marker>[]),
            
            // Current location (blue pulsing)
            if (currentLocation != null)
              Marker(
                point: currentLocation!,
                width: 40,
                height: 40,
                child: _PulsingLocationMarker(isTracking: isTracking),
              ),
          ],
        ),
      ],
    );
  }
}

class _PulsingLocationMarker extends StatefulWidget {
  final bool isTracking;
  
  const _PulsingLocationMarker({required this.isTracking});

  @override
  State<_PulsingLocationMarker> createState() => _PulsingLocationMarkerState();
}

class _PulsingLocationMarkerState extends State<_PulsingLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    if (widget.isTracking) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingLocationMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTracking && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isTracking && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.2 / _animation.value),
          ),
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}