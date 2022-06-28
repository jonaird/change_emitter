part of 'change_emitter_base.dart';

///A simple [ChangeEmitter] that stores a value, emits a [ValueChange] whenever the value changes.
class ValueEmitter<T> extends ChangeEmitter {
  ValueEmitter(
    T value, {
    this.keepHistory = false,
  })  : _value = value,
        _isUnmodifiableView = false;

  ///A [ValueEmitter] that reacts to changes from a list of [ChangeEmitter]s and calls a builder function to get its new value.
  ValueEmitter.reactive({
    required List<ChangeEmitter> reactTo,
    required T Function() withValue,
    this.keepHistory = false,
  })  : _isUnmodifiableView = true,
        super(useSyncronousStream: true) {
    _value = withValue();
    _sub = StreamGroup.merge(reactTo.map((e) => e.changes))
        .listen((_) => _setValueWithoutUnmodifiableCheck(withValue()));
  }

  ValueEmitter.late({
    this.keepHistory = false,
  })  : assert(null is! T),
        _isUnmodifiableView = false,
        _initialized = false;

  ValueEmitter.unmodifiableView(ValueEmitter<T> emitter)
      : _isUnmodifiableView = true,
        _value = emitter.value,
        keepHistory = emitter.keepHistory,
        super(useSyncronousStream: true) {
    _sub = emitter.values.listen((T newVal) => _setValueWithoutUnmodifiableCheck(newVal));
  }

  late T _value;
  final bool _isUnmodifiableView;
  StreamSubscription? _sub;
  bool _initialized = true;
  final _history = <T>[];
  final bool keepHistory;

  @override
  Stream<ValueChange<T>> get changes => super.changes.cast<ValueChange<T>>();

  ValueEmitter<T>? _unmodifiableView;

  ValueEmitter<T> get unmodifiableView {
    if (_isUnmodifiableView) throw ('This value emitter is already an unmodifiable view');
    return _unmodifiableView ??= ValueEmitter<T>.unmodifiableView(this);
  }

  ///A stream of new values.
  Stream<T> get values => changes.map<T>((event) => value);

  ///Whether the current value is null.
  bool get isNull => value == null;

  bool get isNotNull => value != null;

  ///For subclasses to set values without emitting a change
  @protected
  void setValue(T newValue) => _value = newValue;

  void _setValueWithoutUnmodifiableCheck(T newValue) {
    assert(!isDisposed);

    if (_value != newValue) {
      var oldValue = _value;
      _value = newValue;
      _history.add(oldValue);
      _addChange(oldValue, newValue);
    }
  }

  void _addChange(T? oldValue, T newValue) {
    addChangeToStream(ValueChange<T>(oldValue, newValue));
  }

  ///Sets a new value and notifies listeners if the value is different than the old value.
  set value(T newValue) {
    if (_isUnmodifiableView) throw ('Tried to modify an unmodifiable value emitter view');
    if (!_initialized) {
      _value = newValue;
      _initialized = true;
      _addChange(null, newValue);
    } else
      _setValueWithoutUnmodifiableCheck(newValue);
  }

  ///The current value held.
  T get value {
    assert(!isDisposed);
    return _value;
  }

  T? get previous => _history.isNotEmpty ? _history.last : null;

  ///Disposes resources.
  @mustCallSuper
  void dispose() {
    _sub?.cancel();
    _unmodifiableView?.dispose();
    super.dispose();
  }
}

extension Toggleable on ValueEmitter<bool> {
  ///Toggle a boolean value.
  void toggle() {
    this.value = !this.value;
  }
}

///A [Change] emitted by [ValueEmitter]. If [ValueEmitter.emitDetailedChanges] is set to true,
///will provide both the new value and the old value being replaced. Otherwise, will recycle the same cached [new ValueChange.any]
///object to minimize garbage collection.
class ValueChange<T> {
  ///The value being replaced.
  final T? oldValue;

  ///The new value.
  final T? newValue;

  ValueChange(this.oldValue, this.newValue);
}
