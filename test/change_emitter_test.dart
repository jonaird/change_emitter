import 'package:flutter_test/flutter_test.dart';

import 'package:collection/collection.dart';

import 'package:change_emitter/change_emitter.dart';

void main() {
  test('ListEmitter test', () {
    var list = [1, 2, 3, 4, 5, 6];
    var listEmitter = ListEmitter(list);
    var eq = DeepCollectionEquality();
    listEmitter.removeRange(1, 4);
    list.removeRange(1, 4);
    print(listEmitter);
    print(list);
    expect(eq.equals(list, listEmitter), true);
  });
}
