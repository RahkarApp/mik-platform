import 'pim_option_pair.dart';
import 'pim_record.dart';
import 'remote_json.dart';

class PimVariant extends PimRecord {
  @override
  final String id;
  final String productId, combinationKey;
  final String? sku, description;
  final List<String> barcodes;
  final List<PimOptionPair> optionValues;
  @override
  String get name => sku ?? (optionValues.isEmpty ? 'تنوع پایه' : 'تنوع محصول');
  PimVariant.fromJson(Object? value) : this._(RemoteJson(value));
  PimVariant._(super.json)
    : id = json.text('variantId'),
      productId = json.text('productId'),
      combinationKey = json.text('combinationKey'),
      sku = json.optionalText('sku'),
      description = json.optionalText('description'),
      barcodes = json.strings('barcodes'),
      optionValues = json.items('optionValues', PimOptionPair.fromJson);
}
