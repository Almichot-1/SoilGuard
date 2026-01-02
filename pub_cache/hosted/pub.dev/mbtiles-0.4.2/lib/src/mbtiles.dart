import 'dart:typed_data';

import 'package:mbtiles/src/helper/helpers_io.dart'
    if (dart.library.js_util) 'package:mbtiles/src/helper/helpers_web.dart';
import 'package:mbtiles/src/model/mbtiles_metadata.dart';
import 'package:mbtiles/src/repository/metadata.dart';
import 'package:mbtiles/src/repository/tiles.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart'
    if (dart.library.js_util) 'package:sqlite3/wasm.dart';

class MbTiles {
  static const _notEditableAssertMsg =
      'Database not editable, please set the parameter '
      '`MBTiles(..., editable: true).';
  late final CommonDatabase _database;
  late final MetadataRepository _metadataRepo;
  late final TilesRepository _tileRepo;

  /// Set to true if the mbtiles database can be modified, defaults to false.
  ///
  /// If the archive is not marked as editable the SQLite database gets opened
  /// as read-only.
  final bool editable;

  /// cached metadata values
  MbTilesMetadata? _metadata;

  /// Open a MBTiles file.
  /// Use the [sqlitePath] parameter if you don't use the
  /// `sqlite3_flutter_libs` package.
  ///
  /// Set [gzip] to true if the format of the mbtiles file is pbf / mvt and the
  /// tile data is gzip encoded.
  /// This flag is optional and defaults to true if the format is pbf and to
  /// false otherwise.
  MbTiles({
    required String mbtilesPath,
    String? sqlitePath,
    bool? gzip,
    this.editable = false,
  }) {
    if (_kIsWeb) throw UnimplementedError('Web is not supported');

    loadSqLiteLib(sqlitePath);

    _database = sqlite3.open(
      mbtilesPath,
      mode: editable ? OpenMode.readWriteCreate : OpenMode.readOnly,
    );
    _metadataRepo = MetadataRepository(database: _database);
    _tileRepo = TilesRepository(
      database: _database,
      useGzip: gzip ?? getMetadata().format == 'pbf',
    );
  }

  /// Open a MBTiles file.
  /// Use the [sqlitePath] parameter if you don't use the
  /// `sqlite3_flutter_libs` package.
  /// Set [isPBF] to true if the format of the mbtiles file is vector pbf. This
  /// flag is optional but will gain a small performance benefit at the begin.
  MbTiles.create({
    required String mbtilesPath,
    required MbTilesMetadata metadata,
    String? sqlitePath,
  }) : editable = true {
    if (_kIsWeb) throw UnimplementedError('Web is not supported');

    loadSqLiteLib(sqlitePath);

    _database = sqlite3.open(
      mbtilesPath,
      mode: editable ? OpenMode.readWriteCreate : OpenMode.readOnly,
    );
    _metadataRepo = MetadataRepository(database: _database);
    _tileRepo = TilesRepository(
      database: _database,
      useGzip: metadata.format == 'pbf',
    );

    createTables();
    setMetadata(metadata);
  }

  /// Cached metadata that is stored inside the mbtiles file.
  MbTilesMetadata getMetadata({bool allowCache = true}) {
    if (_metadata != null && allowCache) return _metadata!;
    return _metadata = _metadataRepo.getAll();
  }

  /// Fetch the data for a tile, returns null if the tile is not found.
  Uint8List? getTile({
    required int z,
    required int x,
    required int y,
  }) =>
      _tileRepo.getTile(z, x, y);

  /// Create all tables for the mbtiles file.
  ///
  /// Requires [editable] to be true.
  void createTables() {
    assert(editable, _notEditableAssertMsg);
    _metadataRepo.createTable();
    _tileRepo.createTable();
  }

  /// Inserts or updates a tile.
  ///
  /// Requires [editable] to be true.
  void putTile({
    required int z,
    required int x,
    required int y,
    required Uint8List bytes,
  }) {
    assert(editable, _notEditableAssertMsg);
    _tileRepo.putTile(z, x, y, bytes);
  }

  /// Set the metadata of the MBTiles file.
  ///
  /// Requires [editable] to be true.
  void setMetadata(MbTilesMetadata metadata) {
    assert(editable, _notEditableAssertMsg);
    _metadataRepo.putAll(metadata);
  }

  /// Call dispose to correctly close the sqlite database
  void dispose() {
    _tileRepo.dispose();
    _database.dispose();
  }
}

const bool _kIsWeb = bool.fromEnvironment('dart.library.js_util');

@Deprecated('MBTiles has been renamed to MbTiles')
typedef MBTiles = MbTiles;
