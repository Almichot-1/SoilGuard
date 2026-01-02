import 'package:lists/lists.dart';
import 'package:test/test.dart';

void main() {
  test('', () {
    testContains();
    testIterable();
    testLength();
    testList();
    testReversed();
  });
}

StepList list(int start, int end, [int? step]) => StepList(start, end, step);

void testContains() {
  var result = list(0, -100, -3).contains(-3);
  expect(result, true, reason: 'StepList.contains');
  result = list(0, -100, -3).contains(3);
  expect(result, false, reason: 'StepList.contains');
  result = list(0, -100, 3).contains(3);
  expect(result, false, reason: 'StepList.contains');
  result = list(0, -100, 3).contains(-3);
  expect(result, false, reason: 'StepList.contains');
  result = list(0, 100, -3).contains(-3);
  expect(result, false, reason: 'StepList.contains');
  result = list(0, 100, -3).contains(3);
  expect(result, false, reason: 'StepList.contains');
  result = list(0, 100, 3).contains(3);
  expect(result, true, reason: 'StepList.contains');
  result = list(0, 100, 3).contains(-3);
  expect(result, false, reason: 'StepList.contains');
}

void testIterable() {
  final result = list(1, 100, 4);
  expect(result is Iterable<int>, true, reason: 'StepList is Iterable<int>');
  var i = result.start;
  for (var value in result) {
    expect(value, i, reason: 'RangeList.current');
    i += 4;
  }
}

void testLength() {
  var result = list(0, 127).length;
  expect(result, 128, reason: 'StepList.length');
  result = list(0, 127, 1).length;
  expect(result, 128, reason: 'StepList.length');
  result = list(127, 0).length;
  expect(result, 128, reason: 'StepList.length');
  result = list(127, 0, -1).length;
  expect(result, 128, reason: 'StepList.length');
  result = list(0, 99, 4).length;
  expect(result, 25, reason: 'StepList.length');
  result = list(-100, -1, 4).length;
  expect(result, 25, reason: 'StepList.length');
}

void testList() {
  final result = list(0, 49, 10);
  expect(result is List<int>, true, reason: 'StepList is List<int>');
  for (var i = 0, index = 0; i <= 49; i += 10, index++) {
    expect(result[index], i, reason: 'StepList[$index]');
  }
}

void testReversed() {
  final result = list(0, 6, 2).reversed;
  expect(result, [6, 4, 2, 0], reason: 'StepList.reversed');
}
