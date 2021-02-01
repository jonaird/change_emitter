import 'package:flutter_test/flutter_test.dart';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:change_emitter/change_emitter.dart';

var eq = DeepCollectionEquality();

class ExampleEmitter extends EmitterContainer {
  final elist = EmitterList([]);

  get children => [elist];
}

void main() {
  test('ListEmitter test of removeRange', () {
    var list = [1, 2, 3, 4, 5, 6];
    var listEmitter = ListEmitter(list);

    listEmitter.removeRange(1, 4);
    list.removeRange(1, 4);
    print(listEmitter);
    print(list);
    expect(eq.equals(list, listEmitter), true);
  });

  test('check for concurrent modification during iteration of removewhere', () {
    var list = ListEmitter([1, 2, 3, 4]);
    list.removeWhere((element) => element == 1);
    expect(eq.equals(list, [2, 3, 4]), true);
  });

  test('EmitterList disposes of removed children', () async {
    var emitter = ValueEmitter(1);
    var list = EmitterList([emitter]);
    list.removeLast();
    list.emit();
    await Future.delayed(Duration(milliseconds: 200));
    expect(emitter.isDisposed, true);
  });

  test('ValueEmitter.reactive constructor works without throwing', () {
    var a = ValueEmitter.reactive(reactTo: [], withValue: () => true);
  });

  test('findAncestorOfExactType works in deep heirarchies', () {
    var example = ExampleEmitter();
    var secondExample = ExampleEmitter();
    example.registerChildren();
    example.elist
      ..add(secondExample)
      ..emit();
    var ancestor = secondExample.findAncestorOfExactType<ExampleEmitter>();
    expect(example, ancestor);
  });

  testWidgets('scroll emitter doesnt duplicate changes',
      (WidgetTester tester) async {
    var scroll = ScrollEmitter();
    await tester.pumpWidget(MaterialApp(
        home: ListView(controller: scroll.controller, children: [])));
    scroll.offset.value = 5;
    print('scroll emitter test');
  });
}
