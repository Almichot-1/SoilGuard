part of lists;

/// Sparse list based on the grouped range lists.
// TODO: sublist
// TODO: toList
class SparseList<E extends Object> extends Object with ListMixin<E?> {
  final E? defaultValue;

  late final bool Function(E?, E?) _equals;

  late final bool _fixedLength;

  bool _frozen = false;

  final List<GroupedRangeList<E>> _groups = <GroupedRangeList<E>>[];

  late int _length;

  SparseList({
    this.defaultValue,
    bool Function(E? e1, E? e2)? equals,
  }) {
    _length = 0;
    _fixedLength = false;

    if (equals != null) {
      _equals = equals;
    } else {
      _equals = (E? e1, E? e2) => e1 == e2;
    }
  }

  SparseList.fixed(
    this._length, {
    this.defaultValue,
    bool Function(E? e1, E? e2)? equals,
  }) {
    if (_length < 0) {
      throw ArgumentError('length should not be negative: $length');
    }

    _fixedLength = true;

    if (equals != null) {
      _equals = equals;
    } else {
      _equals = (E? e1, E? e2) => e1 == e2;
    }
  }

  /// Returns the 'end' value from the last group (if available); otherwise null.
  int? get end {
    if (_groups.isEmpty) {
      return null;
    }

    return _groups.last.end;
  }

  /// Returns true if the list is frozen; otherwise false.
  bool get frozen {
    return _frozen;
  }

  /// Returns the number of groups.
  int get groupCount => _groups.length;

  /// Returns a read-only list of the groups.
  List<GroupedRangeList<E>> get groups =>
      List<GroupedRangeList<E>>.unmodifiable(_groups);

  /// Returns the length of list.
  @override
  int get length => _length;

  /// Sets the length of list.
  @override
  set length(int newLength) {
    if (_fixedLength) {
      throw StateError('Unable to set the length of a fixed list.');
    }

    if (frozen) {
      _errorModificationNotAllowed();
    }

    if (newLength < 0) {
      throw RangeError(newLength);
    }

    if (_length == newLength) {
      return;
    }

    if (newLength < _length) {
      _resetValues(RangeList(newLength, _length - 1));
    } else if (newLength == 0) {
      _groups.clear();
    }

    _length = newLength;
  }

  /// Returns the 'start' value from the first group (if available); otherwise
  /// null.
  int? get start {
    if (_groups.isEmpty) {
      return null;
    }

    return _groups.first.start;
  }

  @override
  E? operator [](int index) {
    if (index < 0 || index >= _length) {
      throw RangeError(index);
    }

    if (_groups.isEmpty) return defaultValue;

    var right = _groups.length;

    if (right == 1) {
      final group = _groups.first;

      if (index <= group.end && index >= group.start) {
        return group.key;
      } else {
        return defaultValue;
      }
    }

    var left = 0;
    final key = index;
    int middle;
    final value = defaultValue;

    while (left < right) {
      middle = (left + right) >> 1;

      final group = _groups[middle];

      if (group.end < key) {
        left = middle + 1;
      } else {
        if (key >= group.start) {
          return group.key;
        }

        right = middle;
      }
    }

    return value;
  }

  @override
  void operator []=(int index, E? value) {
    if (frozen) {
      _errorModificationNotAllowed();
    }

    if (index < 0 || index >= _length) {
      throw RangeError(index);
    }

    if (value == null && defaultValue != null) {
      ArgumentError(
          "Collection can\'t contains null because default value is not null.");
    }

    if (_equals(value, defaultValue)) {
      _resetValues(RangeList(index, index));
    } else {
      setGroup(GroupedRangeList<E>(index, index, value!));
    }
  }

  /// Sets the values ​​in accordance with the specified [group] and increases
  /// (if required) the length up to (range.end + 1).
  void addGroup(GroupedRangeList<E> group) {
    if (_fixedLength) {
      throw StateError('Unable to add the group into fixed list.');
    }

    if (frozen) {
      _errorModificationNotAllowed();
    }

    if (group.start < 0) {
      throw RangeError(group.start);
    }

    _setGroup(group);

    if (_length < group.end + 1) {
      _length = group.end + 1;
    }
  }

  /// Makes the list unmodifiable.
  void freeze() {
    _frozen = true;
  }

  /// Returns all groups that intersects with the specified [range] which being
  /// expanded (with default value) or shrunk to specified [range].
  List<GroupedRangeList<E?>> getAlignedGroups(RangeList range) {
    final intersecGroups =
        getGroups(range).cast<GroupedRangeList<E?>>().toList();

    if (intersecGroups.isEmpty) {
      return [GroupedRangeList<E?>(range.start, range.end, defaultValue)];
    }

    final first = intersecGroups.first;

    if (range.start > first.start) {
      intersecGroups[0] = first.intersection(range)!;
    } else if (range.start < first.start) {
      final insertion =
          GroupedRangeList<E?>(range.start, first.start - 1, defaultValue);
      intersecGroups.insert(0, insertion);
    }

    final last = intersecGroups.last;

    if (range.end > last.end) {
      final addition =
          GroupedRangeList<E?>(last.end + 1, range.end, defaultValue);
      intersecGroups.add(addition);
    } else if (range.end < last.end) {
      intersecGroups[intersecGroups.length - 1] = last.intersection(range)!;
    }

    return intersecGroups;
  }

  /// Returns all space as groups (including synthetic groups with default
  /// values from not filled space) that intersects with the specified [range]
  /// which being expanded (with default value) or shrunk to specified [range].
  List<GroupedRangeList<E?>> getAllSpace(RangeList range) {
    final groups = <GroupedRangeList<E?>>[];
    GroupedRangeList<E?>? previous;

    for (final group in getAlignedGroups(range)) {
      if (previous != null) {
        final start = previous.end + 1;
        final delta = group.start - start;
        if (delta > 0) {
          // Adds the synthetic group
          groups
              .add(GroupedRangeList<E?>(start, group.start - 1, defaultValue));
        }
      }

      groups.add(group);
      previous = group;
    }

    return groups;
  }

  /// Returns all groups that intersects with the specified [range].
  Iterable<GroupedRangeList<E>> getGroups([RangeList? range]) {
    if (range == null) {
      return _groups.getRange(0, _groups.length);
    }

    final length = _groups.length;
    final left = _findNearestIndex(0, length, range.start);
    var firstIndex = -1;
    var lastIndex = -1;
    for (var i = left; i < length; i++) {
      if (_groups[i].intersect(range)) {
        if (firstIndex == -1) {
          firstIndex = i;
          lastIndex = i;
        } else {
          lastIndex = i;
        }
      } else if (firstIndex != -1) {
        break;
      }
    }

    if (firstIndex == -1) {
      return <GroupedRangeList<E>>[];
    }

    return _groups.getRange(firstIndex, lastIndex + 1);
  }

  /// Returns the indexes of the elements with a value.
  Iterable<int> getIndexes() {
    Iterable<int> generator() sync* {
      for (final group in groups) {
        final end = group.end;
        for (var i = group.start; i <= end; i++) {
          yield i;
        }
      }
    }

    return generator();
  }

  /// Removes the values in the specified range and decreases (if possible) the
  /// length down to (range.start).
  void removeValues(RangeList range) {
    if (_fixedLength) {
      throw StateError('Unable to remove the values from a fixed list.');
    }

    if (frozen) {
      _errorModificationNotAllowed();
    }

    if (range.start < 0) {
      throw RangeError(range.start);
    }

    _resetValues(range);
    if (_groups.isEmpty) {
      if (_length > range.start) {
        _length = range.start;
      }
    } else {
      var length = _groups.last.end + 1;
      if (length > range.start && length < range.end) {
        length = range.start;
      }

      _length = length;
    }
  }

  /// Resets the values in the specified [range] to the default values.
  void resetValues(RangeList range) {
    if (frozen) {
      _errorModificationNotAllowed();
    }

    if (range.start < 0 || range.start >= _length) {
      throw RangeError(range.start);
    }

    if (range.end >= _length) {
      throw RangeError(range.end);
    }

    _resetValues(range);
  }

  /// Sets the values ​​in accordance with the specified [group].
  void setGroup(GroupedRangeList<E> group) {
    if (frozen) {
      _errorModificationNotAllowed();
    }

    if (group.start < 0 || group.start >= _length) {
      throw RangeError(group.start);
    }

    if (group.end >= _length) {
      throw RangeError(group.end);
    }

    _setGroup(group);
  }

  /// Sets the length of list equal to the last not empty index + 1; otherwise
  /// sets the length to 0.
  void trim() {
    if (_fixedLength) {
      throw StateError('Unable to trim a fixed list.');
    }

    if (frozen) {
      _errorModificationNotAllowed();
    }

    final groupCount = _groups.length;
    if (groupCount == 0) {
      _length = 0;
    } else {
      _length = _groups[groupCount - 1].end + 1;
    }
  }

  void _errorModificationNotAllowed() {
    throw StateError('Unable to modify the frozen list.');
  }

  int _findNearestIndex(int left, int right, int key) {
    if (right == 0) {
      return 0;
    }

    int middle;
    while (left < right) {
      middle = (left + right) >> 1;
      if (_groups[middle].end < key) {
        left = middle + 1;
      } else {
        right = middle;
      }
    }

    if (left > 0) {
      left--;
    }

    return left;
  }

  void _resetValues(RangeList range) {
    final rangeStart = range.start;
    final rangeEnd = range.end;
    final length = _groups.length;
    final left = _findNearestIndex(0, length, range.start);
    var count = 0;
    final newGroups = <GroupedRangeList<E>>[];
    for (var i = left; i < length; i++) {
      final current = _groups[i];
      final start = current.start;
      if (start > rangeEnd) {
        break;
      }

      final intersect = current.intersect(range);
      if (intersect) {
        final end = current.end;
        final key = current.key;
        if (start < rangeStart) {
          final newGroup = GroupedRangeList<E>(start, rangeStart - 1, key);
          newGroups.add(newGroup);
        }

        if (end > rangeEnd) {
          final newGroup = GroupedRangeList<E>(rangeEnd + 1, end, key);
          newGroups.add(newGroup);
        }
      } else {
        newGroups.add(current);
      }

      count++;
    }

    _groups.removeRange(left, left + count);
    _groups.insertAll(left, newGroups);
  }

  void _setGroup(GroupedRangeList<E> group) {
    final groupKey = group.key;
    final length = _groups.length;
    if (length == 0) {
      _groups.add(group);
      return;
    }

    final groupStart = group.start;
    final lastEnd = _groups.last.end;
    int left;
    if (groupStart == lastEnd + 1) {
      left = length - 1;
    } else if (groupStart > lastEnd) {
      _groups.add(group);
      return;
    } else {
      left = _findNearestIndex(0, length, group.start);
    }

    final groupEnd = group.end;
    var count = 0;
    final newGroups = <GroupedRangeList<E>>[];
    for (var i = left; i < length; i++) {
      final current = _groups[i];
      final start = current.start;
      if (start > groupEnd + 1) {
        break;
      }

      final end = current.end;
      final key = current.key;
      final intersect = current.intersect(group);
      if (intersect) {
        if (start < groupStart) {
          if (_equals(key, groupKey)) {
            group = GroupedRangeList<E>(start, groupEnd, groupKey);
          } else {
            final newGroup = GroupedRangeList<E>(start, groupStart - 1, key);
            newGroups.add(newGroup);
          }
        }

        if (end > groupEnd) {
          if (_equals(key, groupKey)) {
            group = GroupedRangeList<E>(groupStart, end, key);
          } else {
            final newGroup = GroupedRangeList<E>(groupEnd + 1, end, key);
            newGroups.add(newGroup);
          }
        }
      } else {
        if (_equals(key, groupKey)) {
          if (groupStart == end + 1) {
            group = GroupedRangeList<E>(start, groupEnd, key);
          } else if (start == groupEnd + 1) {
            group = GroupedRangeList<E>(groupStart, end, key);
          } else {
            newGroups.add(current);
          }
        } else {
          newGroups.add(current);
        }
      }

      count++;
    }

    newGroups.add(group);
    newGroups.sort((a, b) => a.start.compareTo(b.start));
    _groups.removeRange(left, left + count);
    _groups.insertAll(
        left, newGroups.where((e) => !_equals(e.key, defaultValue)));
  }
}
