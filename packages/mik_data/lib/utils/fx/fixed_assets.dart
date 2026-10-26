import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/financial_report.dart';
import '../../source/remote/models/fixed_asset.dart';
import '../../source/remote/models/expense.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/business_branch.dart';
import '../../source/remote/models/scope_authorization.dart';
import 'business_context.dart';
import 'treasury.dart';
import 'sale_invoice.dart';

class AssetCommand {
  final String action, key, _body;
  final String? _before;
  bool attempted;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  Map<String, dynamic>? get before =>
      _before == null ? null : jsonDecode(_before) as Map<String, dynamic>;
  AssetCommand(
    this.action,
    Map<String, dynamic> body, {
    Map<String, dynamic>? before,
  }) : key = const Uuid().v4(),
       _body = jsonEncode(body),
       _before = before == null ? null : jsonEncode(before),
       attempted = false;
  AssetCommand.fromJson(Object? value) : this._(RemoteJson(value));
  AssetCommand._(RemoteJson row)
    : action = row.text('action'),
      key = row.text('key'),
      _body = jsonEncode(RemoteJson(row.value['body']).value),
      _before = row.value['before'] == null
          ? null
          : jsonEncode(RemoteJson(row.value['before']).value),
      attempted = row.flag('attempted') {
    FinancialReportPage.uuid(key);
    if (![
      'create',
      'category',
      'commission',
      'depreciate',
      'update',
      'transfer',
      'custody',
      'repair',
      'dispose',
    ].contains(action)) {
      throw const FormatException('Invalid asset command');
    }
  }
  Map<String, dynamic> toJson() => {
    'action': action,
    'key': key,
    'body': body,
    'before': before,
    'attempted': attempted,
  };
}

class FixedAssetsFX {
  final BusinessContext context;
  final String branchId;
  final FlutterSecureStorage storage;
  AssetCommand? pending;
  bool sending = false;
  late final access = TreasuryFX.forContext(context, branchId);
  FixedAssetsFX(this.context, {this.storage = const FlutterSecureStorage()})
    : branchId = context.selectedBranch?.branchId ?? '';
  void check() {
    context.check();
    if (branchId.isEmpty || context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<void> authorize() async {
    check();
    await access.authorize();
    check();
    if (!access.has('accounting.asset.read')) {
      throw const AuthError(403, 'FORBIDDEN');
    }
  }

  bool get canCreate => access.has('accounting.asset.create');
  bool canOperate(String action, RemoteFixedAsset row) {
    if (row.branchId != branchId ||
        row.businessId != access.businessId ||
        ['SOLD', 'SCRAPPED', 'LOST', 'CANCELLED'].contains(row.status)) {
      return false;
    }
    if (action == 'dispose') {
      return access.has('accounting.asset.dispose') &&
          row.money('pendingAmount') == 0;
    }
    if (action == 'repair') {
      return access.has('accounting.asset.maintain') &&
          access.has('accounting.expense.create');
    }
    if (action == 'custody') return access.has('accounting.asset.custody');
    if (action == 'update') return access.has('accounting.asset.update');
    if (action == 'transfer') {
      return access.has('accounting.asset.transfer') &&
          row.money('liabilityAmount') == 0 &&
          row.money('pendingAmount') == 0;
    }
    return action == 'commission'
        ? access.has('accounting.asset.update') &&
              row.json['inServiceOn'] == null
        : action == 'depreciate' &&
              access.has('accounting.asset.depreciate') &&
              row.json['inServiceOn'] != null &&
              row.json['depreciationMethod'] == 'STRAIGHT_LINE';
  }

  bool get canManageCategories =>
      access.has('accounting.asset.category.manage', business: true);
  String get _key =>
      'assets.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.${access.businessId}.$branchId';
  Future<AssetCommand?> restore() async {
    check();
    final value = await storage.read(key: _key);
    check();
    return pending = value == null
        ? null
        : AssetCommand.fromJson(jsonDecode(value));
  }

  Future<List<AssetCategory>> categories() async {
    await authorize();
    if (!access.has('accounting.asset.read', business: true)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final rows = <AssetCategory>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final page = await _get('/categories', {
        'status': 'ACTIVE',
        'limit': '100',
        'after': ?after,
      });
      final items = page.items('items', AssetCategory.new);
      for (final row in items) {
        if (row.businessId != access.businessId ||
            row.status != 'ACTIVE' ||
            !ids.add(row.id)) {
          throw const FormatException('Unexpected asset category');
        }
        rows.add(row);
      }
      final next = page.optionalText('nextCursor');
      if (next != null) {
        FinancialReportPage.uuid(next);
        if (items.isEmpty || next != items.last.id || !cursors.add(next)) {
          throw const FormatException('Invalid category cursor');
        }
      }
      after = next;
    } while (after != null);
    return rows;
  }

  Future<int?> send(AssetCommand command) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    try {
      await restore();
      if (pending != null && pending!.key != command.key) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      await authorize();
      final operating = [
        'commission',
        'depreciate',
        'update',
        'transfer',
        'custody',
        'repair',
        'dispose',
      ].contains(command.action);
      RemoteFixedAsset? before;
      if (operating) {
        before = RemoteFixedAsset(command.before);
        _scope(before);
      }
      if (!(operating
          ? canOperate(command.action, before!)
          : command.action == 'category'
          ? canManageCategories
          : canCreate)) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if (![
            'category',
            'create',
            'commission',
            'depreciate',
            'update',
            'transfer',
            'custody',
            'repair',
            'dispose',
          ].contains(command.action) ||
          command.action == 'create' &&
              (command.body['source'] != 'PURCHASE' ||
                  command.body['confirmed'] != true ||
                  command.body.containsKey('payments') ||
                  command.body.containsKey('asOf') ||
                  command.body.containsKey('partnerMovementId'))) {
        throw const FormatException('Unsupported asset acquisition');
      }
      if (operating) {
        final body = RemoteJson(command.body);
        if (body.text('fixedAssetId') != before!.id ||
            body.number('expectedRevision') != before.revision ||
            body.text('reason').trim().isEmpty ||
            body.text('reason').length > 1000) {
          throw const FormatException('Invalid asset operation');
        }
        if (!['update', 'custody'].contains(command.action)) {
          final on = body.text(
            command.action == 'commission'
                ? 'inServiceOn'
                : ['transfer', 'dispose'].contains(command.action)
                ? 'effectiveOn'
                : command.action == 'repair'
                ? 'occurredOn'
                : 'throughOn',
          );
          RemoteFixedAsset.day(on);
          if (on.compareTo(before.json['financialThrough'] as String) < 0 ||
              command.action == 'depreciate' &&
                  on.compareTo(before.json['depreciatedThrough'] as String) <
                      0 ||
              on.compareTo(
                    DateTime.now().toUtc().toIso8601String().substring(0, 10),
                  ) >
                  0) {
            throw const FormatException('Invalid asset operation');
          }
        }
        if (command.action == 'update') {
          const editable = [
            'name',
            'code',
            'assetCategoryId',
            'serialNumber',
            'location',
            'note',
            'warrantyUntil',
            'dueOn',
          ];
          if (body.value.keys.any(
                (k) => ![
                  'fixedAssetId',
                  'expectedRevision',
                  'reason',
                  ...editable,
                ].contains(k),
              ) ||
              !editable.any(body.value.containsKey) ||
              body.value.containsKey('dueOn') &&
                  before.json['source'] != 'PURCHASE') {
            throw const FormatException('Unsupported asset metadata update');
          }
          for (final key in ['dueOn', 'warrantyUntil']) {
            if (body.value[key] != null) RemoteFixedAsset.day(body.text(key));
          }
          if (body.value['assetCategoryId'] != null) {
            FinancialReportPage.uuid(body.text('assetCategoryId'));
          }
        }
        if (command.action == 'dispose') {
          final kind = body.text('kind');
          final proceeds = FinancialReportPage.money(
            body.value['proceeds'] ?? 0,
            nonnegative: true,
          );
          if (!['SALE', 'SCRAP', 'LOSS'].contains(kind) ||
              body.value['confirmed'] != true ||
              body.value.keys.any(
                (k) => ![
                  'fixedAssetId',
                  'expectedRevision',
                  'kind',
                  'effectiveOn',
                  'reason',
                  'confirmed',
                  'proceeds',
                  'receipt',
                  'buyerName',
                ].contains(k),
              ) ||
              kind != 'SALE' &&
                  (proceeds != 0 ||
                      body.value.containsKey('receipt') ||
                      body.value.containsKey('buyerName')) ||
              proceeds == 0 && body.value.containsKey('receipt')) {
            throw const FormatException('Invalid asset disposal');
          }
          if (body.value.containsKey('buyerName') &&
              (body.text('buyerName').trim().isEmpty ||
                  body.text('buyerName').length > 200)) {
            throw const FormatException('Invalid buyer name');
          }
          if (proceeds > 0) {
            final receipt = RemoteJson(body.value['receipt']);
            final method = receipt.text('method');
            if (!access.has('accounting.treasury.use') ||
                method == 'BANK_TRANSFER' && !access.canUseBank) {
              throw const AuthError(403, 'FORBIDDEN');
            }
            final routing = RemoteJson(receipt.value['routing']);
            if (receipt.value['confirmed'] != true ||
                !['CASH', 'BANK_TRANSFER'].contains(method) ||
                receipt.value.keys.any(
                  (k) => ![
                    'method',
                    'routing',
                    'confirmed',
                    'transactionReference',
                  ].contains(k),
                ) ||
                routing.value.length != 1 ||
                !routing.value.containsKey('fundId') ||
                receipt.value.containsKey('transactionReference') &&
                    (receipt.text('transactionReference').trim().isEmpty ||
                        receipt.text('transactionReference').length > 200)) {
              throw const FormatException('Invalid disposal receipt');
            }
            FinancialReportPage.uuid(routing.text('fundId'));
          }
        }
        if (command.action == 'repair') {
          final capital = body.text('kind') == 'CAPITALIZE';
          if (capital && !access.has('accounting.asset.capitalize')) {
            throw const AuthError(403, 'FORBIDDEN');
          }
          if (!['ROUTINE', 'CAPITALIZE'].contains(body.text('kind')) ||
              body.text('title').trim().isEmpty ||
              body.text('title').length > 200 ||
              body.value.keys.any(
                (k) => ![
                  'fixedAssetId',
                  'expectedRevision',
                  'kind',
                  'amount',
                  'occurredOn',
                  'categoryId',
                  'payeeId',
                  'title',
                  'reason',
                  'capitalizationConfirmed',
                  'remainingLifeMonths',
                  'status',
                ].contains(k),
              ) ||
              (capital
                  ? body.value['capitalizationConfirmed'] != true
                  : body.value.containsKey('capitalizationConfirmed') ||
                        body.value.containsKey('remainingLifeMonths'))) {
            throw const FormatException('Invalid maintenance fields');
          }
          if (FinancialReportPage.money(
                body.value['amount'],
                nonnegative: true,
              ) <=
              0) {
            throw const FormatException('Invalid maintenance amount');
          }
          for (final field in ['categoryId', 'payeeId']) {
            FinancialReportPage.uuid(body.text(field));
          }
          if (body.value.containsKey('remainingLifeMonths')) {
            final months = body.number('remainingLifeMonths');
            if (!capital ||
                before.json['depreciationMethod'] == 'NONE' ||
                months < 1 ||
                months > 1200) {
              throw const FormatException('Invalid remaining useful life');
            }
          }
          if (body.value.containsKey('status') &&
              !(before.json['inServiceOn'] == null
                      ? ['REGISTERED']
                      : ['IN_USE', 'UNDER_REPAIR'])
                  .contains(body.text('status'))) {
            throw const FormatException('Invalid maintenance status');
          }
        }
        if (command.action == 'custody') {
          if (!body.value.containsKey('custodianMembershipId') ||
              body.value.keys.any(
                (k) => ![
                  'fixedAssetId',
                  'expectedRevision',
                  'reason',
                  'custodianMembershipId',
                  'location',
                ].contains(k),
              )) {
            throw const FormatException('Invalid custody fields');
          }
          if (body.value['custodianMembershipId'] != null) {
            FinancialReportPage.uuid(body.text('custodianMembershipId'));
          }
          if (body.value.containsKey('location') &&
              (body.text('location').trim().isEmpty ||
                  body.text('location').length > 500)) {
            throw const FormatException('Invalid custody location');
          }
        }
        if (command.action == 'transfer') {
          final id = body.text('toBranchId');
          FinancialReportPage.uuid(id);
          if (id == branchId ||
              body.value.containsKey('custodianMembershipId')) {
            throw const FormatException('Invalid transfer destination');
          }
          await _authorizeTransferDestination(id);
        }
      }
      final previous = command.attempted;
      pending = command;
      command.attempted = true;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      check();
      try {
        final data = RemoteJson(
          await context.auth.request(
            'POST',
            '/v1/businesses/${access.businessId}/accounting/assets${command.action == 'category'
                ? '/categories'
                : operating
                ? '/${command.action}'
                : ''}',
            branchId: branchId,
            data: command.body,
            idempotencyKey: command.key,
          ),
        );
        check();
        if (data.number('businessId') != access.businessId) {
          throw const FormatException('Unexpected saved asset business');
        }
        final body = command.body;
        int? amount;
        if (command.action == 'category') {
          final row = AssetCategory(data.value['item']);
          if (row.businessId != access.businessId ||
              row.name != body['name'] ||
              row.status != 'ACTIVE') {
            throw const FormatException('Unexpected saved category');
          }
        } else if (command.action == 'dispose') {
          final row = RemoteFixedAsset(data.value['asset']), prior = before!;
          _scope(row);
          final rawMovement = RemoteJson(data.value['movement']);
          final movement = RemoteAssetMovement(rawMovement.value);
          final details = RemoteJson(rawMovement.value['details']);
          final proceeds = body['proceeds'] ?? 0;
          final expectedStatus = {
            'SALE': 'SOLD',
            'SCRAP': 'SCRAPPED',
            'LOSS': 'LOST',
          }[body['kind']];
          if (row.id != prior.id ||
              row.revision <= prior.revision ||
              row.status != expectedStatus ||
              row.money('bookValue') != 0 ||
              row.json['custodian'] != null ||
              row.json['inServiceOn'] != prior.json['inServiceOn'] ||
              row.json['depreciationMethod'] !=
                  prior.json['depreciationMethod'] ||
              row.json['financialThrough'] != body['effectiveOn'] ||
              row.json['depreciatedThrough'] != body['effectiveOn'] ||
              row.money('accumulatedDepreciation') <
                  prior.money('accumulatedDepreciation') ||
              movement.assetId != prior.id ||
              movement.businessId != access.businessId ||
              movement.branchId != branchId ||
              movement.kind != 'DISPOSE' ||
              !movement.financial ||
              movement.reason != body['reason'] ||
              movement.on != body['effectiveOn'] ||
              details.number('proceeds') != proceeds ||
              details.number('gain') !=
                  (proceeds as int) -
                      (row.money('cost') -
                          row.money('accumulatedDepreciation')) ||
              details.value['buyerName'] != body['buyerName']) {
            throw const FormatException('Disposal not confirmed');
          }
          // Disposal removes the asset; it does not forgive the supplier's debt.
          for (final field in [
            'cost',
            'acquisitionCost',
            'residualValue',
            'paidAmount',
            'pendingAmount',
            'liabilityAmount',
          ]) {
            if (row.money(field) != prior.money(field)) {
              throw const FormatException('Unexpected disposal balance');
            }
          }
          if (proceeds > 0) {
            final requested = RemoteJson(body['receipt']);
            final receipt = RemoteJson(details.value['receipt']);
            final route = RemoteJson(receipt.value['routing']);
            if (receipt.text('method') != requested.text('method') ||
                route.text('fundId') !=
                    RemoteJson(requested.value['routing']).text('fundId') ||
                !(requested.text('method') == 'CASH'
                        ? ['CASH', 'PETTY_CASH']
                        : ['BANK'])
                    .contains(route.text('kind')) ||
                receipt.value['transactionReference'] !=
                    requested.value['transactionReference']) {
              throw const FormatException('Disposal receipt not confirmed');
            }
          } else if (details.value.containsKey('receipt')) {
            throw const FormatException('Unexpected disposal receipt');
          }
          amount = details.number('gain');
        } else if (command.action == 'repair') {
          final row = RemoteFixedAsset(data.value['asset']), prior = before!;
          _scope(row);
          final capital = body['kind'] == 'CAPITALIZE';
          final expense = RemoteExpense(data.value['expense']);
          final movement = RemoteAssetMovement(data.value['movement']);
          if (row.id != prior.id ||
              row.revision <= prior.revision ||
              row.status != (body['status'] ?? prior.status) ||
              row.json['inServiceOn'] != prior.json['inServiceOn'] ||
              row.json['depreciationMethod'] !=
                  prior.json['depreciationMethod'] ||
              expense.json['businessId'] != access.businessId ||
              expense.json['branchId'] != branchId ||
              expense.json['fixedAssetId'] != prior.id ||
              expense.json['capitalizedAssetId'] !=
                  (capital ? prior.id : null) ||
              expense.status != 'ISSUED' ||
              expense.json['paymentStatus'] != 'UNPAID' ||
              expense.money('amount') != body['amount'] ||
              expense.money('paidAmount') != 0 ||
              expense.money('pendingAmount') != 0 ||
              expense.json['title'] != body['title'] ||
              expense.json['categoryId'] != body['categoryId'] ||
              expense.json['payeeId'] != body['payeeId'] ||
              DateTime.parse(expense.json['occurredAt'] as String)
                      .toUtc()
                      .toIso8601String()
                      .substring(0, 10) !=
                  body['occurredOn'] ||
              data.items('payments', ExpenseDisbursement.new).isNotEmpty ||
              movement.assetId != prior.id ||
              movement.businessId != access.businessId ||
              movement.branchId != branchId ||
              movement.kind != (capital ? 'CAPITALIZE' : 'REPAIR') ||
              movement.financial != capital ||
              movement.on != body['occurredOn'] ||
              movement.reason != body['reason']) {
            throw const FormatException('Maintenance result not confirmed');
          }
          for (final field in [
            'acquisitionCost',
            'residualValue',
            'paidAmount',
            'pendingAmount',
            'liabilityAmount',
          ]) {
            if (row.money(field) != prior.money(field)) {
              throw const FormatException('Unexpected acquisition change');
            }
          }
          if (capital) {
            if (row.money('cost') !=
                    prior.money('cost') + (body['amount'] as int) ||
                row.money('accumulatedDepreciation') <
                    prior.money('accumulatedDepreciation') ||
                row.money('bookValue') !=
                    row.money('cost') - row.money('accumulatedDepreciation') ||
                row.json['financialThrough'] != body['occurredOn'] ||
                row.json['depreciatedThrough'] != body['occurredOn'] ||
                body.containsKey('remainingLifeMonths') &&
                    row.json['usefulLifeMonths'] !=
                        body['remainingLifeMonths']) {
              throw const FormatException('Capitalization not confirmed');
            }
          } else {
            for (final field in [
              'cost',
              'bookValue',
              'accumulatedDepreciation',
              'financialThrough',
              'depreciatedThrough',
              'usefulLifeMonths',
            ]) {
              if (row.json[field] != prior.json[field]) {
                throw const FormatException(
                  'Routine repair changed asset value',
                );
              }
            }
          }
        } else if (['update', 'transfer', 'custody'].contains(command.action)) {
          final row = RemoteFixedAsset(data.value['asset']), prior = before!;
          final transfer = command.action == 'transfer';
          final custody = command.action == 'custody';
          if (row.id != prior.id ||
              row.businessId != access.businessId ||
              row.revision <= prior.revision ||
              row.branchId != (transfer ? body['toBranchId'] : branchId) ||
              row.status != prior.status ||
              row.json['inServiceOn'] != prior.json['inServiceOn'] ||
              row.json['depreciationMethod'] !=
                  prior.json['depreciationMethod']) {
            throw const FormatException('Unexpected asset edit result');
          }
          for (final key in [
            'cost',
            'acquisitionCost',
            'residualValue',
            'paidAmount',
            'pendingAmount',
            'liabilityAmount',
          ]) {
            if (row.money(key) != prior.money(key)) {
              throw const FormatException('Unexpected asset edit balance');
            }
          }
          if (transfer) {
            if (row.json['financialThrough'] != body['effectiveOn'] ||
                row.json['depreciatedThrough'] != body['effectiveOn'] ||
                row.json['custodian'] != null ||
                row.json['location'] != body['location'] ||
                row.money('accumulatedDepreciation') <
                    prior.money('accumulatedDepreciation') ||
                row.money('bookValue') !=
                    prior.money('bookValue') -
                        (row.money('accumulatedDepreciation') -
                            prior.money('accumulatedDepreciation'))) {
              throw const FormatException('Asset transfer not confirmed');
            }
          } else {
            for (final key in [
              'name',
              'code',
              'assetCategoryId',
              'serialNumber',
              'location',
              'note',
              'warrantyUntil',
              'dueOn',
            ]) {
              if (body.containsKey(key) && row.json[key] != body[key]) {
                throw const FormatException('Asset metadata not confirmed');
              }
            }
            for (final key in [
              'bookValue',
              'accumulatedDepreciation',
              'financialThrough',
              'depreciatedThrough',
            ]) {
              if (row.json[key] != prior.json[key]) {
                throw const FormatException(
                  'Unexpected metadata financial change',
                );
              }
            }
          }
          if (custody) {
            final custodian = row.json['custodian'];
            final requested = body['custodianMembershipId'];
            if ((requested == null
                    ? custodian != null
                    : custodian == null ||
                          RemoteJson(custodian).text('membershipId') !=
                              requested) ||
                row.json['location'] !=
                    (body.containsKey('location')
                        ? body['location']
                        : prior.json['location'])) {
              throw const FormatException('Asset custody not confirmed');
            }
          }
          final movement = RemoteAssetMovement(data.value['movement']);
          if (movement.assetId != prior.id ||
              movement.businessId != access.businessId ||
              movement.branchId != branchId ||
              movement.kind !=
                  (transfer
                      ? 'TRANSFER'
                      : custody
                      ? 'CUSTODY'
                      : 'UPDATE') ||
              movement.reason != body['reason'] ||
              transfer &&
                  (movement.toBranchId != body['toBranchId'] ||
                      movement.on != body['effectiveOn'])) {
            throw const FormatException('Unexpected asset edit movement');
          }
        } else if (operating) {
          final row = RemoteFixedAsset(data.value['asset']);
          _scope(row);
          final prior = before!;
          final on =
              body[command.action == 'commission'
                  ? 'inServiceOn'
                  : 'throughOn'];
          if (row.id != prior.id ||
              row.revision < prior.revision ||
              row.money('cost') != prior.money('cost') ||
              row.json['financialThrough'] != on ||
              row.json['depreciatedThrough'] != on) {
            throw const FormatException('Unexpected asset operation result');
          }
          if (command.action == 'commission') {
            if (row.revision <= prior.revision ||
                row.status != 'IN_USE' ||
                row.json['inServiceOn'] != on ||
                row.money('accumulatedDepreciation') !=
                    prior.money('accumulatedDepreciation') ||
                row.money('bookValue') != prior.money('bookValue')) {
              throw const FormatException('Asset commission not confirmed');
            }
          } else {
            amount = FinancialReportPage.money(
              data.value['amount'],
              nonnegative: true,
            );
            if (row.status != prior.status ||
                row.json['inServiceOn'] != prior.json['inServiceOn'] ||
                row.money('accumulatedDepreciation') !=
                    prior.money('accumulatedDepreciation') + amount ||
                row.money('bookValue') != prior.money('bookValue') - amount ||
                row.money('bookValue') < row.money('residualValue') ||
                row.revision == prior.revision &&
                    (amount != 0 ||
                        on != prior.json['depreciatedThrough'] ||
                        on != prior.json['financialThrough'])) {
              throw const FormatException('Asset depreciation not confirmed');
            }
          }
          if (row.revision > prior.revision) {
            final movement = RemoteAssetMovement(data.value['movement']);
            if (movement.assetId != row.id ||
                movement.businessId != row.businessId ||
                movement.branchId != branchId ||
                movement.kind !=
                    (command.action == 'commission'
                        ? 'COMMISSION'
                        : 'DEPRECIATE') ||
                movement.reason != body['reason']) {
              throw const FormatException(
                'Unexpected asset operation movement',
              );
            }
          }
        } else {
          final row = RemoteFixedAsset(data.value['asset']);
          _scope(row);
          for (final field in [
            'name',
            'source',
            'assetCategoryId',
            'supplierId',
            'acquiredOn',
            'cost',
            'inServiceOn',
            'code',
            'serialNumber',
            'location',
            'note',
            'dueOn',
          ]) {
            if (body.containsKey(field) && row.json[field] != body[field]) {
              throw const FormatException('Unexpected saved asset values');
            }
          }
          final plan = RemoteJson(body['depreciation']);
          if (row.json['depreciationMethod'] != plan.text('method') ||
              row.json['acquisitionCost'] != body['cost'] ||
              row.json['bookValue'] != body['cost'] ||
              row.json['accumulatedDepreciation'] != 0 ||
              plan.text('method') == 'NONE' && row.json['residualValue'] != 0 ||
              row.json['paidAmount'] != 0 ||
              row.json['pendingAmount'] != 0 ||
              row.json['liabilityAmount'] != body['cost'] ||
              row.json['paymentStatus'] != 'UNPAID' ||
              row.status !=
                  (body['inServiceOn'] == null ? 'REGISTERED' : 'IN_USE')) {
            throw const FormatException('Asset acquisition not confirmed');
          }
          for (final field in ['usefulLifeMonths', 'residualValue']) {
            if (plan.value.containsKey(field) &&
                row.json[field] != plan.value[field]) {
              throw const FormatException('Unexpected depreciation');
            }
          }
        }
        await storage.delete(key: _key);
        pending = null;
        return amount;
      } on AuthError catch (error) {
        if (!previous &&
            error.statusCode < 500 &&
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

  Future<RemoteJson> _get(String path, [Map<String, String>? query]) async {
    check();
    final result = RemoteJson(
      await context.auth.request(
        'GET',
        '/v1/businesses/${access.businessId}/accounting/assets$path',
        branchId: branchId,
        query: query,
      ),
    );
    check();
    if (result.number('businessId') != access.businessId) {
      throw const FormatException('Unexpected asset business');
    }
    return result;
  }

  Future<List<SalePaymentTarget>> disposalTargets(String method) async {
    await authorize();
    if (!['CASH', 'BANK_TRANSFER'].contains(method)) {
      throw const FormatException('Invalid disposal method');
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
      final page = RemoteJson(
        await context.auth.request(
          'GET',
          '/v1/businesses/${access.businessId}/accounting/treasury/options',
          branchId: branchId,
          query: {'kind': 'fund', 'limit': '100', 'after': ?after},
        ),
      );
      check();
      if (page.number('businessId') != access.businessId) {
        throw const FormatException('Unexpected treasury business');
      }
      final items = page.items(
        'items',
        (v) => SalePaymentTarget.fromJson(v, terminal: false),
      );
      for (final item in items) {
        if (!ids.add(item.id) ||
            item.branchId != null && item.branchId != branchId) {
          throw const FormatException('Unexpected disposal fund');
        }
        if (item.accepts(method)) result.add(item);
      }
      after = page.optionalText('nextCursor');
      if (after != null) {
        FinancialReportPage.uuid(after);
        if (items.isEmpty || after != items.last.id || !cursors.add(after)) {
          throw const FormatException('Invalid fund cursor');
        }
      }
    } while (after != null);
    return result;
  }

  Future<void> _authorizeTransferDestination(String id) async {
    final row = ScopeAuthorization.fromJson(
      await context.auth.request(
        'GET',
        '/v1/businesses/${access.businessId}/authorization',
        query: {'scopeType': 'BRANCH', 'scopeId': id},
      ),
    );
    check();
    if (!row.allowed ||
        row.businessId != access.businessId ||
        row.membershipId != context.session.business.membershipId ||
        row.scopeType != 'BRANCH' ||
        row.scopeId != id ||
        !row.permissionCodes.contains('accounting.asset.transfer')) {
      throw const AuthError(403, 'FORBIDDEN');
    }
  }

  Future<List<BusinessBranch>> transferBranches() async {
    await authorize();
    final rows = <BusinessBranch>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      // BusinessContext.branches() clears the selected branch; this picker must not.
      final page = RemoteJson(
        await context.auth.request(
          'GET',
          '/v1/businesses/${access.businessId}/branches',
          branchId: branchId,
          query: {'limit': '100', 'after': ?after},
        ),
      );
      check();
      final items = page.items('items', BusinessBranch.fromJson);
      for (final item in items) {
        FinancialReportPage.uuid(item.branchId);
        if (item.businessId != access.businessId ||
            item.revision < 1 ||
            !ids.add(item.branchId) ||
            !['ACTIVE', 'SUSPENDED', 'ARCHIVED'].contains(item.status)) {
          throw const FormatException('Invalid transfer branch');
        }
        if (item.status == 'ACTIVE' && item.branchId != branchId) {
          rows.add(item);
        }
      }
      final next = page.optionalText('nextCursor');
      if (next != null) {
        FinancialReportPage.uuid(next);
        if (items.isEmpty || !cursors.add(next)) {
          throw const FormatException('Repeated branch cursor');
        }
      }
      after = next;
    } while (after != null);
    return rows;
  }

  void _scope(RemoteFixedAsset item) {
    if (item.businessId != access.businessId || item.branchId != branchId) {
      throw const FormatException('Unexpected asset branch');
    }
  }

  Future<List<RemoteFixedAsset>> list() async {
    await authorize();
    final rows = <RemoteFixedAsset>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final data = await _get('', {'limit': '100', 'after': ?after});
      final page = data.items('items', RemoteFixedAsset.new);
      for (final row in page) {
        _scope(row);
        if (!ids.add(row.id)) throw const FormatException('Repeated asset');
        rows.add(row);
      }
      final next = data.optionalText('nextCursor');
      if (next != null) {
        FinancialReportPage.uuid(next);
        if (page.isEmpty || next != page.last.id || !cursors.add(next)) {
          throw const FormatException('Invalid asset cursor');
        }
      }
      after = next;
    } while (after != null);
    return List.unmodifiable(rows);
  }

  Future<RemoteFixedAsset> detail(String id) async {
    FinancialReportPage.uuid(id);
    await authorize();
    final row = RemoteFixedAsset((await _get('/$id')).value['item']);
    _scope(row);
    if (row.id != id) throw const FormatException('Unexpected asset');
    return row;
  }

  Future<List<RemoteAssetMovement>> movements(String id) async {
    FinancialReportPage.uuid(id);
    await authorize();
    final rows = <RemoteAssetMovement>[],
        ids = <String>{},
        cursors = <String>{};
    String? after;
    do {
      final data = await _get('/movements', {
        'fixedAssetId': id,
        'limit': '100',
        'after': ?after,
      });
      final page = data.items('items', RemoteAssetMovement.new);
      for (final row in page) {
        // Transfers are visible in both branches; older unrelated branch history is not.
        if (row.businessId != access.businessId ||
            row.assetId != id ||
            row.branchId != branchId && row.toBranchId != branchId ||
            !ids.add(row.id)) {
          throw const FormatException('Unexpected asset movement scope');
        }
        rows.add(row);
      }
      final next = data.optionalText('nextCursor');
      if (next != null) {
        FinancialReportPage.uuid(next);
        if (page.isEmpty || next != page.last.id || !cursors.add(next)) {
          throw const FormatException('Invalid movement cursor');
        }
      }
      after = next;
    } while (after != null);
    rows.sort((a, b) => b.number.compareTo(a.number));
    return List.unmodifiable(rows);
  }
}
