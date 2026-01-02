part of lists;

/// Range list.
@immutable
class RangeList extends Object with ListMixin<int> {
  final int end;

  @override
  final int hashCode;

  final int start;

  late final int _length;

  RangeList(int start, int end)
      : hashCode = start.hashCode | end.hashCode,
        start = start,
        end = end {
    if (start > end) {
      throw ArgumentError(
          'The value of the argument \'start\' is greater than the value of the argument \'end\': $this');
    }

    _length = end - start + 1;
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
  RangeList operator +(List<int> other) {
    if (other is! RangeList) {
      throw ArgumentError('other: $other');
    }

    int start;
    int end;
    final otherRange = other;
    if (this.start < otherRange.start) {
      start = this.start;
    } else {
      start = otherRange.start;
    }

    if (this.end > otherRange.end) {
      end = this.end;
    } else {
      end = otherRange.end;
    }

    return RangeList(start, end);
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is RangeList) {
      return start == other.start && end == other.end;
    }

    return false;
  }

  @override
  int operator [](int index) {
    if (index < 0 || index >= _length) {
      throw RangeError(index);
    }

    return start + index;
  }

  @alwaysThrows
  @override
  void operator []=(int index, int value) {
    throw UnsupportedError('operator []=');
  }

  /// Returns true if range list contains the [value]; otherwise false.
  @override
  bool contains(Object? value) {
    if (value == null || value is! int || value > end || value < start) {
      return false;
    }

    return true;
  }

  /// Returns true if this range list includes [other]; otherwise false.
  bool includes(RangeList other) {
    return (other.start >= start && other.start <= end) &&
        (other.end >= start && other.end <= end);
  }

  /// Returns true if this range list intersect [other]; otherwise false.
  bool intersect(RangeList other) {
    return (start <= other.start && end >= other.start) ||
        (other.start <= start && other.end >= start);
  }

  /// Returns the intersection of this range list and the [other] range list;
  /// otherwise null.
  RangeList? intersection(RangeList other) {
    if (!intersect(other)) {
      return null;
    }

    if (this == other) {
      return RangeList(this.start, this.end);
    }

    var start = this.start;
    if (other.start > start) {
      start = other.start;
    }

    var end = this.end;
    if (other.end < end) {
      end = other.end;
    }

    return RangeList(start, end);
  }

  /// Subtracts from this range the [other] range and returns the the resulting
  /// ranges.
  List<RangeList> subtract(RangeList other) {
    final result = <RangeList>[];
    if (!intersect(other)) {
      return result;
    }

    if (start < other.start) {
      result.add(RangeList(start, other.start - 1));
    }

    if (other.end < end) {
      result.add(RangeList(other.end + 1, end));
    }

    return result;
  }

  /// Returns the list of elements with specified step.
  StepList toStepList(int step) => StepList(start, end, step);

  /// Returns the string representation of range list.
  @override
  String toString() {
    return '[$start..$end]';
  }
}
