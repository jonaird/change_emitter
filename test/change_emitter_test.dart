import 'package:flutter_test/flutter_test.dart';

import 'package:collection/collection.dart';

import 'package:change_emitter/change_emitter.dart';

var eq = DeepCollectionEquality();

class ExampleEmitter extends EmitterContainer {
  final elist = EmitterList([]);

  get children => [elist];
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
    list.emit();
    await Future.delayed(Duration(milliseconds: 200));
    expect(emitter.isDisposed, true);
  });

  test('ValueEmitter.reactive constructor works without throwing', () {
    var a = ValueEmitter.reactive(reactTo: [], withValue: () => true);
    expect(a.runtimeType, ValueEmitter);
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
}
