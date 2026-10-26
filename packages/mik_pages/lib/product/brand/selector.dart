import 'package:flutter/material.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_data/source/remote/models/models.dart';

class ProductBrandSelector extends StatelessWidget {
  final List<PimBrand> brands;
  final String? value;
  final bool enabled;
  final String? error;
  final ValueChanged<String?> onChanged;
  const ProductBrandSelector({
    super.key,
    required this.brands,
    this.value,
    required this.enabled,
    this.error,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final items = [
      ItemValue(text: 'بدون برند', data: null),
      for (final brand in brands) ItemValue(text: brand.name, data: brand.id),
      if (value != null && !brands.any((v) => v.id == value))
        ItemValue(text: 'برند فعلی (شناسه: $value)', data: value),
    ];
    return Column(
      children: [
        Dropdown(
          name: 'برند (اختیاری)',
          itemValue: true,
          items_Value: items,
          defaultValue: items.where((v) => v.data == value).firstOrNull,
          disable: !enabled,
          onChange: (v) => onChanged((v as ItemValue).data as String?),
        ),
        if (error != null) Text('فهرست برندها در دسترس نیست: $error'),
      ],
    );
  }
}
