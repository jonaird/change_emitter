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
  StreamSubscription _subscription;

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
