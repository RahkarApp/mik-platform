import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/CatInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/unitInput.dart';
import 'package:mik_data/utils/fx/pim.dart';

import 'controller.dart';
import '../components/attribute_fields.dart';
import '../brand/selector.dart';

class ProductEditScreen extends StatefulWidget {
  final PimFX fx;
  final String productId;
  final String? variantId;
  const ProductEditScreen({
    super.key,
    required this.fx,
    required this.productId,
    this.variantId,
  });
  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  late final c = ProductEditController(
    widget.fx,
    productId: widget.productId,
    variantId: widget.variantId,
  );
  final name = TextEditingController(),
      slug = TextEditingController(),
      model = TextEditingController(),
      description = TextEditingController(),
      short = TextEditingController(),
      sku = TextEditingController(),
      barcodes = TextEditingController(),
      category = TextEditingController(),
      unitCtl = TextEditingController();
  final selected = <String>[].obs;
  final primary = RxnString();
  final unit = RxnInt();
  final brand = RxnString();
  Future<void> load() async {
    await c.load();
    if (!mounted || c.item == null) return;
    final values = c.values;
    name.text = values['name'] as String? ?? '';
    slug.text = values['slug'] as String? ?? '';
    model.text = values['model'] as String? ?? '';
    brand.value = values['brandId'] as String?;
    description.text = values['description'] as String? ?? '';
    short.text = values['shortDescription'] as String? ?? '';
    sku.text = values['sku'] as String? ?? '';
    barcodes.text = (values['barcodes'] as List? ?? []).join('\n');
    selected.assignAll(List<String>.from(values['categoryIds'] as List? ?? []));
    primary.value = values['primaryCategoryId'] as String?;
    unit.value = values['unitId'] as int?;
    unitCtl.text =
        c.units.where((u) => u.id == unit.value).firstOrNull?.name ?? '';
    category.text = c.categories
        .where((v) => selected.contains(v.id))
        .map((v) => v.name)
        .join('، ');
  }

  Future<void> save() async {
    final fields = c.isVariant
        ? <String, dynamic>{
            'sku': sku.text,
            'barcodes': barcodes.text
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .toList(),
            'description': description.text,
          }
        : <String, dynamic>{
            'name': name.text,
            'slug': slug.text,
            'model': model.text,
            if (c.canBrands && !c.frozen.value) 'brandId': brand.value,
            if (c.canCategories && !c.frozen.value)
              'categoryIds': selected.toList(),
            if (c.canCategories && !c.frozen.value)
              'primaryCategoryId': primary.value,
            if (!c.frozen.value) 'unitId': unit.value,
            if (c.canAttributes && !c.frozen.value)
              'attributeValues': c.attributeDraft.toList(),
            if (c.canDescribe) ...{
              'description': description.text,
              'shortDescription': short.text,
            },
          };
    if (await c.save(fields) && mounted) Get.back(result: true);
  }

  @override
  void dispose() {
    for (final ctl in [
      name,
      slug,
      model,
      description,
      short,
      sku,
      barcodes,
      category,
      unitCtl,
    ]) {
      ctl.dispose();
    }
    c.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(
    () => PopScope(
      canPop: !c.saving.value,
      child: Main(
        header: Header.page(
          context,
          text: c.isVariant ? 'ویرایش تنوع' : 'ویرایش محصول',
          help: false,
        ),
        initState: () async {
          await load();
          return true;
        },
        child: (_) => Obx(() {
          if (c.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.loadError.value != null) {
            return ErrorSection(c.loadError.value, act: load);
          }
          final categoryItems = c.categories
              .where((v) => selected.contains(v.id))
              .map((v) => ItemValue(text: v.name, data: v.id))
              .toList();
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              if (c.frozen.value)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'نتیجهٔ درخواست قبلی قطعی نشده است؛ تلاش مجدد همان تغییرات قبلی را ارسال می‌کند.',
                  ),
                ),
              AbsorbPointer(
                absorbing: c.frozen.value || c.saving.value || c.conflict.value,
                child: Column(
                  children: [
                    if (c.isVariant) ...[
                      Input(
                        key: const ValueKey('edit-sku'),
                        name: 'SKU',
                        controller: sku,
                        maxLength: 100,
                        maxLines: 1,
                      ),
                      Input(
                        key: const ValueKey('edit-barcodes'),
                        name: 'بارکدها (هر بارکد در یک خط)',
                        controller: barcodes,
                        maxLength: 2020,
                        maxLines: 5,
                      ),
                    ] else ...[
                      Input(
                        key: const ValueKey('edit-name'),
                        name: 'نام',
                        controller: name,
                        maxLength: 200,
                        maxLines: 1,
                      ),
                      Input(
                        key: const ValueKey('edit-slug'),
                        name: 'نامک',
                        controller: slug,
                        maxLength: 200,
                        maxLines: 1,
                      ),
                      Input(
                        key: const ValueKey('edit-model'),
                        name: 'مدل',
                        controller: model,
                        maxLength: 200,
                        maxLines: 1,
                      ),
                      ProductBrandSelector(
                        brands: c.brands,
                        value: brand.value,
                        enabled: c.canBrands && !c.frozen.value,
                        error: c.brandError.value,
                        onChanged: (v) => brand.value = v,
                      ),
                      if (c.canCategories && !c.frozen.value) ...[
                        CatInput(
                          controller: category,
                          type: 'product',
                          name: 'دسته‌بندی',
                          categories: c.categories.toList(),
                          selected: selected.toList(),
                          onChanged: (List values) {
                            selected.assignAll(
                              values.map((v) => v['uid'] as String),
                            );
                            if (!selected.contains(primary.value)) {
                              primary.value = selected.isEmpty
                                  ? null
                                  : selected.first;
                            }
                            category.text = values
                                .map((v) => v['name'])
                                .join('، ');
                          },
                        ),
                        Dropdown(
                          name: 'دسته‌بندی اصلی',
                          itemValue: true,
                          items_Value: categoryItems,
                          defaultValue: categoryItems
                              .where((v) => v.data == primary.value)
                              .firstOrNull,
                          onChange: (value) => primary.value =
                              (value as ItemValue).data as String,
                        ),
                      ],
                      if (!c.frozen.value)
                        UnitInput(
                          controller: unitCtl,
                          name: 'واحد کالا',
                          units: c.units.toList(),
                          selected: {'id': unit.value, 'name': unitCtl.text},
                          onChanged: (value) {
                            unit.value = value['id'] as int?;
                            unitCtl.text = value['name'] as String;
                          },
                        ),
                      if (c.attributeError.value != null)
                        Text(
                          'ویژگی‌های توصیفی در دسترس نیستند: ${c.attributeError.value}',
                        ),
                      if (c.canAttributes)
                        ProductDescriptiveFields(
                          key: ValueKey(c.item),
                          attributes: c.attributes,
                          units: c.units,
                          axisIds: c.axisIds,
                          values: c.attributeDraft,
                          frozen: c.frozen.value,
                        ),
                      if (c.canDescribe)
                        Input(
                          key: const ValueKey('edit-short'),
                          name: 'توضیح کوتاه',
                          controller: short,
                          maxLength: 2000,
                          maxLines: 3,
                        ),
                    ],
                    if (c.canDescribe)
                      Input(
                        key: const ValueKey('edit-description'),
                        name: 'توضیحات',
                        controller: description,
                        maxLength: 10000,
                        maxLines: 4,
                      ),
                  ],
                ),
              ),
              if (c.error.value != null)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(c.error.value!),
                ),
              if (c.conflict.value)
                BTN(onTap: load, name: 'دریافت نسخه جدید و جایگزینی فرم')
              else
                BTN(
                  onTap: save,
                  name: c.frozen.value
                      ? 'تلاش مجدد همان ویرایش'
                      : 'ذخیره تغییرات',
                  disabled: c.saving.value,
                ),
            ],
          );
        }),
      ),
    ),
  );
}

Widget buildProductEditRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductEditScreen(
    fx: args.required<PimFX>('fx'),
    productId: args.required<String>('productId'),
    variantId: args.optional<String>('variantId'),
  );
}
