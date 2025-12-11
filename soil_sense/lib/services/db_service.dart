import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_result.dart';

class DatabaseService {
  Database? _database;
  
  bool get isInitialized => _database != null;

  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'soil_sense.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE soil_scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            avg_ph REAL NOT NULL,
            avg_moisture REAL NOT NULL,
            avg_temp REAL NOT NULL,
            area_m2 REAL NOT NULL,
            area_ha REAL NOT NULL,
            gps_points TEXT,
            timestamp TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE recommendations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_id INTEGER NOT NULL,
            crop_name TEXT NOT NULL,
            suitability_percent INTEGER NOT NULL,
            seed_kg REAL NOT NULL,
            spacing_cm TEXT NOT NULL,
            plant_count INTEGER NOT NULL,
            FOREIGN KEY (scan_id) REFERENCES soil_scans(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  /// Save a scan result with recommendations
  Future<int> saveScanResult(ScanResult result) async {
    if (_database == null) await initialize();

    // Insert scan
    final scanId = await _database!.insert('soil_scans', result.toDbMap());

    // Insert recommendations
    for (final rec in result.recommendations) {
      await _database!.insert('recommendations', {
        'scan_id': scanId,
        'crop_name': rec.crop.name,
        'suitability_percent': rec.suitabilityPercent.round(),
        'seed_kg': rec.seedKg,
        'spacing_cm': rec.spacing,
        'plant_count': rec.plantCount,
      });
    }

    return scanId;
  }

  /// Get all scan history
  Future<List<Map<String, dynamic>>> getAllScans() async {
    if (_database == null) await initialize();

    return await _database!.query(
      'soil_scans',
      orderBy: 'timestamp DESC',
    );
  }

  /// Get recommendations for a scan
  Future<List<Map<String, dynamic>>> getRecommendations(int scanId) async {
    if (_database == null) await initialize();

    return await _database!.query(
      'recommendations',
      where: 'scan_id = ?',
      whereArgs: [scanId],
    );
  }

  /// Delete a scan and its recommendations
  Future<void> deleteScan(int id) async {
    if (_database == null) await initialize();

    await _database!.delete(
      'soil_scans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear all scans and recommendations
  Future<void> clearAll() async {
    if (_database == null) await initialize();
    await _database!.delete('recommendations');
    await _database!.delete('soil_scans');
  }

  /// Get scan count
  Future<int> getScanCount() async {
    if (_database == null) await initialize();

    final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM soil_scans');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}