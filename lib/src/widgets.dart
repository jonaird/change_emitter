part of 'change_emitter_base.dart';

//MIT License
// Copyright (c) 2019 Remi Rousselet

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

class Provider<T extends ChangeEmitter> extends StatelessWidget {
  Provider({required this.state, this.child, this.builder})
      : assert((child != null && builder == null) ||
            (child == null && builder != null));
  final T state;
  final Widget? child;
  final Widget Function(BuildContext context, T state)? builder;
  @override
  Widget build(BuildContext context) {
    return _InheritedProvider(
        value: state,
        child: child != null
            ? child!
            : Builder(builder: (c) => builder!(c, c.depend<T>()!)));
  }
}

class Reprovider<T extends ChangeEmitter, S extends ChangeEmitter>
    extends StatelessWidget {
  Reprovider({required this.selector, this.child, this.builder})
      : assert((child != null && builder == null) ||
            (child == null && builder != null));
  final S Function(T state) selector;
  final Widget? child;
  final Widget Function(BuildContext context, S state)? builder;

  @override
  Widget build(BuildContext context) {
    var state = context.select(selector)!;
    return _InheritedProvider<S>(
        value: state,
        child: child != null
            ? child!
            : Builder(builder: (c) => builder!(c, c.depend<S>()!)));
  }
}

class _InheritedProvider<T extends ChangeEmitter> extends InheritedWidget {
  _InheritedProvider({required this.value, required Widget child})
      : super(child: child);
  final T value;

  @override
  updateShouldNotify(_InheritedProvider<T> oldWidget) =>
      oldWidget.value != value;

  @override
  _InheritedProviderElement<T> createElement() =>
      _InheritedProviderElement(this);
}

class _Dependencies<T extends ChangeEmitter> {
  bool fullDependency = false;
  bool shouldClearSelectors = false;
  bool addedPostFrameCallback = false;
  final selectors = <_SelectorAspect<T>>[];
}

typedef _SelectorAspect<T extends ChangeEmitter> = bool Function(T);

class _InheritedProviderElement<T extends ChangeEmitter>
    extends InheritedElement {
  _InheritedProviderElement(_InheritedProvider<T> widget) : super(widget) {
    _subscribeToChanges();
  }

  var _notifyDependents = false;

  StreamSubscription<Change>? _subscription;

  _InheritedProvider<T> get widget => super.widget as _InheritedProvider<T>;

  T get value => widget.value;

  void _subscribeToChanges() {
    if (_subscription != null) _subscription!.cancel();
    _subscription = value.changes.listen((event) => this
      .._notifyDependents = true
      ..markNeedsBuild());
  }

  @override
  void update(covariant _InheritedProvider<T> newWidget) {
    var oldValue = value;
    super.update(newWidget);
    if (value != oldValue) _subscribeToChanges();
  }

  @override
  void updateDependencies(Element dependent, Object? aspect) {
    var dependencies = (getDependencies(dependent) as _Dependencies<T>?);
    if (dependencies == null) {
      dependencies = _Dependencies<T>();
      setDependencies(dependent, dependencies);
    }

    if (aspect == null)
      dependencies.fullDependency = true;
    else if (!dependencies.fullDependency) {
      if (dependencies.shouldClearSelectors) dependencies.selectors.clear();
      dependencies.selectors.add(aspect as _SelectorAspect<T>);
      if (!dependencies.addedPostFrameCallback)
        _addPostFrameCallback(dependencies);
    }
  }

  void _addPostFrameCallback(_Dependencies<T> dependencies) {
    dependencies.addedPostFrameCallback = true;

    SchedulerBinding.instance!.addPostFrameCallback((timeStamp) => dependencies
      ..addedPostFrameCallback = false
      ..shouldClearSelectors = true);
  }

  @override
  void notifyDependent(
      covariant _InheritedProvider oldWidget, Element dependent) {
    var shouldNotify = false;
    if (oldWidget.value != value) shouldNotify = true;
    var dependencies = getDependencies(dependent) as _Dependencies<T>;
    if (dependencies.fullDependency)
      shouldNotify = true;
    else {
      for (var selector in dependencies.selectors)
        if (selector(value)) {
          shouldNotify = true;
          break;
        }
    }
    if (shouldNotify) dependent.didChangeDependencies();
  }

  @override
  Widget build() {
    if (_notifyDependents) notifyClients(widget);
    _notifyDependents = false;
    return super.build();
  }

  @override
  void unmount() {
    _subscription?.cancel();
    super.unmount();
  }
}

extension BuildContextExtensions on BuildContext {
  T? read<T extends ChangeEmitter>() => _ipe<T>()?.value;

  S? select<T extends ChangeEmitter, S>(S Function(T) selector) {
    var inheritedElement = _ipe<T>();
    if (inheritedElement == null) return null;
    var selection = selector(inheritedElement.value);
    dependOnInheritedElement(inheritedElement,
        aspect: (T state) => selector(state) != selection);
    return selection;
  }

  T? depend<T extends ChangeEmitter>() {
    var inheritedElement = _ipe<T>();
    if (inheritedElement == null) return null;
    dependOnInheritedElement(inheritedElement);
    return inheritedElement.value;
  }

  _InheritedProviderElement<T>? _ipe<T extends ChangeEmitter>() =>
      (getElementForInheritedWidgetOfExactType<_InheritedProvider<T>>()
          as _InheritedProviderElement<T>?);
}

extension ProviderExtension<T extends ChangeEmitter> on EmitterList<T> {
  ///Converts [this] into a list of Providers that provide the elements of [this] with a child or a builder.
  ///
  ///To use this method you must depend on this EmitterList's [parent] in the build method in which
  ///this method is called or your app may display incorrect state.
  List<Widget> toProviderList(
      {Widget? child,
      Widget Function(BuildContext context, int index, T state)? builder}) {
    assert((child == null && builder != null) ||
        (child != null && builder == null));
    return [
      for (var i = 0; i < length; i++)
        Provider<T>(
          state: this[i],
          child: child,
          builder: builder != null ? (c, s) => builder(c, i, s) : null,
        )
    ];
  }
}
