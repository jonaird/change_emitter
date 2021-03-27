import 'package:flutter/material.dart';
import 'package:change_emitter/change_emitter.dart';

/// An [EmitterContainer] is a [ChangeEmitter] that lets you compose other ChangeEmitters as children.
/// [AppState] will emit a [Change] whenever any of its [children] emit a change.
class AppState extends EmitterContainer {
  ///An [EmitterList] is a [ListEmitter] that can only take [ChangeEmitter]s as elements and automatically calls [ChangeEmitter.dispose] when
  ///they are removed from the list.
  final tabs = EmitterList([TabState()]);

  get children => [tabs];

  void addTab() => tabs
    ..add(TabState())
    ..emit();
}

class TabState extends EmitterContainer {
  final textInput = TextEditingEmitter(text: 'Some text');
  final bold = ValueEmitter(false);
  final italic = ValueEmitter(false);
  final color = ValueEmitter<Color>(Colors.red);

  ///This [ValueEmitter] will react to changes in [color] or [bold] and set its
  ///value using the builder. This means all we need to do is worry about setting the
  ///right color and value for bold and it will update automatically.

  late final ValueEmitter<bool> isRedAndBold = ValueEmitter.reactive(
    reactTo: [color, bold],
    withValue: () => color.value == Colors.red && bold.value,
  );

  ///We have to provide a list of all [ChangeEmitter]s defined in this class.
  ///This makes for very easy disposing of resources. If [this] is ever disposed,
  ///children will be disposed as well.
  @override
  get children => [textInput, bold, italic, color, isRedAndBold];

  ///We actually don't want all [children] to cause our UI to update. Since [isRedAndBold] updates
  ///on changes of other elements and we don't actually need it to display our text,
  ///we override this getter to provide a subset of children that should trigger updates. We
  ///also only want our text widget to update on changes to the [textInput]'s text property.
  @override
  get emittingChildren => [textInput.text, bold, italic, color];
}

void main() {
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    //We provide the root of our state tree using a [RootProvider]
    return RootProvider<AppState>(
      state: AppState(),
      builder: (_, state) => DefaultTabController(
        length: state.tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Reprovider Example'),
            bottom: TabBar(
              tabs: [
                for (int i = 0; i < state.tabs.length; i++)
                  Tab(child: Text(i.toString()))
              ],
            ),
          ),
          body: TabBarView(
              children: state.tabs.toProviderList(child: TextPage())),
          floatingActionButton: IconButton(
            icon: Icon(Icons.add),
            onPressed: () => state.addTab(),
          ),
        ),
      ),
    );
  }
}

class TextPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 500,
        height: 700,
        child: Column(
          children: [
            TextField(
              ///[TextEditingEmitter] provides a controller for us to use. It will be disposed of automatically
              ///when our state is disposed.
              controller: context.read<TabState>()!.textInput.controller,
            ),
            Row(children: [
              Text('Bold: '),
              Reprovider<TabState, ValueEmitter<bool>>(
                  selector: (state) => state.bold,
                  builder: (context, bold) => Switch(
                        ///We get the value held by a [ValueEmitter] use the [ValueEmitter.value] property
                        value: bold.value,

                        ///We set a new value the same way.
                        onChanged: (newValue) => bold.value = newValue,
                      ))
            ]),
            Row(children: [
              Text('Italic: '),
              Reprovider(
                selector: (TabState state) => state.italic,
                builder: (_, ValueEmitter<bool> italic) => Switch(
                    value: italic.value,
                    onChanged: (value) => italic.value = value),
              )
            ]),
            Row(children: [
              Text('Color: '),
              Reprovider<TabState, ValueEmitter<Color>>(
                  selector: (state) => state.color,
                  builder: (_, color) => DropdownButton<Color>(
                        items: [
                          DropdownMenuItem(
                              child: Text('red'), value: Colors.red),
                          DropdownMenuItem(
                              child: Text('blue'), value: Colors.blue),
                          DropdownMenuItem(
                              child: Text('green'), value: Colors.green),
                          DropdownMenuItem(
                              child: Text('purple'), value: Colors.purple)
                        ],
                        value: color.value,
                        onChanged: (value) => color.value = value!,
                      ))
            ]),
            DisplayText(),
            Reprovider<TabState, ValueEmitter<bool>>(
              selector: (state) => state.isRedAndBold,
              builder: (_, isRedAndBold) =>
                  Text("Red and bold: " + isRedAndBold.value.toString()),
            ),
            TextButton(
              child: Text('append text'),
              onPressed: () =>
                  context.read<TabState>()!.textInput.text.value += ' text',
            ),
            TextButton(
              child: Text('clear'),
              onPressed: () =>
                  context.read<TabState>()!.textInput.text.value = '',
            ),
          ],
        ),
      ),
    );
  }
}

///Here is the part we care about, correctly displaying our text.
class DisplayText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var state = context.depend<TabState>();

    return Text(
      state.textInput.text.value,
      style: TextStyle(
          color: state.color.value,
          fontSize: 24,
          fontWeight: state.bold.value ? FontWeight.bold : FontWeight.normal,
          fontStyle: state.italic.value ? FontStyle.italic : FontStyle.normal),
    );
  }
}
