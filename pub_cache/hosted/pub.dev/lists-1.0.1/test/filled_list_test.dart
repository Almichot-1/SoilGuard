import 'package:lists/lists.dart';
import 'package:test/test.dart';

void main() {
  test('', testContent);
}

FilledList list(int length, fill) => FilledList(length, fill);

void testContent() {
  final result = list(5, '1');
  expect(result, ['1', '1', '1', '1', '1'], reason: 'FilledList');
}
