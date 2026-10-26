import 'settlement_profiles.dart';

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/remote_json.dart';
import 'package:mik_data/source/remote/models/scope_authorization.dart';
import 'package:mik_data/utils/fx/business_context.dart';

class RemoteShop {
  final String id, name, subdomain, status, syncStatus, domainStatus;
  final String? branchId, customDomain, syncError;
  final int businessId, revision;
  final String description;
  final Map<String, dynamic> branding, payment;
  final Map<String, dynamic>? domainVerification;
  final bool enabled;
  final List<String> hosts;
  RemoteShop(Object? value) : this._(RemoteJson(value));
  RemoteShop._(RemoteJson row)
    : description = (row.value['description'] as String?) ?? '',
      branding = Map.unmodifiable(
        (row.value['branding'] as Map<String, dynamic>?) ?? {},
      ),
      payment = Map.unmodifiable(
        (row.value['payment'] as Map<String, dynamic>?) ?? {'enabled': false},
      ),
      domainVerification = row.value['domainVerification'] == null
          ? null
          : Map.unmodifiable(RemoteJson(row.value['domainVerification']).value),
      id = row.text('shopId'),
      businessId = row.number('businessId'),
      branchId = row.optionalText('branchId'),
      name = row.text('name'),
      subdomain = row.text('subdomain'),
      status = row.text('status'),
      syncStatus = row.text('syncStatus'),
      domainStatus = row.text('domainStatus'),
      enabled = row.flag('enabled'),
      revision = row.number('revision'),
      hosts = List.unmodifiable(row.strings('hosts')),
      customDomain = row.optionalText('customDomain'),
      syncError = row.optionalText('syncErrorCode') {
    ShopFX.uuid(id);
    if (branchId != null) ShopFX.uuid(branchId!);
    if (hosts.isEmpty ||
        hosts.toSet().length != hosts.length ||
        revision < 1 ||
        !['PROVISIONING', 'ACTIVE', 'SUSPENDED'].contains(status) ||
        !['PENDING', 'PROCESSING', 'READY', 'FAILED'].contains(syncStatus) ||
        !['NONE', 'PENDING', 'VERIFIED'].contains(domainStatus)) {
      throw const FormatException('Invalid shop response');
    }
    for (final host in hosts) {
      ShopFX.host(host);
    }
    if (customDomain != null) ShopFX.host(customDomain!);
    if (domainStatus == 'VERIFIED' &&
        (customDomain == null || !hosts.contains(customDomain))) {
      throw const FormatException('Invalid verified shop domain');
    }
  }
  // Only hosts returned by the server may be opened; pending domains are not public.
  Uri get url =>
      Uri.https(domainStatus == 'VERIFIED' ? customDomain! : hosts.first, '');
  bool get ready => enabled && status == 'ACTIVE' && syncStatus == 'READY';
}

class ShopCommand {
  final String key, _body;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  ShopCommand(Map<String, dynamic> body)
    : key = const Uuid().v4(),
      _body = jsonEncode(body);
  ShopCommand.fromJson(Object? value) : this._(RemoteJson(value));
  ShopCommand._(RemoteJson row)
    : key = row.text('key'),
      _body = jsonEncode(RemoteJson(row.value['body']).value) {
    ShopFX.uuid(key);
  }
  Map<String, Object> toJson() => {'key': key, 'body': body};
}

class ShopFX {
  final BusinessContext context;
  final FlutterSecureStorage storage;
  final String? branchId;
  ScopeAuthorization? access;
  ShopCommand? pending;
  ShopManagementCommand? managementPending;
  bool sending = false;
  ShopFX(this.context, {this.storage = const FlutterSecureStorage()})
    : branchId = context.selectedBranch?.branchId;
  int get businessId => context.session.business.businessId;
  String get base => '/v1/businesses/$businessId';
  String get _key =>
      'shop.create.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId';
  void check() {
    context.check();
    if (context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  static void uuid(String value) {
    if (!Uuid.isValidUUID(fromString: value)) {
      throw const FormatException('Invalid shop id');
    }
  }

  static void host(String value) {
    if (value.length > 253 ||
        !value.contains('.') ||
        value
            .split('.')
            .any(
              (label) => !RegExp(
                r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
                caseSensitive: false,
              ).hasMatch(label),
            ) ||
        RegExp(r'^\d+(\.\d+){3}$').hasMatch(value)) {
      throw const FormatException('Invalid shop host');
    }
  }

  static String subdomain(String value) {
    final result = value.trim().toLowerCase();
    if (result.length > 63 ||
        !RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(result) ||
        [
          'www',
          'api',
          'admin',
          'crm',
          'mail',
          'payment',
          'static',
          'assets',
        ].contains(result)) {
      throw const FormatException('Invalid or reserved shop subdomain');
    }
    return result;
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
      throw const FormatException('Unexpected shop authorization');
    }
    access = result;
  }

  RemoteShop parse(Object? value, {String? id}) {
    final row = RemoteShop(value);
    if (row.businessId != businessId || id != null && row.id != id) {
      throw const FormatException('Unexpected shop scope');
    }
    return row;
  }

  Future<List<RemoteShop>> list() async {
    check();
    if (!has('shop.store.read')) throw const AuthError(403, 'FORBIDDEN');
    final result = <RemoteShop>[], ids = <String>{};
    String? after;
    do {
      final page = RemoteJson(
        await context.request(
          'GET',
          '$base/shops',
          query: {'limit': '50', 'after': ?after},
        ),
      );
      check();
      final items = page.items('items', (v) => parse(v));
      for (final row in items) {
        if (!ids.add(row.id) || after != null && row.id.compareTo(after) <= 0) {
          throw const FormatException('Invalid shop pagination');
        }
      }
      result.addAll(items);
      final next = page.optionalText('nextCursor');
      if (next != null && (items.isEmpty || next != items.last.id)) {
        throw const FormatException('Invalid shop cursor');
      }
      after = next;
    } while (after != null);
    return result;
  }

  Future<RemoteShop> get(String id) async {
    check();
    uuid(id);
    if (!has('shop.store.read')) throw const AuthError(403, 'FORBIDDEN');
    final page = RemoteJson(await context.request('GET', '$base/shops/$id'));
    check();
    return parse(page.value['item'], id: id);
  }

  Future<({bool excluded, String? priceId, int revision})> publication(
    String shopId,
    String productId,
  ) async {
    check();
    uuid(shopId);
    uuid(productId);
    if (!has('shop.publication.read')) throw const AuthError(403, 'FORBIDDEN');
    final page = RemoteJson(
      await context.request(
        'GET',
        '$base/shops/$shopId/products/$productId/publication',
      ),
    );
    check();
    final item = RemoteJson(page.value['item']);
    final revision = item.number('revision'),
        priceId = item.optionalText('productPriceId');
    if (item.text('productId') != productId || revision < 0) {
      throw const FormatException('Unexpected product publication');
    }
    if (priceId != null) uuid(priceId);
    return (
      excluded: item.flag('excluded'),
      priceId: priceId,
      revision: revision,
    );
  }

  String get _managementKey => '$_key.management';

  Future<void> restoreManagement() async {
    check();
    if (sending) return;
    final raw = await storage.read(key: _managementKey);
    check();
    managementPending = raw == null
        ? null
        : ShopManagementCommand.fromJson(jsonDecode(raw));
  }

  RemoteJson parseWarehousePolicy(Object? value, String shopId) {
    final row = RemoteJson(value);
    uuid(row.text('channelWarehouseAccessId'));
    if (row.number('businessId') != businessId ||
        row.text('channelConnectionId') != shopId ||
        (row.value['storefrontKind'] ?? 'SHOP') != 'SHOP' ||
        row.number('revision') < 1 ||
        !['ALL', 'SELECTED'].contains(row.text('warehouseMode'))) {
      throw const FormatException('Unexpected shop warehouse policy');
    }
    final order = row.strings('warehouseOrder');
    for (final id in order) {
      uuid(id);
    }
    if (order.length > 30 || order.toSet().length != order.length) {
      throw const FormatException('Invalid shop warehouse policy');
    }
    return row;
  }

  Future<RemoteJson> warehousePolicy(String shopId) async {
    check();
    uuid(shopId);
    if (!has('business.channel-warehouse-access.read')) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final page = RemoteJson(
      await context.request(
        'GET',
        '$base/channel-warehouse-access',
        query: {'channelConnectionId': shopId, 'limit': '2'},
      ),
    );
    check();
    final rows = page.items(
      'items',
      (value) => parseWarehousePolicy(value, shopId),
    );
    if (page.number('businessId') != businessId ||
        rows.length != 1 ||
        page.optionalText('nextCursor') != null) {
      throw const FormatException('Missing or ambiguous shop warehouse policy');
    }
    return rows.single;
  }

  Future<List<ShopShippingMethod>> shipping(String shopId) async {
    check();
    uuid(shopId);
    if (!has('shop.shipping.read')) throw const AuthError(403, 'FORBIDDEN');
    final rows = <ShopShippingMethod>[], ids = <String>{};
    String? after;
    do {
      final page = RemoteJson(
        await context.request(
          'GET',
          '$base/shops/$shopId/shipping-methods',
          query: {'limit': '50', 'after': ?after},
        ),
      );
      check();
      final items = page.items('items', ShopShippingMethod.new);
      for (final row in items) {
        if (!ids.add(row.id) || after != null && row.id.compareTo(after) <= 0) {
          throw const FormatException('Invalid shipping pagination');
        }
      }
      rows.addAll(items);
      final next = page.optionalText('nextCursor');
      if (next != null && (items.isEmpty || next != items.last.id)) {
        throw const FormatException('Invalid shipping cursor');
      }
      after = next;
    } while (after != null);
    return rows;
  }

  Future<List<({String id, String name})>> gateways() async {
    check();
    if (!has('payment.gateway.manage')) throw const AuthError(403, 'FORBIDDEN');
    return SettlementProfilesFX(context).gateways();
  }

  Future<List<({String id, String name, String gatewayId})>>
  settlementProfiles() async {
    check();
    if (branchId == null ||
        !context.hasPermission('accounting.payout.read', inBranch: true)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    return SettlementProfilesFX(context).settlementProfiles();
  }

  Future<Object> manage(ShopManagementCommand command) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    try {
      check();
      final raw = await storage.read(key: _managementKey);
      check();
      managementPending = raw == null
          ? managementPending
          : ShopManagementCommand.fromJson(jsonDecode(raw));
      if (managementPending != null &&
          jsonEncode(managementPending!.toJson()) !=
              jsonEncode(command.toJson())) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      await authorize();
      if (!has(command.permission) ||
          command.action == ShopManagementAction.update &&
              command.body.containsKey('payment') &&
              !has('payment.gateway.manage')) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      command.validate();
      managementPending = command;
      await storage.write(
        key: _managementKey,
        value: jsonEncode(command.toJson()),
      );
      try {
        final page = RemoteJson(
          await context.request(
            command.method,
            command.action == ShopManagementAction.warehousePolicy
                ? '$base/channel-warehouse-access/${command.resourceId}'
                : '$base/shops/${command.shopId}${command.suffix}',
            data: command.body,
            idempotencyKey: command.key,
          ),
        );
        check();
        final Object result;
        switch (command.action) {
          case ShopManagementAction.update:
          case ShopManagementAction.verifyDomain:
            final shop = parse(page.value['item'], id: command.shopId);
            if (command.action == ShopManagementAction.update &&
                    shop.revision != command.body['expectedRevision'] + 1 ||
                command.action == ShopManagementAction.verifyDomain &&
                    shop.domainStatus != 'VERIFIED') {
              throw const FormatException('Unexpected store update receipt');
            }
            if (command.action == ShopManagementAction.update) {
              final values = <String, Object?>{
                'name': shop.name,
                'description': shop.description,
                'enabled': shop.enabled,
              };
              for (final entry in values.entries) {
                if (command.body.containsKey(entry.key) &&
                    command.body[entry.key] != entry.value) {
                  throw const FormatException('Unexpected store field receipt');
                }
              }
              for (final field in ['branding', 'payment']) {
                if (!command.body.containsKey(field)) continue;
                final expected = RemoteJson(command.body[field]).value,
                    actual = field == 'branding' ? shop.branding : shop.payment;
                if (field == 'branding' && expected.length != actual.length ||
                    expected.entries.any(
                      (entry) => actual[entry.key] != entry.value,
                    )) {
                  throw const FormatException(
                    'Unexpected store settings receipt',
                  );
                }
              }
            }
            result = shop;
          case ShopManagementAction.shippingCreate:
          case ShopManagementAction.shippingUpdate:
            final row = ShopShippingMethod(page.value['item']);
            if (command.resourceId != null && row.id != command.resourceId ||
                row.revision != (command.body['expectedRevision'] ?? 0) + 1) {
              throw const FormatException('Unexpected shipping receipt');
            }
            final values = <String, Object?>{
              'name': row.name,
              'description': row.description,
              'amount': row.amount,
              'active': row.active,
              'requiresAddress': row.requiresAddress,
            };
            if (values.entries.any(
              (entry) =>
                  command.body.containsKey(entry.key) &&
                  command.body[entry.key] != entry.value,
            )) {
              throw const FormatException('Unexpected shipping fields');
            }
            result = row;
          case ShopManagementAction.publication:
            final row = RemoteJson(page.value['item']);
            if (row.text('productId') != command.resourceId ||
                row.number('revision') !=
                    command.body['expectedRevision'] + 1 ||
                row.flag('excluded') != command.body['excluded'] ||
                row.optionalText('productPriceId') !=
                    command.body['productPriceId']) {
              throw const FormatException('Unexpected publication receipt');
            }
            result = row.value;
          case ShopManagementAction.warehousePolicy:
            final row = parseWarehousePolicy(
              page.value['item'],
              command.shopId,
            );
            if (row.text('channelWarehouseAccessId') != command.resourceId ||
                row.number('revision') !=
                    command.body['expectedRevision'] + 1 ||
                row.text('warehouseMode') != command.body['warehouseMode'] ||
                jsonEncode(row.strings('warehouseOrder')) !=
                    jsonEncode(command.body['warehouseOrder'])) {
              throw const FormatException(
                'Unexpected warehouse policy receipt',
              );
            }
            result = row;
          case ShopManagementAction.recover:
            if (!page.flag('accepted')) {
              throw const FormatException('Recovery was not accepted');
            }
            if (command.body['mode'] == 'FAILED_EVENTS' &&
                page.number('recoveredCount') < 0) {
              throw const FormatException('Invalid recovery count');
            }
            result = page.value;
        }
        await storage.delete(key: _managementKey);
        managementPending = null;
        return result;
      } on AuthError catch (error) {
        // An ambiguous timeout keeps the exact key and body for a safe replay.
        if (error.statusCode < 500 &&
            !error.retryable &&
            !error.requiresLogin &&
            error.statusCode != 403 &&
            ![
              'IDEMPOTENCY_CONFLICT',
              'SELECTION_CHANGED',
            ].contains(error.code)) {
          await storage.delete(key: _managementKey);
          managementPending = null;
        }
        rethrow;
      }
    } finally {
      sending = false;
    }
  }

  Future<ShopCommand?> restore() async {
    check();
    if (sending) return pending;
    final raw = await storage.read(key: _key);
    check();
    return pending = raw == null ? null : ShopCommand.fromJson(jsonDecode(raw));
  }

  Future<RemoteShop> create(ShopCommand command) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    try {
      check();
      if (pending == null) {
        final raw = await storage.read(key: _key);
        check();
        pending = raw == null ? null : ShopCommand.fromJson(jsonDecode(raw));
      }
      if (pending != null &&
          (pending!.key != command.key ||
              jsonEncode(pending!.toJson()) != jsonEncode(command.toJson()))) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      await authorize();
      if (!has('shop.store.create') ||
          !has('business.channel-warehouse-access.update')) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      final body = RemoteJson(command.body), name = body.text('name').trim();
      if (name.isEmpty ||
          name.length > 200 ||
          RegExp(r'[\x00-\x1f]').hasMatch(name) ||
          body.text('subdomain') != subdomain(body.text('subdomain')) ||
          (body.optionalText('branchId') != null &&
              body.optionalText('branchId') != branchId)) {
        throw const FormatException('Invalid shop creation');
      }
      if (body.optionalText('branchId') != null) uuid(body.text('branchId'));
      uuid(command.key);
      pending = command;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      try {
        final result = RemoteJson(
          await context.request(
            'POST',
            '$base/shops',
            data: command.body,
            idempotencyKey: command.key,
          ),
        );
        check();
        final row = parse(result.value['item']);
        if (row.name != name ||
            row.subdomain != body.text('subdomain') ||
            row.branchId != body.optionalText('branchId') ||
            row.status != 'PROVISIONING' ||
            !row.enabled ||
            row.revision != 1) {
          throw const FormatException('Unexpected shop creation receipt');
        }
        await storage.delete(key: _key);
        pending = null;
        return row;
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
}

class ShopShippingMethod {
  final String id, name, description;
  final int amount, revision;
  final bool active, requiresAddress;
  ShopShippingMethod(Object? value) : this._(RemoteJson(value));
  ShopShippingMethod._(RemoteJson row)
    : id = row.text('shippingMethodId'),
      name = row.text('name'),
      description = row.value['description'] as String,
      amount = row.number('amount'),
      revision = row.number('revision'),
      active = row.flag('active'),
      requiresAddress = row.flag('requiresAddress') {
    ShopFX.uuid(id);
    if (row.text('currency') != 'TOMAN' ||
        amount < 0 ||
        amount > 9000000000000 ||
        revision < 1) {
      throw const FormatException('Invalid shipping response');
    }
  }
}

enum ShopManagementAction {
  update,
  verifyDomain,
  shippingCreate,
  shippingUpdate,
  publication,
  recover,
  warehousePolicy,
}

class ShopManagementCommand {
  final ShopManagementAction action;
  final String shopId, key, _body;
  final String? resourceId;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  ShopManagementCommand(
    this.action,
    this.shopId,
    Map<String, dynamic> body, {
    this.resourceId,
  }) : key = const Uuid().v4(),
       _body = jsonEncode(body);
  ShopManagementCommand.fromJson(Object? value) : this._(RemoteJson(value));
  ShopManagementCommand._(RemoteJson row)
    : action = ShopManagementAction.values.byName(row.text('action')),
      shopId = row.text('shopId'),
      resourceId = row.optionalText('resourceId'),
      key = row.text('key'),
      _body = jsonEncode(RemoteJson(row.value['body']).value) {
    validate();
  }
  Map<String, Object?> toJson() => {
    'action': action.name,
    'shopId': shopId,
    'resourceId': resourceId,
    'key': key,
    'body': body,
  };
  String get permission => switch (action) {
    ShopManagementAction.update ||
    ShopManagementAction.verifyDomain => 'shop.store.update',
    ShopManagementAction.shippingCreate ||
    ShopManagementAction.shippingUpdate => 'shop.shipping.manage',
    ShopManagementAction.publication => 'shop.publication.update',
    ShopManagementAction.recover => 'shop.sync.recover',
    ShopManagementAction.warehousePolicy =>
      'business.channel-warehouse-access.update',
  };
  String get method => switch (action) {
    ShopManagementAction.update ||
    ShopManagementAction.shippingUpdate ||
    ShopManagementAction.warehousePolicy => 'PATCH',
    ShopManagementAction.publication => 'PUT',
    _ => 'POST',
  };
  String get suffix => switch (action) {
    ShopManagementAction.update || ShopManagementAction.warehousePolicy => '',
    ShopManagementAction.verifyDomain => '/domain/verify',
    ShopManagementAction.shippingCreate => '/shipping-methods',
    ShopManagementAction.shippingUpdate => '/shipping-methods/$resourceId',
    ShopManagementAction.publication => '/products/$resourceId/publication',
    ShopManagementAction.recover => '/sync/recover',
  };
  void validate() {
    ShopFX.uuid(key);
    ShopFX.uuid(shopId);
    if ([
      ShopManagementAction.shippingUpdate,
      ShopManagementAction.publication,
      ShopManagementAction.warehousePolicy,
    ].contains(action)) {
      ShopFX.uuid(resourceId ?? '');
    }
    final revision = body['expectedRevision'];
    if ([
          ShopManagementAction.update,
          ShopManagementAction.shippingUpdate,
          ShopManagementAction.publication,
          ShopManagementAction.warehousePolicy,
        ].contains(action) &&
        (revision is! int ||
            revision < (action == ShopManagementAction.publication ? 0 : 1))) {
      throw const FormatException('Invalid shop revision');
    }
    if (action == ShopManagementAction.recover) {
      if (!['RECONCILE', 'FAILED_EVENTS', 'ORDER'].contains(body['mode'])) {
        throw const FormatException('Invalid recovery mode');
      }
      if (body['mode'] == 'ORDER') {
        ShopFX.uuid(body['orderId'] as String);
        if (revision is! int || revision < 1) {
          throw const FormatException('Invalid order revision');
        }
      }
    }
  }
}
