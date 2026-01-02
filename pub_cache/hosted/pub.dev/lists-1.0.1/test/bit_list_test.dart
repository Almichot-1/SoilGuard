import 'package:lists/lists.dart';
import 'package:test/test.dart';

void main() {
  test('bit list', testContent);
}

BitList list(int length, [bool fill = false]) => BitList(length, fill);

void testContent() {
  var result = list(3);
  expect(result, [false, false, false], reason: 'BitList');
  result = list(3, false);
  expect(result, [false, false, false], reason: 'BitList');
  result = list(3, true);
  expect(result, [true, true, true], reason: 'BitList');
  final count = 128;
  var bits = list(count);
  for (var i = 0; i < count; i++) {
    expect(bits[i], false, reason: 'BitList.[$i]');
    bits[i] = true;
    expect(bits[i], true, reason: 'BitList.[$i]');
    bits[i] = false;
    expect(bits[i], false, reason: 'BitList.[$i]');
  }

  bits = list(count);
  for (var i = 0; i < count; i++) {
    expect(bits.get(i), false, reason: 'BitList.[$i]');
    bits.set(i);
    expect(bits.get(i), true, reason: 'BitList.[$i]');
    bits.reset(i);
    expect(bits.get(i), false, reason: 'BitList.[$i]');
  }
}
