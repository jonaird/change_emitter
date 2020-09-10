part of 'change_emitter_base.dart';

///A [Selector] that selects a subcomponent of your state (must be a [ChangeEmitter]) and rebuilds
///whenever that element changes or the element was replaced with a new one. Should be used in lieu
///of [Consumer] if you just need to update based on a part of your state.
class ChangeEmitterSelector<S, E extends ChangeEmitter> extends StatefulWidget {
  final E Function(BuildContext context, S state) selector;
  final Widget Function(BuildContext context, E value, Widget child) builder;
  final Widget child;

  ChangeEmitterSelector(
      {@required this.selector, @required this.builder, this.child});

  @override
  _ChangeEmitterSelectorState<S, E> createState() =>
      _ChangeEmitterSelectorState<S, E>();
}

class _ChangeEmitterSelectorState<S, E extends ChangeEmitter>
    extends State<ChangeEmitterSelector<S, E>> {
  StreamSubscription _subscription;
  E element;

  @override
  void didChangeDependencies() {
    var state = Provider.of<S>(context);
    if (_subscription != null && widget.selector(context, state) != element) {
      _subscription.cancel();
      element = widget.selector(context, state);
      _subscription = element.changes.listen((event) => setState(() {}));
      setState(() {});
    } else if (_subscription == null) {
      element = widget.selector(context, state);
      _subscription = element.changes.listen((event) => setState(() {}));
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, element, widget.child);
}

///A [Provider] (for use with the [Provider package](https://pub.dev/packages/provider)) for any [ChangeEmitter]
///that rebuilds dependent widgets upon changes.
class ChangeEmitterProvider<S extends ChangeEmitter>
    extends InheritedProvider<S> {
  ChangeEmitterProvider({
    Key key,
    @required Create<S> create,
    bool lazy,
    Widget child,
  }) : super(
          key: key,
          create: create,
          dispose: (context, S element) => element.dispose(),
          lazy: lazy,
          child: child,
          startListening: _startListening,
        );

  ChangeEmitterProvider.value({
    Key key,
    @required S value,
    bool lazy,
    Widget child,
  }) : super.value(
          key: key,
          value: value,
          child: child,
          startListening: _startListening,
        );

  static VoidCallback _startListening(
    InheritedContext<ChangeEmitter> e,
    ChangeEmitter value,
  ) {
    var subscripton =
        value.changes.listen((event) => e.markNeedsNotifyDependents());
    return () => subscripton.cancel();
  }
}
