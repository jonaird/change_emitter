import 'dart:async';
import 'package:flutter/material.dart';
// import 'dart:math';
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
  group('ListEmitter', () {
    test('removeRange should work as expected', () {
      var list = [1, 2, 3, 4, 5, 6];
      var listEmitter = ListEmitter(list);

      listEmitter.removeRange(1, 4);
      list.removeRange(1, 4);
      expect(eq.equals(list, listEmitter), true);
    });

    test('setting new length works', () {
      var list = <int?>[1, 2, 3, 4, 5, 6];
      var listEmitter = ListEmitter(list);

      listEmitter.length = 9;
      list.length = 9;
      expect(eq.equals(list, listEmitter), true);
    });

    test('multi-unit test', () {
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
    test('only emits once using a transaction', () async {
      final list = ListEmitter([1, 2, 3, 4]);
      var numEmits = 0;
      list.changes.listen((event) => numEmits++);
      list.startTransaction();
      list.add(3);
      list.remove(2);
      list[0] = 6;
      list.endTransaction();
      scheduleMicrotask(() => expect(numEmits, 1));
    });
    test('emits once on methods that nest other mutation methods', () async {
      final list = ListEmitter([2, 3, 4, 5]);
      var numEmits = 0;
      list.changes.listen((event) => numEmits++);
      list.addAll([4, 5, 67, 3]);
      scheduleMicrotask(() => expect(numEmits, 1));
    });
    test('check for concurrent modification during iteration of removewhere', () {
      var list = ListEmitter([1, 2, 3, 4]);
      list.removeWhere((element) => element == 1);
      expect(eq.equals(list, [2, 3, 4]), true);
    });
  });

  group('MapEmitter', () {
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
    test('transactions only emit once', () async {
      final map = MapEmitter({0: 1, 4: 5, 3: 4});
      var numEmits = 0;
      map.changes.listen((event) {
        numEmits++;
      });
      map.startTransaction();
      map.addEntries([MapEntry(5, 3)]);
      map.remove(2);
      map[0] = 6;
      map.endTransaction();
      scheduleMicrotask(() => expect(numEmits, 1));
    });
  });

  test('EmitterList disposes of removed children', () async {
    var emitter = ValueEmitter(1);
    var list = EmitterList([emitter]);
    list.removeLast();
    await Future.delayed(Duration(milliseconds: 200));
    scheduleMicrotask(() => expect(emitter.isDisposed, true));
  });

  test('ValueEmitter.reactive constructor works without throwing', () {
    var a = ValueEmitter.reactive(reactTo: [], withValue: () => true);
  });
  group('EmitterContainer', () {
    test('findAncestorOfExactType works in deep heirarchies', () {
      var example = ExampleEmitter();
      var secondExample = ExampleEmitter();
      example.registerChildren();
      example.elist.add(secondExample);
      var ancestor = secondExample.findAncestorOfExactType<ExampleEmitter>();
      expect(example, ancestor);
    });

    test('only emits once after a transaction', () async {
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
      scheduleMicrotask(() => expect(numChanges, 1));
    });
  });

  group('ScrollEmitter', () {
    testWidgets('restores correct scroll position', (widgetTester) async {
      var showScrollView = ValueNotifier(true);
      final scrollEmitter = ScrollEmitter();

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Material(
            child: AnimatedBuilder(
              animation: showScrollView,
              builder: (context, _) {
                if (showScrollView.value) {
                  return ListView.builder(
                    controller: scrollEmitter,
                    itemBuilder: (context, index) => ListTile(title: Text(index.toString())),
                  );
                } else
                  return Container();
              },
            ),
          ),
        ),
      );

      var listFinder = find.byType(Scrollable);
      var itemFinder = find.text('50');

      await widgetTester.scrollUntilVisible(itemFinder, 50, scrollable: listFinder);
      expect(scrollEmitter.offset, isNot(0));

      final savedOffset = scrollEmitter.offset;
      showScrollView.value = false;
      await widgetTester.pump();
      expect(listFinder, findsNothing);

      showScrollView.value = true;
      await widgetTester.pump();
      expect(scrollEmitter.offset, savedOffset);

      return Future.value();
    });
  });
}
