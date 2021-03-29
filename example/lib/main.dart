import 'package:flutter/material.dart';
import 'package:change_emitter/change_emitter.dart';

/// [RootEmitter] is an [EmitterContainer] which is a [ChangeEmitter] that lets
/// you compose other ChangeEmitters as children. [AppState] will emit a
/// [Change] whenever any of its [children] emit a change.
/// You should use [RootEmitter] for the top level [ChangeEmitter] in
/// order for children to be able to depend on state up the tree.
class AppState extends RootEmitter {
  ///An [EmitterList] is a [ListEmitter] that can only take [ChangeEmitter]s as
  ///children, registers itself as their parent and automatically calls
  ///[ChangeEmitter.dispose] on children when they are removed from the list.
  final tabs = EmitterList([TabState()]);

  @override
  get children => [tabs];

  void addTab() => tabs
    ..add(TabState())
    ..emit();

  void removeTab() => tabs
    ..removeLast()
    ..emit();
}

class TabState extends EmitterContainer {
  ///A [TextEditingEmitter] is an adapter on top of a [TextEditingController] that
  ///allows you to use it like an [EmitterContainer] and exposes a
  ///[TextEditingEmitter.controller] to use in [TextField]s.
  ///The controller gets disposed when [this] is disposed.
  final textInput = TextEditingEmitter(
    text: 'Some text',
    selectionShouldEmit: false,
    composingShouldEmit: false,
  );
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

  ///Ancestors in the state tree are accessible after
  ///[ChangeEmitter.didRegisterParent] is fired letting you access [parent]
  ///and [findAncestorOfExactType]
  @override
  void didRegisterParent() {
    print(parent);
    print(findAncestorOfExactType<AppState>());
  }

  ///We have to provide a list of all [ChangeEmitter]s defined in this class.
  ///This makes for very easy disposing of resources. If [this] is ever disposed,
  ///children will be disposed as well. It will also register [this] as the
  ///parent of each child.
  @override
  get children => [textInput, bold, italic, color, isRedAndBold];

  ///We actually don't want all [children] to cause our UI to update. Since [isRedAndBold] updates
  ///on changes of other elements and we don't actually need it to display our text,
  ///we override this getter to provide a subset of children that should trigger updates.
  @override
  get emittingChildren => [textInput, bold, italic, color];
}

void main() {
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    ///A top level [Provider] should either only be done in widgets that will
    ///never rebuild or you should define your [AppState] as a global singleton
    return Provider<AppState>(
      state: AppState(),
      builder: (_, state) => DefaultTabController(
        length: state.tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text('OST Example'),
            bottom: TabBar(
              tabs: state.tabs.toProviderList(
                  builder: (_, index, __) =>
                      Tab(child: Text(index.toString()))),
            ),
          ),
          body: TabBarView(
              children: state.tabs.toProviderList(child: TextPage())),
          floatingActionButton: FloatingActionButtons(),
        ),
      ),
    );
  }
}

class FloatingActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          child: Icon(Icons.remove),

          ///access your state without rebuilding on changes using
          ///[BuildContext.read]
          onPressed: () => context.read<AppState>()!.removeTab(),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () => context.read<AppState>()!.addTab(),
          ),
        ),
      ],
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
                controller: context.read<TabState>()!.textInput.controller),
            Row(children: [
              Text('Bold: '),

              ///we can use a [Reprovider] to depend on a portion of our app state
              Reprovider<TabState, ValueEmitter<bool>>(
                  selector: (state) => state.bold,
                  builder: (context, bold) => Switch(
                        ///We get the value held by a [ValueEmitter] use the
                        ///[ValueEmitter.value] property
                        value: bold.value,

                        ///We set a new value the same way which will cause
                        ///our UI to update.
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
            Builder(
              builder: (builderContext) {
                ///we can use [BuildContext.select] to select for values.
                ///The builder will rebuild when the value changes.
                var isRedAndBold = builderContext.select<TabState, bool>(
                    (state) => state.isRedAndBold.value);
                return Text("Red and bold: " + isRedAndBold.toString());
              },
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
    ///depending on the [TabState] in our widget scope will rebuild whenever
    ///it emits a change i.e. whenever an element of [TabState.emittingChildren]
    ///emits a change.
    var state = context.depend<TabState>()!;

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
