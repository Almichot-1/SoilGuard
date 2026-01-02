import 'dart:ffi';

import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:mbtiles/src/repository/metadata.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  test('Put and get Metadata', () {
    // given
    const metadata1 = MbTilesMetadata(
      name: 'Example MBTiles',
      format: 'pbf',
      minZoom: 1,
      maxZoom: 12,
      version: 23,
      json: "{}",
      description: "A small description",
      defaultZoom: 6,
      defaultCenter: LatLng(47, 9),
      type: TileLayerType.baseLayer,
      attributionHtml: "Not a real attribution message",
      bounds: MbTilesBounds(bottom: -180, left: -90, top: 180, right: 90),
    );
    open.overrideForAll(() => DynamicLibrary.open(sqliteLibPath));
    final database = sqlite3.openInMemory();
    final repo = MetadataRepository(database: database);

    // when
    repo.createTable();
    repo.putAll(metadata1);
    final metadata2 = repo.getAll();

    // then
    expect(metadata2, equals(metadata1));
  });
  test('Metadata toString', () {
    // given
    const metadata1 = MbTilesMetadata(
      name: 'Example MBTiles',
      format: 'pbf',
      minZoom: 1,
      maxZoom: 12,
      version: 23,
      json: "{}",
      description: "A small description",
      defaultZoom: 6,
      defaultCenter: LatLng(47, 9),
      attributionHtml: "Not a real attribution message",
      type: TileLayerType.baseLayer,
      bounds: MbTilesBounds(bottom: -180, left: -90, top: 180, right: 90),
    );
    expect(metadata1.toString(), contains('Example MBTiles'));
    expect(metadata1.toString(), contains('A small description'));
    expect(metadata1.toString(), contains('Not a real attribution message'));
    expect(metadata1.toString(), contains('baselayer'));
  });
  test('Metadata hashCode equals', () {
    // given
    const metadata1 = MbTilesMetadata(
      name: 'Example MBTiles',
      format: 'pbf',
      minZoom: 1,
      maxZoom: 12,
      version: 23,
      json: "{}",
      description: "A small description",
      defaultZoom: 6,
      defaultCenter: LatLng(47, 9),
      attributionHtml: "Not a real attribution message",
      bounds: MbTilesBounds(bottom: -180, left: -90, top: 180, right: 90),
    );
    const metadata2 = MbTilesMetadata(
      name: 'Example MBTiles',
      format: 'pbf',
      minZoom: 1,
      maxZoom: 12,
      version: 23,
      json: "{}",
      description: "A small description",
      defaultZoom: 6,
      defaultCenter: LatLng(47, 9),
      attributionHtml: "Not a real attribution message",
      bounds: MbTilesBounds(bottom: -180, left: -90, top: 180, right: 90),
    );
    expect(metadata1.hashCode, equals(metadata2.hashCode));
  });
  test('Metadata hashCode not equal', () {
    // given
    const metadata1 = MbTilesMetadata(
      name: 'Example MBTiles',
      format: 'pbf',
      minZoom: 1,
      maxZoom: 12,
      version: 23,
      json: "{}",
      description: "A small description",
      defaultZoom: 6,
      defaultCenter: LatLng(47, 9),
      attributionHtml: "Not a real attribution message",
      bounds: MbTilesBounds(bottom: -180, left: -90, top: 180, right: 90),
    );
    const metadata2 = MbTilesMetadata(
      name: 'Example MBTiles2',
      format: 'pbf',
      minZoom: 1,
      maxZoom: 12,
      version: 23,
      json: "{}",
      description: "A small description",
      defaultZoom: 6,
      defaultCenter: LatLng(47, 9),
      attributionHtml: "Not a real attribution message",
      bounds: MbTilesBounds(bottom: -180, left: -90, top: 180, right: 90),
    );
    expect(metadata1.hashCode != metadata2.hashCode, isTrue);
  });
}
