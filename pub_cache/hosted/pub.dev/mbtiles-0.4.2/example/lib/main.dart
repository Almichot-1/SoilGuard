import 'dart:io';
import 'dart:math';

import 'package:mbtiles/mbtiles.dart';

void main() {
  // Get paths for the current platform. This is not needed if you use the
  // package on flutter and include the `sqlite3_flutter_libs` package.
  final sqlitePath = switch (Platform.operatingSystem) {
    'windows' => r'assets\windows\sqlite3.dll',
    'macos' => 'assets/macos/sqlite3',
    'linux' => 'assets/linux/sqlite3',
    String() => throw Exception(
        'The example program is dart-only and running it on flutter is '
        'not supported.\n'
        'If you want to use this package in a flutter app, head over to '
        'the package documentation!',
      ),
  };

  // ### RASTER MBTILES ###

  // open mbtiles
  final rasterMbtiles = MbTiles(
    mbtilesPath: 'assets/mbtiles/countries-raster.mbtiles',
    sqlitePath: sqlitePath,
  );

  // get metadata
  print('[RASTER MBTILES] metadata: ${rasterMbtiles.getMetadata()}');

  // get tile data
  final rasterTile = rasterMbtiles.getTile(z: 0, x: 0, y: 0);
  final rasterTileSize = rasterTile?.length ?? 0;
  print('[RASTER MBTILES] Tile size: ${formatSize(rasterTileSize)}');

  // close mbtiles
  rasterMbtiles.dispose();

  // ### VECTOR MBTILES ###

  // open mbtiles
  final vectorMbtiles = MbTiles(
    mbtilesPath: 'assets/mbtiles/countries-vector.mbtiles',
    sqlitePath: sqlitePath,
  );

  // get metadata
  print('[VECTOR MBTILES] metadata: ${vectorMbtiles.getMetadata()}');

  // get tile data
  final vectorTile = vectorMbtiles.getTile(z: 0, x: 0, y: 0);
  final vectorTileSize = vectorTile?.length ?? 0;
  print(
    '[VECTOR MBTILES] Uncompressed tile size: ${formatSize(vectorTileSize)}',
  );

  // close mbtiles
  vectorMbtiles.dispose();
}

/// Return a formatted String for an amount of bytes
/// (from https://stackoverflow.com/a/74568711/9439899)
String formatSize(int amountBytes, {int decimals = 0}) {
  const suffixes = ["b", "kb", "mb", "gb", "tb"];
  if (amountBytes == 0) return '0${suffixes[0]}';
  final i = (log(amountBytes) / log(1024)).floor();
  return ((amountBytes / pow(1024, i)).toStringAsFixed(decimals)) + suffixes[i];
}
