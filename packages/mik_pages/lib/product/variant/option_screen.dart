import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/models/models.dart';

import 'axes_controller.dart';

class ProductOptionScreen extends StatefulWidget {
  final ProductAxesController controller;
  final PimAttribute attribute;
  const ProductOptionScreen({
    super.key,
    required this.controller,
    required this.attribute,
  });
  @override
  State<ProductOptionScreen> createState() => _ProductOptionScreenState();
}

class _ProductOptionScreenController extends GetxController {
  final name = TextEditingController();
  Color? color;
}

class _ProductOptionScreenState extends State<ProductOptionScreen> {
  late final _page = _ProductOptionScreenController();

  ProductAxesController get c => widget.controller;

  @override
  void dispose() {
    _page.name.dispose();
    super.dispose();
  }

  void pickColor() {
    FocusScope.of(context).unfocus();
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
  ) => GetBuilder<_ProductOptionScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => PopScope(
        canPop: !c.saving.value,
        child: Main(
          header: Header.page(
            context,
            text: 'گزینهٔ جدید ${widget.attribute.name}',
            help: false,
          ),
          initState: () async => true,
          child: (_) => Obx(
            () => ListView(
              padding: const EdgeInsets.all(10),
              children: [
                MyDivider(text: 'افزودن گزینه به فهرست مشترک'),
                const Text(
                  'این گزینه به فهرست مشترک ویژگی اضافه می‌شود و برای محصولات دیگر هم قابل انتخاب خواهد بود.',
                ),
                Input(
                  key: const ValueKey('variant-option-name'),
                  controller: _page.name,
                  name: 'عنوان گزینه',
                  require: true,
                  maxLength: 200,
                  enabled: !c.locked,
                ),
                if (widget.attribute.kind == 'COLOR')
                  MiniBTN(
                    name: _page.color == null
                        ? 'انتخاب رنگ'
                        : 'تغییر رنگ انتخاب‌شده',
                    icon: IconsaxPlusLinear.edit,
                    noFlex: true,
                    onTap: c.locked ? null : pickColor,
                  ),
                if (_page.color != null)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(height: 32, color: _page.color),
                  ),
                if (c.error.value != null) Text(c.error.value!),
                if (c.conflict.value)
                  const Text(
                    'ویژگی در سرور تغییر کرده است؛ به فرم گزینه‌های محصول برگردید و نسخهٔ جدید را دریافت کنید.',
                  )
                else if (c.pending.value != null)
                  const Text(
                    'نتیجهٔ ثبت مشخص نیست؛ به فرم گزینه‌های محصول برگردید و همان درخواست را ادامه دهید.',
                  )
                else
                  BTN(
                    name: 'ثبت گزینهٔ جدید',
                    disabled: c.saving.value || !c.writable,
                    onTap: () async {
                      final hex = _page.color == null
                          ? null
                          : '#${(_page.color!.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
                      if (await c.addOption(
                            attribute: widget.attribute,
                            name: _page.name.text,
                            colorHex: hex,
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

Widget buildProductOptionRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductOptionScreen(
    controller: args.required<ProductAxesController>('controller'),
    attribute: args.required<PimAttribute>('attribute'),
  );
}
