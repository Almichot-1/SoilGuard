import 'package:unicode/unicode.dart' as unicode;

void main(List<String> args) {
  var ch = unicode.toRune('я');
  if (unicode.isLowercaseLetter(ch)) {
    print(char2Str(ch) + ' is lowercase letter');
  }

  ch = unicode.toRune('{');
  if (unicode.isOpenPunctuation(ch)) {
    print(char2Str(ch) + ' is open punctuation');
  }

  ch = unicode.toRune('©');
  if (unicode.isOtherSymbol(ch)) {
    print(char2Str(ch) + ' is other symbol');
  }

  ch = unicode.toRune('ǁ');
  if (unicode.isOtherLetter(ch)) {
    print(char2Str(ch) + ' is other letter');
  }
}

String char2Str(int c) {
  return String.fromCharCode(c);
}
