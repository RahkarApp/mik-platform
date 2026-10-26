import 'package:uuid/uuid.dart';

import 'remote_json.dart';

class SmsTemplate {
  final RemoteJson row;
  SmsTemplate(Object? value, int businessId) : row = RemoteJson(value) {
    if (row.text('platformId') != 'mik' ||
        row.number('businessId') != businessId ||
        !Uuid.isValidUUID(fromString: id) ||
        revision < 1) {
      throw const FormatException('Unexpected SMS template');
    }
    row.text('name');
    row.text('body');
    row.text('eventKey');
    row.flag('active');
    if (row.value['default'] != null) {
      final selected = RemoteJson(row.value['default']);
      if (selected.text('templateId') != id ||
          selected.text('eventKey') != eventKey ||
          selected.number('businessId') != businessId ||
          selected.text('platformId') != 'mik' ||
          selected.number('revision') < 1) {
        throw const FormatException('Unexpected SMS default');
      }
    }
  }
  String get id => row.text('templateId');
  String get name => row.text('name');
  String get body => row.text('body');
  String get eventKey => row.text('eventKey');
  int get revision => row.number('revision');
  bool get active => row.flag('active');
  bool get isDefault => row.value['default'] != null;
}

class SmsWallet {
  final int balance, held, available;
  SmsWallet(Object? value, int businessId, {String kind = 'SMS'})
    : this._(RemoteJson(value), businessId, kind);
  SmsWallet._(RemoteJson row, int businessId, String kind)
    : balance = row.number('balance'),
      held = row.number('held'),
      available = row.number('available') {
    if (row.text('platformId') != 'mik' ||
        row.number('businessId') != businessId ||
        !['SMS', 'SALES'].contains(kind) ||
        row.text('kind') != kind ||
        row.text('currency') != 'TOMAN' ||
        !Uuid.isValidUUID(fromString: row.text('accountId')) ||
        balance < 0 ||
        held < 0 ||
        held > balance ||
        available != balance - held ||
        row.number('revision') < 0) {
      throw const FormatException('Unexpected SMS wallet');
    }
  }
}

class SmsTopupPayment {
  final RemoteJson row;
  SmsTopupPayment(Object? value, int businessId) : row = RemoteJson(value) {
    if (row.text('platformId') != 'mik' ||
        row.number('businessId') != businessId ||
        row.text('purpose') != 'SMS_TOPUP' ||
        row.text('currency') != 'TOMAN' ||
        row.text('beneficiary') != 'PLATFORM' ||
        row.text('gatewayOwnership') != 'PLATFORM' ||
        !Uuid.isValidUUID(fromString: id) ||
        !Uuid.isValidUUID(fromString: row.text('subjectId')) ||
        !Uuid.isValidUUID(fromString: row.text('gatewayAccountId')) ||
        amount < 1 ||
        amount > 1000000000000 ||
        row.number('revision') < 1 ||
        !statuses.containsKey(status) ||
        ![
          'WAITING',
          'PENDING',
          'APPLIED',
          'ACTION_REQUIRED',
        ].contains(fulfillment) ||
        DateTime.tryParse(row.text('expiresAt')) == null ||
        (fulfillment == 'APPLIED' && status != 'PAID')) {
      throw const FormatException('Unexpected SMS payment');
    }
    if (status == 'PAID' &&
        (DateTime.tryParse(row.text('paidAt')) == null ||
            !RegExp(r'^[0-9]{1,40}$').hasMatch(row.text('referenceNo')))) {
      throw const FormatException('Incomplete paid SMS receipt');
    }
    if (row.optionalText('paymentUrl') case final url?) {
      final uri = Uri.tryParse(url);
      // These are the redirect hosts emitted by the current server PSP adapter.
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          !['www.zarinpal.com', 'sandbox.zarinpal.com'].contains(uri.host) ||
          uri.port != 443 ||
          !RegExp(r'^/pg/StartPay/[A-Za-z0-9]{20,100}$').hasMatch(uri.path) ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const FormatException('Unexpected payment URL');
      }
    }
  }
  String get id => row.text('paymentId');
  int get amount => row.number('amount');
  String get status => row.text('status');
  String get fulfillment => row.text('fulfillmentStatus');
  bool get applied => status == 'PAID' && fulfillment == 'APPLIED';
  bool get terminal => applied || status == 'FAILED';
  String get description => applied
      ? 'پرداخت موفق و اعتبار پیامک اعمال شد.'
      : status == 'PAID'
      ? (fulfillment == 'ACTION_REQUIRED'
            ? 'پرداخت انجام شده؛ اعمال اعتبار نیاز به بررسی پشتیبانی دارد.'
            : 'پرداخت تأیید شده؛ در انتظار اعمال اعتبار پیامک.')
      : statuses[status]!;
  static const statuses = {
    'CREATING': 'در حال ساخت درخواست پرداخت',
    'PENDING': 'در انتظار پرداخت و تأیید بانک',
    'UNKNOWN': 'نتیجه پرداخت هنوز مشخص نیست؛ پیگیری کنید.',
    'PAID': 'پرداخت تأیید شده',
    'FAILED': 'پرداخت ناموفق بود؛ اعتبار اضافه نشده است.',
    'ACTION_REQUIRED':
        'وضعیت پرداخت نیاز به بررسی پشتیبانی دارد؛ پرداخت تکراری انجام ندهید.',
  };
}

class SmsMessage {
  final RemoteJson row;
  SmsMessage(Object? value, int businessId) : row = RemoteJson(value) {
    if (row.text('platformId') != 'mik' ||
        row.number('senderBusinessId') != businessId ||
        !Uuid.isValidUUID(fromString: id) ||
        row.number('revision') < 1 ||
        !statuses.containsKey(status) ||
        DateTime.tryParse(row.text('createdAt')) == null) {
      throw const FormatException('Unexpected SMS message');
    }
    row.text('recipientMasked');
  }
  String get id => row.text('notificationId');
  String get status => row.text('status');
  static const statuses = {
    'PENDING': 'در انتظار ارسال',
    'PROCESSING': 'در حال پردازش',
    'ACCEPTED': 'پذیرفته‌شده توسط سرویس ارسال',
    'FAILED': 'ناموفق',
    'UNKNOWN': 'نتیجه نامشخص',
    'EXPIRED': 'منقضی‌شده',
    'CANCELLED': 'لغوشده',
  };
}
