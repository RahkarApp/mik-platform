// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_consts/units.dart';
import 'package:mik_data/source/remote/models/catalog_unit.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';

import 'package:persian_number_utility/persian_number_utility.dart';

class UnitInput extends GetView {
  @override
  TextEditingController controller;
  FocusNode? focusNode;
  String name;
  TextDirection? textDirection;
  TextAlign? textAlign;
  bool? readOnly;
  bool? enabled;
  bool? require;
  var onChanged;
  String? hintText;
  var selected;
  final List<CatalogUnit>? units;

  ///cost,product
  UnitInput({
    super.key,
    required this.selected,
    this.units,
    required this.controller,
    this.focusNode,
    this.textDirection,
    this.textAlign,
    this.readOnly,
    required this.onChanged,
    this.enabled,
    this.hintText,
    this.require,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Input(
      controller: controller,
      name: name,
      require: require,
      focusNode: focusNode,
      textDirection: textDirection,
      textAlign: textAlign,
      readOnly: true,
      maxLines: 1,
      minLines: 1,
      onTap: () => select(context, (v) => onChanged(v)),
      enabled: enabled,
      hintText: hintText,
      suffixIcon: controller.text.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: InkWell(
                onTap: () {
                  onChanged({'name': '', 'id': null});
                },
                child: const Icon(IconsaxPlusLinear.close_square),
              ),
            )
          : null,
    );
  }

  select(context, callback) {
    RxList list = [].obs;
    final source = units == null
        ? productUnits
        : [
            for (final unit in units!) {'id': unit.id, 'name': unit.name},
          ];
    list.value = source;

    return MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          MySearchBar(
            type: SearchBarType.unit,
            callback: (value) {
              if (value.length > 0) {
                list.value = source
                    .where(
                      (e) => e['name']
                          .toString()
                          .toLowerCase()
                          .toEnglishDigit()
                          .contains(
                            value.toString().toLowerCase().toEnglishDigit(),
                          ),
                    )
                    .toList();
              } else {
                final source = units == null
                    ? productUnits
                    : [
                        for (final unit in units!)
                          {'id': unit.id, 'name': unit.name},
                      ];
                list.value = source;
              }
            },
          ),
          Expanded(
            child: Obx(
              () => list.isNotEmpty
                  ? GridView.count(
                      controller: scrollController,
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.5,
                      children: [
                        for (var i = 0; i < list.length; i++)
                          if (list[i]['name'] != '')
                            InkWell(
                              onTap: () {
                                callback(list[i]);
                                Get.back();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color:
                                      selected != null &&
                                          selected['id']?.toString() ==
                                              list[i]['id']?.toString()
                                      ? AppColors.primary.withValues(alpha: 0.5)
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        selected != null &&
                                            selected['id']?.toString() ==
                                                list[i]['id']?.toString()
                                        ? AppColors.primary
                                        : darkMode.value
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                child: Text(
                                  list[i]['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: darkMode.value
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    )
                  : Center(
                      child: Text(
                        'واحد کالایی مطابق جستجو یافت نشد!',
                        style: TextStyle(
                          fontSize: 16,
                          color: darkMode.value ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      title: 'واحد کالا',
      initialChildSize: 0.5,
    );
  }
}
