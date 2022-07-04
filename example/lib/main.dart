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
  get children => {tabs};

  void addTab() => tabs.add(TabState());

  void removeTab() => tabs.removeLast();
}

class TabState extends EmitterContainer {
  ///A [TextEditingEmitter] is an adapter on top of a [TextEditingController] that
  ///allows you to use it like an [EmitterContainer] and exposes a
  ///[TextEditingEmitter.controller] to use in [TextField]s.
  ///The controller gets disposed when [this] is disposed.
  final TextEditingEmitter textInput = TextEditingEmitter(text: 'Some text');
  final bold = ValueEmitter(false);
  final italic = ValueEmitter(false);
  final color = ValueEmitter<Color>(Colors.red);
  final textViewModel = TextViewModel();

  ///This [ValueEmitter] will react to changes in [color] or [bold] and set its
  ///value using the builder. This means all we need to do is worry about setting the
  ///right color and value for bold and it will update automatically.

  late final ValueEmitter<bool> isRedAndBold = ValueEmitter.reactive(
    reactTo: [color, bold],
    withValue: () => color.value == Colors.red && bold.value,
  );

  void appendText() => textInput.text.value += ' text';

  void clearText() => textInput.text.value = '';

  ///Ancestors in the state tree are accessible after
  ///[ChangeEmitter.didRegisterWithParent] is fired letting you access [parent]
  ///and [findAncestorOfExactType]
  @override
  void didRegisterWithParent() {
    print(parent);
    print(findAncestorOfExactType<AppState>());
  }

  ///We have to provide a list of all [ChangeEmitter]s defined in this class.
  ///This makes for very easy disposing of resources. If [this] is ever disposed,
  ///children will be disposed as well. It will also register [this] as the
  ///parent of each child.
  @override
  get children => {textInput, bold, italic, color, isRedAndBold, textViewModel};
}

class TextViewModel extends EmitterContainer {
  TabState get parent => super.parent as TabState;

  bool get bold => parent.bold.value;
  bool get italic => parent.italic.value;
  Color get color => parent.color.value;
  String get text => parent.textInput.text.value;

  @override
  get dependencies => {parent.bold, parent.italic, parent.color, parent.textInput.text};
}

void main() {
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  static final appState = AppState();

  @override
  Widget build(BuildContext context) {
    return Provider<AppState>(
      appState,
      builder: (_, state) => DefaultTabController(
        length: state.tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('OST Example'),
            bottom: TabBar(
              tabs: state.tabs.toProviderList(
                  builder: (_, index, __) => Tab(child: Text(index.toString()))),
            ),
          ),
          body: TabBarView(children: state.tabs.toProviderList(child: const TextPage())),
          floatingActionButton: const FloatingActionButtons(),
        ),
      ),
    );
  }
}

class FloatingActionButtons extends StatelessWidget {
  const FloatingActionButtons();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          child: Icon(Icons.remove),

          ///access your state without rebuilding on changes using
          ///[BuildContext.read]
          onPressed: context.read<AppState>()!.removeTab,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: context.read<AppState>()!.addTab,
          ),
        ),
      ],
    );
  }
}

class TextPage extends StatelessWidget {
  const TextPage();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 500,
        height: 700,
        child: Column(
          children: [
            TextField(controller: context.read<TabState>()!.textInput.controller),
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
                builder: (_, ValueEmitter<bool> italic) =>
                    Switch(value: italic.value, onChanged: (value) => italic.value = value),
              )
            ]),
            Row(children: [
              Text('Color: '),
              Reprovider<TabState, ValueEmitter<Color>>(
                  selector: (state) => state.color,
                  builder: (_, color) => DropdownButton<Color>(
                        items: [
                          DropdownMenuItem(child: Text('red'), value: Colors.red),
                          DropdownMenuItem(child: Text('blue'), value: Colors.blue),
                          DropdownMenuItem(child: Text('green'), value: Colors.green),
                          DropdownMenuItem(child: Text('purple'), value: Colors.purple)
                        ],
                        value: color.value,
                        onChanged: (value) => color.value = value!,
                      ))
            ]),
            DisplayText(),
            RedAndBold(),
            TextButton(
              child: Text('append text'),
              onPressed: context.read<TabState>()!.appendText,
            ),
            TextButton(
              child: Text('clear'),
              onPressed: context.read<TabState>()!.clearText,
            ),
          ],
        ),
      ),
    );
  }
}

class RedAndBold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    ///we can use [BuildContext.select] to select for values.
    ///The builder will rebuild when the value changes.
    var isRedAndBold = context.select<TabState, bool>((state) => state.isRedAndBold.value);
    return Text("Red and bold: " + isRedAndBold.toString());
  }
}

///Here is the part we care about, correctly displaying our text.
class DisplayText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Reprovider(
        selector: (TabState state) => state.textViewModel,
        builder: (context, TextViewModel viewModel) {
          return Text(
            viewModel.text,
            style: TextStyle(
                color: viewModel.color,
                fontSize: 24,
                fontWeight: viewModel.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: viewModel.italic ? FontStyle.italic : FontStyle.normal),
          );
        });
  }
}
