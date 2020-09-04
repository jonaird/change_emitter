part of 'change_emitter_base.dart';

///A simple [ChangeEmitter] that stores a value, emits a [ValueChange] whenever the value changes.
class ValueEmitter<T> extends ChangeEmitter<ValueChange<T>> {
  T _value;

  StreamSubscription _sub;

  ValueEmitter(T value, {bool observable = false})
      : _value = value,
        emitDetailedChanges = observable;

  ///A [ValueEmitter] that reacts to changes from a list of [ChangeEmitter]s and calls a builder function to get its new value.
  ValueEmitter.reactive(Iterable<ChangeEmitter> reactTo, T Function() withValue,
      {this.emitDetailedChanges = false}) {
    value = withValue();
    _sub = StreamGroup.merge(reactTo.map((e) => e.changes))
        .listen((_) => value = withValue());
  }

  ///{@macro detailed}
  ///
  ///Detailed changes will contain the new value and the old value that was replaced.
  ///See [ValueChange].
  final bool emitDetailedChanges;

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
      addChangeToStream(emitDetailedChanges
          ? ValueChange(oldValue, newValue)
          : ValueChange.any());
    }
  }

  ///Sets a new value and emits a change if the value is different than the old value but will
  ///not trigger any parent [EmitterContainer] to emit a change.
  quietSet(T newValue) {
    assert(!isDisposed);
    if (_value != newValue) {
      var oldValue = _value;
      _value = newValue;
      addChangeToStream(emitDetailedChanges
          ? ValueChange(oldValue, newValue, quiet: true)
          : ValueChange.any(quiet: true));
    }
  }

  ///The current value held.
  T get value {
    assert(!isDisposed);
    return _value;
  }

  ///Disposes resources.
  @mustCallSuper
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

///A [Change] emitted by [ValueEmitter]. If [ValueEmitter.emitDetailedChanges] is set to true,
///will provide both the new value and the old value being replaced. Otherwise, will recycle the same cached [new ValueChange.any]
///object to minimize garbage collection.
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

  ///A change notification that doesn't include detailed information about the change. Will
  ///recycle the same object to minimize GC.
  factory ValueChange.any({bool quiet = false}) {
    if (quiet) return ValueChange<T>._any(quiet: true);

    return _anyCache[T] ??= ValueChange<T>._any();
  }
}
