import 'package:mik_router/mik_router.dart' as nav_routes;

import 'package:mik_data/utils/fx/stock.dart';
import 'package:mik_data/utils/fx/warehouse_management.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_data/source/remote/models/models.dart';

import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_components/elements/productImage.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_data/utils/fx/product_facts.dart';

import 'controller.dart';

class ProductDetailScreen extends StatefulWidget {
  final String appId, productId;
  final int businessId;
  const ProductDetailScreen({
    super.key,
    required this.appId,
    required this.businessId,
    required this.productId,
  });

  static Widget fromArguments(Object? arguments, {required String appId}) {
    if (arguments is! Map ||
        arguments['appId'] != appId ||
        arguments['businessId'] is! int ||
        arguments['productId'] is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        ).hasMatch(arguments['productId'] as String)) {
      return const Scaffold(
        body: Center(child: Text('اطلاعات مسیر محصول معتبر نیست.')),
      );
    }
    return ProductDetailScreen(
      appId: appId,
      businessId: arguments['businessId'] as int,
      productId: arguments['productId'] as String,
    );
  }

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenController extends GetxController {
  _ProductDetailScreenController(this.widget);
  ProductDetailScreen widget;
  late final c = ProductDetailController(
    appId: widget.appId,
    businessId: widget.businessId,
    productId: widget.productId,
  );
  Worker? _readErrors;
  int currentIndex = 0;
  ProductFactsFX? _factsSource;
  ProductFacts? summary;
  Object? summaryError;
  bool summaryLoading = false;
  int summaryGeneration = 0;
  Future<void> loadSummary(ProductFactsFX? source, PimProduct item) async {
    final request = ++summaryGeneration;
    summaryLoading = source != null;
    summary = null;
    summaryError = null;
    try {
      final result = await source?.load(item);
      if (isClosed || request != summaryGeneration) return;
      summary = result;
    } catch (failure) {
      if (isClosed || request != summaryGeneration) return;
      summaryError = failure;
    } finally {
      if (!isClosed && request == summaryGeneration) {
        summaryLoading = false;
        update();
      }
    }
  }

  bool openingStock = false;
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final _page = _ProductDetailScreenController(widget);

  @override
  void initState() {
    super.initState();
    _page._readErrors = everAll([_page.c.error, _page.c.variantsError], (
      value,
    ) {
      if (mounted && value is String && value.isNotEmpty) {
        Alert.error(value, context: context);
      }
    });
  }

  @override
  void dispose() {
    _page._readErrors?.dispose();
    _page.c.onClose();
    super.dispose();
  }

  String status(String value) => switch (value) {
    'ACTIVE' => 'فعال',
    'DRAFT' => 'پیش‌نویس',
    'ARCHIVED' => 'آرشیو',
    _ => value,
  };
  Widget field(String title, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text.rich(
      TextSpan(
        text: '$title: ',
        children: [
          TextSpan(
            text: value ?? '—',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
  Widget heading(String title) => MyDivider(text: title);
  Future<void> edit({PimVariant? variant}) async {
    final fx = _page.c.facts?.pim;
    if (fx == null) return;
    await Get.toNamed(
      nav_routes.RoutesName.PRODUCT_EDIT,
      arguments: {
        'fx': fx,
        'productId': widget.productId,
        'variantId': variant?.id,
      },
      preventDuplicates: false,
    );
    if (mounted) await _page.c.load();
  }

  String statusAction(String target) => switch (target) {
    'ACTIVE' => 'فعال‌سازی محصول',
    'ARCHIVED' => 'آرشیو محصول',
    _ => 'بازگردانی به پیش‌نویس',
  };
  void changeStatus(String target) {
    Confirm.con(
      context,
      type: ConfirmType.CHANGE,
      subtext: target == 'ACTIVE'
          ? 'محصول فعال شود؟ فعال‌سازی به تنوع فعال و قیمت پیش‌فرض معتبر نیاز دارد.'
          : target == 'ARCHIVED'
          ? 'محصول آرشیو شود؟'
          : 'محصول به پیش‌نویس بازگردد؟',
      confirmText: statusAction(target),
      onTapConfirm: () async {
        Get.back();
        await _page.c.changeStatus(target);
      },
    );
  }

  Future<void> openStock({required bool transfer}) async {
    if (_page.openingStock || _page.c.saving.value) return;
    final product = _page.c.product.value,
        business = _page.c.facts?.pim.context;
    if (product == null || business == null) return;
    _page.openingStock = true;
    try {
      final fx = WarehouseManagementFX.forContext(business);
      final warehouses = await fx.warehouses();
      final available = <BusinessWarehouse>[];
      for (final warehouse in warehouses) {
        if (transfer && warehouse.status != 'ACTIVE') continue;
        final stock = StockFX(business, warehouse.warehouseId);
        if (await stock.allowed('READ_STOCK') &&
            await stock.allowed(transfer ? 'TRANSFER_OUT' : 'READ_KARDEX')) {
          available.add(warehouse);
        }
      }
      fx.check();
      if (!mounted) return;
      if (available.isEmpty) {
        Alert.error(
          'انبار مجاز برای این عملیات در شعبه انتخاب‌شده وجود ندارد.',
          context: context,
        );
        return;
      }
      final selected = await MyBottomSheet.view(
        context,
        title: transfer ? 'انتخاب انبار مبدأ انتقال' : 'انتخاب انبار کاردکس',
        child: (scroll) => ListView(
          controller: scroll,
          shrinkWrap: true,
          children: [
            for (final warehouse in available)
              MiniBTN(
                name: warehouse.name,
                noFlex: true,
                icon: IconsaxPlusLinear.box,
                onTap: () => Get.back(result: warehouse),
              ),
          ],
        ),
      );
      if (!mounted || selected is! BusinessWarehouse) return;
      fx.check();
      await Get.toNamed(
        nav_routes.RoutesName.WAREHOUSE_STOCK,
        arguments: {
          'appId': widget.appId,
          'warehouse': selected,
          'transfer': transfer,
          'kardex': !transfer,
          'productId': product.id,
          'productName': product.name,
        },
        preventDuplicates: false,
      );
      if (mounted) await _page.c.load();
    } catch (failure) {
      if (mounted) Alert.error(StockFX.message(failure), context: context);
    } finally {
      _page.openingStock = false;
    }
  }

  Future<void> showDetails() async {
    await MyBottomSheet.view(
      context,
      title: 'مشخصات محصول',
      child: (scroll) => SingleChildScrollView(
        controller: scroll,
        child: Obx(() {
          final item = _page.c.product.value;
          if (item == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field('شناسه محصول', item.id),
              field('وضعیت محصول', status(item.status)),
              if (_page.c.statusNotice.value != null)
                Text(_page.c.statusNotice.value!),
              if (_page.c.statusError.value != null)
                Text(_page.c.statusError.value!),
              if (_page.c.statusConflict.value)
                BTN(
                  name: 'دریافت نسخه جدید محصول',
                  icon: IconsaxPlusLinear.refresh,
                  onTap: _page.c.load,
                )
              else if (_page.c.pendingStatus.value != null) ...[
                const Text(
                  'یک درخواست تعیین‌تکلیف‌نشده وجود دارد؛ تا روشن شدن نتیجه، تغییر وضعیت تازه انجام نمی‌شود.',
                ),
                if (_page.c.pendingHere)
                  BTN(
                    name: 'تلاش مجدد همان تغییر وضعیت',
                    icon: IconsaxPlusLinear.refresh,
                    onTap: () => _page.c.changeStatus(
                      _page.c.pendingStatus.value!.body['status'] as String,
                    ),
                    disabled: _page.c.saving.value,
                  )
                else
                  const Text(
                    'درخواست باز مربوط به عملیات دیگری است؛ آن را در صفحهٔ مربوط ادامه دهید.',
                  ),
              ] else ...[
                for (final target in ['ACTIVE', 'DRAFT', 'ARCHIVED'])
                  if (_page.c.canStatus(target))
                    BTN(
                      name: statusAction(target),
                      icon: IconsaxPlusLinear.refresh,
                      onTap: () => changeStatus(target),
                    ),
                if (_page.c.canStatus('ACTIVE'))
                  const Text(
                    'فعال‌سازی به تنوع فعال و قیمت پیش‌فرض معتبر نیاز دارد.',
                  ),
              ],
              if (_page.c.saving.value)
                const Text('در حال ذخیرهٔ وضعیت محصول…'),
              field('مدل', item.model),
              field('نامک', item.slug),
              field('کد واحد', item.unitId.toString()),
              if (item.brandId != null)
                field('برند (نام یا شناسه)', _page.c.label(item.brandId!)),
              field('توضیح کوتاه', item.shortDescription),
              field('توضیحات', item.description),
              if (item.attributeValues.isNotEmpty) heading('ویژگی‌های محصول'),
              for (final value in item.attributeValues)
                field(
                  _page.c.label(value.attributeId),
                  value.textValue ??
                      value.numberValue?.toString() ??
                      (value.booleanValue == null
                          ? null
                          : value.booleanValue!
                          ? 'بله'
                          : 'خیر') ??
                      value.valueIds
                          ?.map((id) => _page.c.option(value.attributeId, id))
                          .join('، '),
                ),
            ],
          );
        }),
      ),
    );
  }

  String priceText(ProductPriceSummary? price) {
    if (price?.minimum == null) return price?.message ?? 'قیمت در دسترس نیست.';
    return price!.minimum == price.maximum
        ? Price.showWithCurrency(price.minimum!)
        : '${Price.show(price.minimum!)} - ${Price.showWithCurrency(price.maximum!)}';
  }

  String variantName(PimVariant item) => item.optionValues.isEmpty
      ? item.name
      : item.optionValues
            .map((v) => _page.c.option(v.attributeId, v.valueId))
            .join(' / ');

  Widget variant(PimVariant item, ProductFacts? summary) {
    final stock = summary?.stock.variants[item.id];
    final price = summary?.price.variants[item.id];
    return ExpansionTile(
      key: PageStorageKey('product-variant-${item.id}'),
      shape: const Border(bottom: BorderSide(color: Colors.grey)),
      collapsedShape: const Border(bottom: BorderSide(color: Colors.grey)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              variantName(item),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          if (stock?.available.isZero == true &&
              !stock!.warehouses.single.blockedForCount)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'بدون موجودی',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Text(
              stock?.available.toString() ??
                  (item.status == 'ARCHIVED' ? 'آرشیو' : '—'),
              style: const TextStyle(fontSize: 13),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('قیمت فروش:', style: TextStyle(fontSize: 11)),
            Flexible(
              child: Text(
                priceText(price),
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field('وضعیت', status(item.status)),
              field('SKU', item.sku),
              field(
                'بارکدها',
                item.barcodes.isEmpty ? null : item.barcodes.join('، '),
              ),
              for (final option in item.optionValues)
                field(
                  _page.c.label(option.attributeId),
                  _page.c.option(option.attributeId, option.valueId),
                ),
              field(
                'موجودی قابل فروش انبار پیش‌فرض',
                stock?.available.toString(),
              ),
              if (stock?.warehouses.single.blockedForCount == true)
                const Text(
                  'انبارگردانی باز است؛ موجودی قابل فروش مسدود شده است.',
                ),
              if (item.description != null)
                field('توضیحات تنوع', item.description),
              if (item.status != 'ARCHIVED' &&
                  _page.c.product.value?.status != 'ARCHIVED' &&
                  _page.c.facts?.pim.has('pim.variant.update') == true)
                MiniBTN(
                  name: 'ویرایش تنوع',
                  icon: IconsaxPlusLinear.edit,
                  noFlex: true,
                  onTap:
                      _page.c.saving.value ||
                          _page.c.pendingStatus.value != null
                      ? null
                      : () => edit(variant: item),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_ProductDetailScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => PopScope(
        canPop: !_page.c.saving.value,
        child: Main(
          header: Header.page(context, text: 'جزئیات محصول', help: false),
          initState: () async {
            await _page.c.load();
            return true;
          },
          child: (_) => Obx(() {
            if (_page.c.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_page.c.error.value != null) {
              return ErrorSection(_page.c.error.value, act: _page.c.load);
            }
            final item = _page.c.product.value;
            if (item == null) return const SizedBox.shrink();
            // Reuse the existing price/stock request; switching tabs must not fetch it again.
            if (!identical(_page._factsSource, _page.c.facts)) {
              _page._factsSource = _page.c.facts;
              _page.loadSummary(_page.c.facts, item);
            }
            return GetBuilder<_ProductDetailScreenController>(
              init: _page,
              global: false,
              autoRemove: false,
              builder: (_) {
                final ready = !_page.summaryLoading;
                final summary = _page.summary;
                final failure = _page.summaryError == null
                    ? null
                    : ProductFactsFX.message(_page.summaryError!);
                return Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        key: const ValueKey('product-detail-summary'),
                        children: [
                          ProductImage.img(
                            context,
                            item,
                            90,
                            showAll: true,
                            business: _page.c.facts?.pim.context,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'کد: ${item.id}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item.name,
                                  maxLines: 2,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      IconsaxPlusLinear.category,
                                      size: 15,
                                      color: Colors.grey.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        item.categoryIds.isEmpty
                                            ? '—'
                                            : item.categoryIds
                                                  .map(_page.c.label)
                                                  .join('، '),
                                        maxLines: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: darkMode.isTrue
                              ? Colors.grey[700]
                              : Colors.grey[200],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('قیمت فروش:'),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    !ready
                                        ? 'در حال دریافت…'
                                        : failure ?? priceText(summary?.price),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('موجودی قابل فروش:'),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    !ready
                                        ? 'در حال دریافت…'
                                        : failure ??
                                              summary?.stock.available
                                                  ?.toString() ??
                                              summary?.stock.message ??
                                              'موجودی در دسترس نیست.',
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'انبار پیش‌فرض شعبه؛ همهٔ عنوان‌های قیمت معتبر',
                              style: TextStyle(fontSize: 11),
                            ),
                            if (summary?.stock.blockedForCount == true)
                              const Text(
                                'انبارگردانی باز است؛ موجودی قابل فروش مسدود شده است.',
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: darkMode.isTrue
                                ? Colors.grey[700]
                                : Colors.grey[200],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Material(
                              color: darkMode.isTrue
                                  ? Colors.grey[700]
                                  : Colors.grey[200],
                              child: Column(
                                children: [
                                  MyTabBar(
                                    tabs: ['بر اساس ویژگی', 'بر اساس انبار'],
                                    currentIndex: _page.currentIndex,
                                    bgColor: darkMode.isTrue
                                        ? Colors.grey[800]
                                        : Colors.grey[300],
                                    divider: false,
                                    index: (value) {
                                      _page.currentIndex = value as int;
                                      _page.update();
                                    },
                                  ),
                                  Expanded(
                                    child: RefreshIndicator(
                                      onRefresh: _page.c.load,
                                      child: ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        children: [
                                          if (!ready)
                                            const LinearProgressIndicator(),
                                          if (failure != null)
                                            ErrorSection(
                                              failure,
                                              act: _page.c.load,
                                            )
                                          else if (_page
                                                  .c
                                                  .variantsError
                                                  .value !=
                                              null)
                                            ErrorSection(
                                              _page.c.variantsError.value,
                                              act: _page.c.load,
                                            )
                                          else if (_page.currentIndex == 0) ...[
                                            if (_page.c.variants.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.all(15),
                                                child: Text(
                                                  'تنوعی برای این محصول ثبت نشده است.',
                                                ),
                                              ),
                                            for (final row in _page.c.variants)
                                              variant(row, summary),
                                          ] else if (summary?.stock.available ==
                                              null)
                                            Padding(
                                              padding: const EdgeInsets.all(15),
                                              child: Text(
                                                !ready
                                                    ? 'در حال دریافت…'
                                                    : summary?.stock.message ?? 'موجودی در دسترس نیست.',
                                              ),
                                            )
                                          else
                                            ExpansionTile(
                                              key: const PageStorageKey(
                                                'product-default-warehouse',
                                              ),
                                              initiallyExpanded: true,
                                              title: const Text(
                                                'انبار پیش‌فرض شعبه',
                                              ),
                                              trailing: Text(
                                                summary!.stock.available
                                                    .toString(),
                                              ),
                                              children: [
                                                for (final row
                                                    in _page.c.variants)
                                                  if (summary.stock.variants
                                                      .containsKey(row.id))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 8,
                                                            horizontal: 15,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              variantName(row),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Text(
                                                            summary
                                                                .stock
                                                                .variants[row
                                                                    .id]!
                                                                .available
                                                                .toString(),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      BTN(
                        name: 'تصاویر محصول',
                        navigate: true,
                        disabled: _page.c.saving.value,
                        onTap: () async {
                          final fx = _page.c.facts?.pim;
                          if (fx == null) return;
                          await Get.toNamed(
                            nav_routes.RoutesName.PRODUCT_MEDIA,
                            arguments: {'fx': fx, 'productId': item.id},
                            preventDuplicates: false,
                          );
                          if (mounted) await _page.c.load();
                        },
                      ),
                      Row(
                        children: [
                          if (item.status != 'ARCHIVED' &&
                              _page.c.facts?.pim.has('pim.product.update') ==
                                  true)
                            MiniBTN(
                              name: 'ویرایش',
                              height: 53,
                              color: darkMode.isTrue
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                              itemColor: darkMode.isFalse
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                              icon: IconsaxPlusLinear.edit_2,
                              onTap:
                                  _page.c.saving.value ||
                                      _page.c.pendingStatus.value != null
                                  ? null
                                  : () => edit(),
                            ),
                          if (_page.c.facts?.pim.has('pim.variant.read') ==
                              true)
                            MiniBTN(
                              name: 'ویژگی‌',
                              height: 53,
                              color: darkMode.isTrue
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                              itemColor: darkMode.isFalse
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                              icon: IconsaxPlusLinear.star,
                              onTap: _page.c.saving.value
                                  ? null
                                  : () async {
                                      final fx = _page.c.facts?.pim;
                                      if (fx == null) return;
                                      await Get.toNamed(
                                        nav_routes.RoutesName.PRODUCT_VARIANTS,
                                        arguments: {
                                          'fx': fx,
                                          'productId': item.id,
                                        },
                                        preventDuplicates: false,
                                      );
                                      if (mounted) await _page.c.load();
                                    },
                            ),
                          if (_page.c.facts?.pim.has('pim.price.read') == true)
                            MiniBTN(
                              name: 'قیمت‌',
                              height: 53,
                              color: darkMode.isTrue
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                              itemColor: darkMode.isFalse
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                              icon: IconsaxPlusLinear.money_change,
                              onTap: _page.c.saving.value
                                  ? null
                                  : () async {
                                      final fx = _page.c.facts?.pim;
                                      if (fx == null) return;
                                      await Get.toNamed(
                                        nav_routes.RoutesName.PRODUCT_PRICES,
                                        arguments: {
                                          'fx': fx,
                                          'productId': item.id,
                                        },
                                        preventDuplicates: false,
                                      );
                                      if (mounted) await _page.c.load();
                                    },
                            ),
                          MiniBTN(
                            name: 'انتقال',
                            height: 53,
                            color: darkMode.isTrue
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                            itemColor: darkMode.isFalse
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                            icon: IconsaxPlusLinear.arrow_swap_horizontal,
                            onTap: _page.c.saving.value
                                ? null
                                : () => openStock(transfer: true),
                          ),
                          MiniBTN(
                            name: 'شاپ',
                            height: 53,
                            color: darkMode.isTrue
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                            itemColor: darkMode.isFalse
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                            icon: IconsaxPlusLinear.link,
                            onTap: _page.c.saving.value
                                ? null
                                : () async {
                                    final business = _page.c.facts?.pim.context;
                                    if (business == null) return;
                                    await Get.toNamed(
                                      nav_routes.RoutesName.PRODUCT_SHOP,
                                      arguments: {
                                        'business': business,
                                        'productId': item.id,
                                        'productName': item.name,
                                      },
                                      preventDuplicates: false,
                                    );
                                  },
                          ),
                          MiniBTN(
                            name: 'کاردکس',
                            height: 53,
                            color: darkMode.isTrue
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                            itemColor: darkMode.isFalse
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                            icon: IconsaxPlusLinear.document,
                            onTap: _page.c.saving.value
                                ? null
                                : () => openStock(transfer: false),
                          ),
                          MiniBTN(
                            name: 'مشخصات',
                            height: 53,
                            color: darkMode.isTrue
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                            itemColor: darkMode.isFalse
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                            icon: IconsaxPlusLinear.document,
                            onTap: _page.c.saving.value ? null : showDetails,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}
