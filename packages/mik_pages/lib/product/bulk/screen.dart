import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/CatInput.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/input/unitInput.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/pim_group.dart';

import '../brand/selector.dart';
import 'controller.dart';

class ProductBulkScreen extends StatefulWidget {
  final BusinessContext context;
  final ProductBulkController? controller;
  final bool fromChat;
  const ProductBulkScreen({
    super.key,
    required this.context,
    this.controller,
    this.fromChat = false,
  });
  @override
  State<ProductBulkScreen> createState() => _ProductBulkScreenState();
}

class _ProductBulkScreenState extends State<ProductBulkScreen> {
  late final c =
      widget.controller ??
      ProductBulkController(
        PimGroupFX.forProducts(PimFX.forContext(widget.context)),
      );
  @override
  void dispose() {
    if (widget.controller == null) c.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(
    () => PopScope(
      canPop: !c.saving.value,
      child: Main(
        header: Header.page(context, text: 'افزودن گروهی محصولات', help: false),
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
              if (!c.locked)
                const Text(
                  'با ثبت نهایی، قیمت فروش هر محصول ثبت و محصول فعال می‌شود. قیمت همه محصولات را وارد کنید.',
                ),
              if (c.locked && !c.done.value)
                const Text(
                  'ثبت قبلی کامل نشده است. برای جلوگیری از ثبت تکراری، ادامه همان درخواست‌های قبلی انجام می‌شود و ردیف‌ها فعلاً قابل ویرایش نیستند.',
                ),
              if (!c.form.canActivate && !c.locked)
                const Text('برای ثبت نهایی، مجوز فعال‌سازی محصول لازم است.'),
              if (c.form.brandError.value != null)
                Text('دریافت برندها ناموفق بود: ${c.form.brandError.value}'),
              for (final entry in c.rows.indexed)
                if (c.locked)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyDivider(text: '${entry.$1 + 1}. ${entry.$2.name}'),
                      Text(c.progress(entry.$2)),
                      if (entry.$2.error.value != null)
                        Text(entry.$2.error.value!),
                    ],
                  )
                else
                  _BulkRowEditor(
                    key: ValueKey(entry.$2.id),
                    c: c,
                    row: entry.$2,
                    index: entry.$1,
                  ),
              if (c.error.value != null) Text(c.error.value!),
              if (c.storageError.value != null)
                Text('ذخیره محلی انجام نشد: ${c.storageError.value}'),
              if (c.done.value)
                BTN(
                  name: 'بازگشت به محصولات',
                  onTap: () => Get.back(result: true),
                  navigate: true,
                )
              else if (c.locked && !c.state.value.pending)
                const Text(
                  'درخواست باز مربوط به عملیات دیگری است؛ آن را در صفحه مربوط ادامه دهید.',
                )
              else ...[
                if (!c.locked && !widget.fromChat)
                  BTN(
                    name: 'افزودن ردیف',
                    icon: IconsaxPlusLinear.add,
                    borderOnly: true,
                    disabled: c.saving.value,
                    onTap: c.addRow,
                  ),
                BTN(
                  name: c.locked ? 'ادامهٔ ثبت قبلی' : 'ثبت نهایی محصولات',
                  disabled: c.saving.value,
                  onTap: c.save,
                ),
              ],
            ],
          );
        }),
      ),
    ),
  );
}

class _BulkRowEditor extends StatefulWidget {
  final ProductBulkController c;
  final BulkProductRow row;
  final int index;
  const _BulkRowEditor({
    super.key,
    required this.c,
    required this.row,
    required this.index,
  });
  @override
  State<_BulkRowEditor> createState() => _BulkRowEditorState();
}

class _BulkRowEditorController extends GetxController {
  final name = TextEditingController(),
      price = TextEditingController(),
      category = TextEditingController(),
      unit = TextEditingController();
}

class _BulkRowEditorState extends State<_BulkRowEditor> {
  late final _page = _BulkRowEditorController();

  ProductBulkController get c => widget.c;
  BulkProductRow get row => widget.row;
  @override
  void initState() {
    super.initState();
    _page.name.text = row.name;
    _page.price.text = row.price;
    _page.category.text = row.categoryIds
        .map(
          (id) =>
              c.form.categories.where((v) => v.id == id).firstOrNull?.name ??
              'شناسه: $id',
        )
        .join('، ');
    _page.unit.text =
        c.form.units.where((v) => v.id == row.unitId).firstOrNull?.name ??
        (row.unitId?.toString() ?? '');
  }

  void changed() {
    {
      _page.update();
    }
    c.changed(row);
  }

  @override
  void dispose() {
    for (final v in [_page.name, _page.price, _page.category, _page.unit]) {
      v.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_BulkRowEditorController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(() {
      final primary = c.form.categories
          .where((v) => row.categoryIds.contains(v.id))
          .map((v) => ItemValue(text: v.name, data: v.id))
          .toList();
      return AbsorbPointer(
        absorbing: !c.editable,
        child: Column(
          children: [
            MyDivider(text: 'محصول ${widget.index + 1}'),
            Input(
              key: ValueKey('bulk-name-${row.id}'),
              controller: _page.name,
              name: 'نام محصول',
              maxLength: 200,
              require: true,
              onChanged: (v) {
                row.name = v;
                c.changed(row);
              },
            ),
            CatInput(
              controller: _page.category,
              type: 'product',
              name: 'دسته‌بندی',
              require: true,
              categories: c.form.categories.toList(),
              selected: row.categoryIds
                  .where((id) => c.form.categories.any((v) => v.id == id))
                  .toList(),
              onChanged: (List values) {
                row.categoryIds = values
                    .map((v) => v['uid'] as String)
                    .toList();
                if (!row.categoryIds.contains(row.primaryCategoryId)) {
                  row.primaryCategoryId = row.categoryIds.firstOrNull;
                }
                _page.category.text = values.map((v) => v['name']).join('، ');
                changed();
              },
            ),
            Dropdown(
              name: 'دسته‌بندی اصلی',
              itemValue: true,
              items_Value: primary,
              defaultValue: primary
                  .where((v) => v.data == row.primaryCategoryId)
                  .firstOrNull,
              onChange: (v) {
                row.primaryCategoryId = (v as ItemValue).data as String;
                changed();
              },
            ),
            UnitInput(
              controller: _page.unit,
              name: 'واحد کالا',
              units: c.form.units.toList(),
              selected: {'id': row.unitId, 'name': _page.unit.text},
              onChanged: (v) {
                row.unitId = v['id'] as int?;
                _page.unit.text = v['name'] as String;
                changed();
              },
            ),
            ProductBrandSelector(
              brands: c.form.brands,
              value: row.brandId,
              enabled: c.form.canBrands,
              error: c.form.brandError.value,
              onChanged: (v) {
                row.brandId = v;
                changed();
              },
            ),
            PriceInput(
              key: ValueKey('bulk-price-${row.id}'),
              controller: _page.price,
              name: 'قیمت فروش',
              require: true,
              enabled: c.form.canPrice,
              onChanged: (v) {
                row.price = _page.price.text;
                c.changed(row);
              },
            ),
            if (!c.form.canPrice)
              const Text(
                'اجازه ثبت قیمت پیش‌فرض را ندارید؛ برای ثبت نهایی این مجوز لازم است.',
              ),
            if (!c.form.canPrice && row.price.isNotEmpty)
              MiniBTN(
                name: 'حذف قیمت اولیه',
                icon: IconsaxPlusLinear.close_square,
                noFlex: true,
                onTap: () {
                  _page.price.clear();
                  row.price = '';
                  changed();
                },
              ),
            if (row.error.value != null) Text(row.error.value!),
            MiniBTN(
              name: 'حذف ردیف',
              icon: IconsaxPlusLinear.trash,
              noFlex: true,
              height: 40,
              onTap: c.rows.length > 1 ? () => c.removeRow(row) : null,
            ),
          ],
        ),
      );
    }),
  );
}

Widget buildProductBulkRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductBulkScreen(
    context: args.required<BusinessContext>('context'),
    controller: args.optional<ProductBulkController>('controller'),
    fromChat: args.optional<bool>('fromChat') ?? false,
  );
}
