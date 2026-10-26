import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';

class SettlementProfilesFX {
  final BusinessContext context;
  final String? branchId;
  final FlutterSecureStorage storage;
  bool sending = false;
  SettlementProfilesFX(
    this.context, {
    this.storage = const FlutterSecureStorage(),
  }) : branchId = context.selectedBranch?.branchId;
  int get businessId => context.session.business.businessId;
  static void uuid(String value) {
    if (!Uuid.isValidUUID(fromString: value))
      throw const FormatException('Invalid settlement identity');
  }

  String get base => '/v1/businesses/${context.session.business.businessId}';
  String get key =>
      'settlement-profile.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.${context.session.business.businessId}.$branchId';
  void check() {
    context.check();
    if (branchId == null || context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<Map<String, dynamic>?> restore() async {
    check();
    final raw = await storage.read(key: key);
    check();
    return raw == null ? null : RemoteJson(jsonDecode(raw)).value;
  }

  Future<String> create(Map<String, dynamic>? data) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    try {
      check();
      final saved = await restore();
      if (saved != null &&
          data != null &&
          jsonEncode(saved['body']) != jsonEncode(data)) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      final command = saved ?? {'key': const Uuid().v4(), 'body': data};
      final body = RemoteJson(command['body']).value;
      if (!['payment', 'mik-woocommerce'].contains(body['adapterProducer']) ||
          !Uuid.isValidUUID(
            fromString: body['connectionId'] as String? ?? '',
          ) ||
          !Uuid.isValidUUID(fromString: command['key'] as String? ?? '')) {
        throw const FormatException('Invalid settlement profile scope');
      }
      await storage.write(key: key, value: jsonEncode(command));
      try {
        final response = RemoteJson(
          await context.request(
            'POST',
            '$base/accounting/treasury/settlement-profiles',
            data: body,
            idempotencyKey: command['key'] as String,
          ),
        );
        check();
        final row = RemoteJson(response.value['profile']);
        final id = row.text('settlementProfileId');
        if (!Uuid.isValidUUID(fromString: id) ||
            response.number('businessId') !=
                context.session.business.businessId ||
            row.number('businessId') != context.session.business.businessId ||
            row.text('branchId') != branchId ||
            row.text('fundId') != body['fundId'] ||
            row.text('adapterProducer') != body['adapterProducer'] ||
            row.text('connectionId') != body['connectionId'] ||
            row.text('status') != 'ACTIVE') {
          throw const FormatException(
            'Unexpected settlement profile confirmation',
          );
        }
        await storage.delete(key: key);
        return id;
      } on AuthError catch (error) {
        if (error.statusCode < 500 &&
            !error.retryable &&
            !error.requiresLogin &&
            error.statusCode != 403 &&
            ![
              'IDEMPOTENCY_CONFLICT',
              'SELECTION_CHANGED',
            ].contains(error.code)) {
          await storage.delete(key: key);
        }
        rethrow;
      }
    } finally {
      sending = false;
    }
  }

  Future<List<({String id, String name})>> gateways() async {
    check();

    final page = RemoteJson(
      await context.request('GET', '$base/payment-gateways'),
    );
    check();
    return page
        .items('items', (value) {
          final row = RemoteJson(value), id = row.text('gatewayAccountId');
          uuid(id);
          if (row.number('businessId') != businessId ||
              row.text('platformId') != 'mik' ||
              row.text('ownership') != 'BUSINESS') {
            throw const FormatException('Unexpected payment gateway');
          }
          return (
            id: id,
            name: row.text('name'),
            active: row.text('status') == 'ACTIVE',
          );
        })
        .where((row) => row.active)
        .map((row) => (id: row.id, name: row.name))
        .toList();
  }

  Future<List<({String id, String name, String gatewayId})>>
  settlementProfiles() async {
    check();
    final rows = <({String id, String name, String gatewayId})>[],
        cursors = <String>{},
        ids = <String>{};
    String? after;
    do {
      final page = RemoteJson(
        await context.request(
          'GET',
          '$base/accounting/treasury/settlement-profiles',
          query: {'limit': '100', 'status': 'ACTIVE', 'after': ?after},
        ),
      );
      check();
      if (page.number('businessId') != businessId) {
        throw const FormatException('Unexpected settlement scope');
      }
      for (final value in page.items('items', RemoteJson.new)) {
        final id = value.text('settlementProfileId');
        uuid(id);
        if (!ids.add(id) ||
            value.number('businessId') != businessId ||
            value.text('branchId') != branchId) {
          throw const FormatException('Unexpected settlement profile');
        }
        if (value.text('status') == 'ACTIVE' &&
            value.value['adapterProducer'] == 'payment' &&
            ['ONLINE', 'SHARED_ONLINE'].contains(value.text('kind'))) {
          final gateway = value.text('connectionId');
          uuid(gateway);
          rows.add((id: id, name: value.text('name'), gatewayId: gateway));
        }
      }
      after = page.optionalText('nextCursor');
      if (after != null && !cursors.add(after)) {
        throw const FormatException('Repeated settlement cursor');
      }
    } while (after != null);
    return rows;
  }
}
