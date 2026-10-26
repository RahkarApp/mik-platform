import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';

import 'package:mik_data/source/remote/models/models.dart';

class ProductDescriptiveFields extends StatefulWidget {
  final List<PimAttribute> attributes;
  final List<CatalogUnit> units;
  final Set<String> axisIds;
  final RxList<Map<String, dynamic>> values;
  final bool frozen;
  const ProductDescriptiveFields({
    super.key,
    required this.attributes,
    required this.units,
    required this.axisIds,
    required this.values,
    this.frozen = false,
  });
  @override
  State<ProductDescriptiveFields> createState() =>
      _ProductDescriptiveFieldsState();
}

class _ProductDescriptiveFieldsState extends State<ProductDescriptiveFields> {
  final inputs = <String, TextEditingController>{};
  TextEditingController input(Map<String, dynamic> row) => inputs.putIfAbsent(
    row['attributeId'] as String,
    () => TextEditingController(
      text: (row['textValue'] ?? row['numberValue'])?.toString() ?? '',
    ),
  );
  void update(String id, String key, Object value) {
    final index = widget.values.indexWhere((v) => v['attributeId'] == id);
    if (index >= 0) widget.values[index] = {'attributeId': id, key: value};
  }

  @override
  void dispose() {
    for (final ctl in inputs.values) {
      ctl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final available = widget.attributes
        .where(
          (a) =>
              a.status == 'ACTIVE' &&
              !widget.axisIds.contains(a.id) &&
              !widget.values.any((v) => v['attributeId'] == a.id),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyDivider(text: 'ویژگی‌های توصیفی محصول'),
        for (final row in widget.values)
          Builder(
            builder: (_) {
              final id = row['attributeId'] as String;
              final attribute = widget.attributes
                  .where((v) => v.id == id)
                  .firstOrNull;
              final unit = attribute?.unitId == null
                  ? null
                  : widget.units
                        .where((v) => v.id == attribute!.unitId)
                        .firstOrNull
                        ?.name;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '${attribute?.name ?? id}${unit == null ? '' : ' ($unit)'}',
                    ),
                  ),
                  if (attribute == null)
                    Text(
                      (row['textValue'] ??
                              row['numberValue'] ??
                              row['booleanValue'] ??
                              row['valueIds'] ??
                              'مقدار وارد نشده')
                          .toString(),
                    )
                  else if (attribute.dataType == 'TEXT' ||
                      attribute.dataType == 'NUMBER')
                    Input(
                      key: ValueKey('descriptive-$id'),
                      controller: input(row),
                      name: attribute.name,
                      require: true,
                      maxLength: attribute.dataType == 'TEXT' ? 5000 : null,
                      keyboardType: attribute.dataType == 'NUMBER'
                          ? const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            )
                          : TextInputType.text,
                      onChanged: (String value) => update(
                        id,
                        attribute.dataType == 'TEXT'
                            ? 'textValue'
                            : 'numberValue',
                        value,
                      ),
                    ),
                  if (attribute?.dataType == 'BOOLEAN')
                    Builder(
                      builder: (_) {
                        const choices = [
                          ItemValue(text: 'بله', data: true),
                          ItemValue(text: 'خیر', data: false),
                        ];
                        return Dropdown(
                          name: attribute!.name,
                          itemValue: true,
                          items_Value: choices,
                          defaultValue: choices
                              .where((v) => v.data == row['booleanValue'])
                              .firstOrNull,
                          onChange: (value) => update(
                            id,
                            'booleanValue',
                            (value as ItemValue).data as bool,
                          ),
                        );
                      },
                    ),
                  if (attribute?.dataType == 'SELECT')
                    Builder(
                      builder: (_) {
                        final selected = (row['valueIds'] as List? ?? [])
                            .whereType<String>()
                            .toList();
                        final choices = attribute!.values
                            .where((v) => v.active)
                            .map(
                              (v) => ItemValue(text: v.name, data: v.valueId),
                            )
                            .toList();
                        return Column(
                          children: [
                            for (final valueId in selected.where(
                              (id) => !attribute.values.any(
                                (v) => v.valueId == id && v.active,
                              ),
                            ))
                              Text('گزینهٔ قبلی در دسترس نیست: $valueId'),
                            Dropdown(
                              name: attribute.name,
                              itemValue: true,
                              items_Value: choices,
                              defaultValue: choices
                                  .where((v) => selected.contains(v.data))
                                  .firstOrNull,
                              onChange: (value) => update(id, 'valueIds', [
                                (value as ItemValue).data as String,
                              ]),
                            ),
                          ],
                        );
                      },
                    ),
                  if (attribute?.dataType == 'MULTI_SELECT') ...[
                    for (final value in attribute!.values.where(
                      (v) =>
                          v.active ||
                          (row['valueIds'] as List? ?? []).contains(v.valueId),
                    ))
                      CheckboxListTile(
                        title: Text(
                          '${value.name}${value.active ? '' : ' (غیرفعال)'}',
                        ),
                        value: (row['valueIds'] as List? ?? []).contains(
                          value.valueId,
                        ),
                        onChanged: (checked) {
                          final ids = List<String>.from(
                            row['valueIds'] as List? ?? [],
                          );
                          if (checked == true &&
                              value.active &&
                              !ids.contains(value.valueId)) {
                            ids.add(value.valueId);
                          }
                          if (checked != true) ids.remove(value.valueId);
                          update(id, 'valueIds', ids);
                        },
                      ),
                  ],
                  MiniBTN(
                    name: 'برداشتن ویژگی از محصول',
                    icon: IconsaxPlusLinear.close_square,
                    noFlex: true,
                    onTap: () => widget.values.removeWhere(
                      (v) => v['attributeId'] == id,
                    ),
                  ),
                ],
              );
            },
          ),
        if (!widget.frozen &&
            widget.values.length < 100 &&
            available.isNotEmpty)
          Dropdown(
            key: ValueKey(
              'descriptive-picker-${widget.values.map((v) => v['attributeId']).join(',')}',
            ),
            name: 'افزودن ویژگی توصیفی',
            itemValue: true,
            items_Value: available
                .map((a) => ItemValue(text: a.name, data: a.id))
                .toList(),
            onChange: (value) {
              final id = (value as ItemValue).data as String;
              inputs[id]?.clear();
              widget.values.add({'attributeId': id});
            },
          ),
        if (widget.values.isEmpty)
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'ویژگی توصیفی انتخاب نشده است. ویژگی‌ها را ابتدا در تب «ویژگی‌ها» تعریف کنید.',
            ),
          ),
      ],
    );
  });
}
