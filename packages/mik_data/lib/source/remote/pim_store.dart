import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/pim_command.dart';

abstract interface class PimCommandStore {
  Future<PimCommand?> read(String key);
  Future<void> write(String key, PimCommand command);
  Future<void> clear(String key);
}

class SecurePimStore implements PimCommandStore {
  final FlutterSecureStorage storage;
  const SecurePimStore({this.storage = const FlutterSecureStorage()});
  @override
  Future<PimCommand?> read(String key) async {
    final value = await storage.read(key: key);
    return value == null ? null : PimCommand.fromJson(jsonDecode(value));
  }

  @override
  Future<void> write(String key, PimCommand command) =>
      storage.write(key: key, value: jsonEncode(command.toJson()));
  @override
  Future<void> clear(String key) => storage.delete(key: key);
}
