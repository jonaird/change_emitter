import 'dart:async';
import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:async/async.dart';
import 'dart:math';

part 'map_emitter.dart';
part 'list_emitter.dart';
part 'value_emitter.dart';
part 'controller_emitters.dart';
part 'widgets.dart';

///An alternative to [ChangeNotifier] from the Flutter framework that exposes
///a stream of [Change]s to notify widgets and other components of your state
///that they should update instead of a list of callbacks. This allows [ChangeEmitter]s
///to provide extra information about individual changes and makes them more easily composable.
///
///For more information on how to compose [ChangeEmitter]s, see [EmitterContainer].
///
///This library also comes with wigdets to use with the [Provider package](https://github.com/rrousselGit/provider)
///to provide and consume state for your app. See [ChangeEmitterProvider] and [ChangeEmitterSelector].
///
///To implement an emitter with custom Change objects override [changes] and cast it
///to the appropriate type.
abstract class ChangeEmitter {
  ChangeEmitter({bool useSyncronousStream = false})
      : _controller = StreamController.broadcast(sync: useSyncronousStream);

  final StreamController _controller;

  ChangeEmitter? _parent;

  ChangeEmitter? get parent => _parent;

  T? findAncestorOfExactType<T extends ChangeEmitter>() {
    var ancestor = parent;
    while (ancestor != null)
      if (ancestor.runtimeType == T)
        return ancestor as T;
      else
        ancestor = ancestor.parent;

    return null;
  }

  ///Will be called after [parent] is set and the ancestor tree is available.
  @protected
  void didRegisterParent() => null;

  ///Used by subclasses to broadcast [Change]s.
  @protected
  void addChangeToStream(dynamic change) => _controller.add(change);

  ///The stream of [Change]s to notify your UI or other state elements that they should update.
  Stream get changes => _controller.stream;

  ///Disposes resources and closes the stream controller.
  @mustCallSuper
  void dispose() => _controller.close();

  ///Whether [this] has been disposed.
  bool get isDisposed => _controller.isClosed;
}

mixin ParentEmitter on ChangeEmitter {
  @protected
  void registerChildren();
  @protected
  void registerChild(ChangeEmitter child) {
    child._parent = this;
    child.didRegisterParent();
    if (child is ParentEmitter) child.registerChildren();
  }
}

///A [ChangeEmitter] that can be subclassed in order to compose multiple [ChangeEmitter]s into a single unit.
///To use, simply define any  [ChangeEmitter]s you need in your class and override the [children] getter with
///a complete list of all of them. This will dispose all children  when the container is disposed and
///will trigger the container to emit a change whenever any of the children changes
///
///If you want only a subset of the container's children to emit changes, override the [emittingChildren] getter:
///
///```
///class TextStyleState extends EmitterContainer {
///  final bold = ValueEmitter(false);
///  final italic = ValueEmitter(false);
///  final color = ValueEmitter<Color>(Colors.red);
///  ValueEmitter<bool> boldAndRed;
///
///   TextStyleState(){
///     boldAndRed = ValueEmitter.reactive(
///       [bold, color],
///       () => bold.value && color.value == Colors.red
///     );
///   }
///
///  @override
///  get children => [bold, italic, color, isRedAndBold];
///
///  @override
///  get emittingChildren => [text, bold, italic, color];
///}
///```
///
///
abstract class EmitterContainer extends ChangeEmitter with ParentEmitter {
  var _transactionStarted = false;
  final _changesDuringTransaction = <DependencyChange>[];

  void registerChildren() {
    for (var child in children) registerChild(child);
  }

  void startTransaction() => _transactionStarted = true;
  void endTransaction() {
    addChangeToStream(ContainerChange(List.from(_changesDuringTransaction)));
    _transactionStarted = false;
  }

  bool get ongoingTransaction => _transactionStarted;

  // var _stream;

  // get changes => _stream ??= _getStream();

  late final Stream<List<DependencyChange>> changes = _getStream();

  ///override this method in order to create and use your own subclass of [ContainerChange]
  ///If you use [EmitterContainer.emit] then this function will be called with child and childChange as null
  @protected
  List<DependencyChange> containerChangeFromDependency(ChangeEmitter? dependency,
      [dynamic change]) {
    return [if (dependency != null) DependencyChange(dependency, change)];
  }

  Stream<List<DependencyChange>> _getStream() {
    var streams = dependencies.map(_dependencyToChangeStreamMap).toList()
      ..add(super.changes.cast<List<DependencyChange>>());

    return StreamGroup.merge<List<DependencyChange>>(streams).asBroadcastStream();
  }

  Stream<List<DependencyChange>> _dependencyToChangeStreamMap(ChangeEmitter dependency) {
    return dependency.changes.where((change) {
      if (_transactionStarted)
        _changesDuringTransaction.add(DependencyChange(dependency, change));
      return !_transactionStarted;
    }).map((change) => containerChangeFromDependency(dependency, change));
  }

  ///Override to provide a list of all the [ChangeEmitter]s defined in your subclass. This
  ///will dispose all children when this class is disposed and will emit a [ContainerChange]
  ///whenever any of the children change so that UI or other elements of your state
  ///can update reactively. If you only want a subset of
  ///the children to trigger changes, override [emittingChildren].
  Set<ChangeEmitter> get children => {};

  ///A list of [children] that should trigger this container to emit changes. If you want all children
  ///to trigger changes, then you don't need to override this getter.
  Set<ChangeEmitter> get dependencies => children;

  ///Emits [new ContainerChange.any]).
  ///
  ///To emit a change but prevent a parent [EmitterContainer] from emitting a change, set quiet to true.
  void emit() => addChangeToStream(containerChangeFromDependency(null));

  ///Disposes resources of all [children] and [this].
  @mustCallSuper
  void dispose() {
    for (var child in children) child.dispose();
    super.dispose();
  }
}

class DependencyChange {
  DependencyChange(this.child, this.change);
  final ChangeEmitter child;
  final Object? change;
}

abstract class RootEmitter extends EmitterContainer {
  RootEmitter() {
    registerChildren();
  }
}

///A [Change] used by [EmitterContainer] to notify listeners whenever a child element (see [EmitterContainer.children]) changed
///or [EmitterContainer.emit] is called.
class ContainerChange {
  final List<DependencyChange> childChanges;

  ContainerChange(
    this.childChanges,
  );
}

mixin ListenableEmitterMixin on ChangeEmitter implements Listenable {
  final _listeners = <VoidCallback, StreamSubscription>{};

  @override
  void addListener(VoidCallback listener) {
    _listeners[listener] = changes.listen((event) => listener());
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener)?.cancel();
  }

  void disposeListeners() {
    for (var sub in _listeners.values) sub.cancel();
  }
}
