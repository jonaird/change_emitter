import 'dart:async';
import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:async/async.dart';
//import 'package:provider/provider.dart';

part 'map_emitter.dart';
part 'list_emitter.dart';
part 'value_emitter.dart';
//part 'widgets_old.dart';
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
abstract class ChangeEmitter<C extends Change> {
  ChangeEmitter({bool useSyncronousStream = false})
      : _controller = StreamController<C>.broadcast(sync: useSyncronousStream);

  final StreamController<C> _controller;

  ChangeEmitter? _parent;

  ChangeEmitter? get parent => _parent;

  @protected
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
  void addChangeToStream(C change) => _controller.add(change);

  ///The stream of [Change]s to notify your UI or other state elements that they should update.
  Stream<C> get changes => _controller.stream;

  ///Disposes resources and closes the stream controller.
  @mustCallSuper
  void dispose() => _controller.close();

  ///Whether [this] has been disposed.
  bool get isDisposed => _controller.isClosed;
}

///An immutable class used by [ChangeEmitter]s to trigger UI or other components
///of your state to update.
@immutable
abstract class Change {
  ///Whether a change will trigger a parent [EmitterContainer] to notify its listeners that it has changed.
  ///This can be useful if you want to batch changes to children of a [EmitterContainer] but have
  ///the container only emit one change.
  final bool quiet;
  Change({this.quiet = false});
}

abstract class ChangeWithAny extends Change {
  ///Whether this change is generic or contains specific information about the change.
  ///By default [ChangeEmitter]s contained in this library don't contain
  ///specific information about a change (except for the [Change.quiet] value)
  ///and instead recycle the same [Change] object on each change
  ///to minimize garbage collection.
  final bool any;
  ChangeWithAny({required bool quiet, required this.any}) : super(quiet: quiet);
}

mixin ParentEmitter<C extends Change> on ChangeEmitter<C> {
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
abstract class EmitterContainer<C extends ContainerChange>
    extends ChangeEmitter<C> with ParentEmitter {
  EmitterContainer({this.emitDetailedChanges = false});

  void registerChildren() {
    for (var child in children) registerChild(child);
  }

  ///{@macro detailed}
  ///
  ///Detailed changes will include the child's [Change] object
  ///that triggered the change as well as a reference to the child.
  ///See [EmitterChange].
  final bool emitDetailedChanges;

  // var _stream;

  // get changes => _stream ??= _getStream();

  late final changes = _getStream();

  ///override this method in order to create and use your own subclass of [ContainerChange]
  ///If you use [EmitterContainer.emit] then this function will be called with child and childChange as null
  @protected
  C containerChangeFromDependency(
      {ChangeEmitter? dependency, Change? change, bool quiet = false}) {
    if (emitDetailedChanges && dependency != null)
      return ContainerChange(dependency, change) as C;
    return ContainerChange.any() as C;
  }

  Stream<C> _getStream() {
    var streams = dependencies
        .map((e) => e.changes.where((event) => !event.quiet).map((event) =>
            containerChangeFromDependency(dependency: e, change: event)))
        .toList()
          ..add(_controller.stream);

    return StreamGroup.merge<C>(streams).asBroadcastStream();
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
  void emit({bool quiet = false}) =>
      addChangeToStream(containerChangeFromDependency(quiet: quiet));

  ///Disposes resources of all [children] and [this].
  @mustCallSuper
  void dispose() {
    for (var child in children) child.dispose();
    super.dispose();
  }
}

abstract class RootEmitter<C extends ContainerChange>
    extends EmitterContainer<C> {
  RootEmitter({bool emitDetailedChanges = false})
      : super(emitDetailedChanges: emitDetailedChanges) {
    registerChildren();
  }
}

///A [Change] used by [EmitterContainer] to notify listeners whenever a child element (see [EmitterContainer.children]) changed
///or [EmitterContainer.emit] is called.
class ContainerChange extends ChangeWithAny {
  ///The child [ChangeEmitter] that changed.
  final ChangeEmitter? changedElement;

  ///The [Change] broadcast by the [changedElement] that triggerd this change.
  final Change? change;

  ContainerChange(this.changedElement, this.change, {bool quiet = false})
      : super(quiet: quiet, any: false);

  static final _anyCache = ContainerChange._any();

  ContainerChange._any({bool quiet = false})
      : changedElement = null,
        change = null,
        super(quiet: quiet, any: true);

  ///A change that doesn't provide detailed information about the change
  /// (does specify [Change.quiet] value).
  ///This is the default for [EmitterContainer]. Will provide
  ///the same cached object to minimize garbage collection.
  factory ContainerChange.any({bool quiet = false}) {
    return quiet ? ContainerChange._any(quiet: true) : _anyCache;
  }
}

abstract class ListenableEmitterMixin extends ChangeEmitter
    implements Listenable {
  final _listeners = <VoidCallback, StreamSubscription>{};

  @override
  void addListener(VoidCallback listener) {
    _listeners[listener] = changes.listen((event) => listener());
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener)?.cancel();
  }
}
