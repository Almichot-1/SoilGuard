import 'package:lists/lists.dart';
import 'package:test/test.dart';

void main() {
  test('', () {
    testContent();
    testModify();
  });
}

WrappedList list(List source) => WrappedList(source);

void testContent() {
  final result = list([0, 1, 2, 3, 4, 5]);
  expect(result, [0, 1, 2, 3, 4, 5], reason: 'WrappedList');
}

void testModify() {
  var result = false;
  try {
    final l = list([0, 1, 2]);
    l[0] = 0;
  } on UnsupportedError {
    result = true;
  }

  expect(result, true, reason: 'WrappedList');

  result = false;
  try {
    final l = list([0, 1, 2]);
    l.length = 0;
  } on UnsupportedError {
    result = true;
  }

  expect(result, true, reason: 'WrappedList');
}
