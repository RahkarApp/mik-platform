/// Applies a server change to a local box without acknowledging failed writes.
abstract final class SocketStore {
  static Future<dynamic> apply({
    required dynamic box,
    required int operation,
    required dynamic value,
    required Object? identity,
    required Object? Function(dynamic) identityOf,
    bool singleton = false,
  }) async {
    if (operation < 0 || operation > 2) {
      throw ArgumentError.value(operation, 'operation');
    }
    if (singleton) {
      if (operation == 2) {
        if (box.isEmpty) return null;
        final previous = box.getAt(0);
        await box.deleteAt(0);
        return previous;
      }
      if (box.isEmpty) {
        await box.add(value);
      } else {
        await box.putAt(0, value);
      }
      return value;
    }
    if (identity == null || identity == '') {
      throw ArgumentError.value(identity, 'identity');
    }
    for (var index = 0; index < box.length; index++) {
      final stored = box.getAt(index);
      if (stored != null && identityOf(stored) == identity) {
        if (operation == 2) {
          await box.deleteAt(index);
          return stored;
        }
        await box.putAt(index, value);
        return value;
      }
    }
    if (operation != 2) {
      await box.add(value);
      return value;
    }
    return null;
  }
}
