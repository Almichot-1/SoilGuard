import 'dart:io';
import 'dart:math' as math;

import 'package:mbtiles/mbtiles.dart';
import 'package:sqlite3/sqlite3.dart';

({int x, int y}) latLonToTileXY({
  required double lat,
  required double lon,
  required int z,
}) {
  // XYZ scheme
  final n = math.pow(2.0, z).toDouble();
  final x = ((lon + 180.0) / 360.0 * n).floor();
  final latRad = lat * math.pi / 180.0;
  final y = ((1.0 - math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi) /
          2.0 *
          n)
      .floor();
  return (x: x, y: y);
}

int xyzToTmsY({required int z, required int yXyz}) => ((1 << z) - 1) - yXyz;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/inspect_mbtiles.dart <path_to_mbtiles>');
    exitCode = 64;
    return;
  }

  final path = args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $path');
    exitCode = 66;
    return;
  }

  print('Inspecting: ${file.absolute.path}');
  print('Size: ${file.lengthSync()} bytes');

  // Read high-level metadata via mbtiles package.
  final mb = MbTiles(mbtilesPath: file.path);
  final meta = mb.getMetadata();
  print('MbTilesMetadata: $meta');

  // Read raw metadata table values (including optional keys like scheme).
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    final rows = db.select('SELECT name, value FROM metadata ORDER BY name');
    print('\nRaw metadata table:');
    for (final row in rows) {
      print('  ${row['name']}: ${row['value']}');
    }

    final sample = db.select(
      'SELECT zoom_level, tile_column, tile_row, length(tile_data) AS len '
      'FROM tiles ORDER BY zoom_level DESC LIMIT 5',
    );
    print('\nSample tiles rows (top 5 by zoom desc):');
    for (final r in sample) {
      print(
        '  z=${r['zoom_level']} x=${r['tile_column']} y=${r['tile_row']} len=${r['len']}',
      );
    }
  } finally {
    db.dispose();
  }

  // Quick probe near Addis Ababa.
  const addisLat = 8.9806;
  const addisLon = 38.7578;

  // Probe a few zooms around what you expect.
  final zooms = <int>{
    if (meta.minZoom != null) meta.minZoom!.round(),
    if (meta.maxZoom != null) meta.maxZoom!.round(),
    12,
    13,
    14,
    15,
    16,
  }..removeWhere((z) => z < 0 || z > 22);

  print('\nProbe tiles near Addis (lat=$addisLat lon=$addisLon):');
  for (final z in zooms.toList()..sort()) {
    final xy = latLonToTileXY(lat: addisLat, lon: addisLon, z: z);
    final yTms = xyzToTmsY(z: z, yXyz: xy.y);

    final bytesTms = mb.getTile(z: z, x: xy.x, y: yTms);
    final bytesXyz = mb.getTile(z: z, x: xy.x, y: xy.y);

    print(
      '  z=$z x=${xy.x} yXyz=${xy.y} yTms=$yTms -> '
      'TMS=${bytesTms?.length ?? 0} bytes, XYZ=${bytesXyz?.length ?? 0} bytes',
    );
  }

  mb.dispose();
}
