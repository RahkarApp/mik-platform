import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/business_sms.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_sms.dart';

class SmsFundingCommand {
  final String key, kind, _body;
  String? paymentId;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  SmsFundingCommand(this.kind, Map<String, dynamic> body)
    : key = const Uuid().v4(),
      _body = jsonEncode(body);
  SmsFundingCommand.fromJson(Object? value) : this._(RemoteJson(value));
  SmsFundingCommand._(RemoteJson row)
    : key = row.text('key'),
      kind = row.text('kind'),
      _body = jsonEncode(RemoteJson(row.value['body']).value),
      paymentId = row.optionalText('paymentId') {
    if (!Uuid.isValidUUID(fromString: key) ||
        paymentId != null && !Uuid.isValidUUID(fromString: paymentId!)) {
      throw const FormatException('Invalid saved SMS funding');
    }
    SmsFundingFX.validate(this);
  }
  Map<String, dynamic> toJson() => {
    'key': key,
    'kind': kind,
    'body': body,
    'paymentId': paymentId,
  };
}

class SmsFundingFX {
  final BusinessSmsFX sms;
  final FlutterSecureStorage storage;
  SmsFundingCommand? pending;
  bool sending = false;
  SmsFundingFX(this.sms, {this.storage = const FlutterSecureStorage()});
  static const returnUrl = String.fromEnvironment('SMS_PAYMENT_RETURN_URL');
  String get _key =>
      'sms-funding.v1.${sms.context.auth.appId}.${sms.context.origin}.${sms.context.session.identityId}.${sms.businessId}';
  bool get canTopup =>
      sms.context.valid &&
      sms.access?.permissionCodes.contains('payment.payment.create') == true;
  bool get canReadPayment =>
      sms.context.valid &&
      sms.access?.permissionCodes.contains('payment.payment.read') == true;
  Future<SmsFundingCommand?> restore() async {
    sms.context.check();
    final value = await storage.read(key: _key);
    sms.context.check();
    return pending = value == null
        ? null
        : SmsFundingCommand.fromJson(jsonDecode(value));
  }

  Future<SmsWallet?> sales() async {
    if (!sms.has('balance.transfer')) throw const AuthError(403, 'FORBIDDEN');
    final page = RemoteJson(
      await sms.context.request('GET', '${sms.base}/wallet'),
    );
    final accounts = page
        .items('accounts', RemoteJson.new)
        .where((r) => r.text('kind') == 'SALES')
        .toList();
    if (accounts.length > 1) {
      throw const FormatException('Duplicate sales wallet');
    }
    return accounts.isEmpty
        ? null
        : SmsWallet(accounts.single.value, sms.businessId, kind: 'SALES');
  }

  Future<SmsTopupPayment> payment(String id, {int? amount}) async {
    if (!canReadPayment) throw const AuthError(403, 'FORBIDDEN');
    if (!Uuid.isValidUUID(fromString: id)) {
      throw const FormatException('Invalid payment ID');
    }
    final result = RemoteJson(
      await sms.context.request(
        'GET',
        '/v1/businesses/${sms.businessId}/payments/$id',
      ),
    );
    final saved = SmsTopupPayment(result.value['payment'], sms.businessId);
    if (saved.id != id || amount != null && saved.amount != amount) {
      throw const FormatException('Unexpected SMS payment');
    }
    return saved;
  }

  static void validate(SmsFundingCommand command) {
    final body = RemoteJson(command.body), amount = body.number('amount');
    if (amount < 1 || amount > 1000000000000) {
      throw const AuthError(400, 'VALIDATION_FAILED');
    }
    if (command.kind == 'TRANSFER') {
      if (body.value.length != 1 || command.paymentId != null) {
        throw const FormatException('Invalid transfer command');
      }
    } else if (command.kind == 'TOPUP') {
      if (body.value.length != 3 || body.text('purpose') != 'SMS_TOPUP') {
        throw const FormatException('Invalid topup command');
      }
      final url = Uri.tryParse(body.text('returnUrl'));
      if (url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty ||
          url.hasFragment ||
          url.toString().length > 2000) {
        throw const AuthError(400, 'RETURN_URL_FORBIDDEN');
      }
    } else {
      throw const FormatException('Invalid funding kind');
    }
  }

  Future<Object> send(SmsFundingCommand command) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    var attempted = false;
    try {
      await restore();
      attempted = pending != null;
      if (pending != null &&
          jsonEncode(pending!.toJson()) != jsonEncode(command.toJson())) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      validate(command);
      await sms.authorize();
      if (command.kind == 'TRANSFER'
          ? !sms.has('balance.transfer')
          : !canTopup || !canReadPayment) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      pending = command;
      // Persist before either mutation. An interrupted response must replay this exact amount and key.
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      if (command.kind == 'TRANSFER') {
        final result = RemoteJson(
          await sms.context.request(
            'POST',
            '${sms.base}/wallet/transfers',
            data: command.body,
            idempotencyKey: command.key,
          ),
        );
        if (!Uuid.isValidUUID(fromString: result.text('operationId'))) {
          throw const FormatException('Invalid transfer receipt');
        }
        result.flag('replayed');
        final account = SmsWallet(result.value['account'], sms.businessId);
        await storage.delete(key: _key);
        pending = null;
        return account;
      }
      SmsTopupPayment saved;
      if (command.paymentId != null) {
        saved = await payment(
          command.paymentId!,
          amount: command.body['amount'] as int,
        );
      } else {
        final result = RemoteJson(
          await sms.context.request(
            'POST',
            '/v1/businesses/${sms.businessId}/payments',
            data: command.body,
            idempotencyKey: command.key,
          ),
        );
        result.flag('replayed');
        saved = SmsTopupPayment(result.value['payment'], sms.businessId);
        if (saved.amount != command.body['amount']) {
          throw const FormatException('Unexpected topup amount');
        }
        command.paymentId = saved.id;
        await storage.write(key: _key, value: jsonEncode(command.toJson()));
      }
      if (saved.terminal) {
        await storage.delete(key: _key);
        pending = null;
      }
      return saved;
    } on AuthError catch (error) {
      if (!attempted &&
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

  static String message(Object error) {
    if (error is AuthError) {
      const messages = {
        'GATEWAY_NOT_CONFIGURED':
            'درگاه شارژ پیامک هنوز در سرور تنظیم نشده است.',
        'GATEWAY_DISABLED': 'درگاه پرداخت غیرفعال است.',
        'RETURN_URL_FORBIDDEN':
            'نشانی بازگشت پرداخت تنظیم نشده یا در سرور مجاز نیست.',
        'INSUFFICIENT_CREDIT': 'اعتبار قابل استفاده کیف فروش کافی نیست.',
        'VALIDATION_FAILED':
            'مبلغ باید عدد صحیح بین ۱ تا ۱٬۰۰۰٬۰۰۰٬۰۰۰٬۰۰۰ تومان باشد.',
      };
      if (messages.containsKey(error.code)) return messages[error.code]!;
    }
    return BusinessSmsFX.messageFor(error);
  }
}
