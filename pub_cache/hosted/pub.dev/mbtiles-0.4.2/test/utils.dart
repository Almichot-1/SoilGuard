import 'dart:io';

final sqliteLibPath = switch (Platform.operatingSystem) {
  'windows' => r'example\assets\windows\sqlite3.dll',
  'macos' => 'example/assets/macos/sqlite3',
  'linux' => 'example/assets/linux/sqlite3',
  String() => throw Exception(
      'The example program is dart-only and running it on flutter is '
      'not supported.\n'
      'If you want to use this package in a flutter app, head over to '
      'the package documentation!',
    ),
};

const mbtilesDirPath = 'example/assets/mbtiles';

const vectorMbtilesPath = '$mbtilesDirPath/countries-vector.mbtiles';
const rasterMbtilesPath = '$mbtilesDirPath/countries-raster.mbtiles';
