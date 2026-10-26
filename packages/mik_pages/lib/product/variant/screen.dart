import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_components/elements/buttons/button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';

import 'controller.dart';

class ProductVariantsScreen extends StatefulWidget {
  final PimFX fx;
  final String productId;
  const ProductVariantsScreen({
    super.key,
    required this.fx,
    required this.productId,
  });
  @override
  State<ProductVariantsScreen> createState() => _ProductVariantsScreenState();
}

class _ProductVariantsScreenState extends State<ProductVariantsScreen> {
  late final c = ProductVariantController(widget.fx, widget.productId);
  void changeStatus(PimVariant item) {
    Confirm.con(
      context,
      type: ConfirmType.CHANGE,
      subtext:
          '${c.title(item.optionValues)}\n${item.status == 'ACTIVE' ? 'این تنوع آرشیو شود؟' : 'این تنوع دوباره فعال شود؟'}',
      confirmText: item.status == 'ACTIVE' ? 'آرشیو تنوع' : 'فعال‌سازی تنوع',
      onTapConfirm: () async {
        Get.back();
        await c.changeStatus(item);
      },
    );
  }

  @override
  Widget build(BuildContext context) => Obx(
    () => PopScope(
      canPop: !c.saving.value,
      child: Main(
        header: Header.page(context, text: 'تنوع‌های محصول', help: false),
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
          return RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              padding: const EdgeInsets.all(10),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (c.notice.value != null) Text(c.notice.value!),
                if (c.error.value != null) Text(c.error.value!),
                if (c.conflict.value)
                  BTN(
                    name: 'دریافت نسخه جدید تنوع‌ها',
                    icon: IconsaxPlusLinear.refresh,
                    onTap: c.load,
                    disabled: c.busy,
                  ),
                if (c.pending.value != null) ...[
                  const Text(
                    'یک درخواست تعیین‌تکلیف‌نشده وجود دارد؛ تا روشن شدن نتیجه، ثبت تازه انجام نمی‌شود.',
                  ),
                  if (c.pendingHere)
                    BTN(
                      name: 'تلاش مجدد همان درخواست تنوع',
                      icon: IconsaxPlusLinear.refresh,
                      onTap: c.resume,
                      disabled: c.busy,
                    )
                  else
                    const Text(
                      'درخواست باز مربوط به عملیات دیگری است؛ آن را در صفحهٔ مربوط ادامه دهید.',
                    ),
                ],
                if (c.canEditAxes)
                  BTN(
                    name: c.pendingAxes
                        ? 'ادامهٔ مدیریت گزینه‌ها'
                        : 'ویرایش گزینه‌های محصول',
                    icon: IconsaxPlusLinear.edit,
                    onTap: () async {
                      await Get.toNamed(
                        nav_routes.RoutesName.PRODUCT_AXES,
                        arguments: {'fx': c.fx, 'productId': c.productId},
                        preventDuplicates: false,
                      );
                      if (mounted) await c.load();
                    },
                    disabled:
                        c.busy ||
                        c.conflict.value ||
                        c.pending.value != null && !c.pendingAxes,
                    navigate: true,
                  ),
                if (c.canGenerate) ...[
                  MyDivider(text: 'ساخت ترکیب‌های محصول'),
                  const Text(
                    'گزینه‌های ثبت‌شدهٔ محصول را انتخاب کنید. ترکیب‌های موجود تکرار نمی‌شوند و تنوع‌های آرشیوشده خودکار فعال نمی‌شوند.',
                  ),
                  for (final axis in c.product!.variantAxes) ...[
                    MyDivider(text: c.label(axis.attributeId)),
                    for (final id in axis.valueIds)
                      CheckboxListTile(
                        title: Text(c.option(axis.attributeId, id)),
                        value:
                            c.selected[axis.attributeId]?.contains(id) == true,
                        onChanged:
                            c.busy ||
                                c.pending.value != null ||
                                c.conflict.value
                            ? null
                            : (value) =>
                                  c.select(axis.attributeId, id, value == true),
                      ),
                  ],
                  BTN(
                    name: c.previewing.value
                        ? 'در حال دریافت پیش‌نمایش'
                        : 'پیش‌نمایش ترکیب‌ها',
                    icon: IconsaxPlusLinear.eye,
                    onTap: c.showPreview,
                    disabled:
                        c.busy || c.pending.value != null || c.conflict.value,
                  ),
                  if (c.preview.value != null) ...[
                    MyDivider(text: 'پیش‌نمایش'),
                    for (final row in c.preview.value!.combinations)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${c.title(row)} — ${c.existing(row) == null
                              ? 'جدید'
                              : c.existing(row)!.status == 'ARCHIVED'
                              ? 'موجود، آرشیو'
                              : 'موجود، فعال'}',
                        ),
                      ),
                    if (c.preview.value!.combinations.any(
                      (row) => c.existing(row) == null,
                    ))
                      BTN(
                        name: 'ساخت تنوع‌های جدید',
                        icon: IconsaxPlusLinear.add,
                        onTap: c.generate,
                        disabled:
                            c.busy ||
                            c.pending.value != null ||
                            c.conflict.value,
                      )
                    else
                      const Text(
                        'همهٔ ترکیب‌های انتخاب‌شده قبلاً ثبت شده‌اند.',
                      ),
                  ],
                ],
                MyDivider(text: 'تنوع‌های ثبت‌شده'),
                if (c.variants.isEmpty) const Text('تنوعی ثبت نشده است.'),
                for (final item in c.variants)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title(item.optionValues)),
                      Text('شناسه تنوع: ${item.id}'),
                      if (item.sku != null) Text('SKU: ${item.sku}'),
                      Text(item.status == 'ACTIVE' ? 'فعال' : 'آرشیو'),
                      if (c.writable &&
                          item.status == 'ACTIVE' &&
                          c.fx.has('pim.variant.update'))
                        MiniBTN(
                          name: 'ویرایش تنوع',
                          icon: IconsaxPlusLinear.edit,
                          noFlex: true,
                          onTap:
                              c.busy ||
                                  c.pending.value != null ||
                                  c.conflict.value
                              ? null
                              : () async {
                                  await Get.toNamed(
                                    nav_routes.RoutesName.PRODUCT_EDIT,
                                    arguments: {
                                      'fx': c.fx,
                                      'productId': c.productId,
                                      'variantId': item.id,
                                    },
                                    preventDuplicates: false,
                                  );
                                  if (mounted) await c.load();
                                },
                        ),
                      if (c.canChange(item))
                        MiniBTN(
                          name: item.status == 'ACTIVE'
                              ? 'آرشیو تنوع'
                              : 'فعال‌سازی تنوع',
                          icon: IconsaxPlusLinear.refresh,
                          noFlex: true,
                          onTap: () => changeStatus(item),
                        ),
                      if (c.product?.status == 'ACTIVE' &&
                          item.status == 'ACTIVE' &&
                          c.variants
                                  .where((v) => v.status == 'ACTIVE')
                                  .length ==
                              1)
                        const Text(
                          'آخرین تنوع فعالِ محصول فعال قابل آرشیو نیست.',
                        ),
                      MyDivider(),
                    ],
                  ),
              ],
            ),
          );
        }),
      ),
    ),
  );
}

Widget buildProductVariantsRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductVariantsScreen(
    fx: args.required<PimFX>('fx'),
    productId: args.required<String>('productId'),
  );
}
