import 'package:unicode/unicode.dart' as unicode;
import 'package:test/test.dart';

void main() {
  test('Unicode', () {
    testCharacterSets();
    testIsXXX();
    testSimpleCasing();
    testToCase();
    testUnassigned();
  });
}

void testCharacterSets() {
  //
  var subject = 'uppercaseLetterCharacters';
  var character = 65; // A
  var result = unicode.uppercaseLetterCharacters[character];
  expect(result, true, reason: subject);
}

void testIsXXX() {
  //
  var subject = 'isUppercaseLetter';
  var character = 65; // A
  var result = unicode.isUppercaseLetter(character);
  expect(result, true, reason: subject);
  //
  subject = 'isUppercaseLetter';
  character = unicode.toRune('Я'); // Я
  result = unicode.isUppercaseLetter(character);
  expect(result, true, reason: subject);
  //
  subject = 'isLowercaseLetter';
  character = 97; // a
  result = unicode.isLowercaseLetter(character);
  expect(result, true, reason: subject);
  //
  subject = 'isLowercaseLetter';
  character = unicode.toRune('я'); // я
  result = unicode.isLowercaseLetter(character);
  expect(result, true, reason: subject);
  //
  subject = 'isOtherLetter';
  character = 0x3400;
  result = unicode.isOtherLetter(character);
  expect(result, true, reason: subject);
  //
  subject = 'isOtherLetter';
  character = 0x4db5;
  result = unicode.isOtherLetter(character);
  expect(result, true, reason: subject);
}

void testSimpleCasing() {
  //
  var subject = 'simpleLowercaseMapping';
  var character = unicode.toRune('Я');
  var result = unicode.simpleLowercaseMapping[character];
  expect(result, unicode.toRune('я'), reason: subject);
  //
  subject = 'simpleUppercaseMapping';
  character = unicode.toRune('я');
  result = unicode.simpleUppercaseMapping[character];
  result = unicode.simpleUppercaseMapping[character];
  expect(result, unicode.toRune('Я'), reason: subject);
  //
  subject = 'simpleTitlecaseMapping';
  character = unicode.toRune('я');
  result = unicode.simpleTitlecaseMapping[character];
  result = unicode.simpleTitlecaseMapping[character];
  expect(result, unicode.toRune('Я'), reason: subject);
}

void testToCase() {
  //
  var subject = 'toLowercase';
  var string = 'Привет, Андрей!';
  var result = unicode.toLowercase(string);
  expect(result, 'привет, андрей!', reason: subject);
  //
  subject = 'toUppercase';
  string = 'Привет, Андрей!';
  result = unicode.toUppercase(string);
  expect(result, 'ПРИВЕТ, АНДРЕЙ!', reason: subject);
  //
  subject = 'toTitlecase';
  string = 'Привет, Андрей!';
  result = unicode.toTitlecase(string);
  expect(result, 'ПРИВЕТ, АНДРЕЙ!', reason: subject);
  // Performance
  var count = 1000000;
  string = 'Привет, Андрей!';
  measure('String.toUpperCase()', () {
    for (var i = 0; i < count; i++) {
      string.toUpperCase();
    }
  });

  measure('unicode.toUppercase(string)', () {
    for (var i = 0; i < count; i++) {
      unicode.toLowercase(string);
    }
  });
}

void testUnassigned() {
  // Unassigned
  var subject = 'generalCategories';
  var result = unicode.generalCategories[0x378];
  expect(result, unicode.NOT_ASSIGNED, reason: subject);
}

void measure(String msg, Function() f) {
  var sw = Stopwatch();
  sw.start();
  f();
  sw.stop();
  var time = sw.elapsedMicroseconds / 1000000;
  print('$msg: $time sec');
}
