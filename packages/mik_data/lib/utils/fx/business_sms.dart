import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/business_sms.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/scope_authorization.dart';
import 'business_context.dart';
import 'sale_invoice.dart';

class SmsTemplateCommand {
  final String key, method, path, _body;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  SmsTemplateCommand(this.method, this.path, Map<String, dynamic> body)
    : key = const Uuid().v4(),
      _body = jsonEncode(body);
  SmsTemplateCommand.fromJson(Object? value) : this._(RemoteJson(value));
  SmsTemplateCommand._(RemoteJson row)
    : key = row.text('key'),
      method = row.text('method'),
      path = row.text('path'),
      _body = jsonEncode(RemoteJson(row.value['body']).value) {
    if (!Uuid.isValidUUID(fromString: key)) {
      throw const FormatException('Invalid SMS key');
    }
  }
  Map<String, dynamic> toJson() => {
    'key': key,
    'method': method,
    'path': path,
    'body': body,
  };
}

class BusinessSmsFX {
  final BusinessContext context;
  final FlutterSecureStorage storage;
  ScopeAuthorization? access;
  bool sending = false;
  SmsTemplateCommand? pending;
  BusinessSmsFX(this.context, {this.storage = const FlutterSecureStorage()});
  int get businessId => context.session.business.businessId;
  String get base => '/v1/businesses/$businessId/sms';
  String get _key =>
      'sms-template.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId';
  bool has(String permission) =>
      context.valid &&
      access?.permissionCodes.contains(
            'notification.notification.$permission',
          ) ==
          true;
  Future<void> authorize() async {
    access = null;
    final result = ScopeAuthorization.fromJson(
      await context.request(
        'GET',
        '/v1/businesses/$businessId/authorization',
        query: {'scopeType': 'BUSINESS', 'scopeId': '$businessId'},
      ),
    );
    if (!result.allowed ||
        result.businessId != businessId ||
        result.membershipId != context.session.business.membershipId ||
        result.scopeType != 'BUSINESS' ||
        result.scopeId != '$businessId') {
      throw const FormatException('Unexpected SMS authorization');
    }
    access = result;
  }

  Future<RemoteJson> _get(
    String path,
    String permission, {
    Map<String, String>? query,
  }) async {
    context.check();
    if (!has(permission)) throw const AuthError(403, 'FORBIDDEN');
    return RemoteJson(
      await context.request('GET', '$base/$path', query: query),
    );
  }

  Future<Map<String, List<String>>> events() async {
    final result = await _get('events', 'template.read');
    result.flag('clubIntegrationActive');
    final events = RemoteJson(result.value['events']);
    return {for (final key in events.value.keys) key: events.strings(key)};
  }

  Future<SmsWallet?> wallet() async {
    final result = await _get('wallet', 'balance.read');
    final accounts = result.items('accounts', RemoteJson.new);
    final sms = accounts.where((r) => r.text('kind') == 'SMS').toList();
    if (sms.length > 1) throw const FormatException('Duplicate SMS wallet');
    return sms.isEmpty ? null : SmsWallet(sms.single.value, businessId);
  }

  Future<List<SmsTemplate>> templates() async {
    final rows = <SmsTemplate>[], seen = <String>{}, ids = <String>{};
    String? after;
    do {
      final page = await _get(
        'templates',
        'template.read',
        query: {'limit': '100', 'after': ?after},
      );
      final items = page.items('items', (r) => SmsTemplate(r, businessId));
      if (items.any((r) => !ids.add(r.id))) {
        throw const FormatException('Duplicate SMS template');
      }
      rows.addAll(items);
      after = page.optionalText('nextCursor');
      if (after != null && !seen.add(after)) {
        throw const FormatException('Repeated SMS cursor');
      }
    } while (after != null);
    return rows;
  }

  Future<RemoteJson> history(DateTime start, DateTime end, {String? after}) =>
      _get(
        'messages',
        'history.read',
        query: {
          'limit': '50',
          'after': ?after,
          'startAt': start.toUtc().toIso8601String(),
          'endAt': end.toUtc().toIso8601String(),
        },
      );
  Future<SmsMessage> message(String id) async {
    if (!Uuid.isValidUUID(fromString: id)) {
      throw const FormatException('Invalid SMS id');
    }
    final result = SmsMessage(
      (await _get('messages/$id', 'history.read')).value,
      businessId,
    );
    if (result.id != id) throw const FormatException('Unexpected SMS detail');
    return result;
  }

  Future<RemoteJson> entries({String? after}) async {
    final page = await _get(
      'wallet/entries',
      'balance.read',
      query: {'limit': '50', 'after': ?after},
    );
    if (page.text('currency') != 'TOMAN') {
      throw const FormatException('Invalid wallet currency');
    }
    for (final row in page.items('items', RemoteJson.new)) {
      if (row.text('platformId') != 'mik' ||
          row.number('businessId') != businessId ||
          row.text('kind') != 'SMS' ||
          !Uuid.isValidUUID(fromString: row.text('entryId')) ||
          row.number('balanceAfter') < 0 ||
          DateTime.tryParse(row.text('createdAt')) == null) {
        throw const FormatException('Unexpected SMS entry');
      }
      row.number('amount');
      row.text('reason');
    }
    return page;
  }

  Future<SmsTemplateCommand?> restore() async {
    context.check();
    final value = await storage.read(key: _key);
    context.check();
    return pending = value == null
        ? null
        : SmsTemplateCommand.fromJson(jsonDecode(value));
  }

  Future<void> send(SmsTemplateCommand command) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    var alreadyPending = false;
    try {
      await restore();
      alreadyPending = pending != null;
      if (pending != null &&
          jsonEncode(pending!.toJson()) != jsonEncode(command.toJson())) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      await authorize();
      final create = command.method == 'POST' && command.path == 'templates';
      final update = command.method == 'PATCH';
      final deleting = command.method == 'DELETE';
      if (!create &&
          !(RegExp(r'^templates/[a-f0-9-]{36}$').hasMatch(command.path) &&
              (update || deleting))) {
        throw const FormatException('Invalid SMS command');
      }
      if (!has(
        'template.${create
            ? 'create'
            : update
            ? 'update'
            : 'delete'}',
      )) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      final body = RemoteJson(command.body);
      final fields = deleting
          ? ['expectedRevision']
          : create
          ? ['name', 'eventKey', 'body']
          : ['name', 'body', 'active', 'expectedRevision'];
      if (body.value.keys.any((key) => !fields.contains(key)) ||
          body.value.length != fields.length) {
        throw const FormatException('Unexpected SMS command fields');
      }
      if (!create && body.number('expectedRevision') < 1) {
        throw const FormatException('Invalid revision');
      }
      if (!deleting) {
        if (body.text('name').trim().isEmpty ||
            body.text('name').length > 100 ||
            body.text('body').trim().isEmpty ||
            body.text('body').length > 1000) {
          throw const AuthError(400, 'VALIDATION_FAILED');
        }
        if (create) {
          final catalog = await events();
          if (!catalog.containsKey(body.text('eventKey'))) {
            throw const AuthError(400, 'VALIDATION_FAILED');
          }
        }
      }
      // Keep the exact key/body until the server confirms this command; retry cannot create another template.
      pending = command;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      final result = RemoteJson(
        await context.request(
          command.method,
          '$base/${command.path}',
          data: command.body,
          idempotencyKey: command.key,
        ),
      );
      final saved = SmsTemplate(result.value['template'], businessId);
      result.flag('replayed');
      if ((create && (saved.revision != 1 || !saved.active)) ||
          (!deleting && saved.row.value['deletedAt'] != null) ||
          (!create && saved.id != command.path.split('/').last) ||
          (!create && saved.revision != body.number('expectedRevision') + 1) ||
          (deleting
              ? saved.active || saved.row.value['deletedAt'] == null
              : saved.name != body.text('name').trim() ||
                    saved.body != body.text('body').trim() ||
                    (create
                        ? saved.eventKey != body.text('eventKey')
                        : saved.active != body.flag('active')))) {
        throw const FormatException('SMS command not confirmed');
      }
      await storage.delete(key: _key);
      pending = null;
    } on AuthError catch (error) {
      // A definitive rejection of a new request can be corrected. An uncertain replay keeps its original command.
      if (!alreadyPending &&
          error.statusCode >= 400 &&
          error.statusCode < 500 &&
          !error.retryable &&
          !error.requiresLogin &&
          error.statusCode != 403 &&
          !['IDEMPOTENCY_CONFLICT', 'SELECTION_CHANGED'].contains(error.code)) {
        await storage.delete(key: _key);
        pending = null;
      }
      rethrow;
    } finally {
      sending = false;
    }
  }

  Future<void> setDefault(SmsTemplate template, int expectedRevision) async {
    await authorize();
    if (!has('template.default')) throw const AuthError(403, 'FORBIDDEN');
    final result = RemoteJson(
      (await context.request(
        'POST',
        '$base/templates/${template.id}/default',
        data: {'expectedRevision': expectedRevision},
      )) as Map<String, dynamic>,
    );
    final row = RemoteJson(result.value['default']);
    if (row.text('platformId') != 'mik' ||
        row.number('businessId') != businessId ||
        row.text('templateId') != template.id ||
        row.text('eventKey') != template.eventKey ||
        row.number('revision') != expectedRevision + 1) {
      throw const FormatException('SMS default not confirmed');
    }
  }

  static String messageFor(Object error) {
    if (error is FormatException) {
      return 'پاسخ سرویس پیامک کامل یا معتبر نیست؛ دوباره دریافت کنید.';
    }
    if (error is AuthError) {
      const messages = {
        'FORBIDDEN': 'مجوز این عملیات پیامک را ندارید.',
        'REVISION_CONFLICT':
            'قالب تغییر کرده است؛ اطلاعات را دوباره دریافت کنید.',
        'RECORD_IN_USE':
            'قالب پیش‌فرض قابل حذف نیست؛ ابتدا قالب پیش‌فرض دیگری انتخاب کنید.',
        'VALIDATION_FAILED': 'نام، متن قالب و متغیرهای آن را بررسی کنید.',
        'IDEMPOTENCY_CONFLICT': 'ابتدا نتیجه عملیات قبلی را پیگیری کنید.',
      };
      if (messages.containsKey(error.code)) return messages[error.code]!;
    }
    return SaleInvoiceFX.message(error);
  }
}
