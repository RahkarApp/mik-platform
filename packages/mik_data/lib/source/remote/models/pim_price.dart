import 'pim_record.dart';
import 'remote_json.dart';

class PimPrice extends PimRecord {
  @override
  final String id, name;
  final String productId, currency;
  final int amount;
  final bool isDefault;
  final DateTime? validFrom, validUntil;
  PimPrice.fromJson(Object? value) : this._(RemoteJson(value));
  PimPrice._(super.json)
    : id = json.text('productPriceId'),
      name = json.text('name'),
      productId = json.text('productId'),
      currency = json.text('currency'),
      amount = json.number('amount'),
      isDefault = json.flag('isDefault'),
      validFrom = json.optionalText('validFrom') == null
          ? null
          : DateTime.parse(json.text('validFrom')),
      validUntil = json.optionalText('validUntil') == null
          ? null
          : DateTime.parse(json.text('validUntil'));
}
