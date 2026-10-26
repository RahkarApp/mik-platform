import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/financial_report.dart';
import '../../source/remote/models/partner_movement.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/supplier.dart';
import 'business_context.dart';
import 'sale_invoice.dart';
import 'treasury.dart';

class PartnerMovementCommand {
  final String action, key, _body, _before;
  final String? _original;
  bool attempted;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  Map<String, dynamic> get before =>
      jsonDecode(_before) as Map<String, dynamic>;
  Map<String, dynamic>? get original =>
      _original == null ? null : jsonDecode(_original) as Map<String, dynamic>;
  PartnerMovementCommand(
    this.action,
    Map<String, dynamic> body, {
    required Map<String, dynamic> before,
    Map<String, dynamic>? original,
  }) : key = const Uuid().v4(),
       _body = jsonEncode(body),
       _before = jsonEncode(before),
       _original = original == null ? null : jsonEncode(original),
       attempted = false;
  PartnerMovementCommand.fromJson(Object? value) : this._(RemoteJson(value));
  PartnerMovementCommand._(RemoteJson row)
    : action = row.text('action'),
      key = row.text('key'),
      _body = jsonEncode(RemoteJson(row.value['body']).value),
      _before = jsonEncode(RemoteJson(row.value['before']).value),
      _original = row.value['original'] == null
          ? null
          : jsonEncode(RemoteJson(row.value['original']).value),
      attempted = row.flag('attempted') {
    FinancialReportPage.uuid(key);
    if (!['create', 'reverse'].contains(action)) {
      throw const FormatException('Invalid partner command');
    }
  }
  Map<String, dynamic> toJson() => {
    'action': action,
    'key': key,
    'body': body,
    'before': before,
    'original': original,
    'attempted': attempted,
  };
}

class PartnerMovementsFX {
  final BusinessContext context;
  final String branchId;
  final FlutterSecureStorage storage;
  late final access = TreasuryFX.forContext(context, branchId);
  PartnerMovementCommand? pending;
  bool sending = false;
  PartnerMovementsFX(
    this.context, {
    this.storage = const FlutterSecureStorage(),
  }) : branchId = context.selectedBranch?.branchId ?? '';
  int get businessId => context.session.business.businessId;
  String get base => '/v1/businesses/$businessId/accounting';
  String get _key =>
      'partner-movements.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId';
  void check() {
    context.check();
    if (branchId.isEmpty || context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  bool has(String code) =>
      access.has('accounting.partner.$code', business: true);
  Future<void> authorize() async {
    check();
    await access.authorize();
    check();
    if (!has('read')) throw const AuthError(403, 'FORBIDDEN');
  }

  Future<RemoteJson> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? data,
    String? key,
  }) async {
    check();
    final result = RemoteJson(
      await context.auth.request(
        method,
        '$base/$path',
        branchId: branchId,
        query: query,
        data: data,
        idempotencyKey: key,
      ),
    );
    check();
    if (result.number('businessId') != businessId) {
      throw const FormatException('Unexpected partner business');
    }
    return result;
  }

  RemoteSupplier parsePartner(Object? value) {
    final row = RemoteSupplier.fromJson(
      value,
      type: AccountingPersonType.partner,
    );
    if (row.businessId != businessId ||
        row.capitalBalance == null ||
        row.currentBalance == null) {
      throw const FormatException('Invalid partner balances');
    }
    return row;
  }

  Map<String, dynamic> snapshot(RemoteSupplier row) => {
    'partnerId': row.id,
    'businessId': row.businessId,
    'revision': row.revision,
    'name': row.name,
    'status': row.status,
    'capitalBalance': row.capitalBalance,
    'currentBalance': row.currentBalance,
  };
  Future<RemoteSupplier> partner(String id) async {
    FinancialReportPage.uuid(id);
    final row = parsePartner(
      (await request('GET', 'capital/partners/$id')).value['item'],
    );
    if (row.id != id) throw const FormatException('Unexpected partner');
    return row;
  }

  Future<List<RemoteSupplier>> partners() async {
    final result = <RemoteSupplier>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final page = await request(
        'GET',
        'capital/partners',
        query: {'limit': '100', 'after': ?after},
      );
      final items = page.items('items', parsePartner);
      for (final row in items) {
        if (!ids.add(row.id)) throw const FormatException('Repeated partner');
      }
      result.addAll(items);
      after = page.optionalText('nextCursor');
      if (after != null &&
          (items.isEmpty || after != items.last.id || !cursors.add(after))) {
        throw const FormatException('Invalid partner cursor');
      }
    } while (after != null);
    return result;
  }

  Future<List<PartnerMovement>> movements({String? partnerId}) async {
    if (partnerId != null) FinancialReportPage.uuid(partnerId);
    final result = <PartnerMovement>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final page = await request(
        'GET',
        'capital/movements',
        query: {'limit': '100', 'after': ?after, 'partnerId': ?partnerId},
      );
      final items = page.items('items', PartnerMovement.new);
      for (final row in items) {
        if (row.json['businessId'] != businessId ||
            partnerId != null && row.partnerId != partnerId ||
            !ids.add(row.id)) {
          throw const FormatException('Unexpected partner movement');
        }
      }
      result.addAll(items);
      after = page.optionalText('nextCursor');
      if (after != null &&
          (items.isEmpty || after != items.last.id || !cursors.add(after))) {
        throw const FormatException('Invalid movement cursor');
      }
    } while (after != null);
    return result;
  }

  Future<List<SalePaymentTarget>> targets(String method) async {
    if (!['CASH', 'BANK_TRANSFER'].contains(method)) {
      throw const FormatException('Invalid partner payment method');
    }
    if (!access.has('accounting.treasury.use') ||
        method == 'BANK_TRANSFER' && !access.canUseBank) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final result = <SalePaymentTarget>[],
        ids = <String>{},
        cursors = <String>{};
    String? after;
    do {
      final page = await request(
        'GET',
        'treasury/options',
        query: {'kind': 'fund', 'limit': '100', 'after': ?after},
      );
      final items = page.items(
        'items',
        (v) => SalePaymentTarget.fromJson(v, terminal: false),
      );
      for (final row in items) {
        if (!ids.add(row.id) ||
            row.branchId != null && row.branchId != branchId) {
          throw const FormatException('Unexpected partner fund');
        }
        if (row.accepts(method)) result.add(row);
      }
      after = page.optionalText('nextCursor');
      if (after != null &&
          (items.isEmpty || after != items.last.id || !cursors.add(after))) {
        throw const FormatException('Invalid fund cursor');
      }
    } while (after != null);
    return result;
  }

  Future<PartnerMovementCommand?> restore() async {
    check();
    final value = await storage.read(key: _key);
    check();
    return pending = value == null
        ? null
        : PartnerMovementCommand.fromJson(jsonDecode(value));
  }

  Future<void> send(PartnerMovementCommand command) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    try {
      await restore();
      if (pending != null && pending!.key != command.key) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      await authorize();
      final reverse = command.action == 'reverse';
      if (!['create', 'reverse'].contains(command.action) ||
          !has(reverse ? 'reverse' : 'transact')) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      final before = parsePartner(command.before),
          body = RemoteJson(command.body);
      if (before.status != 'ACTIVE' ||
          body.value['fundsConfirmed'] != true ||
          body.text('reason').trim().isEmpty ||
          body.text('reason').length > 500 ||
          body.number(
                reverse ? 'expectedPartnerRevision' : 'expectedRevision',
              ) !=
              before.revision) {
        throw const FormatException('Invalid partner operation');
      }
      int capitalDelta, currentDelta, amount;
      PartnerMovement? original;
      if (reverse) {
        original = PartnerMovement(command.original);
        if (original.json['businessId'] != businessId ||
            original.partnerId != before.id ||
            original.kind == 'REVERSAL' ||
            body.text('partnerMovementId') != original.id ||
            body.value.keys.any(
              (k) => ![
                'partnerMovementId',
                'expectedPartnerRevision',
                'fundsConfirmed',
                'reason',
              ].contains(k),
            )) {
          throw const FormatException('Invalid partner reversal');
        }
        capitalDelta = -original.money('capitalDelta');
        currentDelta = -original.money('currentDelta');
        amount = original.money('amount');
      } else {
        final kind = body.text('kind');
        final noncash = kind == 'NONCASH_CAPITAL_IN';
        if (!partnerMovementKinds.containsKey(kind) ||
            kind == 'REVERSAL' ||
            body.text('partnerId') != before.id ||
            body.value.keys.any(
              (k) => ![
                'partnerId',
                'expectedRevision',
                'kind',
                'amount',
                'method',
                'routing',
                'occurredAt',
                'reason',
                'fundsConfirmed',
                'allowDebitBalance',
                'assetDescription',
                'valuationConfirmed',
              ].contains(k),
            )) {
          throw const FormatException('Invalid partner movement fields');
        }
        amount = FinancialReportPage.money(
          body.value['amount'],
          nonnegative: true,
        );
        final on = DateTime.parse(body.text('occurredAt'));
        if (amount <= 0 || on.isAfter(DateTime.now().toUtc())) {
          throw const FormatException('Invalid movement amount/date');
        }
        final incoming = [
          'CAPITAL_IN',
          'CURRENT_IN',
          'NONCASH_CAPITAL_IN',
        ].contains(kind);
        capitalDelta = kind.contains('CAPITAL')
            ? (incoming ? amount : -amount)
            : 0;
        currentDelta = kind.startsWith('CURRENT')
            ? (incoming ? amount : -amount)
            : 0;
        if (body.value.containsKey('allowDebitBalance') &&
            body.value['allowDebitBalance'] is! bool) {
          throw const FormatException('Invalid debit confirmation');
        }
        if (before.currentBalance! + currentDelta < 0 &&
            currentDelta < 0 &&
            (!has('overdraw') || body.value['allowDebitBalance'] != true)) {
          throw const AuthError(403, 'FORBIDDEN');
        }
        if (noncash) {
          if (body.value['valuationConfirmed'] != true ||
              body.text('assetDescription').trim().isEmpty ||
              body.text('assetDescription').length > 1000 ||
              body.value.containsKey('method') ||
              body.value.containsKey('routing')) {
            throw const FormatException('Invalid noncash contribution');
          }
        } else if (body.value.containsKey('assetDescription') ||
            body.value.containsKey('valuationConfirmed')) {
          throw const FormatException('Unexpected valuation');
        }
      }
      if (before.capitalBalance! + capitalDelta < 0) {
        throw const AuthError(409, 'INSUFFICIENT_CREDIT');
      }
      final requestedRoute = reverse
          ? original!.json['routing']
          : body.value['routing'];
      final method = reverse ? original!.json['method'] : body.value['method'];
      if (requestedRoute != null ||
          !reverse && body.value['kind'] != 'NONCASH_CAPITAL_IN') {
        final route = RemoteJson(requestedRoute);
        if (!access.has('accounting.treasury.use') ||
            method == 'BANK_TRANSFER' && !access.canUseBank) {
          throw const AuthError(403, 'FORBIDDEN');
        }
        if (!['CASH', 'BANK_TRANSFER'].contains(method) ||
            !reverse &&
                (route.value.length != 1 ||
                    !route.value.containsKey('fundId'))) {
          throw const FormatException('Invalid movement route');
        }
        FinancialReportPage.uuid(route.text('fundId'));
      }
      final previous = command.attempted;
      pending = command;
      command.attempted = true;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      check();
      try {
        final response = await request(
          'POST',
          'capital/movements${reverse ? '/reverse' : ''}',
          data: command.body,
          key: command.key,
        );
        final partner = parsePartner(response.value['partner']);
        final movement = PartnerMovement(response.value['movement']);
        if (partner.id != before.id ||
            partner.revision <= before.revision ||
            partner.status != before.status ||
            partner.capitalBalance != before.capitalBalance! + capitalDelta ||
            partner.currentBalance != before.currentBalance! + currentDelta ||
            movement.json['businessId'] != businessId ||
            movement.partnerId != before.id ||
            movement.json['branchId'] != branchId ||
            movement.kind != (reverse ? 'REVERSAL' : body.text('kind')) ||
            movement.money('amount') != amount ||
            movement.money('capitalDelta') != capitalDelta ||
            movement.money('currentDelta') != currentDelta ||
            movement.money('capitalBalance') != partner.capitalBalance ||
            movement.money('currentBalance') != partner.currentBalance ||
            movement.json['reason'] != body.text('reason') ||
            reverse && movement.json['originalMovementId'] != original!.id ||
            !reverse &&
                DateTime.parse(movement.json['occurredAt'] as String).toUtc() !=
                    DateTime.parse(body.text('occurredAt')).toUtc()) {
          throw const FormatException('Partner movement not confirmed');
        }
        if (requestedRoute != null) {
          if (movement.json['method'] != method ||
              RemoteJson(movement.json['routing']).text('fundId') !=
                  RemoteJson(requestedRoute).text('fundId')) {
            throw const FormatException('Partner fund not confirmed');
          }
        } else if (movement.json['routing'] != null ||
            movement.json['assetDescription'] !=
                (reverse
                    ? original!.json['assetDescription']
                    : body.value['assetDescription'])) {
          throw const FormatException('Noncash contribution not confirmed');
        }
        await storage.delete(key: _key);
        pending = null;
      } on AuthError catch (failure) {
        if (!previous &&
            failure.statusCode < 500 &&
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
    } finally {
      sending = false;
    }
  }
}
