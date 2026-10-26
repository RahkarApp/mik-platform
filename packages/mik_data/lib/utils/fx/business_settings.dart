import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/business_settings_detail.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/scope_authorization.dart';
import 'business_context.dart';

class BusinessSettingsFX {
  static final _clients = Expando<BusinessSettingsFX>();
  static BusinessSettingsFX forContext(BusinessContext context) =>
      _clients[context] ??= BusinessSettingsFX(context);
  final BusinessContext context;
  final FlutterSecureStorage storage;
  BusinessSettingsFX(
    this.context, {
    this.storage = const FlutterSecureStorage(),
  });
  ScopeAuthorization? _access;
  String? _pending;
  bool _sending = false;
  bool get hasPending => _pending != null;
  int get businessId => context.session.business.businessId;
  String get _base => '/v1/businesses/$businessId/settings';
  String get _key =>
      'business.settings.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId';
  bool get canEdit =>
      context.valid &&
      _access?.permissionCodes.contains('business.business.settings.update') ==
          true;
  void _require(String permission) {
    context.check();
    if (_access?.permissionCodes.contains(permission) != true) {
      throw const AuthError(403, 'FORBIDDEN');
    }
  }

  Future<void> authorize() async {
    context.check();
    _access = null;
    final result = ScopeAuthorization.fromJson(
      await context.auth.request(
        'GET',
        '/v1/businesses/$businessId/authorization',
        query: {'scopeType': 'BUSINESS', 'scopeId': '$businessId'},
      ),
    );
    context.check();
    if (!result.allowed ||
        result.businessId != businessId ||
        result.membershipId != context.session.business.membershipId ||
        result.scopeType != 'BUSINESS' ||
        result.scopeId != '$businessId') {
      throw const AuthError(403, 'FORBIDDEN');
    }
    _access = result;
  }

  BusinessSettingsDetail _read(Object? value) {
    final item = BusinessSettingsDetail.fromJson(
      RemoteJson(value).value['item'],
    );
    if (item.businessId != businessId) {
      throw const FormatException('Unexpected business settings');
    }
    return item;
  }

  Future<BusinessSettingsDetail> load() async {
    if (_sending) throw const AuthError(409, 'SETTINGS_PENDING');
    await authorize();
    _require('business.business.read');
    _pending = await storage.read(key: _key);
    context.check();
    return _read(await context.request('GET', _base));
  }

  Future<BusinessSettingsDetail> save(
    BusinessSettingsDetail before,
    Map<String, dynamic> values,
  ) async {
    if (_sending) throw const AuthError(409, 'SETTINGS_PENDING');
    _sending = true;
    try {
      await authorize();
      _require('business.business.settings.update');
      _pending ??= await storage.read(key: _key);
      context.check();
      if (_pending == null) {
        if (before.businessId != businessId) {
          throw const AuthError(403, 'FORBIDDEN');
        }
        final changes = before.changes(values);
        if (changes.isEmpty) {
          throw const FormatException('تغییری برای ذخیره وجود ندارد.');
        }
        _pending = jsonEncode({
          'key': const Uuid().v4(),
          'body': {...changes, 'expectedRevision': before.revision},
        });
      }
      await storage.write(key: _key, value: _pending!);
      context.check();
      final command = RemoteJson(jsonDecode(_pending!));
      final body = RemoteJson(command.value['body']);
      final key = command.text('key');
      if (!Uuid.isValidUUID(fromString: key) ||
          body.number('expectedRevision') < 1) {
        throw const FormatException('Invalid pending settings');
      }
      try {
        final response = RemoteJson(
          await context.request(
            'PATCH',
            _base,
            data: body.value,
            idempotencyKey: key,
          ),
        );
        final result = _read(response.value);
        if (response.number('businessId') != businessId ||
            result.revision <= body.number('expectedRevision')) {
          throw const FormatException('Unexpected settings confirmation');
        }
        for (final path in BusinessSettingsDetail.paths) {
          final expected = BusinessSettingsDetail.at(body.value, path);
          if (expected == null) continue;
          final actual = BusinessSettingsDetail.at(result.json, path);
          if (expected is List
              ? actual is! List ||
                    actual.length != expected.length ||
                    !actual.toSet().containsAll(expected)
              : actual != expected) {
            throw const FormatException('Unexpected settings confirmation');
          }
        }
        await storage.delete(key: _key);
        _pending = null;
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
          _pending = null;
        }
        rethrow;
      }
    } finally {
      _sending = false;
    }
  }

  static String message(Object error) {
    if (error is AuthError) {
      if (error.code == 'FORBIDDEN') {
        return 'مجوز مشاهده یا تغییر تنظیمات کسب‌وکار را ندارید.';
      }
      if (error.code == 'REVISION_CONFLICT') {
        return 'تنظیمات تغییر کرده است؛ دوباره دریافت کنید و تغییرات را اعمال کنید.';
      }
      if (error.code == 'VALIDATION_FAILED') {
        return 'مقادیر تنظیمات و ارتباط شعبه و انبار را بررسی کنید.';
      }
      if (['SETTINGS_PENDING', 'IDEMPOTENCY_CONFLICT'].contains(error.code)) {
        return 'درخواست قبلی هنوز تعیین تکلیف نشده است؛ همان درخواست را پیگیری کنید.';
      }
      if (error.code == 'RECORD_NOT_FOUND') {
        return 'تنظیمات این کسب‌وکار در سرور پیدا نشد.';
      }
      if (error.code == 'SELECTION_CHANGED') {
        return 'کسب‌وکار یا شعبه تغییر کرده است؛ صفحه را دوباره باز کنید.';
      }
      if (!error.requiresLogin && error.statusCode < 500) {
        return 'عملیات تنظیمات انجام نشد؛ کد خطای سرور: ${error.code}';
      }
    }
    if (error is FormatException) {
      return 'اطلاعات تنظیمات یا پاسخ سرور معتبر نیست.';
    }
    return API.loginError(error);
  }
}
