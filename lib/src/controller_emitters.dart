part of 'change_emitter_base.dart';

///A [ChangeEmitter] that lets you read values from and control a [TextField]. To use,
///provide the [TextField] with the [controller] property. The controller will be disposed when
///[this] is disposed. Should only be used with one TextField at a time.
class TextEditingEmitter extends EmitterContainer {
  ///Control and read the text from a [TextField].
  final ValueEmitter<String> text;

  ///Control and read selection.
  final selection = ValueEmitter(TextSelection.collapsed(offset: -1));

  ///Control and read composition.
  final composing = ValueEmitter(TextRange.empty);
  final TextEditingController controller;
  late StreamSubscription _subscription;

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

  get children => [text, selection, composing];

  void dispose() {
    _subscription.cancel();
    controller.dispose();
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
        offset = OffsetEmitter(initialScrollOffset) {
    offset.changes.where((change) => !change.setByController).listen((change) {
      controller.removeListener(_listener);
      controller.jumpTo(change.newValue!);
      controller.addListener(_listener);
    });
    controller.addListener(_listener);
  }

  _listener() => offset._controllerSet(controller.offset);

  final ScrollController controller;
  final OffsetEmitter offset;

  void jumpTo(double offset) => this.offset.value = offset;

  void animateTo(double offset,
          {required Duration duration, required Curve curve}) =>
      controller.animateTo(offset, duration: duration, curve: curve);

  get children => [offset];

  dispose() {
    controller.dispose();
    super.dispose();
  }
}

class OffsetEmitter extends ValueEmitter<double> {
  OffsetEmitter(double initialOffset) : super(initialOffset);

  Stream<OffsetChange> get changes =>
      super.changes.map<OffsetChange>((change) => change as OffsetChange);

  void _controllerSet(double newValue) {
    if (value != newValue) {
      var oldValue = value;
      setValue(newValue);
      addChangeToStream(OffsetChange(oldValue, newValue, true));
    }
  }

  set value(double newValue) {
    if (value != newValue) {
      var oldValue = value;
      setValue(newValue);
      addChangeToStream(OffsetChange(oldValue, newValue, false));
    }
  }
}

class OffsetChange extends ValueChange<double> {
  OffsetChange(double oldValue, double newValue, this.setByController)
      : super(
          oldValue,
          newValue,
        );

  final bool setByController;
}
