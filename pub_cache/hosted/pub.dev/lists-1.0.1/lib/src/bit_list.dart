part of lists;

class BitList extends Object with ListMixin<bool> {
  /// Length of list.
  @override
  final int length;

  late final List<int> _list;

  BitList(this.length, [bool fill = false]) {
    if (length < 0) {
      throw ArgumentError('length should not be negative: $length');
    }

    final slots = (length - 1) ~/ 30 + 1;

    if (fill == true) {
      _list = List<int>.filled(slots, 0x3fffffff);
    } else {
      _list = List<int>.filled(slots, 0);
    }
  }

  /// Sets the length of list.
  @alwaysThrows
  @override
  set length(int length) {
    throw UnsupportedError('length=');
  }

  @override
  bool operator [](int index) {
    if (index < 0 || index >= length) {
      throw RangeError(index);
    }

    final slot = index ~/ 30;
    final position = slot * 30;
    final mask = 1 << (index - position);
    return (_list[slot] & mask) != 0;
  }

  @override
  void operator []=(int index, bool value) {
    if (index < 0 || index >= length) {
      throw RangeError(index);
    }

    final slot = index ~/ 30;
    final position = slot * 30;
    final mask = 1 << (index - position);

    if (value) {
      _list[slot] |= mask;
    } else {
      _list[slot] &= 0x3fffffff ^ mask;
    }
  }

  /// Returns the state at specified [index].
  bool get(int index) => this[index];

  /// Resets the state to false at specified [index].
  void reset(int index) {
    this[index] = false;
  }

  /// Sets the state to true at specified [index].
  void set(int index) {
    this[index] = true;
  }
}
