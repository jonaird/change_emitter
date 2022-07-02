part of 'change_emitter_base.dart';

///A [ChangeEmitter] implementation of a map. Modifying a [MapEmitter] won't automatically
///emit a change. To emit a change after it has been modified, call [_emit].
class MapEmitter<K, V> extends ChangeEmitter<MapChange<K, V>> with MapMixin<K, V> {
  MapEmitter(Map<K, V> map) : _map = Map.from(map);
  Map<K, V> _map;

  final _modifications = <MapModification<K, V>>[];
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
  Stream<List<MapModification<K, V>>> get changes =>
      super.changes.cast<List<MapModification<K, V>>>();

  ///Emits a change if the map has been modified since the last emit (or since it was initialized).
  ///
  ///To emit a change but prevent a parent [EmitterContainer] from emitting a change, set quiet to true.
  _emit() {
    assert(!isDisposed);
    if (_dirty) addChangeToStream(List<MapModification<K, V>>.from(_modifications));
    _modifications.clear();
  }

  ///The keys of [this].
  ///
  ///The returned iterable has efficient length and contains operations, based on [length] and [containsKey] of the map.
  ///
  ///The order of iteration is defined by the individual Map implementation, but must be consistent between changes to the map.
  ///
  ///Modifying the map while iterating the keys may break the iteration.
  @override
  Iterable<K> get keys {
    assert(!isDisposed);
    return _map.keys;
  }

  @override
  operator [](key) {
    assert(!isDisposed);
    return _map[key];
  }

  @override
  operator []=(K key, V value) {
    assert(!isDisposed);
    if (keys.contains(key)) {
      var oldVal = _map[key];
      if (value != oldVal) {
        _map[key] = value;
        _modifications.add(MapModification(key, oldVal!, value));
      }
    } else {
      _map[key] = value;
      _modifications.add(MapModification.insert(key, value));
    }
    _conditionalEmit();
  }

  @override
  void addAll(Map<K, V> other) {
    _mutationDepth++;
    super.addAll(other);
    _mutationDepth--;
    _conditionalEmit();
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    _mutationDepth++;
    final val = super.putIfAbsent(key, ifAbsent);
    _mutationDepth--;
    _conditionalEmit();
    return val;
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    _mutationDepth++;
    final val = super.update(key, update, ifAbsent: ifAbsent);
    _mutationDepth--;
    _conditionalEmit();
    return val;
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    _mutationDepth++;
    super.updateAll(update);
    _mutationDepth--;
    _conditionalEmit();
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    _mutationDepth++;
    super.addEntries(newEntries);
    _mutationDepth--;
    _conditionalEmit();
  }

  @override
  void removeWhere(bool Function(K key, V value) test) {
    _mutationDepth++;
    super.removeWhere(test);
    _mutationDepth--;
    _conditionalEmit();
  }

  ///Removes all pairs from the map.
  ///
  ///After this, the map is empty.
  @override
  void clear() {
    if (keys.length > 0) {
      for (var entry in _map.entries)
        _modifications.add(MapModification.remove(entry.key, entry.value));
      _map.clear();
    }
    _conditionalEmit();
  }

  ///Removes [key] and its associated value, if present, from the map.
  ///
  ///Returns the value associated with key before it was removed. Returns null if key was not in the map.
  ///
  ///Note that values can be null and a returned null value doesn't always mean that the key was absent.
  @override
  V? remove(key) {
    assert(!isDisposed);
    V? removed;
    if (keys.contains(key)) {
      removed = _map.remove(key);
      _modifications.add(MapModification.remove(key as K, removed));
    }
    _conditionalEmit();
    return removed;
  }
}

///A [Change] emiited by [MapEmitter]. If [MapEmitter.emitDetailedChanges] is set to true,
///will provide a list of [MapModification]s. Otherwise, will recycle the same cached [new ListChange.any]
///object to minimize garbage collection.
// class MapChange<K, V>  {
//   ///A list of modifications since a the last time [MapEmitter.notifyChange] was called or the map was initialized.
//   final List<MapModification<K, V>> modifications;
//   MapChange(this.modifications);
// }

///An individual modification, either an insert, remove or both (see [isInsert], [isRemove], [isReplace]).
class MapModification<K, V> {
  ///The key at which there was an insert, remove or replace.
  final K key;

  ///The value inserted.
  final V? newValue;

  ///The value removed.
  final V? oldValue;

  ///Whether [this] is an insert modification.
  final bool isInsert;

  ///Whether [this] is a remove modification.
  final bool isRemove;

  MapModification(this.key, this.oldValue, this.newValue)
      : isInsert = true,
        isRemove = true;
  MapModification.remove(this.key, this.oldValue)
      : newValue = null,
        isInsert = false,
        isRemove = true;
  MapModification.insert(this.key, this.newValue)
      : oldValue = null,
        isInsert = true,
        isRemove = false;

  ///Whether the modification inserted and removed a value from the map for a key.
  bool get isReplace => isInsert && isRemove;
}

typedef MapChange<K, V> = List<MapModification<K, V>>;
