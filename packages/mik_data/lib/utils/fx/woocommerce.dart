import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/scope_authorization.dart';
import 'business_context.dart';

class WooConnection {
  final String id, name, siteUrl, status, moneyUnit;
  final String? branchId, lastError;
  final int businessId, revision;
  final bool enabled, allowRemoteEdits;
  final DateTime? connectedAt;
  final Map<String, dynamic> payment;
  WooConnection(Object? value) : this._(RemoteJson(value));
  WooConnection._(RemoteJson row)
    : payment = Map<String, dynamic>.unmodifiable(
        row.value['payment'] == null
            ? <String, dynamic>{}
            : RemoteJson(row.value['payment']).value,
      ),
      id = row.text('connectionId'),
      businessId = row.number('businessId'),
      name = row.text('name'),
      siteUrl = row.text('siteUrl'),
      branchId = row.optionalText('branchId'),
      status = row.text('status'),
      moneyUnit = row.text('moneyUnit'),
      enabled = row.flag('enabled'),
      allowRemoteEdits = row.flag('allowRemoteEdits'),
      revision = row.number('revision'),
      connectedAt = row.optionalText('connectedAt') == null
          ? null
          : DateTime.parse(row.text('connectedAt')),
      lastError = row.optionalText('lastErrorCode') {
    WooCommerceFX.uuid(id);
    if (branchId != null) WooCommerceFX.uuid(branchId!);
    WooCommerceFX.site(siteUrl);
    if (revision < 1 ||
        ![
          'AWAITING_PAIRING',
          'CONNECTING',
          'ACTIVE',
          'SUSPENDED',
        ].contains(status) ||
        !['RIAL', 'TOMAN'].contains(moneyUnit)) {
      throw const FormatException('Invalid WooCommerce connection');
    }
  }
}

class WooCommand {
  final String action, key, _body;
  final String? id, connectionId;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  WooCommand(
    this.action,
    Map<String, dynamic> body, {
    this.id,
    this.connectionId,
  }) : key = const Uuid().v4(),
       _body = jsonEncode(body);
  WooCommand.fromJson(Object? value) : this._(RemoteJson(value));
  WooCommand._(RemoteJson row)
    : action = row.text('action'),
      key = row.text('key'),
      id = row.optionalText('id'),
      connectionId = row.optionalText('connectionId'),
      _body = jsonEncode(RemoteJson(row.value['body']).value) {
    WooCommerceFX.uuid(key);
    if (id != null) WooCommerceFX.uuid(id!);
    if (connectionId != null) WooCommerceFX.uuid(connectionId!);
  }
  Map<String, dynamic> toJson() => {
    'action': action,
    'key': key,
    'id': id,
    'connectionId': connectionId,
    'body': body,
  };
}

class WooCommerceFX {
  final BusinessContext context;
  final FlutterSecureStorage storage;
  final String? branchId;
  ScopeAuthorization? access;
  WooCommand? pending;
  bool sending = false;
  WooCommerceFX(this.context, {this.storage = const FlutterSecureStorage()})
    : branchId = context.selectedBranch?.branchId;
  int get businessId => context.session.business.businessId;
  String get base => '/v1/businesses/$businessId';
  String get _key =>
      'woocommerce.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId';
  void check() {
    context.check();
    if (context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  static void uuid(String value) {
    if (!Uuid.isValidUUID(fromString: value)) {
      throw const FormatException('Invalid WooCommerce id');
    }
  }

  static String site(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port != 443) {
      throw const FormatException(
        'Site URL must be HTTPS without credentials or query',
      );
    }
    final result = uri.toString();
    return result.endsWith('/')
        ? result.substring(0, result.length - 1)
        : result;
  }

  bool has(String permission) =>
      context.valid && access?.permissionCodes.contains(permission) == true;
  Future<void> authorize() async {
    check();
    access = null;
    final result = ScopeAuthorization.fromJson(
      await context.request(
        'GET',
        '$base/authorization',
        query: {'scopeType': 'BUSINESS', 'scopeId': '$businessId'},
      ),
    );
    check();
    if (!result.allowed ||
        result.businessId != businessId ||
        result.membershipId != context.session.business.membershipId ||
        result.scopeType != 'BUSINESS' ||
        result.scopeId != '$businessId') {
      throw const FormatException('Unexpected WooCommerce authorization');
    }
    access = result;
  }

  void require(String permission) {
    check();
    if (!has(permission)) throw const AuthError(403, 'FORBIDDEN');
  }

  Future<RemoteJson> request(
    String method,
    String path, {
    Object? body,
    String? key,
    Map<String, String>? query,
  }) async {
    check();
    final result = RemoteJson(
      await context.request(
        method,
        '$base/$path',
        data: body,
        idempotencyKey: key,
        query: query,
      ),
    );
    check();
    return result;
  }

  WooConnection connection(Object? value, {String? id}) {
    final row = WooConnection(value);
    if (row.businessId != businessId || id != null && row.id != id) {
      throw const FormatException('Unexpected WooCommerce scope');
    }
    return row;
  }

  Future<List<WooConnection>> list() async {
    require('woocommerce.connection.read');
    final rows = <WooConnection>[], ids = <String>{};
    String? after;
    do {
      final page = await request(
        'GET',
        'woocommerce/connections',
        query: {'limit': '50', 'after': ?after},
      );
      final items = page.items('items', (v) => connection(v));
      for (final item in items) {
        if (!ids.add(item.id) ||
            after != null && item.id.compareTo(after) <= 0) {
          throw const FormatException('Invalid WooCommerce cursor');
        }
      }
      rows.addAll(items);
      final next = page.optionalText('nextCursor');
      if (next != null && (items.isEmpty || next != items.last.id)) {
        throw const FormatException('Invalid WooCommerce cursor');
      }
      after = next;
    } while (after != null);
    return rows;
  }

  Future<WooConnection> get(String id) async {
    require('woocommerce.connection.read');
    uuid(id);
    return connection(
      (await request('GET', 'woocommerce/connections/$id')).value['item'],
      id: id,
    );
  }

  RemoteJson policy(Object? value, String connectionId) {
    final row = RemoteJson(value);
    uuid(row.text('channelWarehouseAccessId'));
    if (row.number('businessId') != businessId ||
        row.text('channelConnectionId') != connectionId ||
        row.text('storefrontKind') != 'WOOCOMMERCE' ||
        row.number('revision') < 1 ||
        !['ALL', 'SELECTED'].contains(row.text('warehouseMode'))) {
      throw const FormatException('Unexpected WooCommerce warehouse policy');
    }
    final order = row.strings('warehouseOrder');
    for (final id in order) {
      uuid(id);
    }
    if (order.toSet().length != order.length) {
      throw const FormatException('Duplicate warehouse');
    }
    return row;
  }

  Future<RemoteJson> warehousePolicy(String connectionId) async {
    require('business.channel-warehouse-access.read');
    uuid(connectionId);
    final result = await request(
      'GET',
      'channel-warehouse-access',
      query: {'channelConnectionId': connectionId, 'limit': '2'},
    );
    final rows = result.items('items', (v) => policy(v, connectionId));
    if (rows.length != 1 || result.optionalText('nextCursor') != null) {
      throw const FormatException(
        'Missing or ambiguous channel warehouse policy',
      );
    }
    return rows.single;
  }

  Future<List<({String id, String name})>> externalProfiles(
    WooConnection target,
  ) async {
    check();
    if (target.businessId != businessId ||
        target.branchId != branchId ||
        branchId == null) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
    final rows = <({String id, String name})>[];
    final ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final page = await request(
        'GET',
        'accounting/treasury/settlement-profiles',
        query: {'status': 'ACTIVE', 'limit': '100', 'after': ?after},
      );
      if (page.number('businessId') != businessId) {
        throw const FormatException('Unexpected settlement scope');
      }
      for (final row in page.items('items', RemoteJson.new)) {
        final id = row.text('settlementProfileId');
        uuid(id);
        if (!ids.add(id) ||
            row.number('businessId') != businessId ||
            row.text('branchId') != branchId) {
          throw const FormatException('Unexpected settlement profile');
        }
        // Woo receipts must use the adapter and connection checked by accounting.
        if (row.text('status') == 'ACTIVE' &&
            ['ONLINE', 'SHARED_ONLINE'].contains(row.text('kind')) &&
            row.value['adapterProducer'] == 'mik-woocommerce' &&
            row.value['connectionId'] == target.id) {
          rows.add((id: id, name: row.text('name')));
        }
      }
      after = page.optionalText('nextCursor');
      if (after != null && !cursors.add(after)) {
        throw const FormatException('Repeated settlement cursor');
      }
    } while (after != null);
    return rows;
  }

  Future<WooCommand?> restore() async {
    check();
    if (sending) return pending;
    final raw = await storage.read(key: _key);
    check();
    return pending = raw == null ? null : WooCommand.fromJson(jsonDecode(raw));
  }

  Future<RemoteJson> send(WooCommand command) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    try {
      check();
      pending ??= await restorePending();
      if (pending != null &&
          (pending!.key != command.key ||
              jsonEncode(pending!.toJson()) != jsonEncode(command.toJson()))) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      await authorize();
      final action = command.action, body = command.body;
      uuid(command.key);
      final id = command.id;
      if (id != null) uuid(id);
      final permission = switch (action) {
        'CREATE' => 'woocommerce.connection.create',
        'UPDATE' || 'PAIR' || 'PROFILE' => 'woocommerce.connection.update',
        'POLICY' => 'business.channel-warehouse-access.update',
        _ => throw const FormatException('Invalid WooCommerce command'),
      };
      require(permission);
      if (action != 'CREATE' && id == null) {
        throw const FormatException('Missing WooCommerce target');
      }
      if (action == 'CREATE') {
        site(RemoteJson(body).text('siteUrl'));
        if (!['RIAL', 'TOMAN'].contains(body['moneyUnit']) ||
            body['branchId'] != branchId ||
            branchId == null) {
          throw const FormatException('Invalid WooCommerce creation scope');
        }
      }
      if (action == 'POLICY') {
        if (command.connectionId == null) {
          throw const FormatException('Missing policy connection');
        }
        uuid(command.connectionId!);
      }
      if (action == 'PROFILE') {
        final target = await get(id!);
        if (target.branchId != branchId ||
            body['connectionId'] != id ||
            body['adapterProducer'] != 'mik-woocommerce' ||
            body['kind'] != 'ONLINE') {
          throw const FormatException('Unexpected settlement creation scope');
        }
      }
      final pairedSite = action == 'PAIR' ? (await get(id!)).siteUrl : null;
      final path = action == 'PROFILE'
          ? 'accounting/treasury/settlement-profiles'
          : action == 'POLICY'
          ? 'channel-warehouse-access/$id'
          : 'woocommerce/connections${id == null ? '' : '/$id'}${action == 'PAIR' ? '/pairing' : ''}';
      pending = command;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      try {
        final result = await request(
          action == 'UPDATE' || action == 'POLICY' ? 'PATCH' : 'POST',
          path,
          body: body,
          key: command.key,
        );
        if (action == 'PAIR') {
          if (result.text('connectionId') != id ||
              !RegExp(r'^[A-Za-z0-9_-]{43}$')
                  .hasMatch(result.text('pairingCode')) ||
              !DateTime.parse(result.text('expiresAt')).isUtc) {
            throw const FormatException('Invalid pairing response');
          }
          if (site(result.text('siteUrl')) != pairedSite) {
            throw const FormatException('Unexpected pairing site');
          }
          site(result.text('gatewayOrigin'));
        } else if (action == 'PROFILE') {
          final profile = RemoteJson(result.value['profile']);
          uuid(profile.text('settlementProfileId'));
          if (result.number('businessId') != businessId ||
              profile.number('businessId') != businessId ||
              profile.text('branchId') != branchId ||
              profile.text('connectionId') != id ||
              profile.text('adapterProducer') != 'mik-woocommerce' ||
              profile.text('fundId') != body['fundId'] ||
              profile.text('status') != 'ACTIVE') {
            throw const FormatException('Unexpected settlement confirmation');
          }
        } else if (action == 'POLICY') {
          if (command.connectionId == null) {
            throw const FormatException('Missing policy connection');
          }
          final row = policy(result.value['item'], command.connectionId!);
          if (row.text('channelWarehouseAccessId') != id ||
              row.number('revision') != body['expectedRevision'] + 1 ||
              row.text('warehouseMode') != body['warehouseMode'] ||
              jsonEncode(row.strings('warehouseOrder')) !=
                  jsonEncode(body['warehouseOrder'])) {
            throw const FormatException('Unexpected policy confirmation');
          }
        } else {
          final row = connection(result.value['item'], id: id);
          for (final key in ['name', 'enabled', 'allowRemoteEdits']) {
            if (body.containsKey(key) &&
                RemoteJson(result.value['item']).value[key] != body[key]) {
              throw const FormatException('Unexpected connection confirmation');
            }
          }
          if (action == 'CREATE' &&
                  (row.siteUrl != site(body['siteUrl'] as String) ||
                      row.branchId != branchId ||
                      row.moneyUnit != body['moneyUnit'] ||
                      row.enabled ||
                      row.status != 'AWAITING_PAIRING') ||
              action == 'UPDATE' &&
                  row.revision != body['expectedRevision'] + 1) {
            throw const FormatException('Unexpected connection confirmation');
          }
        }
        await storage.delete(key: _key);
        pending = null;
        return result;
      } on AuthError catch (error) {
        if (error.statusCode < 500 &&
            !error.retryable &&
            !error.requiresLogin &&
            error.statusCode != 403 &&
            ![
              'IDEMPOTENCY_CONFLICT',
              'SELECTION_CHANGED',
            ].contains(error.code)) {
          await storage.delete(key: _key);
          pending = null;
        }
        rethrow;
      }
    } finally {
      sending = false;
    }
  }

  Future<WooCommand?> restorePending() async {
    final raw = await storage.read(key: _key);
    check();
    return raw == null ? null : WooCommand.fromJson(jsonDecode(raw));
  }
}
