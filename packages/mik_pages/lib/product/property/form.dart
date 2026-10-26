import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/unitInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:uuid/uuid.dart';

import '../screen/tabs/controllers/property.dart';

class ProductAttributeForm extends StatefulWidget {
  final ProductPropertyTabDashboardController controller;
  final PimAttribute? item;
  const ProductAttributeForm({super.key, required this.controller, this.item});
  @override
  State<ProductAttributeForm> createState() => _ProductAttributeFormState();
}

class _ProductAttributeFormController extends GetxController {
  final name = TextEditingController(), unit = TextEditingController();
  final variant = 'مشخصات محصول'.obs;
  PimAttribute? item;
  String kind = 'GENERAL', dataType = 'TEXT';
  int? unitId;
  List<PimOption> values = [];
  String? localError;
}

class _ProductAttributeFormState extends State<ProductAttributeForm> {
  late final _page = _ProductAttributeFormController();

  ProductPropertyTabDashboardController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    fill(widget.item);
  }

  void fill(PimAttribute? value) {
    _page.item = value;
    _page.name.text = value?.name ?? '';
    _page.kind = value?.kind ?? 'GENERAL';
    _page.dataType = value?.dataType ?? 'TEXT';
    _page.variant.value = value?.usableForVariant == true
        ? 'قابل استفاده در تنوع'
        : 'مشخصات محصول';
    _page.unitId = value?.unitId;
    _page.unit.text = _page.unitId == null
        ? ''
        : c.units.where((v) => v.id == _page.unitId).firstOrNull?.name ??
              '${_page.unitId}';
    _page.values = List.of(value?.values ?? <PimOption>[]);
    _page.localError = null;
  }

  Future<void> reload() async {
    await c.init();
    if (!mounted || c.error.value != null) return;
    final current = c.pro.where((v) => v.id == _page.item?.id).firstOrNull;
    if (current == null) {
      {
        _page.localError = 'ویژگی دیگر در دسترس نیست.';
        _page.update();
      }
      return;
    }
    {
      fill(current);
      _page.update();
    }
  }

  void option([PimOption? value]) {
    MyBottomSheet.view(
      context,
      title: value == null ? 'گزینهٔ جدید' : 'ویرایش گزینه',
      child: (_) => AttributeOptionEditor(
        option: value,
        isColor: _page.kind == 'COLOR',
        onSave: (next) {
          if (!mounted) return;
          {
            if (value == null) {
              _page.values.add(next);
            } else {
              _page.values[_page.values.indexWhere(
                    (v) => v.valueId == value.valueId,
                  )] =
                  next;
            }
            _page.update();
          }
        },
      ),
    );
  }

  void remove(PimOption value) {
    Confirm.con(
      context,
      type: ConfirmType.DELETE,
      subtext:
          'گزینهٔ «${value.name}» از این فرم حذف شود؟ هنگام ذخیره، سرور استفاده‌شدن آن در محصولات را بررسی می‌کند.',
      confirmText: 'حذف گزینه',
      onTapConfirm: () {
        Get.back();
        {
          _page.values.removeWhere((v) => v.valueId == value.valueId);
          _page.update();
        }
      },
    );
  }

  @override
  void dispose() {
    _page.name.dispose();
    _page.unit.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_ProductAttributeFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => PopScope(
        canPop: !c.saving.value,
        child: Main(
          header: Header.page(
            context,
            text: _page.item == null ? 'ویژگی جدید' : 'ویرایش ویژگی',
            help: false,
          ),
          initState: () async {
            try {
              await c.loadUnits();
              if (mounted) {
                {
                  _page.unit.text = _page.unitId == null
                      ? ''
                      : c.units
                                .where((v) => v.id == _page.unitId)
                                .firstOrNull
                                ?.name ??
                            '${_page.unitId}';
                  _page.update();
                }
              }
            } catch (failure) {
              if (mounted) {
                _page.localError = c.message(failure);
                _page.update();
              }
            }
            return true;
          },
          child: (_) => Obx(
            () => ListView(
              padding: const EdgeInsets.all(10),
              children: [
                AbsorbPointer(
                  absorbing: c.locked,
                  child: Column(
                    children: [
                      MyDivider(text: 'تعریف ویژگی'),
                      Input(
                        key: const ValueKey('attribute-name'),
                        controller: _page.name,
                        name: 'عنوان ویژگی',
                        require: true,
                        maxLength: 200,
                      ),
                      Dropdown(
                        name: 'نوع ویژگی',
                        items_String: ProductPropertyTabDashboardController
                            .kinds
                            .values
                            .toList(),
                        defaultValue: ProductPropertyTabDashboardController
                            .kinds[_page.kind],
                        onChange: (value) {
                          _page.kind = ProductPropertyTabDashboardController
                              .kinds
                              .entries
                              .firstWhere((v) => v.value == value)
                              .key;
                          if (['COLOR', 'SIZE'].contains(_page.kind)) {
                            _page.dataType = 'SELECT';
                          }
                          _page.update();
                        },
                      ),
                      Dropdown(
                        name: 'نوع داده',
                        disable:
                            ['COLOR', 'SIZE'].contains(_page.kind) ||
                            _page.variant.value == 'قابل استفاده در تنوع',
                        items_String: ProductPropertyTabDashboardController
                            .types
                            .values
                            .toList(),
                        defaultValue: ProductPropertyTabDashboardController
                            .types[_page.dataType],
                        onChange: (value) {
                          _page.dataType = ProductPropertyTabDashboardController
                              .types
                              .entries
                              .firstWhere((v) => v.value == value)
                              .key;
                          _page.update();
                        },
                      ),
                      MyTab(
                        tab: const ['مشخصات محصول', 'قابل استفاده در تنوع'],
                        value: _page.variant,
                        callback: (value) {
                          _page.variant.value = value;
                          if (value == 'قابل استفاده در تنوع') {
                            _page.dataType = 'SELECT';
                          }
                          _page.update();
                        },
                      ),
                      UnitInput(
                        controller: _page.unit,
                        name: 'واحد (اختیاری)',
                        selected: _page.unitId,
                        units: c.units,
                        onChanged: (value) {
                          _page.unitId = value['id'] as int?;
                          _page.unit.text = value['name'] as String;
                          _page.update();
                        },
                      ),
                      MyDivider(text: 'گزینه‌ها'),
                      if (!['SELECT', 'MULTI_SELECT'].contains(_page.dataType))
                        const Text(
                          'ویژگی متنی، عددی و بله/خیر گزینه ندارد؛ گزینه‌های قبلی خودکار حذف نمی‌شوند.',
                        ),
                      for (final value in _page.values)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${value.name}${value.active ? '' : ' (غیرفعال)'}',
                            ),
                            if (value.code != null) Text('کد: ${value.code}'),
                            Row(
                              children: [
                                MiniBTN(
                                  name: 'ویرایش گزینه',
                                  icon: IconsaxPlusLinear.edit,
                                  onTap: () => option(value),
                                ),
                                MiniBTN(
                                  name: value.active ? 'غیرفعال' : 'فعال',
                                  icon: IconsaxPlusLinear.refresh,
                                  onTap: () {
                                    _page.values[_page.values.indexOf(
                                      value,
                                    )] = PimOption(
                                      valueId: value.valueId,
                                      name: value.name,
                                      code: value.code,
                                      colorHex: value.colorHex,
                                      active: !value.active,
                                    );
                                    _page.update();
                                  },
                                ),
                                MiniBTN(
                                  name: 'حذف',
                                  icon: IconsaxPlusLinear.trash,
                                  onTap: () => remove(value),
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (['SELECT', 'MULTI_SELECT'].contains(_page.dataType) &&
                          _page.values.length < 200)
                        MiniBTN(
                          name: 'افزودن گزینه',
                          icon: IconsaxPlusLinear.add,
                          noFlex: true,
                          onTap: () => option(),
                        ),
                    ],
                  ),
                ),
                if (_page.localError != null) Text(_page.localError!),
                if (c.commandError.value != null) Text(c.commandError.value!),
                if (c.error.value != null) Text(c.error.value!),
                if (c.conflict.value)
                  BTN(name: 'دریافت نسخه جدید و جایگزینی فرم', onTap: reload)
                else if (c.pending.value != null)
                  const Text(
                    'برای ادامهٔ همان درخواست قبلی به تب ویژگی‌ها برگردید.',
                  )
                else
                  BTN(
                    name: 'ذخیره ویژگی',
                    disabled:
                        c.locked ||
                        _page.item != null && !c.canEdit(_page.item!),
                    onTap: () async {
                      if (await c.save(
                            item: _page.item,
                            name: _page.name.text,
                            kind: _page.kind,
                            dataType: _page.dataType,
                            usableForVariant:
                                _page.variant.value == 'قابل استفاده در تنوع',
                            values: _page.values,
                            unitId: _page.unitId,
                          ) &&
                          mounted) {
                        Get.back(result: true);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AttributeOptionEditor extends StatefulWidget {
  final PimOption? option;
  final bool isColor;
  final ValueChanged<PimOption> onSave;
  const AttributeOptionEditor({
    super.key,
    this.option,
    required this.isColor,
    required this.onSave,
  });
  @override
  State<AttributeOptionEditor> createState() => _AttributeOptionEditorState();
}

class _AttributeOptionEditorController extends GetxController {
  final name = TextEditingController(), code = TextEditingController();
  Color? color;
  String? error;
}

class _AttributeOptionEditorState extends State<AttributeOptionEditor> {
  late final _page = _AttributeOptionEditorController();

  @override
  void initState() {
    super.initState();
    _page.name.text = widget.option?.name ?? '';
    _page.code.text = widget.option?.code ?? '';
    final hex = widget.option?.colorHex;
    if (hex != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
      _page.color = Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }
  }

  @override
  void dispose() {
    _page.name.dispose();
    _page.code.dispose();
    super.dispose();
  }

  void pick() {
    var chosen = _page.color ?? Colors.black;
    MyBottomSheet.view(
      context,
      title: 'انتخاب رنگ',
      child: (_) => Column(
        children: [
          ColorPicker(
            color: chosen,
            pickersEnabled: const {
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
            colorCodePrefixStyle: const TextStyle(fontSize: 0),
            onColorChanged: (value) => chosen = value,
          ),
          BTN(
            name: 'تأیید رنگ',
            onTap: () {
              {
                _page.color = chosen;
                _page.update();
              }
              Get.back();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_AttributeOptionEditorController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            key: const ValueKey('attribute-option-name'),
            controller: _page.name,
            name: 'نام گزینه',
            require: true,
            maxLength: 200,
          ),
          Input(
            controller: _page.code,
            name: 'کد گزینه (اختیاری)',
            maxLength: 100,
          ),
          if (widget.isColor)
            MiniBTN(
              name: _page.color == null ? 'انتخاب رنگ' : 'تغییر رنگ',
              icon: IconsaxPlusLinear.edit,
              noFlex: true,
              onTap: pick,
            ),
          if (_page.color != null)
            Container(
              height: 32,
              margin: const EdgeInsets.all(10),
              color: _page.color,
            ),
          if (_page.error != null) Text(_page.error!),
          BTN(
            name: 'ثبت گزینه در فرم',
            onTap: () {
              if (_page.name.text.trim().isEmpty ||
                  widget.isColor && _page.color == null) {
                {
                  _page.error = 'نام گزینه و رنگ لازم را انتخاب کنید.';
                  _page.update();
                }
                return;
              }
              widget.onSave(
                PimOption(
                  valueId: widget.option?.valueId ?? const Uuid().v4(),
                  name: _page.name.text.trim(),
                  code: _page.code.text.trim().isEmpty
                      ? null
                      : _page.code.text.trim(),
                  colorHex: _page.color == null
                      ? widget.option?.colorHex
                      : '#${(_page.color!.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                  active: widget.option?.active ?? true,
                ),
              );
              Get.back();
            },
          ),
        ],
      ),
    ),
  );
}

Widget buildProductAttributeFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductAttributeForm(
    controller: args.required<ProductPropertyTabDashboardController>(
      'controller',
    ),
    item: args.optional<PimAttribute>('item'),
  );
}
