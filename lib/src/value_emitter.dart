part of 'change_emitter_base.dart';

///A simple [ChangeEmitter] that stores a value, and notifies listeners whenever that value has changed. Similar to
///[ValueNotifier] in the Flutter framework.
class ValueEmitter<T> extends ChangeEmitter<ValueChange<T>> {
  T _value;
  final bool _observable;
  StreamSubscription _sub;

  ValueEmitter(T value,
      {

      ///Whether to implement the observable pattern. If true, changes will provide the old and new values (see [ValueChange]).
      ///Otherwise the same object will be reused over and over to minimize garbage collection.
      bool observable = false})
      : _value = value,
        _observable = observable;

  ///A [ValueEmitter] that reacts to changes from a list of [ChangeEmitter]s and calls a builder function to get its new value.
  ValueEmitter.reactive(
    ///Which [ChangeEmitter]s to react to.
    Iterable<ChangeEmitter> reactTo,

    ///Will be called to get new values reactively upon any change to [ChangeEmitter]s this ValueEmitter is reacting to.
    T Function() withValue, {

    ///Whether to implement the observable pattern. If true, changes will provide the old and new values (see [ValueChange]).
    ///Otherwise the same object will be reused over and over to minimize garbage collection
    bool observable = false,
  }) : _observable = observable {
    value = withValue();
    _sub = StreamGroup.merge(reactTo.map((e) => e.changes))
        .listen((_) => value = withValue());
  }

  ///A stream of new values.
  Stream<T> get values => changes.map<T>((event) => _value);

  ///Whether the current value is null.
  bool get isNull => _value == null;

  bool get isNotNull => _value != null;

  ///Sets a new value and notifies listeners if the value is different than the old value.
  set value(T newValue) {
    assert(!isDisposed);
    if (_value != newValue) {
      var oldValue = _value;
      _value = newValue;
      addChangeToStream(
          _observable ? ValueChange(oldValue, newValue) : ValueChange.any());
    }
  }

  ///Sets a new value and notifies listeners if the value is different than the old value but will
  ///not trigger a parent [StateContainer] to notify its listeners.
  quietSet(T newValue) {
    assert(!isDisposed);
    if (_value != newValue) {
      var oldValue = _value;
      _value = newValue;
      addChangeToStream(_observable
          ? ValueChange(oldValue, newValue, quiet: true)
          : ValueChange.any(quiet: true));
    }
  }

  ///The current value held.
  T get value {
    assert(!isDisposed);
    return _value;
  }

  ///Disposes resources and closes it's stream.
  @mustCallSuper
  void dispose() {
    _sub?.cancel();

    super.dispose();
  }
}

///Notifications broadcast by [ValueEmitter] to notify listeners upon a change to its value.
class ValueChange<T> extends ChangeWithAny {
  ///The value being replaced.
  final T oldValue;

  ///The new value.
  final T newValue;

  //Recycles ValueEmitter.any to minimize GC.
  static final _anyCache = <Type, ValueChange>{};

  ValueChange(this.oldValue, this.newValue, {bool quiet = false})
      : super(quiet: quiet, any: false);
  ValueChange._any({bool quiet = false})
      : assert(quiet != null),
        oldValue = null,
        newValue = null,
        super(quiet: quiet, any: true);

  ///A change notification that doesn't include information about the change. Will
  ///recycle the same object to minimize GC.
  factory ValueChange.any({bool quiet = false}) {
    if (quiet) return ValueChange<T>._any(quiet: true);

    return _anyCache[T] ??= ValueChange<T>._any();
  }
}
