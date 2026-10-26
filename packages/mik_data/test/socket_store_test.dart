import 'package:flutter_test/flutter_test.dart';
import 'package:mik_data/source/remote/sockets/socket_store.dart';

class FakeBox {
  final List<dynamic> items;
  bool failWrites = false;
  FakeBox([List<dynamic> values = const []]) : items = List.of(values);
  bool get isEmpty => items.isEmpty;
  int get length => items.length;
  dynamic getAt(int index) => items[index];
  Future<void> add(dynamic value) async {
    if (failWrites) throw StateError('write failed');
    items.add(value);
  }

  Future<void> putAt(int index, dynamic value) async {
    if (failWrites) throw StateError('write failed');
    items[index] = value;
  }

  Future<void> deleteAt(int index) async {
    if (failWrites) throw StateError('write failed');
    items.removeAt(index);
  }
}

void main() {
  Future<dynamic> apply(FakeBox box, int operation, Map value) =>
      SocketStore.apply(
        box: box,
        operation: operation,
        value: value,
        identity: value['uid'],
        identityOf: (v) => v['uid'],
      );

  test('replayed create updates the same record without duplication', () async {
    final box = FakeBox();
    await apply(box, 0, {'uid': 'a', 'name': 'old'});
    await apply(box, 0, {'uid': 'a', 'name': 'new'});
    expect(box.items, [
      {'uid': 'a', 'name': 'new'},
    ]);
  });

  test('edit arriving before create inserts the missing record', () async {
    final box = FakeBox();
    await apply(box, 1, {'uid': 'a'});
    expect(box.items, [
      {'uid': 'a'},
    ]);
  });

  test('settings can be inserted and edited without a UID', () async {
    final box = FakeBox();
    for (final name in ['old', 'new']) {
      await SocketStore.apply(
        box: box,
        operation: 1,
        value: {'name': name},
        identity: null,
        identityOf: (_) => throw StateError('No UID on settings'),
        singleton: true,
      );
    }
    expect(box.items, [
      {'name': 'new'},
    ]);
  });

  test('user deletion matches ID and returns the deleted record', () async {
    final box = FakeBox([
      {'id': 7},
      {'id': 8},
    ]);
    final deleted = await SocketStore.apply(
      box: box,
      operation: 2,
      value: 7,
      identity: 7,
      identityOf: (v) => v['id'],
    );
    expect(deleted, {'id': 7});
    expect(box.items, [
      {'id': 8},
    ]);
  });

  test(
    'warehouse edits preserve distinct variants in the same warehouse',
    () async {
      final box = FakeBox([
        {'p': 'p', 'w': 'w', 'v': 'a', 'stock': 2},
        {'p': 'p', 'w': 'w', 'v': 'b', 'stock': 3},
      ]);
      await SocketStore.apply(
        box: box,
        operation: 1,
        value: {'p': 'p', 'w': 'w', 'v': 'b', 'stock': 5},
        identity: ('p', 'w', 'b'),
        identityOf: (v) => (v['p'], v['w'], v['v']),
      );
      expect(box.items.map((v) => v['stock']), [2, 5]);
    },
  );

  test('failed writes propagate instead of reporting success', () async {
    final box = FakeBox()..failWrites = true;
    await expectLater(apply(box, 0, {'uid': 'a'}), throwsStateError);
    expect(box.items, isEmpty);
  });

  test('missing identities and unknown operations are rejected', () async {
    final box = FakeBox();
    await expectLater(apply(box, 0, {}), throwsArgumentError);
    await expectLater(apply(box, 3, {'uid': 'a'}), throwsArgumentError);
    expect(box.items, isEmpty);
  });
}
