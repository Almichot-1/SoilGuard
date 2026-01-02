import 'dart:io';
import 'dart:typed_data';

import 'package:mbtiles/mbtiles.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('Open read only raster Database', () {
    final mbtiles = MbTiles(
      mbtilesPath: rasterMbtilesPath,
      sqlitePath: sqliteLibPath,
    );
    mbtiles.dispose();
  });
  test('Open read write raster Database', () {
    final mbtiles = MbTiles(
      mbtilesPath: rasterMbtilesPath,
      sqlitePath: sqliteLibPath,
    );
    expect(mbtiles.getTile(z: 0, x: 0, y: 0), isA<Uint8List>());
    expect(mbtiles.getTile(z: 20, x: 123, y: 456), isNull);
    mbtiles.dispose();
  });
  test('Create Database', () {
    final file = File('tmp.mbtiles');
    final mbTiles = MbTiles.create(
      mbtilesPath: file.path,
      sqlitePath: sqliteLibPath,
      metadata: const MbTilesMetadata(name: 'TestFile', format: 'pbf'),
    );
    mbTiles.putTile(z: 0, x: 0, y: 0, bytes: Uint8List(0));
    mbTiles.dispose();
    file.deleteSync();
  });
}
