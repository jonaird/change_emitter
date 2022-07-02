part of 'change_emitter_base.dart';

///A [ChangeEmitter] implementation of a list. Modifying the list will not
///cause it to emit changes. When you would like the list to emit changes, call [_emit].
///This lets you perform multiple changes to a list before updating your UI or other
///parts of state. Calling [_emit] will not emit changes if there have been no changes.
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
  ///Initializes with a list of elements.
  ListEmitter(List<E> list) : _list = List.from(list);
  final List<E> _list;
  final _modifications = <ListModification<E>>[];
  bool get _dirty => _modifications.isNotEmpty;
  var _transactionStarted = false;

  ///Some mutating methods call other mutating methods. In these cases, only the top most
  ///method should trigger [[this]] to emit a change. Thus we have to track the depth
  ///of the call stack.
  var _mutationDepth = 0;

  void startTransaction() => _transactionStarted = true;
  void endTransaction() {
    _emit();
    _transactionStarted = false;
  }

  void _conditionalEmit() {
    if (!_transactionStarted && _mutationDepth == 0) _emit();
  }

  @override
  Stream<List<ListModification<E>>> get changes =>
      super.changes.cast<List<ListModification<E>>>();

  ///Emits a change if the list has been modified since the last emit (or since it was initialized).
  ///
  ///To emit a change but prevent a parent [EmitterContainer] from emitting a change, set quiet to true.
  void _emit() {
    assert(!isDisposed);
    if (_dirty) addChangeToStream(List<ListModification<E>>.from(_modifications));
    _modifications.clear();
  }

  E operator [](int index) {
    assert(!isDisposed);
    return _list[index];
  }

  operator []=(int index, E value) {
    assert(!isDisposed);
    var oldValue = _list[index];
    if (oldValue != value) {
      _list[index] = value;
      _modifications.add(ListModification<E>(index, oldValue, value, true, true));
    }

    _conditionalEmit();
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
    _mutationDepth++;
    if (newLength > length && null is E) //checks if E is nullable
      while (length != newLength) (this as ListEmitter<E?>).add(null);
    else if (newLength > length)
      throw ('can\t set a larger list length for nonNullable generic type $E');
    else
      while (length != newLength) removeAt(newLength);
    _mutationDepth--;
    _conditionalEmit();
  }

  ///Adds [value] to the end of this list, extending the length by one.
  ///
  ///Throws an [UnsupportedError] if the list is fixed-length.
  @override
  void add(E element) {
    assert(!isDisposed);
    _list.add(element);
    _modifications.add(ListModification.insert(length - 1, element));
    _conditionalEmit();
  }

  ///Appends all objects of [iterable] to the end of this list.
  ///
  ///Extends the length of the list by the number of objects in [iterable].
  @override
  void addAll(Iterable<E> iterable) {
    assert(!isDisposed);
    _mutationDepth++;
    super.addAll(iterable);
    _mutationDepth--;
    _conditionalEmit();
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
    _modifications.add(ListModification.insert(index, element));
    _conditionalEmit();
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
    _modifications.add(ListModification.remove(index, removed));
    _conditionalEmit();
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
    _mutationDepth++;
    var index = _list.indexOf(element as E);
    if (index > -1) removeAt(index);
    _mutationDepth--;
    _conditionalEmit();
    return index > -1;
  }

  ///Removes all objects from this list that satisfy [test].
  ///
  ///An object [o] satisfies [test] if [test(o)] is true.
  @override
  void removeWhere(bool Function(E element) test) {
    assert(!isDisposed);
    _mutationDepth++;
    for (E elem in List.from(_list.where(test))) remove(elem);
    _mutationDepth--;
    _conditionalEmit();
  }

  ///Pops and returns the last object in this list.
  ///
  ///The list must not be empty.
  @override
  E removeLast() {
    _mutationDepth++;
    var last = this.last;
    removeAt(length - 1);
    _mutationDepth--;
    _conditionalEmit();
    return last;
  }

  ///Removes all objects from this list that fail to satisfy [test].
  ///
  ///An object [o] satisfies [test] if [test(o)] is true.
  @override
  void retainWhere(bool Function(E element) test) {
    _mutationDepth++;
    removeWhere((element) => !test(element));
    _mutationDepth--;
    _conditionalEmit();
  }

  /// Removes the objects in the range [start] inclusive to [end] exclusive.
  ///
  /// The provided range, given by [start] and [end], must be valid. A range from [start] to [end] is valid if 0 <= start <= end <= len, where len is this list's length. The range starts at start and has length end - start. An empty range (with end == start) is valid.
  @override
  void removeRange(int start, int end) {
    assert(0 <= start && start <= end && end <= length);
    _mutationDepth++;
    for (var i = start; i < end; i++) removeAt(start);
    _mutationDepth--;
    _conditionalEmit();
  }

  @override
  void fillRange(int start, int end, [E? fill]) {
    _mutationDepth++;
    super.fillRange(start, end, fill);
    _mutationDepth--;
    _conditionalEmit();
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    _mutationDepth++;
    super.setRange(start, end, iterable, skipCount);
    _mutationDepth--;
    _conditionalEmit();
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
    _mutationDepth++;
    var i = start;
    for (var elem in newContents) if (i < end) this[i++] = elem;
    if (end - start < newContents.length)
      for (var elem in newContents.skip(end - start)) insert(i++, elem);
    if (end - start > newContents.length) removeRange(end - newContents.length, end);
    _mutationDepth--;
    _conditionalEmit();
  }

  @override
  void shuffle([Random? random]) {
    random ??= Random();

    int length = this.length;
    while (length > 1) {
      int pos = random.nextInt(length);
      length -= 1;
      var tmp = this[length];
      this[length] = this[pos];
      this[pos] = tmp;
      if (this[pos] != this[length]) {
        _modifications.addAll([
          ListModification(length, this[pos], this[length], true, true),
          ListModification(pos, this[length], this[pos], true, true)
        ]);
      }
    }
    _conditionalEmit();
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    _mutationDepth++;
    super.insertAll(index, iterable);
    _mutationDepth--;
    _conditionalEmit();
  }

  @override
  void setAll(int index, Iterable<E> iterable) {
    _mutationDepth++;
    super.setAll(index, iterable);
    _mutationDepth--;
    _conditionalEmit();
  }
}

///A single atomic modification on a [ListEmitter]. Can be an [insert], a [remove] or replace at a particular [index].
class ListModification<E> {
  ///The index at which the modification ocurred.
  ///must be nullable so that subtypes can create changes that don't involve an index
  final int index;

  ///The value inserted at the [index] if any.
  final E? insert;

  ///The value removed at [index] if any.
  final E? remove;

  ///Whether the modification is an insert operation.
  final bool isInsert;

  ///Whether [this] is a remove operation.
  final bool isRemove;

  ListModification(this.index, this.remove, this.insert, this.isInsert, this.isRemove);
  ListModification.remove(this.index, this.remove)
      : insert = null,
        isRemove = true,
        isInsert = false;
  ListModification.insert(this.index, this.insert)
      : remove = null,
        isRemove = false,
        isInsert = true;

  String toString() => 'Modification at index: $index, insert: $insert, remove: $remove';

  ///Whether the modification is both [insert] and [remove].
  bool get isReplace => isInsert && isRemove;
}

typedef ListChange<E> = List<ListModification<E>>;

/// A [ListEmitter] that can only contain [ChangeEmitter]s. [EmitterList] will automatically dispose
/// elements that get removed from the list and all remaining elements in the list when it is disposed.
class EmitterList<E extends ChangeEmitter> extends ListEmitter<E>
    implements ParentEmitter<ListChange<E>> {
  EmitterList(List<E> list, {this.shouldDisposeRemovedElements = true}) : super(list) {
    if (shouldDisposeRemovedElements)
      _sub = changes.listen((change) {
        for (var mod in change)
          if (mod.isRemove && !this.contains(mod.remove)) mod.remove!.dispose();
      });
  }
  final bool shouldDisposeRemovedElements;
  StreamSubscription? _sub;

  void registerChild(ChangeEmitter child) {
    if (child._parent != this && _parent != null) {
      child._parent = this;
      child.didRegisterParent();
      if (child is ParentEmitter) child.registerChildren();
    }
  }

  void registerChildren() {
    for (var child in this) registerChild(child);
  }

  //Registers children for all possible ways of adding an element to the list.

  operator []=(int index, E value) {
    super[index] = value;
    registerChild(value);
  }

  void insert(int index, E element) {
    super.insert(index, element);
    registerChild(element);
  }

  void add(E element) {
    super.add(element);
    registerChild(element);
  }

  @mustCallSuper
  void dispose() {
    _sub?.cancel();
    forEach((element) => element.dispose());
    super.dispose();
  }
}

class NavigationStack<M extends ChangeEmitter> extends EmitterList<M> {
  NavigationStack(List<M> stack) : super(stack);

  void replaceAll(Iterable<M> replacement) {
    replaceRange(0, length, replacement);
  }

  void push(M pageModel) => add(pageModel);

  void pop() => removeLast();
}
