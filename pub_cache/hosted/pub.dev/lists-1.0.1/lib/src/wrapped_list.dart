part of lists;

class WrappedList<E> extends Object with ListMixin<E> {
  final List<E> _source;

  WrappedList(this._source);

  /// Returns the length of list.
  @override
  int get length => _source.length;

  /// Sets the length of list.
  @alwaysThrows
  @override
  set length(int length) {
    throw UnsupportedError('length=');
  }

  @override
  E operator [](int index) => _source[index];

  @alwaysThrows
  @override
  void operator []=(int index, E value) {
    throw UnsupportedError('operator []=');
  }

  /// Returns the string representation of range.
  @override
  String toString() => _source.toString();
}
