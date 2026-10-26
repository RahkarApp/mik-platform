import 'pim_record.dart';
import 'remote_json.dart';

class PimPriceOverride extends PimRecord {
  @override
  final String id;
  final String productPriceId, variantId;
  final int amount;
  @override
  String get name => 'قیمت اختصاصی تنوع';
  PimPriceOverride.fromJson(Object? value) : this._(RemoteJson(value));
  PimPriceOverride._(super.json)
    : id = json.text('overrideId'),
      productPriceId = json.text('productPriceId'),
      variantId = json.text('variantId'),
      amount = json.number('amount');
}
