import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/CatInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/unitInput.dart';
import 'package:mik_components/elements/input/barcodeInput.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/pim_group.dart';

import 'controller.dart';
import '../components/attribute_fields.dart';
import '../brand/selector.dart';

class PimProductAddScreen extends StatefulWidget {
  final BusinessContext context;
  final PimProductAddController? controller;
  const PimProductAddScreen({
    super.key,
    required this.context,
    this.controller,
  });
  static Widget fromArguments(Object? arguments, {required String appId}) {
    final context = BusinessContext.forApp(appId);
    if (arguments is! Map ||
        arguments['appId'] != appId ||
        context == null ||
        arguments['businessId'] != context.session.business.businessId) {
      return const Scaffold(
        body: Center(child: Text('کسب‌وکار مسیر محصول معتبر نیست.')),
      );
    }
    return PimProductAddScreen(context: context);
  }

  @override
  State<PimProductAddScreen> createState() => _PimProductAddScreenState();
}

class _PimProductAddScreenController extends GetxController {
  final name = TextEditingController(),
      category = TextEditingController(),
      price = TextEditingController(),
      barcode = TextEditingController(),
      description = TextEditingController(),
      unitCtl = TextEditingController();
}

class _PimProductAddScreenState extends State<PimProductAddScreen> {
  late final _page = _PimProductAddScreenController();

  late final c =
      widget.controller ??
      PimProductAddController(
        PimGroupFX.forProducts(PimFX.forContext(widget.context)),
      );

  @override
  void dispose() {
    for (final input in [
      _page.name,
      _page.category,
      _page.price,
      _page.barcode,
      _page.description,
      _page.unitCtl,
    ]) {
      input.dispose();
    }
    c.onClose();
    super.dispose();
  }

  Future<void> save() async {
    final success = await c.save(
      name: _page.name.text,
      price: _page.price.text
          .replaceAll('تومان', '')
          .replaceAll(',', '')
          .trim(),
      barcode: _page.barcode.text,
      description: _page.description.text,
    );
    if (mounted && success) Get.back(result: true);
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_PimProductAddScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => PopScope(
        canPop: !c.saving.value,
        child: Main(
          header: Header.page(context, text: 'افزودن محصول', help: false),
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
            final categoryItems = c.categories
                .where((v) => c.selectedCategories.contains(v.id))
                .map((v) => ItemValue(text: v.name, data: v.id))
                .toList();
            if (c.locked.value) {
              final ids = c.recovery.steps.map((s) => s.draftId).toSet();
              final names = c.recovery.drafts
                  .where((d) => ids.contains(d.id))
                  .map((d) => d.name)
                  .join('، ');
              return ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  const Text(
                    'ثبت قبلی هنوز کامل نشده است. برای جلوگیری از ساخت محصول تکراری، همان ثبت را ادامه دهید.',
                  ),
                  if (names.isNotEmpty) Text('محصول‌های در حال ثبت: $names'),
                  if (c.error.value != null) Text(c.error.value!),
                  if (c.recovery.pending)
                    BTN(
                      onTap: save,
                      name: 'ادامهٔ ثبت قبلی',
                      disabled: c.saving.value,
                    )
                  else
                    const Text(
                      'درخواست باز مربوط به عملیات دیگری است؛ ابتدا آن را در صفحهٔ مربوط تعیین تکلیف کنید.',
                    ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                AbsorbPointer(
                  absorbing: c.saving.value,
                  child: Column(
                    children: [
                      MyDivider(text: 'اطلاعات محصول:'),
                      Input(
                        key: const ValueKey('product-name'),
                        controller: _page.name,
                        name: 'نام',
                        require: true,
                        maxLength: 200,
                      ),
                      ProductBrandSelector(
                        brands: c.brands,
                        value: c.brandId.value,
                        enabled: c.canBrands,
                        error: c.brandError.value,
                        onChanged: (v) => c.brandId.value = v,
                      ),
                      CatInput(
                        controller: _page.category,
                        type: 'product',
                        name: 'دسته‌بندی',
                        require: true,
                        categories: c.categories.toList(),
                        selected: c.selectedCategories.toList(),
                        onChanged: (List values) {
                          final ids = values
                              .map((v) => v['uid'] as String)
                              .toSet();
                          for (final id in [...c.selectedCategories]) {
                            if (!ids.contains(id)) c.category(id, false);
                          }
                          for (final id in ids) {
                            c.category(id, true);
                          }
                          _page.category.text = c.categories
                              .where((v) => ids.contains(v.id))
                              .map((v) => v.name)
                              .join('، ');
                        },
                      ),
                      if (c.categories.isEmpty)
                        const Text(
                          'ابتدا یک دسته‌بندی فعال برای کسب‌وکار ثبت کنید.',
                        ),
                      Dropdown(
                        name: 'دسته‌بندی اصلی',
                        itemValue: true,
                        items_Value: categoryItems,
                        defaultValue: categoryItems
                            .where((v) => v.data == c.primaryCategory.value)
                            .firstOrNull,
                        onChange: (value) => c.primaryCategory.value =
                            (value as ItemValue).data as String,
                      ),
                      UnitInput(
                        controller: _page.unitCtl,
                        name: 'واحد کالا',
                        units: c.units.toList(),
                        selected: {
                          'id': c.unitId.value,
                          'name': _page.unitCtl.text,
                        },
                        onChanged: (value) {
                          c.unitId.value = value['id'] as int?;
                          _page.unitCtl.text = value['name'] as String;
                        },
                      ),
                      if (c.fx.has('pim.variant.update'))
                        BarcodeInput(
                          key: const ValueKey('product-barcode'),
                          controller: _page.barcode,
                          name: 'بارکد',
                          onChanged: (value) =>
                              _page.barcode.text = value as String,
                        ),
                      MyDivider(text: 'قیمت‌گذاری:'),
                      if (c.canPrice)
                        PriceInput(
                          key: const ValueKey('product-price'),
                          controller: _page.price,
                          currency: 'تومان',
                          name: 'قیمت فروش پیش‌فرض (تومان)',
                          keyboardType: TextInputType.number,
                          onChanged: (_) {
                            _page.update();
                          },
                        )
                      else
                        const Text(
                          'اجازهٔ ثبت قیمت پیش‌فرض را ندارید؛ محصول پیش‌نویس ذخیره می‌شود.',
                        ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          _page.price.text.trim().isEmpty || !c.canActivate
                              ? 'محصول به‌صورت پیش‌نویس ذخیره می‌شود؛ در فیلتر «همه» قابل مشاهده است.'
                              : 'پس از ثبت قیمت پیش‌فرض و تنوع‌ها، محصول فعال می‌شود.',
                        ),
                      ),
                      if (c.axes.isNotEmpty)
                        const Text(
                          'بارکد اولیه فقط برای محصول بدون ویژگی تنوع است؛ برای ثبت تنوع‌ها این فیلد را خالی بگذارید.',
                        ),
                      MyDivider(text: 'تنوع‌ها:'),
                      if (c.canAxes) ...[
                        for (final attribute in c.attributes)
                          ExpansionTile(
                            title: Text(attribute.name),
                            children: [
                              for (final value in attribute.values.where(
                                (v) => v.active,
                              ))
                                CheckboxListTile(
                                  title: Text(value.name),
                                  value:
                                      c.axes[attribute.id]?.contains(
                                        value.valueId,
                                      ) ==
                                      true,
                                  onChanged:
                                      c.attributeDraft.any(
                                        (v) => v['attributeId'] == attribute.id,
                                      )
                                      ? null
                                      : (checked) => c.option(
                                          attribute.id,
                                          value.valueId,
                                          checked == true,
                                        ),
                                ),
                            ],
                          ),
                        Text(
                          c.axes.isEmpty
                              ? 'بدون انتخاب ویژگی، تنوع پایه ساخته می‌شود.'
                              : 'تعداد ترکیب تنوع‌ها: ${c.combinations}',
                        ),
                      ] else
                        const Text(
                          'بدون انتخاب ویژگی، تنوع پایه توسط سرور ساخته می‌شود.',
                        ),
                      if (c.attributeError.value != null)
                        ErrorSection(
                          'ویژگی‌ها در دسترس نیستند: ${c.attributeError.value}',
                          act: c.load,
                        ),
                      if (c.canAttributes)
                        ProductDescriptiveFields(
                          attributes: c.descriptiveAttributes,
                          units: c.units,
                          axisIds: c.axes.keys.toSet(),
                          values: c.attributeDraft,
                        ),
                      if (c.canDescribe)
                        Input(
                          controller: _page.description,
                          name: 'توضیحات',
                          maxLines: 4,
                          maxLength: 10000,
                        ),
                    ],
                  ),
                ),
                if (c.error.value != null)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(c.error.value!),
                  ),
                BTN(
                  onTap: save,
                  name: c.saving.value ? 'در حال ثبت…' : 'ثبت محصول',
                  disabled: c.saving.value,
                ),
              ],
            );
          }),
        ),
      ),
    ),
  );
}
