import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:collection/collection.dart';

import 'package:change_emitter/change_emitter.dart';

var eq = DeepCollectionEquality();

class ExampleEmitter extends EmitterContainer {
  final elist = EmitterList([]);
  final liste = ListEmitter([]);
  get children => {elist};
}

void main() {
  //list emitter tests
  test('ListEmitter test of removeRange', () {
    var list = [1, 2, 3, 4, 5, 6];
    var listEmitter = ListEmitter(list);

    listEmitter.removeRange(1, 4);
    list.removeRange(1, 4);
    expect(eq.equals(list, listEmitter), true);
  });

  test('ListEmitter test of setting new length', () {
    var list = <int?>[1, 2, 3, 4, 5, 6];
    var listEmitter = ListEmitter(list);

    listEmitter.length = 9;
    list.length = 9;
    expect(eq.equals(list, listEmitter), true);
  });

  test('ListEmitter multi-unit test', () {
    var list = <int?>[1, 2, 3, 4, 5, 6];
    var listEmitter = ListEmitter(list);

    void visitList(List<int?> list) {
      list.length = 9;
      list.addAll([5, 3, 7, 8]);
      list.removeLast();
      list.retainWhere((element) => element != null);
      list.removeRange(1, 4);
      list.replaceRange(2, list.length - 1, [1, 2, 3]);
    }

    visitList(list);
    visitList(listEmitter);

    expect(eq.equals(list, listEmitter), true);
  });

  test('MapEmitter multi-unit test', () {
    var map = <String, int>{'one': 1, 'two': 2, 'three': 3};
    var mapEmitter = MapEmitter(map);

    void visitMap(Map<String, int> map) {
      map['four'] = 4;
      map.remove('two');
    }

    visitMap(map);
    visitMap(mapEmitter);

    expect(eq.equals(map, mapEmitter), true);
  });

  //regression tests
  test('check for concurrent modification during iteration of removewhere', () {
    var list = ListEmitter([1, 2, 3, 4]);
    list.removeWhere((element) => element == 1);
    expect(eq.equals(list, [2, 3, 4]), true);
  });

  test('EmitterList disposes of removed children', () async {
    var emitter = ValueEmitter(1);
    var list = EmitterList([emitter]);
    list.removeLast();
    await Future.delayed(Duration(milliseconds: 200));
    expect(emitter.isDisposed, true);
  });

  test('ValueEmitter.reactive constructor works without throwing', () {
    var a = ValueEmitter.reactive(reactTo: [], withValue: () => true);
    expect((a is ValueEmitter<bool>), true);
  });

  test('findAncestorOfExactType works in deep heirarchies', () {
    var example = ExampleEmitter();
    var secondExample = ExampleEmitter();
    example.registerChildren();
    example.elist.add(secondExample);
    var ancestor = secondExample.findAncestorOfExactType<ExampleEmitter>();
    expect(example, ancestor);
  });

  test('transactions work on Lists', () async {
    final list = ListEmitter([1, 2, 3, 4]);
    var numEmits = 0;
    list.changes.listen((event) => numEmits++);
    list.startTransaction();
    list.add(3);
    list.remove(2);
    list[0] = 6;
    list.endTransaction();
    await Future.delayed(Duration(milliseconds: 300));
    expect(numEmits, 1);
  });
  test('transactions work on maps', () async {
    final map = MapEmitter({0: 1, 4: 5, 3: 4});
    var numEmits = 0;
    map.changes.listen((event) {
      numEmits++;
      print('hello');
    });
    map.startTransaction();
    map.addEntries([MapEntry(5, 3)]);
    map.remove(2);
    map[0] = 6;
    map.endTransaction();
    await Future.delayed(Duration(milliseconds: 500));
    expect(numEmits, 1);
  });

  test('list emits once on methods that nest other mutation methods', () async {
    final list = ListEmitter([2, 3, 4, 5]);
    var numEmits = 0;
    list.changes.listen((event) => numEmits++);
    list.addAll([4, 5, 67, 3]);
    await Future.delayed(Duration(milliseconds: 300));
    expect(numEmits, 1);
  });

  test('changing selected index causes SelectableEmitterList to emit', () async {
    final list = SelectableEmitterList([ValueEmitter(0), ValueEmitter(2)], selectedIndex: 0);
    var didEmit = false;
    list.changes.listen((_) => didEmit = true);
    list.selectedIndex = 1;
    await Future.delayed(Duration(milliseconds: 300));
    expect(didEmit, true);
  });

  test('using transaction on a container catches all child changes', () async {
    final emitter = ExampleEmitter();
    var numChanges = 0;
    emitter.changes.listen((event) => numChanges++);
    emitter.startTransaction();

    emitter.liste.add(5);
    emitter.liste.add(7);
    emitter.liste.add(7);
    emitter.liste.add(7);
    emitter.liste.add(7);
    emitter.endTransaction();
    await Future.delayed(Duration(milliseconds: 500));
    expect(numChanges, 1);
  });
}
