part of 'change_emitter_base.dart';

///A [ChangeEmitter] that implements the list interface. Notifying listeners of changes must be done
///manually by calling [notifyChange] after performing a change on the list. If there haven't been any
///updates to the list since the last time [notifyChange] was called, then
///nothing will happen.
class ListEmitter<E> extends ChangeEmitter<ListChange<E>> with ListMixin<E> {
  final List<E> _list;
  final _changes = <ListModification<E>>[];
  bool _dirty = false;
  final bool _observable;

  ListEmitter(List<E> list, {bool observable = false})
      : _list = List.from(list),
        _observable = observable;

  E operator [](int index) {
    assert(!isDisposed);
    return _list[index];
  }

  operator []=(int index, E value) {
    assert(!isDisposed);
    var oldValue = _list[index];
    if (oldValue != value) {
      _list[index] = value;
      if (_observable)
        _changes.add(ListModification<E>(index, oldValue, value));
      _dirty = true;
    }
  }

  ///The number of objects in this list.
  ///
  ///The valid indices for a list are 0 through length - 1
  int get length {
    assert(!isDisposed);
    return _list.length;
  }

  set length(int newLength) {
    assert(!isDisposed);
    if (newLength > newLength)
      while (length != newLength) add(null);
    else
      while (length != newLength) removeAt(newLength);
  }

  ///Notifies listeners if there has been a change to the list since the last time it was called or the list was initialized.
  void emit({bool quiet = false}) {
    assert(!isDisposed);
    if (_dirty && !quiet)
      addChangeToStream(_observable ? ListChange(_changes) : ListChange.any());
    else if (_dirty)
      addChangeToStream(_observable
          ? ListChange(_changes, quiet: true)
          : ListChange.any(quiet: true));
    _changes.clear();
    _dirty = false;
  }

  ///Adds [value] to the end of this list, extending the length by one.
  ///
  ///Throws an [UnsupportedError] if the list is fixed-length.
  @override
  void add(E element) {
    assert(!isDisposed);
    _list.add(element);
    _dirty = true;
    if (_observable) _changes.add(ListModification.insert(length, element));
  }

  ///Appends all objects of [iterable] to the end of this list.
  ///
  ///Extends the length of the list by the number of objects in [iterable].
  @override
  void addAll(Iterable iterable) {
    assert(!isDisposed);
    for (var elem in iterable) add(elem);
  }

  ///Inserts the object at position [index] in this list.
  ///
  ///This increases the length of the list by one and shifts all objects at or after the index towards the end of the list.
  ///
  ///The [index] value must be non-negative and no greater than [length].
  @override
  void insert(int index, E element) {
    assert(!isDisposed);
    _list.insert(index, element);
    _dirty = true;
    if (_observable) _changes.add(ListModification.insert(index, element));
  }

  ///Removes the object at position [index] from this list.
  ///
  ///This method reduces the length of this by one and moves all later objects down by one position.
  ///
  ///Returns the removed object.
  ///
  ///The [index] must be in the range 0 ≤ index < length.
  @override
  E removeAt(int index) {
    assert(!isDisposed);
    var removed = _list.removeAt(index);
    _dirty = true;
    if (_observable) _changes.add(ListModification.remove(index, removed));
    return removed;
  }

  ///Removes the first occurrence of [value] from this list.
  ///
  ///Returns true if [value] was in the list, false otherwise.
  ///
  ///The method has no effect if [value] was not in the list.
  @override
  bool remove(element) {
    assert(!isDisposed);
    var index = _list.indexOf(element);
    if (index > -1) removeAt(index);
    return index > -1;
  }

  ///Removes all objects from this list that satisfy [test].
  ///
  ///An object [o] satisfies [test] if [test(o)] is true.
  @override
  void removeWhere(bool Function(E element) test) {
    assert(!isDisposed);
    for (E elem in _list.where(test)) remove(elem);
  }

  ///Removes all objects from this list that fail to satisfy [test].
  ///
  ///An object [o] satisfies [test] if [test(o)] is true.
  @override
  void retainWhere(bool Function(E element) test) =>
      removeWhere((element) => !test(element));

  /// Removes the objects in the range [start] inclusive to [end] exclusive.
  ///
  /// The provided range, given by [start] and [end], must be valid. A range from [start] to [end] is valid if 0 <= start <= end <= len, where len is this list's length. The range starts at start and has length end - start. An empty range (with end == start) is valid.
  @override
  void removeRange(int start, int end) {
    for (var i = start; i < end; i++) removeAt(i);
  }

  ///Removes the objects in the range [start] inclusive to [end] exclusive and inserts the contents of [replacement] in its place.
  ///
  ///```
  ///List<int> list = [1, 2, 3, 4, 5];
  ///list.replaceRange(1, 4, [6, 7]);
  ///list.join(', '); // '1, 6, 7, 5'
  ///```
  ///The provided range, given by [start] and [end], must be valid. A range from [start] to [end] is valid if 0 <= start <= end <= len, where len is this list's length. The range starts at start and has length end - start. An empty range (with end == start) is valid.
  @override
  void replaceRange(int start, int end, Iterable<E> newContents) {
    assert(0 <= start && start <= end && end <= length);
    var i = start;
    for (var elem in newContents) if (i < end) this[i++] = elem;
    if (end - start < newContents.length)
      for (var elem in newContents.skip(end - start)) insert(i++, elem);
    if (end - start > newContents.length)
      removeRange(end - newContents.length, end);
  }
}

///Notifications used by [ListEmitter] to notify listeners that it has changed. Can specify
///a list of [modifications] (see [ListModification]) since the last time [ListEmitter.notifyChange] was called
///or the [ListEmitter] was initialized.
class ListChange<E> extends ChangeWithAny {
  final List<ListModification<E>> modifications;

  static final _cache = <Type, ListChange>{};

  ListChange(this.modifications, {bool quiet = false})
      : super(quiet: quiet, any: false);
  ListChange._any({bool quiet = false})
      : modifications = null,
        super(quiet: quiet, any: true);
  factory ListChange.any({bool quiet = false}) {
    if (quiet) return ListChange<E>._any(quiet: true);
    return _cache[E] ??= ListChange<E>._any();
  }
}

///A single atomic modification on a [ListEmitter]. Can be an insert, a remove or replace at a particular [index].
class ListModification<E> {
  ///The index at which the modification ocurred.
  final int index;

  ///The value inserted at the [index] if any.
  final E insert;

  ///The value removed at [index] if any.
  final E remove;

  ///Whether the modification is an insert operation.
  final bool isInsert;

  ///Whether [this] is a remove operation.
  final bool isRemove;

  ListModification(this.index, this.remove, this.insert)
      : isInsert = true,
        isRemove = true;
  ListModification.remove(this.index, this.remove)
      : insert = null,
        isRemove = true,
        isInsert = false;
  ListModification.insert(this.index, this.insert)
      : remove = null,
        isRemove = false,
        isInsert = true;

  bool get isReplace => isInsert && isRemove;
}
