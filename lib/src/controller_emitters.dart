part of 'change_emitter_base.dart';

///A [ChangeEmitter] that lets you read values from and control a [TextField]. To use,
///provide the [TextField] with the [controller] property. The controller will be disposed when
///[this] is disposed. Should only be used with one TextField at a time.
class TextEditingEmitter extends EmitterContainer {
  TextEditingEmitter({String text = ''})
      : text = ValueEmitter(text),
        controller = TextEditingController(text: text) {
    _subscription = changes.listen((change) {
      controller.value = controller.value.copyWith(
        text: this.text.value,
        selection: selection.value,
        composing: composing.value,
      );
    });
    controller.addListener(() {
      this.text.value = controller.text;
      selection.value = controller.selection;
      composing.value = controller.value.composing;
    });
  }

  ///Control and read the text from a [TextField].
  final ValueEmitter<String> text;

  ///Control and read selection.
  final selection = ValueEmitter(TextSelection.collapsed(offset: -1));

  ///Control and read composition.
  final ValueEmitter<TextRange> composing = ValueEmitter(TextRange.empty);
  final TextEditingController controller;
  late StreamSubscription _subscription;

  get children => {text, selection, composing};

  get dependencies => {text, selection, composing};

  void dispose() {
    _subscription.cancel();
    //sometimes the controller is still attached to a view after disposing.
    Timer(Duration(seconds: 3), () => controller.dispose());
    super.dispose();
  }
}

///A drop in replacement for [ScrollController] that is also a [ChangeEmitter].
///[ScrollEmiiter] differs in behavior in 2 ways:
/// 1. It can only be used with one [Scrollable] widget at a time.
/// 2. The scroll position is stored internally rather than in [PageStorage].
/// These changes allow scroll position to be treated as part of app state.
class ScrollEmitter extends ScrollController implements ChangeEmitter<double> {
  ScrollEmitter({super.initialScrollOffset = 0, super.debugLabel})
      : _storedOffset = initialScrollOffset,
        super(keepScrollOffset: false);
  final _streamController = StreamController<double>.broadcast();
  Stream<double> get changes => _streamController.stream;
  ParentEmitter? _parent;
  void register(ParentEmitter newParent) => _parent = newParent;
  ParentEmitter? get parent => _parent;
  bool get isDisposed => _streamController.isClosed;

  double _storedOffset;

  @override
  void attach(ScrollPosition newPosition) {
    if (positions.isNotEmpty)
      throw ('ScrollEmitter should only be used with one Scrollable widget at a time');
    newPosition.addListener(_onPositionChange);
    super.attach(newPosition);
  }

  @override
  void detach(ScrollPosition position) {
    super.detach(position);
    position.removeListener(_onPositionChange);
  }

  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return ScrollPositionWithSingleContext(
      physics: physics,
      context: context,
      initialPixels: _storedOffset,
      keepScrollOffset: false,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }

  void _onPositionChange() {
    _streamController.add(position.pixels);
    _storedOffset = position.pixels;
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }
}
