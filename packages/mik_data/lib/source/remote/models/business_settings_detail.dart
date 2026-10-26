import 'dart:convert';

import 'remote_json.dart';

class BusinessSettingsDetail {
  static const choices = {
    'accounting.allocationPolicy': [
      'OLDEST_DUE_FIRST',
      'OLDEST_FIRST',
      'MANUAL',
    ],
    'inventory.itemFulfillmentMode': ['SINGLE_WAREHOUSE', 'MULTI_WAREHOUSE'],
    'inventory.supplyAllocation.mode': ['AUTO', 'MANUAL'],
    'inventory.supplyAllocation.priority': ['OLDEST_FIRST', 'PAYMENT_FIRST'],
  };
  static const booleans = [
    'accounting.allowCreditSales',
    'tax.taxpayerSystemEnabled',
  ];
  static const numbers = {
    'inventory.reservation.posTimeoutMinutes': [1, 1440],
    'inventory.reservation.onlineTimeoutMinutes': [1, 1440],
    'inventory.reservation.maxExtensions': [0, 10],
    'inventory.reservation.maxLifetimeMinutes': [1, 1440],
  };
  static const paymentPath =
      'inventory.supplyAllocation.eligiblePaymentStatuses';
  static const paymentStatuses = ['PAID', 'PARTIALLY_PAID', 'UNPAID'];
  static Iterable<String> get paths => [
    ...booleans,
    ...choices.keys,
    ...numbers.keys,
    paymentPath,
  ];
  final String _json;
  final int businessId, revision;
  Map<String, dynamic> get json => jsonDecode(_json) as Map<String, dynamic>;
  BusinessSettingsDetail.fromJson(Object? value)
    : _json = jsonEncode(RemoteJson(value).value),
      businessId = RemoteJson(value).number('businessId'),
      revision = RemoteJson(value).number('revision') {
    if (revision < 1) throw const FormatException('Invalid settings revision');
    validate(editable);
  }

  static Object? at(Map<String, dynamic> source, String path) {
    Object? value = source;
    for (final key in path.split('.')) {
      if (value is! Map) return null;
      value = value[key];
    }
    return value;
  }

  Map<String, dynamic> get editable => {
    for (final path in paths) path: at(json, path),
  };
  static void validate(Map<String, dynamic> values) {
    if (values.length != paths.length ||
        values.keys.any((key) => !paths.contains(key))) {
      throw const FormatException('اطلاعات تنظیمات کامل نیست.');
    }
    for (final path in booleans) {
      if (values[path] is! bool) {
        throw const FormatException('گزینه‌های تنظیمات معتبر نیستند.');
      }
    }
    for (final entry in choices.entries) {
      if (!entry.value.contains(values[entry.key])) {
        throw const FormatException('گزینه انتخاب‌شده معتبر نیست.');
      }
    }
    for (final entry in numbers.entries) {
      final value = values[entry.key];
      if (value is! int || value < entry.value[0] || value > entry.value[1]) {
        throw FormatException(
          entry.key.endsWith('maxExtensions')
              ? 'تعداد تمدید رزرو باید از ۰ تا ۱۰ باشد.'
              : 'زمان رزرو باید از ۱ تا ۱۴۴۰ دقیقه باشد.',
        );
      }
    }
    final statuses = values[paymentPath];
    if (statuses is! List ||
        statuses.isEmpty ||
        statuses.toSet().length != statuses.length ||
        statuses.any((value) => !paymentStatuses.contains(value))) {
      throw const FormatException(
        'حداقل یک وضعیت پرداخت برای تخصیص موجودی انتخاب کنید.',
      );
    }
    final lifetime = values['inventory.reservation.maxLifetimeMinutes'] as int;
    if (lifetime < (values['inventory.reservation.posTimeoutMinutes'] as int) ||
        lifetime <
            (values['inventory.reservation.onlineTimeoutMinutes'] as int)) {
      throw const FormatException(
        'حداکثر عمر رزرو نباید کمتر از زمان رزرو فروش حضوری یا آنلاین باشد.',
      );
    }
  }

  Map<String, dynamic> changes(Map<String, dynamic> values) {
    validate(values);
    final result = <String, dynamic>{};
    for (final path in paths) {
      final before = at(json, path), after = values[path];
      final unchanged = path == paymentPath
          ? (before as List).length == (after as List).length &&
                before.toSet().containsAll(after)
          : before == after;
      if (unchanged) continue;
      var parent = result;
      final parts = path.split('.');
      for (final key in parts.take(parts.length - 1)) {
        parent = parent.putIfAbsent(
          key,
          () => <String, dynamic>{},
        ) as Map<String, dynamic>;
      }
      parent[parts.last] = after;
    }
    return result;
  }
}
