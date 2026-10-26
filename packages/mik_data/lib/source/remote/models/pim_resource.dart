import 'pim_record.dart';
import 'pim_product.dart';
import 'pim_category.dart';
import 'pim_attribute.dart';
import 'pim_brand.dart';
import 'pim_variant.dart';
import 'pim_price.dart';
import 'pim_price_override.dart';

enum PimResource {
  products('products', 'محصولات', 'pim.product'),
  attributes('attributes', 'ویژگی‌ها', 'pim.attribute'),
  categories('categories', 'دسته‌بندی‌ها', 'pim.product.category'),
  brands('brands', 'برندها', 'pim.brand'),
  variants('variants', 'تنوع‌ها', 'pim.variant'),
  prices('prices', 'قیمت‌ها', 'pim.price'),
  overrides('price-overrides', 'قیمت اختصاصی تنوع', 'pim.price');

  final String path, label, permission;
  const PimResource(this.path, this.label, this.permission);
  String get archivePermission =>
      '$permission.${this == products ? 'archive' : 'delete'}';
  PimRecord parse(Object? value) => switch (this) {
    products => PimProduct.fromJson(value),
    categories => PimCategory.fromJson(value),
    attributes => PimAttribute.fromJson(value),
    brands => PimBrand.fromJson(value),
    variants => PimVariant.fromJson(value),
    prices => PimPrice.fromJson(value),
    overrides => PimPriceOverride.fromJson(value),
  };
}
