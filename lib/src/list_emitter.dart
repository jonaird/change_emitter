part of 'change_emitter_base.dart';

///A [ChangeEmitter] implementation of a list. Modifying the list will not
///cause it to emit changes. When you would like the list to emit changes, call [emit].
///This lets you perform multiple changes to a list before updating your UI or other
///parts of state. Calling [emit] will not emit changes if there have been no changes.
///
///```
///var list = ListEmitter([1,3,5]);
///list.addAll([1,8,2,8]);
///list.retainWhere((elem)=>elem%2==0);
///
///list.emit() // emits change
///```
///
class ListEmitter<E> extends ChangeEmitter<ListChange<E>> with ListMixin<E> {
  final List<E> _list;
  final _changes = <ListModification<E>>[];
  bool _dirty = false;

  ///Initializes with a list of elements.
  ListEmitter(List<E> list, {this.emitDetailedChanges = false})
      : _list = List.from(list);

  ///{@template detailed}
  ///Whether to emit changes that include detailed information about the specific change.
  ///Defaults to false which will emit the same cached change object to
  ///minimize garbage collection.
  ///{@endtemplate}
  ///
  ///Detailed changes will include a list of modifications.
  ///See [ListChange.modifications].
  final bool emitDetailedChanges;

  E operator [](int index) {
    assert(!isDisposed);
    return _list[index];
  }

  operator []=(int index, E value) {
    assert(!isDisposed);
    var oldValue = _list[index];
    if (oldValue != value) {
      _list[index] = value;
      if (emitDetailedChanges)
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
    if (newLength > length && null is E) //checks if E is nullable
      while (length != newLength) (this as ListEmitter<E?>).add(null);
    else if (newLength > length)
      throw ('can\t set a larger list length for nonNullable generic type $E');
    else
      while (length != newLength) removeAt(newLength);
  }

  ///Emits a change if the list has been modified since the last emit (or since it was initialized).
  ///
  ///To emit a change but prevent a parent [EmitterContainer] from emitting a change, set quiet to true.
  void emit({bool quiet = false}) {
    assert(!isDisposed);
    if (_dirty && !quiet)
      addChangeToStream(emitDetailedChanges
          ? ListChange(List.from(_changes))
          : ListChange.any());
    else if (_dirty)
      addChangeToStream(emitDetailedChanges
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
    if (emitDetailedChanges)
      _changes.add(ListModification.insert(length, element));
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
    if (emitDetailedChanges)
      _changes.add(ListModification.insert(index, element));
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
    if (emitDetailedChanges)
      _changes.add(ListModification.remove(index, removed));
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

    var index = _list.indexOf(element as E);
    if (index > -1) removeAt(index);
    return index > -1;
  }

  ///Removes all objects from this list that satisfy [test].
  ///
  ///An object [o] satisfies [test] if [test(o)] is true.
  @override
  void removeWhere(bool Function(E element) test) {
    assert(!isDisposed);
    for (E elem in List.from(_list.where(test))) remove(elem);
  }

  ///Pops and returns the last object in this list.
  ///
  ///The list must not be empty.
  @override
  E removeLast() {
    var last = this.last;
    removeAt(length - 1);
    return last;
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
    assert(0 <= start && start <= end && end <= length);
    for (var i = start; i < end; i++) removeAt(start);
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

///A [Change] emitted by [ListEmitter]. If [ListEmitter.emitDetailedChanges] is set to true,
///will provide a list of [ListModification]s. Otherwise, will recycle the same cached [new ListChange.any]
///object to minimize garbage collection.
class ListChange<E> extends ChangeWithAny {
  final List<ListModification<E>>? modifications;

  static final _cache = <Type, ListChange>{};

  ListChange(this.modifications, {bool quiet = false})
      : super(quiet: quiet, any: false);
  ListChange._any({bool quiet = false})
      : modifications = null,
        super(quiet: quiet, any: true);
  factory ListChange.any({bool quiet = false}) {
    if (quiet) return ListChange<E>._any(quiet: true);
    return (_cache[E] ??= ListChange<E>._any()) as ListChange<E>;
  }

  String toString() {
    return "ListChange with the following modifications: ${modifications.toString()}";
  }
}

///A single atomic modification on a [ListEmitter]. Can be an [insert], a [remove] or replace at a particular [index].
class ListModification<E> {
  ///The index at which the modification ocurred.
  final int index;

  ///The value inserted at the [index] if any.
  final E? insert;

  ///The value removed at [index] if any.
  final E? remove;

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

  String toString() =>
      'Modification at index: $index, insert: $insert, remove: $remove';

  ///Whether the modification is both [insert] and [remove].
  bool get isReplace => isInsert && isRemove;
}

/// A [ListEmitter] that can only contain [ChangeEmitter]s. [EmitterList] will automatically dispose
/// elements that get removed from the list and all remaining elements in the list when it is disposed.
class EmitterList<E extends ChangeEmitter> extends ListEmitter<E>
    implements ParentEmitter<ListChange<E>> {
  EmitterList(List<E> list) : super(list, emitDetailedChanges: true);
  void registerChild(ChangeEmitter child) {
    child._parent = this;
    if (child is ParentEmitter) child.registerChildren();
  }

  void registerChildren() {
    for (var child in this) registerChild(child);
  }

  void emit({bool quiet = false}) {
    for (var mod in _changes) {
      //makes sure that a remove is really a remove and not a re-ordering before disposing
      if (mod.isRemove && !this.contains(mod.remove)) mod.remove!.dispose();
      if (mod.isInsert) registerChild(mod.insert!);
    }
    super.emit(quiet: quiet);
  }

  @mustCallSuper
  void dispose() {
    this.forEach((element) => element.dispose());
    super.dispose();
  }
}
