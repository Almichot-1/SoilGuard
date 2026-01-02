part of lists;

class StepList extends Object with ListMixin<int> {
  final int end;

  final int start;

  late final int _length;

  late final int _step;

  StepList(this.start, this.end, [int? step]) {
    if (step == 0) {
      throw ArgumentError('step: $step');
    }

    final count = end - start;
    if (step == null) {
      if (count > 0) {
        _step = 1;
      } else {
        _step = -1;
      }
    } else {
      _step = step;
    }

    final tempLength = count ~/ _step;
    if (tempLength < 1) {
      _length = 1;
    } else {
      _length = tempLength + 1;
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

  /// Returns the step.
  int get step => _step;

  @override
  int operator [](int index) {
    if (index < 0 || index >= _length) {
      throw RangeError(index);
    }

    return start + step * index;
  }

  @alwaysThrows
  @override
  void operator []=(int index, int value) {
    throw UnsupportedError('operator []=');
  }

  /// Returns true if list contains the [value]; otherwise false.
  @override
  bool contains(value) {
    if (value == null || value is! int) {
      return false;
    }

    if (_length == 1) {
      return value == start;
    }

    final position = value - start;
    final index = position ~/ step;
    if (index >= 0 && index < _length) {
      if (position % index == 0) {
        return true;
      }
    }

    return false;
  }

  /// Returns the string representation of range.
  @override
  String toString() {
    if (step > 0) {
      return '[$start..$end; +$step]';
    } else {
      return '[$start..$end; $step]';
    }
  }
}
