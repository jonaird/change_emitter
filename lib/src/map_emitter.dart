part of 'change_emitter_base.dart';

///A [ChangeEmitter] implementation of a map. Modifying a [MapEmitter] won't automatically
///emit a change. To emit a change after it has been modified, call [emit].
class MapEmitter<K, V> extends ChangeEmitter<MapChange<K, V>>
    with MapMixin<K, V> {
  Map<K, V> _map;

  final _changes = <MapModification<K, V>>[];
  bool _dirty = false;

  MapEmitter(Map<K, V> map, {this.emitDetailedChanges = false})
      : _map = Map.from(map);

  ///{@macro detailed}
  ///
  ///Detailed changes will include a list of modifications.
  ///See [MapChange.modifications].
  final bool emitDetailedChanges;

  ///Emits a change if the map has been modified since the last emit (or since it was initialized).
  ///
  ///To emit a change but prevent a parent [EmitterContainer] from emitting a change, set quiet to true.
  emit({bool quiet = false}) {
    assert(!isDisposed);
    if (_dirty && !quiet)
      addChangeToStream(
          emitDetailedChanges ? MapChange(_changes) : MapChange.any());
    else if (_dirty)
      addChangeToStream(emitDetailedChanges
          ? MapChange(_changes, quiet: true)
          : MapChange.any(quiet: true));
    _changes.clear();
    _dirty = false;
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
        if (emitDetailedChanges)
          _changes.add(MapModification(key, oldVal, value));
        _dirty = true;
      }
    } else {
      _map[key] = value;
      if (emitDetailedChanges) _changes.add(MapModification.insert(key, value));
      _dirty = true;
    }
  }

  ///Removes all pairs from the map.
  ///
  ///After this, the map is empty.
  @override
  void clear() {
    if (keys.length > 0) {
      _dirty = true;
      if (emitDetailedChanges)
        for (var key in _map.keys)
          _changes.add(MapModification.remove(key, _map[key]));
      _map.clear();
    }
  }

  ///Removes [key] and its associated value, if present, from the map.
  ///
  ///Returns the value associated with key before it was removed. Returns null if key was not in the map.
  ///
  ///Note that values can be null and a returned null value doesn't always mean that the key was absent.
  @override
  V remove(key) {
    assert(!isDisposed);
    V removed;
    if (keys.contains(key)) {
      removed = _map.remove(key);
      if (emitDetailedChanges)
        _changes.add(MapModification.remove(key, removed));
      _dirty = true;
    }
    return removed;
  }
}

///A [Change] emiited by [MapEmitter]. If [MapEmitter.emitDetailedChanges] is set to true,
///will provide a list of [MapModification]s. Otherwise, will recycle the same cached [new ListChange.any]
///object to minimize garbage collection.
class MapChange<K, V> extends ChangeWithAny {
  ///A list of modifications since a the last time [MapEmitter.notifyChange] was called or the map was initialized.
  final List<MapModification<K, V>> modifications;
  MapChange(this.modifications, {bool quiet = false})
      : super(quiet: quiet, any: false);

  static final _cache = <Type, Map<Type, MapChange>>{};

  MapChange._any({bool quiet})
      : modifications = null,
        super(quiet: quiet, any: true);

  ///A constructor that doesn't include information about a [MapEmitter] change.
  ///Will recycle the same object per key/value type to minimize GC.
  factory MapChange.any({bool quiet = false}) {
    if (quiet) return MapChange<K, V>._any(quiet: true);

    _cache[K] ??= <Type, MapChange>{};
    _cache[K][V] ??= MapChange<K, V>._any();

    return _cache[K][V];
  }
}

///An individual modification, either an insert, remove or both (see [isInsert], [isRemove], [isReplace]).
class MapModification<K, V> {
  ///The key at which there was an insert, remove or replace.
  final K key;

  ///The value inserted.
  final V newValue;

  ///The value removed.
  final V oldValue;

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
