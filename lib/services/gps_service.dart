import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

enum GpsStatus { disabled, noPermission, ready, tracking }

enum TrackingMode { continuous, manual }

class GpsService extends ChangeNotifier {
  GpsStatus _status = GpsStatus.disabled;
  LatLng? _currentLocation;
  double? _currentAccuracy;
  final List<LatLng> _trackPoints = [];
  final List<LatLng> _rawPoints = [];
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  TrackingMode _trackingMode = TrackingMode.continuous;

  static const double maxAccuracyThreshold = 15.0;
  static const double goodAccuracyThreshold = 5.0;
  static const double minDistanceBetweenPoints = 2.0;

  GpsStatus get status => _status;
  LatLng? get currentLocation => _currentLocation;
  double? get currentAccuracy => _currentAccuracy;
  List<LatLng> get trackPoints => List.unmodifiable(_trackPoints);
  bool get isTracking => _isTracking;
  int get pointCount => _trackPoints.length;
  TrackingMode get trackingMode => _trackingMode;

  void setTrackingMode(TrackingMode mode) {
    if (_trackingMode == mode) return;
    _trackingMode = mode;
    notifyListeners();
  }

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
    // Use frequent updates and do filtering ourselves.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );
  }

  /// Start tracking GPS points for field mapping
  Future<void> startTracking() async {
    if (_isTracking) return;

    _trackPoints.clear();
    _rawPoints.clear();
    _isTracking = true;
    _status = GpsStatus.tracking;
    notifyListeners();

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: _buildLocationSettings(),
        ).listen(
          (Position position) {
            _currentLocation = LatLng(position.latitude, position.longitude);
            _currentAccuracy = position.accuracy;

            if (_trackingMode == TrackingMode.manual) {
              notifyListeners();
              return;
            }

            if (_currentAccuracy == null || _currentAccuracy!.isNaN) {
              return;
            }
            if (_currentAccuracy! > maxAccuracyThreshold) {
              return;
            }

            final newPoint = _currentLocation!;

            if (_trackPoints.isNotEmpty && !_shouldAddPoint(newPoint)) {
              return;
            }

            _rawPoints.add(newPoint);

            if (_rawPoints.length >= 3 && _trackPoints.length >= 2) {
              // Smooth the middle point of the last three raw points.
              // raw: [.., prev, curr, next]
              // replace last track point (which corresponds to curr) before appending next.
              final smoothed = _smoothPoint(_rawPoints.length - 2);
              _trackPoints[_trackPoints.length - 1] = smoothed;
            }

            _trackPoints.add(newPoint);
            notifyListeners();
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

    return meters >= minDistanceBetweenPoints;
  }

  LatLng _smoothPoint(int index) {
    if (index <= 0 || index >= _rawPoints.length - 1) {
      return _rawPoints[index];
    }
    final prev = _rawPoints[index - 1];
    final curr = _rawPoints[index];
    final next = _rawPoints[index + 1];

    final lat = (prev.latitude + (curr.latitude * 2) + next.latitude) / 4;
    final lng = (prev.longitude + (curr.longitude * 2) + next.longitude) / 4;
    return LatLng(lat, lng);
  }

  /// Returns a smoothed version of the current track for display or calculations.
  List<LatLng> getSmoothedTrack() {
    if (_trackPoints.length < 5) return List.from(_trackPoints);
    final out = <LatLng>[];
    out.add(_trackPoints.first);
    for (var i = 1; i < _trackPoints.length - 1; i++) {
      final prev = _trackPoints[i - 1];
      final curr = _trackPoints[i];
      final next = _trackPoints[i + 1];
      final lat = (prev.latitude + (curr.latitude * 2) + next.latitude) / 4;
      final lng = (prev.longitude + (curr.longitude * 2) + next.longitude) / 4;
      out.add(LatLng(lat, lng));
    }
    out.add(_trackPoints.last);
    return out;
  }

  /// Stop tracking and close polygon
  Future<List<LatLng>> stopTracking() async {
    _isTracking = false;
    _status = GpsStatus.ready;

    await _positionStream?.cancel();
    _positionStream = null;

    // Polygon closing (if needed) should be handled by the caller/calculations.

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

  /// In manual mode, store the current location as a corner/vertex.
  bool markCorner() {
    final loc = _currentLocation;
    final acc = _currentAccuracy;
    if (loc == null || acc == null) return false;
    if (acc.isNaN || acc > maxAccuracyThreshold) return false;
    _trackPoints.add(loc);
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}
