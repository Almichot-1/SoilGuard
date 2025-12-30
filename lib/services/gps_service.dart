import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

enum GpsStatus { disabled, noPermission, ready, tracking }

class GpsService extends ChangeNotifier {
  GpsStatus _status = GpsStatus.disabled;
  LatLng? _currentLocation;
  final List<LatLng> _trackPoints = [];
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  GpsStatus get status => _status;
  LatLng? get currentLocation => _currentLocation;
  List<LatLng> get trackPoints => List.unmodifiable(_trackPoints);
  bool get isTracking => _isTracking;
  int get pointCount => _trackPoints.length;

  /// Initialize GPS and check permissions
  Future<bool> initialize() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _status = GpsStatus.disabled;
        notifyListeners();
        return false;
      }

      // Check permissions
      var permission = await Permission.location.status;
      if (permission.isDenied) {
        permission = await Permission.location.request();
      }

      if (permission.isPermanentlyDenied) {
        _status = GpsStatus.noPermission;
        notifyListeners();
        return false;
      }

      if (permission.isGranted) {
        _status = GpsStatus.ready;
        await _getCurrentLocation();
        notifyListeners();
        return true;
      }

      _status = GpsStatus.noPermission;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('GPS initialization error: $e');
      _status = GpsStatus.disabled;
      notifyListeners();
      return false;
    }
  }

  /// Get current location once
  Future<LatLng?> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _buildLocationSettings(),
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      notifyListeners();
      return _currentLocation;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  LocationSettings _buildLocationSettings() {
    // Prefer best accuracy for navigation on Android.
    // On other platforms, fall back to high accuracy.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: Duration(seconds: 1),
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );
  }

  /// Start tracking GPS points for field mapping
  Future<void> startTracking() async {
    if (_isTracking) return;

    _trackPoints.clear();
    _isTracking = true;
    _status = GpsStatus.tracking;
    notifyListeners();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(
      (Position position) {
        // Skip poor fixes (network-only / low quality) to reduce map drift.
        // `position.accuracy` is in meters; smaller is better.
        if (position.accuracy.isNaN || position.accuracy > 25) {
          return;
        }
        final newPoint = LatLng(position.latitude, position.longitude);
        
        // Only add if significantly different from last point
        if (_trackPoints.isEmpty || _shouldAddPoint(newPoint)) {
          _trackPoints.add(newPoint);
          _currentLocation = newPoint;
          notifyListeners();
          debugPrint('GPS Point ${_trackPoints.length}: ${newPoint.latitude}, ${newPoint.longitude}');
        }
      },
      onError: (e) {
        debugPrint('GPS stream error: $e');
      },
    );
  }

  /// Check if new point should be added (minimum distance check)
  bool _shouldAddPoint(LatLng newPoint) {
    if (_trackPoints.isEmpty) return true;
    
    final lastPoint = _trackPoints.last;
    const distance = Distance();
    final meters = distance.as(LengthUnit.Meter, lastPoint, newPoint);
    
    return meters >= 3.0; // Minimum 3 meters apart
  }

  /// Stop tracking and close polygon
  Future<List<LatLng>> stopTracking() async {
    _isTracking = false;
    _status = GpsStatus.ready;
    
    await _positionStream?.cancel();
    _positionStream = null;

    // Auto-close polygon by adding first point at end if needed
    if (_trackPoints.length >= 3) {
      // The polygon will be closed in calculations
    }

    notifyListeners();
    return List.from(_trackPoints);
  }

  /// Clear all tracked points
  void clearTrack() {
    _trackPoints.clear();
    notifyListeners();
  }

  /// Add a manual point (for testing)
  void addManualPoint(LatLng point) {
    _trackPoints.add(point);
    _currentLocation = point;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}