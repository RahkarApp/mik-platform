import 'remote_json.dart';

class PimEffectivePrice {
  final int businessId, amount;
  final String productId, variantId, productPriceId, currency, source;
  PimEffectivePrice.fromJson(Object? value) : this._(RemoteJson(value));
  PimEffectivePrice._(RemoteJson json)
    : businessId = json.number('businessId'),
      amount = json.number('amount'),
      productId = json.text('productId'),
      variantId = json.text('variantId'),
      productPriceId = json.text('productPriceId'),
      currency = json.text('currency'),
      source = json.text('source') {
    if (amount < 0 ||
        amount > 9000000000000 ||
        currency != 'TOMAN' ||
        !['VARIANT_OVERRIDE', 'PRODUCT_BASE'].contains(source)) {
      throw const FormatException('Invalid effective price');
    }
  }
}
