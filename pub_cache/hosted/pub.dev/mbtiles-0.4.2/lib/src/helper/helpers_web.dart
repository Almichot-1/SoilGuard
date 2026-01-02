import 'dart:typed_data';

import 'package:sqlite3/common.dart';

// do nothing

void loadSqLiteLib(String? sqlitePath) {}

extension U8intListExtension on Uint8List {
  Uint8List gzipEncode() => Uint8List(0);

  Uint8List gzipDecode() => Uint8List(0);
}

/// sqlite3 is not defined in the wasm sqlite3 library
const sqlite3 = SqLite3();

class SqLite3 {
  const SqLite3();

  CommonDatabase open(String mbtilesPath, {required OpenMode mode}) {
    throw UnimplementedError();
  }
}
