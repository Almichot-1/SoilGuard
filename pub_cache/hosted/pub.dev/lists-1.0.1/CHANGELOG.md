## 1.0.1

- This package is no longer supported because it was flagged by Google Dart developers as being published by an unknown person. Publisher Unknown. As a normal person, I believe that hardly anyone would want to use software from unknown publishers.

## 1.0.0

- The source code has been migrated to null safety. Thanks to the author of this work, Dmitry (https://github.com/kelegorm).

## 0.1.6

- Added hash code support in `RangeList` implementation

## 0.1.5

- Fixed bug in `SparseList.setGroup()` when the group key is equal to the list default value

## 0.1.4

- Source code changed to be more pedantic

## 0.1.3

- Minor changes

## 0.1.2

- Source code changed to be more pedantic

## 0.1.1

- Added parameter `equals` to constructor `SparseList()` to specify comparison function of complex data structures
- Source code changed to be more pedantic

## 0.1.0

- Algorithm in `SparseList` has been reworked

## 0.0.23

* Fixed strong-mode cast errors.
* Added `increment` to `ListPointer`, which is a type-safe way
to increase the pointer.

## 0.0.22

- Added `strong_mode` option

## 0.0.21

- Added `ListPointer` which can be used effectively when porting the programs written in the C language

## 0.0.20

- Added method `getAllSpace(RangeList range) => List<GroupedRangeList<E>>` to `SparseList<E>`

## 0.0.19

- Added method `getAlignedGroups(RangeList range) => List<GroupedRangeList<E>>` to `SparseList<E>`

## 0.0.18

- Fixed bug in `SparseList.getGroups()`

## 0.0.17

- Added field `frozen => bool` to `SparseList<E>`
- Added method `freeze() => void` to `SparseList<E>`
- `SparseList<E>` now can be frozen

## 0.0.16

- Fixed bug (change length of fixed list) in `SparseList.addGroup()`

## 0.0.15

- Fixed bug (change length of fixed list) in `SparseList.removeValues()`
- Fixed bug (change length of fixed list) in `SparseList.trim()`

## 0.0.14

- Added method `trim() => void` to `SparseList<E>`
- Fixed bug (decrease length) in `SparseList.removeValues()`
- Improved performance of modifications `SparseList<E>`

## 0.0.12

- Fixed bug (decrease length) in `SparseList.removeValues()`

## 0.0.11

- Fixed bug in `SparseList.removeValues()`

## 0.0.10

- Improved performance of modifications `SparseList<E>`
- Removed limitations on the bounds of the range in `SparseList.removeValues()`

## 0.0.9

- Added method `getIndexes() => Iterable<int> ` to `SparseList<E>`

## 0.0.8

- Added field `groups => List<GroupedRangeList<E>>` to `SparseList<E>`

## 0.0.7

- Added field `end => int` to `SparseList<E>` 
- Added field `start => int` to `SparseList<E>`

## 0.0.6

- Added class `SparseBoolList`
- Modified method in `SparseList<E>` from `getGroups(RangeList range)` to `getGroups([RangeList range])`

## 0.0.5

- Improved (up to 15%) the performance of the `SparseList.addGroup()` when the group added to the end

## 0.0.4

- Added class `GroupedRangeList<E>`
- Added class `SparseList<E>`
- Added method `includes(RangeList other) => bool` to `RangeList`
- Added method `intersection(RangeList other) => RangeList` to `RangeList`
- Added method `subtract(RangeList other) => List<RangeList>` to `RangeList`
- Added operator `+(RangeList other) => RangeList` to `RangeList`

