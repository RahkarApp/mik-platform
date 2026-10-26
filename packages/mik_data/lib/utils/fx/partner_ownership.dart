import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/financial_report.dart';
import '../../source/remote/models/partnership.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'partner_movements.dart';

class OwnershipCommand {
  final String key, _body;
  bool attempted;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  OwnershipCommand(Map<String, dynamic> body)
    : key = const Uuid().v4(),
      _body = jsonEncode(body),
      attempted = false;
  OwnershipCommand.fromJson(Object? value) : this._(RemoteJson(value));
  OwnershipCommand._(RemoteJson row)
    : key = row.text('key'),
      _body = jsonEncode(RemoteJson(row.value['body']).value),
      attempted = row.flag('attempted') {
    FinancialReportPage.uuid(key);
  }
  Map<String, dynamic> toJson() => {
    'key': key,
    'body': body,
    'attempted': attempted,
  };
}

class PartnerOwnershipFX {
  final PartnerMovementsFX partners;
  final FlutterSecureStorage storage;
  OwnershipCommand? pending;
  bool sending = false;
  PartnerOwnershipFX(
    BusinessContext context, {
    this.storage = const FlutterSecureStorage(),
  }) : partners = PartnerMovementsFX(context);
  String get _key =>
      'partner-ownership.v1.${partners.context.auth.appId}.${partners.context.origin}.${partners.context.session.identityId}.${partners.businessId}.${partners.branchId}';
  bool get canManage => partners.has('manage');
  Future<PartnerOwnership> get() async {
    await partners.authorize();
    return PartnerOwnership(
      (await partners.request('GET', 'capital/ownership')).value,
      partners.businessId,
    );
  }

  Future<OwnershipCommand?> restore() async {
    partners.check();
    final value = await storage.read(key: _key);
    partners.check();
    return pending = value == null
        ? null
        : OwnershipCommand.fromJson(jsonDecode(value));
  }

  Future<Partnership> send(OwnershipCommand command) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    try {
      await restore();
      if (pending != null && pending!.key != command.key) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      await partners.authorize();
      if (!canManage) throw const AuthError(403, 'FORBIDDEN');
      final body = RemoteJson(command.body), mode = body.text('mode');
      final parts = Partnership.shares(
        body.value['allocations'],
        nullable: false,
      );
      if (body.value.keys.any(
            (k) => ![
              'mode',
              'allocations',
              'expectedRevision',
              'reason',
            ].contains(k),
          ) ||
          !['FIXED', 'CONTRIBUTIONS'].contains(mode) ||
          body.number('expectedRevision') < 0 ||
          body.text('reason').trim().isEmpty ||
          body.text('reason').length > 500 ||
          (mode == 'FIXED'
              ? parts.isEmpty ||
                    parts.fold<int>(
                          0,
                          (sum, p) => sum + p.number('basisPoints'),
                        ) !=
                        10000
              : parts.isNotEmpty)) {
        throw const FormatException('Invalid ownership configuration');
      }
      for (final part in parts) {
        if (part.value.length != 2) {
          throw const FormatException('Unsupported ownership fields');
        }
      }
      // Persist the exact settings before sending; an uncertain response must replay the same command.
      final previous = command.attempted;
      pending = command;
      command.attempted = true;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      try {
        final result = await partners.request(
          'POST',
          'capital/ownership',
          data: command.body,
          key: command.key,
        );
        final saved = Partnership(result.value['partnership']);
        final allocations = Partnership.shares(
          saved.json['allocations'],
          nullable: false,
        );
        if (saved.json['businessId'] != partners.businessId ||
            saved.revision <= body.number('expectedRevision') ||
            saved.mode != mode ||
            saved.json['reason'] != body.text('reason') ||
            allocations.length != parts.length ||
            parts.any(
              (p) => !allocations.any(
                (r) =>
                    r.text('partnerId') == p.text('partnerId') &&
                    r.number('basisPoints') == p.number('basisPoints'),
              ),
            )) {
          throw const FormatException('Ownership configuration not confirmed');
        }
        await storage.delete(key: _key);
        pending = null;
        return saved;
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
