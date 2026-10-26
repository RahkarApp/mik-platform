import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_data/utils/fx/pim.dart';

import 'axes_controller.dart';

class ProductAxesScreen extends StatefulWidget {
  final PimFX fx;
  final String productId;
  const ProductAxesScreen({
    super.key,
    required this.fx,
    required this.productId,
  });
  @override
  State<ProductAxesScreen> createState() => _ProductAxesScreenState();
}

class _ProductAxesScreenState extends State<ProductAxesScreen> {
  late final c = ProductAxesController(widget.fx, widget.productId);
  @override
  Widget build(BuildContext context) => Obx(
    () => PopScope(
      canPop: !c.saving.value,
      child: Main(
        header: Header.page(context, text: 'گزینه‌های تنوع محصول', help: false),
        initState: () async {
          await c.load();
          return true;
        },
        child: (_) => Obx(() {
          if (c.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.loadError.value != null) {
            return ErrorSection(c.loadError.value, act: c.load);
          }
          return ListView(
            padding: const EdgeInsets.all(10),
            children: [
              if (c.notice.value != null) Text(c.notice.value!),
              MyDivider(text: 'ویژگی‌ها و گزینه‌های محصول'),
              const Text(
                'ذخیرهٔ گزینه‌ها تنوعی نمی‌سازد. پس از ذخیره، در صفحهٔ تنوع‌ها ترکیب‌های موردنظر را پیش‌نمایش و ایجاد کنید.',
              ),
              if (c.canConvert)
                const Text(
                  'برای تبدیل محصول ساده، مشخص کنید موجودی و سوابق فعلی کالا مربوط به کدام گزینه از هر ویژگی است. شناسه کالا و ارجاع‌های قبلی حفظ می‌شوند.',
                ),
              if (c.simpleBase && !c.canConvert)
                const Text(
                  'برای تبدیل محصول ساده، مجوز ویرایش تنوع محصول لازم است.',
                ),
              if (c.hasActive && !c.canConvert)
                const Text(
                  'ویژگی‌های تنوع و گزینه‌های استفاده‌شده در تنوع فعال قابل حذف نیستند. می‌توانید گزینه‌های دیگری از همان ویژگی‌ها اضافه کنید.',
                ),
              if (c.attributes.isEmpty)
                const Text('ویژگی قابل استفاده برای تنوع ثبت نشده است.'),
              for (final attribute in c.attributes)
                ExpansionTile(
                  key: ValueKey('axis-${attribute.id}'),
                  initiallyExpanded: c.axes.containsKey(attribute.id),
                  title: Text(attribute.name),
                  children: [
                    if (c.product!.attributeValues.any(
                      (v) => v.attributeId == attribute.id,
                    ))
                      const Text(
                        'این ویژگی در مشخصات محصول استفاده شده و هم‌زمان نمی‌تواند ویژگی تنوع باشد.',
                      ),
                    if (c.canAddOption(attribute))
                      MiniBTN(
                        name: 'افزودن گزینهٔ جدید به ${attribute.name}',
                        icon: IconsaxPlusLinear.add,
                        noFlex: true,
                        onTap: () async {
                          c.error.value = null;
                          await Get.toNamed(
                            nav_routes.RoutesName.PRODUCT_OPTION,
                            arguments: {
                              'controller': c,
                              'attribute': attribute,
                            },
                            preventDuplicates: false,
                          );
                        },
                      ),
                    for (final id in {
                      ...attribute.values
                          .where((v) => v.active)
                          .map((v) => v.valueId),
                      ...?c.axes[attribute.id],
                    })
                      CheckboxListTile(
                        key: ValueKey('axis-option-${attribute.id}-$id'),
                        title: Text(
                          attribute.values
                                  .where((v) => v.valueId == id)
                                  .firstOrNull
                                  ?.name ??
                              id,
                        ),
                        subtitle: c.used(attribute.id, id)
                            ? const Text('در تنوع فعال استفاده شده')
                            : !attribute.values.any(
                                (v) => v.valueId == id && v.active,
                              )
                            ? const Text('گزینه در دسترس یا فعال نیست')
                            : null,
                        value: c.selected(attribute.id, id),
                        onChanged: c.canSelect(attribute, id)
                            ? (value) => c.select(attribute, id, value == true)
                            : null,
                      ),
                    if (c.canConvert && c.axes.containsKey(attribute.id))
                      Dropdown(
                        key: ValueKey('existing-stock-${attribute.id}'),
                        name: '${attribute.name} کالای فعلی',
                        itemValue: true,
                        disable: c.locked,
                        items_Value: [
                          for (final value in attribute.values.where(
                            (value) => c.selected(attribute.id, value.valueId),
                          ))
                            ItemValue(text: value.name, data: value.valueId),
                        ],
                        defaultValue: c.existingOptions[attribute.id] == null
                            ? null
                            : ItemValue(
                                text: '',
                                data: c.existingOptions[attribute.id],
                              ),
                        onChange: (value) {
                          c.existingOptions[attribute.id] =
                              value.data as String;
                        },
                      ),
                  ],
                ),
              if (c.error.value != null) Text(c.error.value!),
              if (c.pending.value != null)
                const Text(
                  'یک درخواست تعیین‌تکلیف‌نشده وجود دارد؛ تا روشن شدن نتیجه، گزینه‌ها قابل تغییر نیستند.',
                ),
              if (c.conflict.value)
                BTN(
                  name: 'دریافت نسخه جدید و جایگزینی انتخاب‌ها',
                  onTap: c.load,
                  disabled: c.saving.value,
                )
              else if (c.pending.value != null && !c.pendingHere)
                const Text(
                  'درخواست باز مربوط به عملیات دیگری است؛ آن را در صفحهٔ مربوط ادامه دهید.',
                )
              else if (c.pendingOption)
                BTN(
                  name: 'تلاش مجدد همان درخواست گزینهٔ جدید',
                  disabled: c.saving.value,
                  onTap: () => c.addOption(),
                )
              else
                BTN(
                  name: c.pendingAxes
                      ? 'تلاش مجدد همان درخواست گزینه‌ها'
                      : 'ذخیره گزینه‌های محصول',
                  disabled: c.saving.value || !c.writable,
                  onTap: () async {
                    final converting = c.canConvert;
                    final saved = await c.save();
                    if (!mounted) return;
                    if (saved) {
                      Alert.success(
                        converting
                            ? 'محصول با حفظ موجودی و سوابق به محصول دارای تنوع تبدیل شد.'
                            : 'گزینه‌های تنوع محصول ذخیره شدند.',
                      );
                      Get.back(result: true);
                    } else if (c.error.value != null) {
                      Alert.error(c.error.value!, context: this.context);
                    }
                  },
                ),
            ],
          );
        }),
      ),
    ),
  );
}

Widget buildProductAxesRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductAxesScreen(
    fx: args.required<PimFX>('fx'),
    productId: args.required<String>('productId'),
  );
}
