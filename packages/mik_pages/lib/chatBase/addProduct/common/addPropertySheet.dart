// Widget برای تعریف ویژگی جدید
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/variable.dart';

class PropertySheet extends StatefulWidget {
  final Function(ProductPropertyDB) onSave;
  final ProductPropertyDB? property;
  const PropertySheet({super.key, this.property, required this.onSave});

  @override
  // ignore: library_private_types_in_public_api
  _PropertySheetState createState() => _PropertySheetState();
}

class _PropertySheetController extends GetxController {
  final TextEditingController nameCtl = TextEditingController();
  final TextEditingController valueNameCtl = TextEditingController();
  final RxString proType = 'نوشتاری'.obs;
  RxBool change = false.obs;
  RxString code = ''.obs;
  String type = 'other';
  RxList values = RxList();
}

class _PropertySheetState extends State<PropertySheet> {
  late final _page = _PropertySheetController();

  @override
  void initState() {
    super.initState();
    if (widget.property != null) {
      _page.values = RxList.from(widget.property!.value);
      _page.nameCtl.text = widget.property!.name;
      _page.type = widget.property!.type ?? 'other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_PropertySheetController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.property == null)
                  Obx(
                    () => Dropdown(
                      name: 'نوع ویژگی',
                      items_String: ['نوشتاری', 'رنگ', 'سایز', 'پارت‌نامبر'],
                      defaultValue: _page.proType.value,
                      require: true,
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
                  ),
                if (widget.property == null)
                  Input(
                    controller: _page.nameCtl,
                    require: true,
                    name: 'نام ویژگی',
                  ),
                if (widget.property == null) SizedBox(height: 15),
                if (widget.property == null) Divider(),

                // مقادیر موجود
                if (_page.values.isNotEmpty) ...[
                  Text(
                    'مقادیر:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Obx(
                    () => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _page.values.map((value) {
                        final v = Map<String, dynamic>.from(value as Map);
                        return Chip(
                          label: Text(v['name'].toString()),
                          onDeleted: () => _page.values.removeWhere(
                            (item) => (item as Map)['id'] == v['id'],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Divider(height: 32),
                ],

                // افزودن مقدار
                _buildAddValueForm(context),

                SizedBox(height: 24),
                BTN(
                  onTap: () async {
                    if (_page.nameCtl.text.isEmpty) {
                      Alert.warning('لطفاً نام ویژگی را وارد کنید.');
                      return;
                    }
                    if (_page.values.isEmpty) {
                      Alert.warning('لطفاً حداقل یک مقدار اضافه کنید.');
                      return;
                    }
                    final uid = widget.property == null
                        ? ID.uidNew()
                        : widget.property!.uid;
                    final newProperty = ProductPropertyDB(
                      uid: uid,
                      name: _page.nameCtl.text,
                      value: _page.values.toList(),
                      inserter: 0,
                    );
                    newProperty.type = _page.type;

                    await productProperty.put(uid, newProperty);
                    widget.onSave(newProperty);
                  },
                  name: widget.property == null
                      ? 'ذخیره ویژگی'
                      : 'تایید تغییرات',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddValueForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('افزودن مقدار:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Row(
          children: [
            Flexible(
              child: Input(
                controller: _page.valueNameCtl,
                name: 'نام مقدار',
                require: true,
              ),
            ),
            if (_page.type == 'color')
              Obx(
                () => BTN(
                  color: Color(int.tryParse(_page.code.value) ?? 4278190080),
                  borderOnly: (int.tryParse(_page.code.value) ?? 0) == 0,
                  showBorder: true,
                  onTap: () => {
                    FocusScope.of(context).unfocus(),
                    _showColorPicker(context),
                  },
                  name: '  انتخاب رنگ  ',
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        BTN(
          onTap: () {
            if (_page.valueNameCtl.text.isEmpty) {
              Alert.warning('لطفاً نام مقدار را وارد کنید.');
              return;
            }
            if (_page.type == 'color' && _page.code.value == '') {
              Alert.warning('لطفاً رنگ را انتخاب کنید.');
              return;
            }

            final newId = _page.values.isEmpty
                ? 1
                : (_page.values
                          .map((v) => (v as Map)['id'] as int)
                          .reduce((a, b) => a > b ? a : b) +
                      1);
            _page.values.add({
              'id': newId,
              'name': _page.valueNameCtl.text,
              if (_page.type == 'color' && _page.code.value.isNotEmpty)
                'code': _page.code.value,
            });
            _page.valueNameCtl.clear();
            _page.code.value = '';
            Alert.success('مقدار جدید افزوده شد.');
          },
          name: 'افزودن مقدار',
          borderOnly: true,
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context) {
    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          ColorPicker(
            color: Color(int.tryParse(_page.code.value) ?? 4280391411),
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
              _page.change.toggle();
              _page.code.value = value.toARGB32().toString();
            },
          ),
          Row(
            children: [
              Flexible(
                flex: 2,
                child: BTN(onTap: () => Get.back(), name: 'تایید'),
              ),
              Flexible(
                child: BTN(
                  onTap: () {
                    _page.code.value = '';
                    Get.back();
                  },
                  borderOnly: true,
                  color: darkMode.isTrue ? Colors.white : Colors.black,
                  name: 'انصراف',
                ),
              ),
            ],
          ),
        ],
      ),
      title: '',
    );
  }
}
