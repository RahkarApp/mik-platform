import 'package:flutter/material.dart';
import 'package:mik_data/source/remote/models/pim_variant.dart';
import 'package:mik_data/source/remote/models/pim_attribute.dart';
import 'package:mik_data/source/remote/models/pim_option.dart';

/// The existing Mik attribute/value chips, shared by invoice and price rows.
class ProductVariantOptions extends StatelessWidget {
  final PimVariant variant;
  final List<PimAttribute> attributes;
  const ProductVariantOptions({
    super.key,
    required this.variant,
    required this.attributes,
  });
  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final pair in variant.optionValues) {
      final attribute = attributes
          .where((a) => a.id == pair.attributeId)
          .firstOrNull;
      final PimOption? option = attribute?.values
          .where((v) => v.valueId == pair.valueId)
          .firstOrNull;
      final hex = attribute?.kind == 'COLOR' ? option?.colorHex : null;
      final color = hex != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)
          ? Color(0xFF000000 | int.parse(hex.substring(1), radix: 16))
          : null;
      final foreground = color == null
          ? Theme.of(context).colorScheme.onSurface
          : color.computeLuminance() < 0.5
          ? Colors.white
          : Colors.black;
      chips.add(
        Tooltip(
          message: attribute == null || option == null
              ? 'نام ویژگی در دسترس نیست'
              : '${attribute.name}: ${option.name}',
          child: Container(
            width: 40,
            height: 29,
            decoration: BoxDecoration(
              color: color,
              border: color == null
                  ? Border.all(width: 0.3, color: foreground)
                  : null,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              children: [
                Container(
                  height: 13,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(width: 0.3, color: foreground),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      attribute?.name ?? 'ویژگی',
                      style: TextStyle(fontSize: 9, color: foreground),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        option?.name ?? 'نام در دسترس نیست',
                        style: TextStyle(fontSize: 9, color: foreground),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return chips.isEmpty
        ? Text(variant.name, style: const TextStyle(fontSize: 12))
        : Wrap(spacing: 5, runSpacing: 5, children: chips);
  }
}
