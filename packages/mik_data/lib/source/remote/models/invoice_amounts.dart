import 'package:persian_number_utility/persian_number_utility.dart';

class InvoiceAmounts {
  final int discount, shipping, surcharge, tax;
  final String? purchaseTaxTreatment;
  const InvoiceAmounts({
    this.discount = 0,
    this.shipping = 0,
    this.surcharge = 0,
    this.tax = 0,
    this.purchaseTaxTreatment,
  });
  int total(int subtotal) {
    const max = 9007199254740991;
    if ([
          subtotal,
          discount,
          shipping,
          surcharge,
          tax,
        ].any((v) => v < 0 || v > max) ||
        discount > subtotal ||
        purchaseTaxTreatment != null &&
            ![
              'RECOVERABLE',
              'NON_RECOVERABLE',
            ].contains(purchaseTaxTreatment)) {
      throw const FormatException('Invalid invoice amounts');
    }
    final result =
        BigInt.from(subtotal) -
        BigInt.from(discount) +
        BigInt.from(shipping) +
        BigInt.from(surcharge) +
        BigInt.from(tax);
    if (result > BigInt.from(max)) {
      throw const FormatException('Invoice money overflow');
    }
    return result.toInt();
  }

  Map<String, Object> get payload => {
    if (discount != 0) 'discountAmount': discount,
    if (shipping != 0) 'shippingAmount': shipping,
    if (surcharge != 0) 'surchargeAmount': surcharge,
    if (tax != 0) 'taxAmount': tax,
    if (tax > 0 && purchaseTaxTreatment != null)
      'purchaseTaxTreatment': purchaseTaxTreatment!,
  };
  static int parse(String text) {
    final value = text
        .toEnglishDigit()
        .replaceAll(RegExp(r'[,٬\s]'), '')
        .replaceAll('تومان', '');
    if (value.isEmpty) return 0;
    final amount = RegExp(r'^\d+$').hasMatch(value)
        ? int.tryParse(value)
        : null;
    if (amount == null || amount > 9007199254740991) {
      throw const FormatException('Invalid invoice money');
    }
    return amount;
  }
}
