import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2E7D32);
  static const secondary = Color(0xFF81C784);
  static const background = Color(0xFFF5F5F5);
  static const surface = Colors.white;
  static const error = Color(0xFFD32F2F);
  static const warning = Color(0xFFFFA000);
  static const success = Color(0xFF388E3C);
  
  static const phColor = Color(0xFF7B1FA2);
  static const moistureColor = Color(0xFF1976D2);
  static const tempColor = Color(0xFFE64A19);
}

class AppConstants {
  static const String appName = 'Soil Sense';
  static const String version = '1.0.0';
  
  // Map tiles
  // Default OSM template for online tiles. For offline prefetch, replace with
  // a tile server you control and set allowTilePrefetch=true.
  static const String tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const bool allowTilePrefetch = false; // Set to true only if permitted by your tile provider
  // Optional: set this to a direct raster .mbtiles URL to auto-download on first run.
  // Leave empty to prompt the user once on first scan.
  static const String bootstrapMbtilesUrl = '';
  
  // BLE
  static const String esp32ServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String esp32CharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  
  // GPS
  static const int gpsIntervalMs = 1000;
  static const double minDistanceMeters = 2.0;
  
  // Scanning
  static const int scanDurationSeconds = 60;
  static const int minPointsForPolygon = 3;
  
}