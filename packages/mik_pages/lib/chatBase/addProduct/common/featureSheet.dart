import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_utils/public/color.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/saveHelper.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/chatBase/addProduct/common/addGroupDetailsController.dart';
import 'package:mik_pages/chatBase/addProduct/common/addPropertySheet.dart';
import 'package:mik_pages/chatBase/addProduct/common/detailsModel.dart';
import 'package:mik_pages/chatBase/addProduct/common/productProperty.dart';

class AddFeatureSheet extends StatefulWidget {
  final ProductDetailsModel product;
  final AddGroupDetailsController controller;
  final ScrollController? scrollController;

  const AddFeatureSheet({
    super.key,
    required this.product,
    required this.controller,
    this.scrollController,
  });

  @override
  State<AddFeatureSheet> createState() => _AddFeatureSheetState();
}

class _AddFeatureSheetController extends GetxController {
  bool isCreatingNew = false;
  final RxMap<String, List<dynamic>> selectedValuesByProperty =
      <String, List<dynamic>>{}.obs;
  final TextEditingController nameCtl = TextEditingController();
  final RxString proType = 'نوشتاری'.obs;
  String type = 'other';
  final RxList values = [].obs;
}

class _AddFeatureSheetState extends State<AddFeatureSheet> {
  late final _page = _AddFeatureSheetController();

  // Map of property uid -> List of selected value ids (as dynamic for int/String compatibility)

  // Fields for new feature

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_AddFeatureSheetController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        return SingleChildScrollView(
          controller: widget.scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_page.isCreatingNew) ...[
                if (productProperty.values.isEmpty) ...[
                  SizedBox(
                    height: 250,
                    child: EmptyList(
                      text: 'هیچ ویژگی تعریف نشده!',
                      icon: IconsaxPlusLinear.shapes_1,
                    ),
                  ),
                  SizedBox(height: 20),
                ] else if (productProperty.values.isNotEmpty) ...[
                  Text(
                    'ویرایش و افزودن ویژگی‌های محصول',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 16),

                  // نمایش همه ویژگی‌ها با مقادیرشان
                  ...productProperty.values.map((property) {
                    // پیدا کردن ویژگی موجود در لیست اگر قبلاً اضافه شده
                    final existingFeature = widget.product.properties
                        .firstWhere(
                          (f) => f.name == property.name,
                          orElse: () => ProductProperty(),
                        );
                    final isAlreadyAdded = existingFeature.uid != null;

                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isAlreadyAdded
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isAlreadyAdded
                            ? AppColors.primary.withValues(alpha: 0.05)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      property.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (isAlreadyAdded) ...[
                                      SizedBox(width: 8),
                                      Icon(
                                        IconsaxPlusBold.tick_circle,
                                        color: AppColors.success,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // دکمه انتخاب همه
                              Obx(() {
                                final allSelected = property.value.every((v) {
                                  final valueId = (v as Map)['id'].toString();
                                  final existsInFeature =
                                      isAlreadyAdded &&
                                      existingFeature.valuesWithId.any(
                                        (ev) => ev['id'].toString() == valueId,
                                      );
                                  final inChanges =
                                      _page
                                          .selectedValuesByProperty[property
                                              .uid]
                                          ?.any(
                                            (id) => id.toString() == valueId,
                                          ) ??
                                      false;
                                  return existsInFeature
                                      ? !inChanges
                                      : inChanges;
                                });

                                return _page.selectedValuesByProperty.isEmpty ||
                                        _page
                                            .selectedValuesByProperty
                                            .isNotEmpty
                                    ? TextButton.icon(
                                        onPressed: () {
                                          if (!_page.selectedValuesByProperty
                                              .containsKey(property.uid)) {
                                            _page.selectedValuesByProperty[property
                                                    .uid] =
                                                [];
                                          }

                                          if (allSelected) {
                                            // لغو انتخاب همه
                                            _page
                                                .selectedValuesByProperty[property
                                                    .uid]!
                                                .clear();
                                          } else {
                                            // انتخاب همه
                                            _page
                                                .selectedValuesByProperty[property
                                                    .uid]!
                                                .clear();
                                            for (var v in property.value) {
                                              final valueId = (v as Map)['id'];
                                              final existsInFeature =
                                                  isAlreadyAdded &&
                                                  existingFeature.valuesWithId
                                                      .any(
                                                        (ev) =>
                                                            ev['id']
                                                                .toString() ==
                                                            valueId.toString(),
                                                      );
                                              if (!existsInFeature) {
                                                _page
                                                    .selectedValuesByProperty[property
                                                        .uid]!
                                                    .add(valueId);
                                              }
                                            }
                                          }
                                          _page.selectedValuesByProperty
                                              .refresh();
                                        },
                                        icon: Icon(
                                          allSelected
                                              ? IconsaxPlusBold.tick_square
                                              : IconsaxPlusLinear.tick_square,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'همه',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      )
                                    : Container();
                              }),
                              IconButton(
                                icon: Icon(
                                  IconsaxPlusLinear.edit,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showEditPropertySheet(context, property),
                                tooltip: 'ویرایش و افزودن مقادیر',
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: property.value.map((value) {
                              final typedValue = Map<String, dynamic>.from(
                                value as Map,
                              );
                              final valueId = typedValue['id'].toString();

                              return Obx(() {
                                // بررسی وضعیت فعلی: آیا در لیست موجود است؟
                                final existsInFeature =
                                    isAlreadyAdded &&
                                    existingFeature.valuesWithId.any(
                                      (v) => v['id'].toString() == valueId,
                                    );

                                // بررسی وضعیت تغییرات: آیا در لیست تغییرات است؟
                                final inChanges =
                                    _page.selectedValuesByProperty[property.uid]
                                        ?.any(
                                          (id) => id.toString() == valueId,
                                        ) ??
                                    false;

                                // وضعیت نهایی: اگر در feature بود و در changes نیست = حذف شده
                                // اگر در feature نبود و در changes هست = اضافه شده
                                final finalSelected = existsInFeature
                                    ? !inChanges
                                    : inChanges;

                                return ChoiceChip(
                                  label: Text(typedValue['name'].toString()),
                                  selected: finalSelected,
                                  onSelected: (selected) {
                                    if (!_page.selectedValuesByProperty
                                        .containsKey(property.uid)) {
                                      _page.selectedValuesByProperty[property
                                              .uid] =
                                          [];
                                    }

                                    if (inChanges) {
                                      // اگر در لیست تغییرات بود، حذفش کن
                                      _page
                                          .selectedValuesByProperty[property
                                              .uid]!
                                          .removeWhere(
                                            (id) => id.toString() == valueId,
                                          );
                                    } else {
                                      // اگر نبود، اضافه‌اش کن
                                      _page
                                          .selectedValuesByProperty[property
                                              .uid]!
                                          .add(typedValue['id']);
                                    }
                                    _page.selectedValuesByProperty.refresh();
                                  },
                                );
                              });
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: 16),
                  BTN(onTap: () => _addSelectedProperties(), name: 'تایید'),
                  Divider(height: 32),
                ],
                BTN(
                  onTap: () => _showCreatePropertySheet(context),
                  name: 'تعریف ویژگی جدید',
                  borderOnly: true,
                ),
              ] else ...[
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        {
                          _page.isCreatingNew = false;
                          _page.update();
                        }
                      },
                      icon: Icon(IconsaxPlusLinear.arrow_right_1),
                    ),
                    Text('تعریف ویژگی جدید'),
                  ],
                ),
                _buildNewFeatureForm(context),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showEditPropertySheet(
    BuildContext context,
    ProductPropertyDB property,
  ) {
    // ذخیره مقادیر قبلی برای تشخیص مقادیر جدید
    final oldValueIds = property.value
        .map((v) => (v as Map)['id'].toString())
        .toSet();

    // باز کردن bottom sheet جدید برای ویرایش
    MyBottomSheet.view(
      context,
      child: (scrollController) => PropertySheet(
        property: property,
        onSave: (updatedProperty) async {
          // به‌روزرسانی property در لیست availableProperties
          final index = productProperty.values.toList().indexWhere(
            (p) => p.uid == property.uid,
          );
          if (index != -1) {
            productProperty.values.toList()[index] = updatedProperty;
            await SaveHelper.save(updatedProperty, index: index);
          }

          // بررسی اینکه آیا این ویژگی در product.properties وجود دارد
          final existingFeatureIndex = widget.product.properties.indexWhere(
            (f) => f.uid == property.uid,
          );

          if (existingFeatureIndex != -1) {
            // ویژگی موجود است - به‌روزرسانی مقادیر آن
            final existingFeature =
                widget.product.properties[existingFeatureIndex];

            // پاک کردن مقادیر قدیمی و اضافه کردن مقادیر جدید
            existingFeature.valuesWithId.clear();
            for (var val in updatedProperty.value) {
              existingFeature.valuesWithId.add(
                Map<String, dynamic>.from(val as Map),
              );
            }

            // به‌روزرسانی variants
            widget.controller.generateVariants(widget.product);
          } else {
            // ویژگی جدید است - پیدا کردن مقادیر جدید و اضافه کردن به انتخاب‌ها
            final newValueIds = updatedProperty.value
                .map((v) => (v as Map)['id'])
                .where((id) => !oldValueIds.contains(id.toString()))
                .toList();

            // اضافه کردن مقادیر جدید به لیست انتخاب‌ها
            if (newValueIds.isNotEmpty) {
              if (!_page.selectedValuesByProperty.containsKey(property.uid)) {
                _page.selectedValuesByProperty[property.uid] = [];
              }
              _page.selectedValuesByProperty[property.uid]!.addAll(newValueIds);
              _page.selectedValuesByProperty.refresh();
            }
          }

          // بستن bottom sheet ویرایش
          Get.back();

          // رفرش کردن UI با rebuild
          {
            _page.update();
          }
        },
      ),
      title: 'ویرایش ویژگی: ${property.name}',
    );
  }

  void _showCreatePropertySheet(BuildContext context) {
    // باز کردن bottom sheet جدید برای تعریف ویژگی
    MyBottomSheet.view(
      context,
      child: (scrollController) => PropertySheet(
        onSave: (newProperty) async {
          // اضافه کردن property جدید به لیست availableProperties
          widget.product.availableProperties.add(newProperty);
          // اضافه کردن همه مقادیر ویژگی جدید به لیست انتخاب‌ها
          _page.selectedValuesByProperty[newProperty.uid] = newProperty.value
              .map((v) => (v as Map)['id'])
              .toList();
          _page.selectedValuesByProperty.refresh();
          await SaveHelper.save(newProperty);
          // بستن bottom sheet
          Get.back();
          // رفرش UI
          {
            _page.update();
          }
        },
      ),
      title: 'تعریف ویژگی جدید',
    );
  }

  void _addSelectedProperties() {
    if (_page.selectedValuesByProperty.isEmpty) {
      Get.back();
      return;
    }

    // بررسی هر ویژگی و اعمال تغییرات
    _page.selectedValuesByProperty.forEach((propertyUid, selectedValueIds) {
      if (selectedValueIds.isEmpty) return;

      final property = productProperty.values.firstWhere(
        (p) => p.uid == propertyUid,
        orElse: () =>
            ProductPropertyDB(uid: '', name: '', value: [], inserter: 0),
      );

      if (property.uid.isEmpty) return;

      // بررسی اینکه آیا ویژگی قبلاً اضافه شده است
      final existingFeature = widget.product.properties.firstWhere(
        (f) => f.name == property.name,
        orElse: () => ProductProperty(),
      );

      if (existingFeature.uid != null) {
        // ویژگی از قبل وجود دارد - اعمال تغییرات (toggle)
        for (var changeId in selectedValueIds) {
          final changeIdStr = changeId.toString();
          final existsInFeature = existingFeature.valuesWithId.any(
            (v) => v['id'].toString() == changeIdStr,
          );

          if (existsInFeature) {
            // مقدار قبلاً بود، باید حذف شود
            var d = existingFeature.valuesWithId.removeWhere(
              (v) => v['id'].toString() == changeIdStr,
            );
            widget
                    .product
                    .variantStocks['${existingFeature.uid}:$changeIdStr'] =
                '0';
          } else {
            // مقدار جدید است، باید اضافه شود
            final valueToAdd = property.value
                .map((v) => Map<String, dynamic>.from(v as Map))
                .firstWhere(
                  (v) => v['id'].toString() == changeIdStr,
                  orElse: () => <String, dynamic>{},
                );

            if (valueToAdd.isNotEmpty) {
              existingFeature.valuesWithId.add(valueToAdd);
            }
          }
        }

        // اگر همه مقادیر حذف شدند، کل ویژگی را حذف کن
        if (existingFeature.valuesWithId.isEmpty) {
          widget.product.properties.removeWhere((f) => f.name == property.name);
          widget.product.variantStocks.clear();
        } else {
          widget.controller.generateVariants(widget.product);
        }
      } else {
        // ویژگی جدید است، اضافه کن
        final selectedValues = <Map<String, dynamic>>[];
        for (var value in property.value) {
          final typedValue = Map<String, dynamic>.from(value as Map);
          if (selectedValueIds.any(
            (id) => id.toString() == typedValue['id'].toString(),
          )) {
            selectedValues.add(typedValue);
          }
        }

        if (selectedValues.isNotEmpty) {
          widget.controller.addExistingFeature(
            widget.product,
            property,
            selectedValues: selectedValues,
          );
        }
      }
    });

    // پاک کردن انتخاب‌ها
    _page.selectedValuesByProperty.clear();
    //  if (widget.product.properties.length == 1) {
    //             widget.product
    //                     .variantStocks['${existingFeature.uid}:$changeIdStr'] =
    //                 widget.product.stockController.text;
    //           }
    // بستن bottom sheet - فقط یک بار
    Get.back();
  }

  Widget _buildNewFeatureForm(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 10),
        Dropdown(
          name: 'نوع ویژگی',
          items_String: ['نوشتاری', 'رنگ', 'سایز', 'پارت‌نامبر'],
          defaultValue: _page.proType.value,
          onChange: (v) {
            _page.proType.value = v;
            {
              _page.type = v == 'رنگ'
                  ? 'color'
                  : v == 'سایز'
                  ? 'size'
                  : v == 'پارت‌نامبر'
                  ? 'part'
                  : 'other';
              _page.update();
            }
          },
        ),
        Input(controller: _page.nameCtl, require: true, name: 'نام ویژگی'),
        SizedBox(height: 15),
        MyDivider(text: 'افزودن مقادیر'),
        _addValueInput(context),
        SizedBox(height: 15),
        MyDivider(text: 'مقدار‌های ویژگی'),
        Obx(
          () => Column(
            children: [
              for (int i = 0; i < _page.values.length; i++)
                Column(
                  children: [
                    Container(
                      padding: EdgeInsets.only(right: 20, top: 5, bottom: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            spacing: 15,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: _page.type == 'color'
                                      ? Color(
                                          int.tryParse(
                                                _page.values[i]['code'],
                                              ) ??
                                              443547886,
                                        )
                                      : AppColors.boxBackground,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _page.values[i]['id'].toString(),
                                  style: TextStyle(
                                    color:
                                        isColorDark(
                                          _page.type == 'color'
                                              ? Color(
                                                  int.tryParse(
                                                        _page.values[i]['code'],
                                                      ) ??
                                                      443547886,
                                                )
                                              : AppColors.boxBackground,
                                        )
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              Text(_page.values[i]['name']),
                            ],
                          ),
                          IconButton(
                            onPressed: () {
                              _page.values.removeAt(i);
                              for (int j = 0; j < _page.values.length; j++) {
                                _page.values[j]['id'] = j + 1;
                              }
                            },
                            icon: Icon(IconsaxPlusLinear.trash_square),
                          ),
                        ],
                      ),
                    ),
                    EndLine(),
                  ],
                ),
            ],
          ),
        ),
        SizedBox(height: 10),
        BTN(
          onTap: () => _saveNewFeature(),
          name: 'افزودن ویژگی به لیست',
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _addValueInput(context) {
    final name = TextEditingController();
    final code = TextEditingController();
    RxBool change = false.obs;

    return Column(
      children: [
        Row(
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Input(controller: name, name: 'نام مقدار', require: true),
            ),
            if (_page.type == 'color')
              Obx(
                () => BTN(
                  color: change.isFalse
                      ? Color(int.tryParse(code.text) ?? 4278190080)
                      : Color(int.tryParse(code.text) ?? 4278190080),
                  borderOnly: change.isFalse || change.isTrue
                      ? (int.tryParse(code.text) ?? 0) == 0
                      : false,
                  showBorder: true,
                  onTap: () => MyBottomSheet.view(
                    context,
                    child: (scrollController) => Column(
                      children: [
                        ColorPicker(
                          color: Color(int.tryParse(code.text) ?? 4280391411),
                          pickersEnabled: {
                            ColorPickerType.wheel: true,
                            ColorPickerType.accent: false,
                            ColorPickerType.primary: false,
                          },
                          width: 30,
                          height: 30,
                          wheelWidth: 10,
                          wheelDiameter: 190,
                          showColorCode: true,
                          colorCodeHasColor: true,
                          colorCodePrefixStyle: TextStyle(fontSize: 0),
                          onColorChanged: (c) {},
                          onColorChangeEnd: (value) {
                            change.toggle();
                            code.text = value.toARGB32().toString();
                          },
                        ),
                        Row(
                          children: [
                            Flexible(
                              flex: 2,
                              child: BTN(
                                onTap: () {
                                  Get.back();
                                },
                                name: 'تایید',
                              ),
                            ),
                            Flexible(
                              child: BTN(
                                onTap: () {
                                  code.text = '';
                                  Get.back();
                                },
                                borderOnly: true,
                                color: darkMode.isTrue
                                    ? Colors.white
                                    : Colors.black,
                                name: 'انصراف',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    title: '',
                  ),
                  name: '  انتخاب رنگ  ',
                ),
              ),
          ],
        ),
        if (_page.type == 'part') Input(controller: code, name: 'code'),
        SizedBox(height: 10),
        BTN(
          onTap: () {
            if (name.text.isEmpty) {
              Alert.error('نام مقدار را وارد کنید');
              return;
            }
            if (_page.values
                .where(
                  (e) => e['name'].toLowerCase() == name.text.toLowerCase(),
                )
                .toList()
                .isNotEmpty) {
              Alert.error('این مقدار قبلا اضافه شده است');
            } else {
              _page.values.add(
                ProductPropertyValue(
                  name: name.text,
                  code: code.text,
                  id: _page.values.length + 1,
                ).toJson(),
              );
            }
            name.clear();
            code.clear();
            change.toggle();
          },
          borderOnly: true,
          name: 'افزودن مقدار',
        ),
      ],
    );
  }

  void _saveNewFeature() async {
    if (_page.nameCtl.text.isEmpty || _page.values.isEmpty) {
      Alert.error('نام و مقادیر ویژگی را وارد کنید.');
      return;
    }

    ProductPropertyDB p = ProductPropertyDB(
      uid: ID.uidNew(),
      name: _page.nameCtl.text,
      type: _page.type,
      value: _page.values,
      inserter: 0,
    );

    await SaveHelper.save(p);
    widget.controller.fetchProperties(); // Refresh list
    widget.controller.addExistingFeature(widget.product, p);
    // Alert.success('ویژگی جدید ساخته و اضافه شد.');
  }
}
