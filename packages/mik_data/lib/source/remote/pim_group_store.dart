import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/pim_product_draft.dart';

abstract interface class PimGroupStore {
  Future<PimGroupState> read(String key);
  Future<void> write(String key, PimGroupState state);
}

class SecurePimGroupStore implements PimGroupStore {
  final FlutterSecureStorage storage;
  const SecurePimGroupStore({this.storage = const FlutterSecureStorage()});
  @override
  Future<PimGroupState> read(String key) async {
    final value = await storage.read(key: key);
    return value == null
        ? const PimGroupState()
        : PimGroupState.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> write(String key, PimGroupState state) =>
      storage.write(key: key, value: jsonEncode(state.toJson()));
}
