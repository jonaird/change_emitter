part of 'change_emitter_base.dart';

///A [ChangeEmitter] that implements the map interface. Notifying listeners of changes must be done
///intentionally by calling [notifyChange] after performing a change on the list. If the list hasn't change
///since the last time [notifyChange] was called or the map was initialized, then
///nothing will happen.
class MapEmitter<K, V> extends ChangeEmitter<MapChange<K, V>>
    with MapMixin<K, V> {
  Map<K, V> _map;
  final bool _observable;
  final _changes = <MapModification<K, V>>[];
  bool _dirty = false;

  MapEmitter(Map<K, V> map, {bool observable = false})
      : _map = Map.from(map),
        _observable = observable;

  ///Notifies listeners if there has been a change to the map since the last time it was called or the list was initialized.
  emit({
    ///{@macro quiet}
    bool quiet = false,
  }) {
    assert(!isDisposed);
    if (_dirty && !quiet)
      addChangeToStream(_observable ? MapChange(_changes) : MapChange.any());
    else if (_dirty)
      addChangeToStream(_observable
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
        if (_observable) _changes.add(MapModification(key, oldVal, value));
        _dirty = true;
      }
    } else {
      _map[key] = value;
      if (_observable) _changes.add(MapModification.insert(key, value));
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
      if (_observable)
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
      if (_observable) _changes.add(MapModification.remove(key, removed));
      _dirty = true;
    }
    return removed;
  }
}

///Notifications used by [MapEmitter] to notify listeners upon a change. Can include a list of [modifications]
///(see [MapModification]) that are either inserts, removes or both. Otherwise, will recycle existing objects
///to minimize GC (see [new MapChange.any]).
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
