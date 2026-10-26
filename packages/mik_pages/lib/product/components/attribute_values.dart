import 'package:mik_data/source/remote/models/models.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

List<Map<String, dynamic>> normalizeProductAttributeValues(
  Object? value, {
  required List<PimAttribute> attributes,
  required Set<String> axisIds,
}) {
  if (value is! List || value.length > 100) {
    throw StateError('حداکثر ۱۰۰ ویژگی توصیفی انتخاب کنید.');
  }
  final result = <Map<String, dynamic>>[], ids = <String>{};
  for (final raw in value) {
    if (raw is! Map ||
        raw['attributeId'] is! String ||
        !ids.add(raw['attributeId'] as String)) {
      throw StateError('ویژگی تکراری یا نامعتبر است.');
    }
    final attribute = attributes
        .where((a) => a.id == raw['attributeId'])
        .firstOrNull;
    if (attribute == null ||
        attribute.status != 'ACTIVE' ||
        axisIds.contains(attribute.id)) {
      throw StateError(
        'ویژگی فعال انتخاب کنید که در محور تنوع همین محصول استفاده نشده باشد.',
      );
    }
    final key = switch (attribute.dataType) {
      'TEXT' => 'textValue',
      'NUMBER' => 'numberValue',
      'BOOLEAN' => 'booleanValue',
      'SELECT' || 'MULTI_SELECT' => 'valueIds',
      _ => throw StateError('نوع ویژگی پشتیبانی نمی‌شود.'),
    };
    if (raw.length != 2 || !raw.containsKey(key)) {
      throw StateError('مقدار «${attribute.name}» را کامل وارد کنید.');
    }
    final input = raw[key];
    Object normalized;
    if (key == 'textValue') {
      if (input is! String ||
          input.trim().isEmpty ||
          input.trim().length > 5000 ||
          RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]').hasMatch(input)) {
        throw StateError('فیلدهای متنی و طول مجاز آن‌ها را بررسی کنید.');
      }
      normalized = input.trim();
    } else if (key == 'numberValue') {
      num? number;
      if (input is num) {
        number = input;
      } else if (input is String) {
        final text = input.toEnglishDigit().replaceAll('٫', '.').trim();
        if (RegExp(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$')
            .hasMatch(text)) {
          number = num.tryParse(text);
        }
      }
      if (number == null ||
          !number.isFinite ||
          number < -1e12 ||
          number > 1e12) {
        throw StateError(
          'عدد معتبر بین منفی و مثبت ۱٬۰۰۰٬۰۰۰٬۰۰۰٬۰۰۰ وارد کنید.',
        );
      }
      normalized = number;
    } else if (key == 'booleanValue') {
      if (input is! bool) {
        throw StateError('برای «${attribute.name}» بله یا خیر را انتخاب کنید.');
      }
      normalized = input;
    } else {
      if (input is! List ||
          input.isEmpty ||
          input.length > 100 ||
          input.toSet().length != input.length ||
          attribute.dataType == 'SELECT' && input.length != 1 ||
          input.any(
            (id) =>
                id is! String ||
                !attribute.values.any((v) => v.valueId == id && v.active),
          )) {
        throw StateError(
          'گزینه‌های فعال و معتبر «${attribute.name}» را انتخاب کنید.',
        );
      }
      normalized = List<String>.from(input);
    }
    result.add({'attributeId': attribute.id, key: normalized});
  }
  return result;
}
