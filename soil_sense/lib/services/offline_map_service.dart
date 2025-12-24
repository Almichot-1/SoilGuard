import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/painting.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class OfflineMapService {
  static const double minLat = 8.90;
  static const double minLon = 38.64;
  static const double maxLat = 9.07;
  static const double maxLon = 38.90;

  static MbTiles? _mb;
  static const _prefsKeyMbtilesUrl = 'mbtiles_url';

  static Future<void> init() async {
    final path = await _defaultMbTilesPath();
    if (File(path).existsSync()) {
      _mb = MbTiles(mbtilesPath: path);
    }
  }

  static TileProvider get tileProvider => _MbTilesTileProvider(_mb);

  static Future<int> downloadAddisRegion({
    int minZoom = 13,
    int maxZoom = 16,
  }) async {
    // Prefetch tiles for Addis bounds if allowed and using a permitted tile source
    if (!AppConstants.allowTilePrefetch ||
        AppConstants.tileUrlTemplate.contains('tile.openstreetmap.org')) {
      return 0;
    }

    int downloaded = 0;
    for (int z = minZoom; z <= maxZoom; z++) {
      final minX = _lon2tileX(minLon, z);
      final maxX = _lon2tileX(maxLon, z);
      final minYXyz = _lat2tileY(maxLat, z); // note: lat2tileY uses XYZ conversion
      final maxYXyz = _lat2tileY(minLat, z);
      for (int x = minX; x <= maxX; x++) {
        for (int y = minYXyz; y <= maxYXyz; y++) {
          final ok = await _downloadTileIfMissing(z, x, y);
          if (ok) downloaded++;
        }
      }
    }
    return downloaded;
  }

  static Future<int> cacheTilesForBounds({
    required LatLngBounds bounds,
    required int zoom,
  }) async {
    if (!AppConstants.allowTilePrefetch ||
        AppConstants.tileUrlTemplate.contains('tile.openstreetmap.org')) {
      return 0;
    }
    final minLatB = min(bounds.south, bounds.north);
    final maxLatB = max(bounds.south, bounds.north);
    final minLonB = min(bounds.west, bounds.east);
    final maxLonB = max(bounds.west, bounds.east);

    final minX = _lon2tileX(minLonB, zoom);
    final maxX = _lon2tileX(maxLonB, zoom);
    final minYXyz = _lat2tileY(maxLatB, zoom);
    final maxYXyz = _lat2tileY(minLatB, zoom);
    int downloaded = 0;
    for (int x = minX; x <= maxX; x++) {
      for (int y = minYXyz; y <= maxYXyz; y++) {
        final ok = await _downloadTileIfMissing(zoom, x, y);
        if (ok) downloaded++;
      }
    }
    return downloaded;
  }

  static Future<bool> hasAnyAddisTileCached() async {
    try {
      final path = await _defaultMbTilesPath();
      if (!File(path).existsSync()) return false;
      final db = MbTiles(mbtilesPath: path);
      final z = 14;
      final x = _lon2tileX(38.76, z);
      final yXyz = _lat2tileY(9.00, z);
      final yTms = ((1 << z) - 1) - yXyz;
      final dynamic tile = db.getTile(z: z, x: x, y: yTms);
      db.dispose();
      if (tile is Uint8List) return tile.isNotEmpty;
      if (tile != null && tile.data is List<int>) return (tile.data as List<int>).isNotEmpty;
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _defaultMbTilesPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'addis.mbtiles');
  }

  static Future<bool> mbtilesFileExists() async {
    final path = await _defaultMbTilesPath();
    return File(path).existsSync();
  }

  static Future<void> setBootstrapUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyMbtilesUrl, url);
  }

  static Future<String?> getBootstrapUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKeyMbtilesUrl);
    if (saved != null && saved.isNotEmpty) return saved;
    if (AppConstants.bootstrapMbtilesUrl.isNotEmpty) return AppConstants.bootstrapMbtilesUrl;
    return null;
  }

  static Future<bool> ensureMbtilesAvailable({void Function(double progress)? onProgress}) async {
    if (await mbtilesFileExists()) return true;
    final url = await getBootstrapUrl();
    if (url == null || url.isEmpty) return false;
    return await downloadMbtilesFromUrlWithProgress(url, onProgress: onProgress);
  }

  static Future<bool> importMbtilesFromPath(String sourcePath, {Uint8List? bytes}) async {
    try {
      final destPath = await _defaultMbTilesPath();
      final dest = File(destPath);
      if (!await dest.parent.exists()) {
        await dest.parent.create(recursive: true);
      }
      if (bytes != null) {
        await dest.writeAsBytes(bytes, flush: true);
      } else {
        final src = File(sourcePath);
        if (!await src.exists()) return false;
        await src.copy(dest.path);
      }
      _mb?.dispose();
      _mb = MbTiles(mbtilesPath: dest.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> downloadMbtilesFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = http.Client();
      final req = http.Request('GET', uri);
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        client.close();
        return false;
      }
      final destPath = await _defaultMbTilesPath();
      final dest = File(destPath);
      if (!await dest.parent.exists()) {
        await dest.parent.create(recursive: true);
      }
      final sink = dest.openWrite();
      await resp.stream.listen((chunk) {
        sink.add(chunk);
      }).asFuture<void>();
      await sink.flush();
      await sink.close();
      client.close();
      _mb?.dispose();
      _mb = MbTiles(mbtilesPath: dest.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> downloadMbtilesFromUrlWithProgress(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final uri = Uri.parse(url);
      final client = http.Client();
      final req = http.Request('GET', uri);
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        client.close();
        return false;
      }
      final destPath = await _defaultMbTilesPath();
      final dest = File(destPath);
      if (!await dest.parent.exists()) {
        await dest.parent.create(recursive: true);
      }
      final total = resp.contentLength ?? -1;
      int received = 0;
      final sink = dest.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      }
      await sink.flush();
      await sink.close();
      client.close();
      _mb?.dispose();
      _mb = MbTiles(mbtilesPath: dest.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> importMbtilesFromBytes(Uint8List bytes) async {
    try {
      final destPath = await _defaultMbTilesPath();
      final dest = File(destPath);
      if (!await dest.parent.exists()) {
        await dest.parent.create(recursive: true);
      }
      await dest.writeAsBytes(bytes, flush: true);
      _mb?.dispose();
      _mb = MbTiles(mbtilesPath: dest.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _tilesRoot() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'tiles');
  }

  static Future<File> _tileFile(int z, int x, int y) async {
    final root = await _tilesRoot();
    final path = p.join(root, '$z', '$x', '$y.png');
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return file;
  }

  static Future<bool> _downloadTileIfMissing(int z, int x, int y) async {
    try {
      final file = await _tileFile(z, x, y);
      if (await file.exists()) return false;
      final url = AppConstants.tileUrlTemplate
          .replaceAll('{z}', '$z')
          .replaceAll('{x}', '$x')
          .replaceAll('{y}', '$y');
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(resp.bodyBytes);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static int _lat2tileY(double lat, int zoom) {
    final rad = lat * pi / 180.0;
    final n = pow(2.0, zoom).toDouble();
    final y = (1 - log(tan(rad) + 1 / cos(rad)) / pi) / 2 * n;
    return y.floor();
  }

  static int _lon2tileX(double lon, int zoom) {
    final n = pow(2.0, zoom).toDouble();
    final x = (lon + 180.0) / 360.0 * n;
    return x.floor();
  }
}

class _MbTilesTileProvider extends TileProvider {
  final MbTiles? _db;
  _MbTilesTileProvider(this._db);

  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    // 1) Check file cache
    try {
      final z = coordinates.z.round();
      final x = coordinates.x.round();
      final y = coordinates.y.round();
      return _fileOrNext(z, x, y, options);
    } catch (_) {}

    // Should not reach here normally
    try {
      final db = _db;
      if (db != null) {
        final z = coordinates.z.round();
        final x = coordinates.x.round();
        final yXyz = coordinates.y.round();
        final yTms = ((1 << z) - 1) - yXyz;
        final dynamic tile = db.getTile(z: z, x: x, y: yTms);
        if (tile is Uint8List && tile.isNotEmpty) {
          return MemoryImage(tile);
        } else if (tile != null && tile.data is List<int> && (tile.data as List<int>).isNotEmpty) {
          return MemoryImage(Uint8List.fromList(tile.data as List<int>));
        }
      }
    } catch (_) {}

    final z = coordinates.z.round();
    final x = coordinates.x.round();
    final y = coordinates.y.round();
    final template =
        options.urlTemplate ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    final url = template
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
    return NetworkImage(url);
  }

  ImageProvider<Object> _fileOrNext(int z, int x, int y, TileLayer options) {
    // Try file cache first
    // This is synchronous-unsafe; but TileProvider expects sync return.
    // We will attempt using existsSync on constructed path (best-effort).
    try {
      final dir = getApplicationDocumentsDirectorySync();
      final path = p.join(dir.path, 'tiles', '$z', '$x', '$y.png');
      final f = File(path);
      if (f.existsSync()) return FileImage(f);
    } catch (_) {}

    // 2) MBTiles
    try {
      final db = _db;
      if (db != null) {
        final yTms = ((1 << z) - 1) - y;
        final dynamic tile = db.getTile(z: z, x: x, y: yTms);
        if (tile is Uint8List && tile.isNotEmpty) {
          return MemoryImage(tile);
        } else if (tile != null && tile.data is List<int> && (tile.data as List<int>).isNotEmpty) {
          return MemoryImage(Uint8List.fromList(tile.data as List<int>));
        }
      }
    } catch (_) {}

    // 3) Network
    final template = options.urlTemplate ?? AppConstants.tileUrlTemplate;
    final url = template
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
    return NetworkImage(url);
  }

  @override
  void dispose() {
    _db?.dispose();
    super.dispose();
  }
}

// Sync helper to get documents directory without awaiting (TileProvider API is sync)
Directory getApplicationDocumentsDirectorySync() {
  // Fallback to platform-specific known locations
  final env = Platform.environment;
  final home = env['USERPROFILE'] ?? env['HOME'] ?? '.';
  // Use typical Flutter app-documents path under home; this matches path_provider output on Windows.
  // May not be exact across platforms, but we only need best-effort File.existsSync.
  return Directory(p.join(home, 'AppData', 'Roaming'));
}
