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

class ScrollEmitter extends EmitterContainer {
  ScrollEmitter({
    double initialScrollOffset = 0.0,
    bool keepScrollOffset = true,
    String? debugLabel,
  })  : controller = ScrollController(
            initialScrollOffset: initialScrollOffset,
            keepScrollOffset: keepScrollOffset,
            debugLabel: debugLabel),
        _offset = ValueEmitter(_OffsetSource(initialScrollOffset, false)) {
    _offset.changes.where((change) => !change.newValue.fromController).listen((change) {
      controller.removeListener(_listener);
      controller.jumpTo(change.newValue.offset);
      controller.addListener(_listener);
    });
    controller.addListener(_listener);
  }

  _listener() => _offset.value = _OffsetSource(controller.offset, true);

  final ScrollController controller;
  final ValueEmitter<_OffsetSource> _offset;

  set offset(double offset) => _offset.value = _OffsetSource(offset, false);

  double get offset => _offset.value.offset;

  void jumpTo(double offset) => this._offset.value = _OffsetSource(offset, false);

  void animateTo(double offset, {required Duration duration, required Curve curve}) =>
      controller.animateTo(offset, duration: duration, curve: curve);

  get children => {_offset};

  dispose() {
    Timer(Duration(seconds: 3), () => controller.dispose());
    super.dispose();
  }
}

class _OffsetSource {
  _OffsetSource(this.offset, this.fromController);
  final double offset;
  final bool fromController;
}
