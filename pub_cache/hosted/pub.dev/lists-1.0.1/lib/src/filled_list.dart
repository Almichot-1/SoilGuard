part of lists;

class FilledList<E> extends Object with ListMixin<E> {
  final E _fill;

  final int _length;

  FilledList(this._length, this._fill) {
    if (_length < 0) {
      throw ArgumentError('length should not be negative: $length');
    }
  }

  /// Returns the length of list.
  @override
  int get length => _length;

  /// Sets the length of list.
  @alwaysThrows
  @override
  set length(int length) {
    throw UnsupportedError('length=');
  }

  @override
  E operator [](int index) {
    if (index < 0 || index >= _length) {
      throw RangeError(index);
    }

    return _fill;
  }

  @alwaysThrows
  @override
  void operator []=(int index, E value) {
    throw UnsupportedError('operator []=');
  }
}
