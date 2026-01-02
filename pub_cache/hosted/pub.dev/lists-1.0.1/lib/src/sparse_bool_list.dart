part of lists;

/// Sparse bool list based on the grouped range lists.
class SparseBoolList extends SparseList<bool> {
  SparseBoolList() : super(defaultValue: false);

  SparseBoolList.fixed(int length) : super.fixed(length, defaultValue: false);

  /// Sets the values ​​in accordance with the specified [group] and increases
  /// (if required) the length up to (range.end + 1).
  @override
  void addGroup(GroupedRangeList<bool> group) {
    if (group.key is! bool) {
      throw ArgumentError("Key '${group.key}' must be of type 'bool'.");
    }

    super.addGroup(group);
  }

  /// Sets the values ​​in accordance with the specified [group].
  @override
  void setGroup(GroupedRangeList<bool> group) {
    if (group.key is! bool) {
      throw ArgumentError("Key '${group.key}' must be of type 'bool'.");
    }

    super.setGroup(group);
  }

  @override
  bool operator [](int index) {
    return super[index]!;
  }
}
