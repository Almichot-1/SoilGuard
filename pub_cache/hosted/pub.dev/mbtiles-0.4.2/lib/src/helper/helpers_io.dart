import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/open.dart';

/// Use the sqlite3 library from the provided path
void loadSqLiteLib(String? sqlitePath) {
  if (sqlitePath != null) {
    open.overrideForAll(() => DynamicLibrary.open(sqlitePath));
  }
}

extension U8intListExtension on Uint8List {
  Uint8List gzipEncode() => gzip.encode(this) as Uint8List;

  Uint8List gzipDecode() => gzip.decode(this) as Uint8List;
}
