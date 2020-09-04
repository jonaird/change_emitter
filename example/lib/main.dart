import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:change_emitter/change_emitter.dart';

void main() {
  runApp(
    ///We'll use the Provider package to provide state.
    ChangeEmitterProvider(
      create: (_) => TextState(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Upstate Example')),
        body: Center(
          child: Container(
            width: 500,
            height: 700,
            child: AppBody(),
          ),
        ),
      ),
    );
  }
}

///We can bundle everything we need to display our text by extending [EmitterContainer].
///This means that when any values change, our UI updates automatically.
class TextState extends EmitterContainer {
  final textInput = TextEditingEmitter(text: 'Some text');
  final bold = ValueEmitter(false);
  final italic = ValueEmitter(false);
  final color = ValueEmitter<Color>(Colors.red);
  ValueEmitter<bool> isRedAndBold;

  TextState() {
    ///This [ValueEmitter] will react to changes in [color] or [bold] and set its
    ///value using the builder. This means all we need to do is worry about setting the
    ///right color and value for bold and this will take care of itself!
    isRedAndBold = ValueEmitter.reactive(
      [color, bold],
      () => color.value == Colors.red && bold.value,
    );
  }

  ///We have to provide a list of all [ChangeEmitter]s defined in this class.
  ///This makes for very easy disposing of resources. If [this] is ever disposed,
  ///Which happens automatically when using [ChangeEmitterProvider], all of the
  ///children will be disposed as well! Convinient!
  @override
  get children => [textInput, bold, italic, color, isRedAndBold];

  ///We actually don't want all [children] to cause our UI to update. Since [isRedAndBold] updates
  ///on changes of other elements and we don't actually need it to display our text,
  ///we override this getter to provide a subset of children that should trigger updates. We
  ///also only want our text widget to update on changes to the [textInput]'s text property.
  @override
  get emittingChildren => [textInput.text, bold, italic, color];
}

class AppBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          ///[TextEditingEmitter] provides a controller for us to use. It will be disposed of automatically
          ///when our state is disposed.
          controller: Provider.of<TextState>(context, listen: false)
              .textInput
              .controller,
        ),
        Row(children: [
          Text('Bold: '),

          ///We can use a [ChangeEmitterSelector] to update some UI when only
          ///a subcomponent of our state changes. In this case we only want
          ///our switch to update when bold changes.
          ChangeEmitterSelector<TextState, ValueEmitter<bool>>(
            selector: (_, state) => state.bold,
            builder: (_, bold, __) => Switch(
              ///We get the value held by a [ValueEmitter] use the value property
              value: bold.value,

              ///We set a new value the same way.
              onChanged: (newValue) => bold.value = newValue,
            ),
          )
        ]),
        Row(children: [
          Text('Italic: '),
          ChangeEmitterSelector<TextState, ValueEmitter<bool>>(
            selector: (_, state) => state.italic,
            builder: (_, italic, __) => Switch(
              value: italic.value,
              onChanged: (value) => italic.value = value,
            ),
          )
        ]),
        Row(children: [
          Text('Color: '),
          ChangeEmitterSelector<TextState, ValueEmitter<Color>>(
            selector: (_, state) => state.color,
            builder: (_, color, __) => DropdownButton(
              items: [
                DropdownMenuItem(child: Text('red'), value: Colors.red),
                DropdownMenuItem(child: Text('blue'), value: Colors.blue),
                DropdownMenuItem(child: Text('green'), value: Colors.green),
                DropdownMenuItem(child: Text('purple'), value: Colors.purple)
              ],
              value: color.value,
              onChanged: (value) => color.value = value,
            ),
          )
        ]),
        MyText(),
        ChangeEmitterSelector(
          selector: (_, TextState state) => state.isRedAndBold,
          builder: (_, isRedAndBold, __) =>
              Text("Red and bold: " + isRedAndBold.value.toString()),
        ),
        FlatButton(
          child: Text('append text'),
          onPressed: () =>
              context.read<TextState>().textInput.text.value += ' text',
        ),
        FlatButton(
          child: Text('clear'),
          onPressed: () => context.read<TextState>().textInput.text.value = '',
        ),
      ],
    );
  }
}

///Here is the part we care about, correctly displaying our text.
class MyText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    ///We can use a vanilla [Consumer] from the Provider package which will call the builder whenever [TextState]
    ///changes.
    return Consumer<TextState>(
      builder: (context, state, child) {
        return Text(
          state.textInput.text.value,
          style: TextStyle(
              color: state.color.value,
              fontSize: 24,
              fontWeight:
                  state.bold.value ? FontWeight.bold : FontWeight.normal,
              fontStyle:
                  state.italic.value ? FontStyle.italic : FontStyle.normal),
        );
      },
    );
  }
}
