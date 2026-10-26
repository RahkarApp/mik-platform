import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/scope_authorization.dart';
import '../../source/remote/models/treasury.dart';
import 'business_context.dart';

class TreasuryCommand {
  final String key, resource, _body;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  TreasuryCommand(this.resource, Map<String, dynamic> body)
    : key = const Uuid().v4(),
      _body = jsonEncode(body);
  TreasuryCommand.fromJson(Object? value) : this._(RemoteJson(value));
  TreasuryCommand._(RemoteJson data)
    : key = data.text('key'),
      resource = data.text('resource'),
      _body = jsonEncode(RemoteJson(data.value['body']).value) {
    if (!Uuid.isValidUUID(fromString: key) ||
        !['funds', 'terminals'].contains(resource)) {
      throw const FormatException('Invalid treasury command');
    }
  }
  bool get update =>
      body.containsKey(resource == 'funds' ? 'fundId' : 'terminalId');
  Map<String, Object?> toJson() => {
    'key': key,
    'resource': resource,
    'body': body,
  };
}

class TreasuryFX {
  static final _clients = Expando<Map<String, TreasuryFX>>();
  static TreasuryFX forContext(BusinessContext context, String branchId) {
    final clients = _clients[context] ??= {};
    final current = clients[branchId];
    if (current == null ||
        current._selected != context.selectedBranch?.branchId) {
      return clients[branchId] = TreasuryFX(context, branchId);
    }
    return current;
  }

  final BusinessContext context;
  final String branchId;
  final FlutterSecureStorage storage;
  final String? _selected;
  ScopeAuthorization? _business, _branch;
  TreasuryCommand? pending;
  Future<Object>? _sending;
  TreasuryFX(
    this.context,
    this.branchId, {
    this.storage = const FlutterSecureStorage(),
  }) : _selected = context.selectedBranch?.branchId;
  int get businessId => context.session.business.businessId;
  String get _base => '/v1/businesses/$businessId/accounting/treasury';
  String get _key =>
      'treasury.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId';
  void check() {
    context.check();
    if (!Uuid.isValidUUID(fromString: branchId) ||
        context.selectedBranch?.branchId != _selected) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  bool has(String permission, {bool business = false}) =>
      context.valid &&
      (business ? _business : _branch)?.permissionCodes.contains(permission) ==
          true;
  bool canManageFund(String kind) => has(
    kind == 'BANK' ? 'accounting.bank.manage' : 'accounting.treasury.manage',
    business: kind == 'BANK',
  );
  bool get canManageTerminal => has('accounting.terminal.manage');
  bool get canUseBank => has('accounting.bank.use', business: true);
  Future<void> authorize() async {
    check();
    _business = _branch = null;
    for (final scope in ['BUSINESS', 'BRANCH']) {
      final id = scope == 'BUSINESS' ? '$businessId' : branchId;
      final access = ScopeAuthorization.fromJson(
        await context.auth.request(
          'GET',
          '/v1/businesses/$businessId/authorization',
          query: {'scopeType': scope, 'scopeId': id},
        ),
      );
      check();
      if (!access.allowed ||
          access.businessId != businessId ||
          access.membershipId != context.session.business.membershipId ||
          access.scopeType != scope ||
          access.scopeId != id) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if (scope == 'BUSINESS') {
        _business = access;
      } else {
        _branch = access;
      }
    }
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? data,
    String? key,
  }) async {
    check();
    // Explicit branch scope also supports management from another branch's sheet.
    final result = await context.auth.request(
      method,
      path,
      branchId: branchId,
      query: query,
      data: data,
      idempotencyKey: key,
    );
    check();
    return result;
  }

  void _fundScope(TreasuryFund row) {
    if (row.businessId != businessId ||
        row.kind != 'BANK' && row.branchId != branchId) {
      throw const FormatException('Unexpected treasury scope');
    }
  }

  void _terminalScope(TreasuryTerminal row) {
    if (row.businessId != businessId || row.branchId != branchId) {
      throw const FormatException('Unexpected terminal scope');
    }
  }

  Future<List<TreasuryFund>> funds(String kind) async {
    if (!['CASH', 'PETTY_CASH', 'BANK'].contains(kind)) {
      throw const FormatException('Invalid fund kind');
    }
    if (!has(
      kind == 'BANK' ? 'accounting.bank.read' : 'accounting.treasury.read',
      business: kind == 'BANK',
    )) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final rows = <TreasuryFund>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await _request(
          'GET',
          '$_base/funds',
          query: {'kind': kind, 'limit': '100', 'after': ?after},
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected treasury business');
      }
      for (final row in json.items('items', TreasuryFund.fromJson)) {
        _fundScope(row);
        if (row.kind != kind || !ids.add(row.id)) {
          throw const FormatException('Unexpected fund');
        }
        rows.add(row);
      }
      after = json.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Invalid treasury cursor');
      }
    } while (after != null);
    return rows;
  }

  Future<List<TreasuryTerminal>> terminals() async {
    if (!has('accounting.terminal.read')) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final rows = <TreasuryTerminal>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await _request(
          'GET',
          '$_base/terminals',
          query: {'limit': '100', 'after': ?after},
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected treasury business');
      }
      for (final row in json.items('items', TreasuryTerminal.fromJson)) {
        _terminalScope(row);
        if (!ids.add(row.id)) throw const FormatException('Repeated terminal');
        rows.add(row);
      }
      after = json.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Invalid treasury cursor');
      }
    } while (after != null);
    return rows;
  }

  Future<TreasuryCommand?> restore() async {
    check();
    if (_sending != null) return pending;
    final value = await storage.read(key: _key);
    check();
    return pending = value == null
        ? null
        : TreasuryCommand.fromJson(jsonDecode(value));
  }

  Future<Object> send(TreasuryCommand command) {
    if (_sending != null) {
      if (pending?.key != command.key) {
        return Future.error(const AuthError(409, 'IDEMPOTENCY_CONFLICT'));
      }
      return _sending!;
    }
    final request = _send(command);
    _sending = request;
    return request.whenComplete(() => _sending = null);
  }

  Future<Object> _send(TreasuryCommand command) async {
    check();
    pending ??= await restore();
    if (pending != null && pending!.key != command.key) {
      throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    }
    await authorize();
    final body = command.body;
    if (command.resource == 'funds') {
      // Updates do not carry kind. Resolve the real record before choosing its permission.
      String kind;
      if (command.update) {
        final json = RemoteJson(
          await _request('GET', '$_base/funds/${body['fundId']}'),
        );
        if (json.number('businessId') != businessId) {
          throw const FormatException('Unexpected fund business');
        }
        final current = TreasuryFund.fromJson(json.value['item']);
        _fundScope(current);
        if (current.id != body['fundId']) {
          throw const FormatException('Unexpected fund id');
        }
        kind = current.kind;
      } else {
        kind = body['kind'] as String;
      }
      if (!canManageFund(kind)) throw const AuthError(403, 'FORBIDDEN');
    } else if (!canManageTerminal ||
        body.containsKey('fundId') && !canUseBank) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    pending = command;
    await storage.write(key: _key, value: jsonEncode(command.toJson()));
    try {
      final json = RemoteJson(
        await _request(
          'POST',
          '$_base/${command.resource}${command.update ? '/update' : ''}',
          data: body,
          key: command.key,
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected treasury confirmation');
      }
      final isFund = command.resource == 'funds';
      final row = RemoteJson(json.value[isFund ? 'fund' : 'terminal']);
      final Object result;
      if (isFund) {
        final fund = TreasuryFund.fromJson(row.value);
        _fundScope(fund);
        result = fund;
      } else {
        final terminal = TreasuryTerminal.fromJson(row.value);
        _terminalScope(terminal);
        result = terminal;
      }
      for (final entry in body.entries) {
        if (entry.key == 'expectedRevision') {
          if (row.number('revision') <= entry.value) {
            throw const FormatException('Unexpected treasury revision');
          }
        } else if (row.value[entry.key] != entry.value) {
          throw const FormatException('Unexpected treasury confirmation');
        }
      }
      await storage.delete(key: _key);
      pending = null;
      return result;
    } on AuthError catch (failure) {
      if (failure.statusCode < 500 &&
          !failure.retryable &&
          !failure.requiresLogin &&
          failure.statusCode != 403 &&
          ![
            'IDEMPOTENCY_CONFLICT',
            'SELECTION_CHANGED',
          ].contains(failure.code)) {
        await storage.delete(key: _key);
        pending = null;
      }
      rethrow;
    }
  }

  static String message(Object failure) {
    if (failure is FormatException) {
      return 'اطلاعات خزانه یا پاسخ سرور معتبر نیست؛ نتیجهٔ درخواست قبلی را پیگیری کنید.';
    }
    if (failure is AuthError) {
      switch (failure.code) {
        case 'FORBIDDEN':
          return 'مجوز مشاهده یا تغییر این بخش خزانه را ندارید.';
        case 'REVISION_CONFLICT':
          return 'اطلاعات تغییر کرده است؛ دوباره دریافت کنید و ویرایش را انجام دهید.';
        case 'RECORD_IN_USE':
          return 'این مورد مانده، تعهد، شیفت باز یا اتصال فعال دارد و تغییر موردنظر مجاز نیست.';
        case 'VALIDATION_FAILED':
          return 'نام، مشخصات بانکی و مقادیر واردشده را بررسی کنید.';
        case 'SELECTION_CHANGED':
          return 'نشست یا شعبه تغییر کرده است؛ صفحه را دوباره باز کنید.';
        case 'IDEMPOTENCY_CONFLICT':
          return 'درخواست قبلی تعیین تکلیف نشده است؛ همان درخواست را پیگیری کنید.';
      }
      if (!failure.requiresLogin && failure.statusCode < 500) {
        return 'عملیات انجام نشد؛ کد خطای سرور: ${failure.code}';
      }
    }
    return API.loginError(failure);
  }
}
