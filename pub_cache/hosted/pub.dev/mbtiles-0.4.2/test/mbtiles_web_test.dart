import 'package:mbtiles/mbtiles.dart';
import 'package:test/test.dart';

const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

void main() {
  test('Test compilation for web', () {
    if (!kIsWeb) return;

    expect(
      () => MbTiles(mbtilesPath: 'noRealFile.mbtiles'),
      throwsA(const TypeMatcher<UnimplementedError>()),
    );

    expect(
      () => MbTiles.create(
        mbtilesPath: 'noRealFile.mbtiles',
        metadata: const MbTilesMetadata(name: 'Test', format: 'pbf'),
      ),
      throwsA(const TypeMatcher<UnimplementedError>()),
    );
  });
}
