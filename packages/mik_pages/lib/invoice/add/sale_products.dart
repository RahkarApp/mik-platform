import 'package:mik_router/mik_router.dart' as nav_routes;

import 'components/selectproduct.dart';

import 'package:mik_pages/product/screen/screen.dart' show PimProductItem;
import 'package:mik_data/utils/fx/product_facts.dart';
import 'package:mik_data/utils/fx/pim.dart';

import 'components/item/item.dart';
import 'components/item/components/amount.dart';
import 'components/item/components/price.dart';
import 'components/item/components/warehouse.dart';

import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_variables/variable.dart';

import 'metadata_editor.dart';
import 'amounts_editor.dart';

import 'package:flutter/material.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/models/customer.dart';
import 'package:mik_pages/customers/customer_controller.dart';

import '../selection_sheet.dart';

import 'package:mik_consts/svgIcon.dart';
import 'package:mik_data/utils/fx/customers.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_utils/public/price.dart';

import 'sale_products_controller.dart';

/// The shared sale flow keeps server UUIDs separate from legacy Hive invoices.
class SaleInvoiceProducts extends StatefulWidget {
  final String appId;
  final String type;
  const SaleInvoiceProducts({
    required this.appId,
    this.type = 'SALE',
    super.key,
  });
  @override
  State<SaleInvoiceProducts> createState() => _SaleInvoiceProductsState();
}

class _SaleInvoiceProductsState extends State<SaleInvoiceProducts> {
  late final c = SaleProductsController(
    appId: widget.appId,
    type: widget.type,
    onError: (message) {
      if (mounted) Alert.error(message, context: context);
    },
    onSuccess: (message) {
      if (mounted) Alert.success(message);
    },
  );
  final branchField = TextEditingController();
  final partyField = TextEditingController();
  final validity = TextEditingController();
  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  void dispose() {
    validity.dispose();
    branchField.dispose();
    partyField.dispose();
    c.onClose();
    super.dispose();
  }

  Future<void> pick() async {
    if (c.locked) return;
    try {
      c.check();
    } catch (_) {
      await c.load();
      return;
    }
    if (!mounted) return;
    final List<SaleInvoiceLine>? rows = await Get.toNamed<dynamic>(
      nav_routes.RoutesName.SALE_PRODUCT_PICKER,
      arguments: {'c': c},
      preventDuplicates: false,
    );
    if (!mounted || rows == null) return;
    try {
      c.check();
      c.lines.assignAll(rows);
      c.quantityErrors.removeWhere(
        (id, _) => !rows.any((row) => row.variant.id == id),
      );
    } catch (_) {
      await c.load();
    }
  }

  Future<void> changePrice(SaleInvoiceLine row) async {
    if (c.locked || c.loading.value) return;
    await c.open(row.product);
    if (!mounted || c.error.value != null) return;
    await MyBottomSheet.view(
      context,
      title: 'قیمت فروش محصول',
      child: (scroll) => Obx(
        () => ListView(
          controller: scroll,
          shrinkWrap: true,
          children: [
            MyDivider(text: row.product.name),
            if (c.prices.isEmpty) const Text('عنوان قیمت فعالی دریافت نشد.'),
            for (final price in c.prices)
              BTN(
                name: price.name,
                disabled: c.locked || c.choosing.value,
                onTap: () async {
                  final result = await c.choose(
                    row.product,
                    row.variant,
                    price: price,
                  );
                  if (!mounted || result == null) return;
                  final index = c.lines.indexWhere(
                    (line) => line.variant.id == row.variant.id,
                  );
                  if (index < 0) return;
                  c.lines[index] = result.copy(
                    quantity: c.lines[index].quantity,
                  );
                  Get.back();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> pickCustomer() async {
    if (c.locked) return;
    final customers = RemoteCustomersController(appId: widget.appId);
    customers.load();
    RemoteCustomer? selected;
    try {
      selected = await MyBottomSheet.view(
        context,
        title: 'مشتریان',
        titleWidget: Obx(
          () => Text(
            'مشتریان (${customers.items.length}${customers.next.value == null ? '' : '+'})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        initialChildSize: 0.8,
        child: (scroll) =>
            _SaleCustomerPicker(controller: customers, scroll: scroll),
      ) as RemoteCustomer?;
    } finally {
      customers.onClose();
    }
    if (!mounted || selected == null || c.locked) return;
    try {
      c.check();
      c.customer.value = selected;
    } catch (_) {
      await c.load();
    }
  }

  Future<void> complete() async {
    if (c.locked) return;
    if (c.customer.value == null || c.lines.isEmpty || c.subtotal == null) {
      c.reportError(
        c.customer.value == null
            ? 'مشتری فاکتور را انتخاب کنید.'
            : 'هیچ محصولی انتخاب نشده است.',
      );
      return;
    }
    var amountsValid = true, metadataValid = true;
    await MyBottomSheet.view(
      context,
      title: 'تکمیل فاکتور',
      child: (scroll) => SingleChildScrollView(
        controller: scroll,
        child: Obx(() {
          const methods = [
            ItemValue(text: 'نقدی', data: 'CASH'),
            ItemValue(text: 'واریز بانکی', data: 'BANK_TRANSFER'),
            ItemValue(text: 'کارت', data: 'CARD'),
          ];
          final targets = c.paymentTargets
              .map((t) => ItemValue(text: t.name, data: t.id))
              .toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InvoiceAmountsEditor(
                embedded: true,
                initial: c.amounts.value,
                subtotal: c.subtotal!,
                canDiscount: c.canDiscount,
                canSurcharge: c.canSurcharge,
                purchase: false,
                scroll: scroll,
                onValidity: (valid) => amountsValid = valid,
                onSave: (value) => c.amounts.value = value,
              ),
              InvoiceMetadataEditor(
                embedded: true,
                dueAt: c.dueAt.value,
                note: c.note.value,
                scroll: scroll,
                onValidity: (valid) => metadataValid = valid,
                onSave: (date, note) {
                  c.dueAt.value = date;
                  c.note.value = note;
                },
              ),
              if (c.proforma && c.pendingSale.value == null) ...[
                DateInput(
                  key: const ValueKey('proforma-valid-until'),
                  controller: validity,
                  name: 'مهلت اعتبار (اختیاری)',
                  timePicker: true,
                  enabled: !c.locked,
                  onChanged: (value) {
                    try {
                      c.validUntil.value = DateTime.parse(
                        DateConvertor.jalaliToGrigori(validity.text),
                      ).toUtc();
                      c.validityError = null;
                    } catch (_) {
                      c.validityError = 'مهلت اعتبار معتبر نیست.';
                      c.reportError(c.validityError!);
                    }
                  },
                ),
                MiniBTN(
                  name: 'بدون مهلت اعتبار',
                  noFlex: true,
                  icon: IconsaxPlusLinear.close_circle,
                  onTap: c.locked
                      ? null
                      : () {
                          validity.clear();
                          c.validUntil.value = null;
                          c.validityError = null;
                        },
                ),
              ],
              if (!c.proforma && c.pendingSale.value == null) ...[
                MyDivider(text: 'تسویه و پرداخت فاکتور'),
                MyTab(
                  tab: const ['دریافت کامل', 'اعتباری'],
                  value: c.paymentMode,
                  enabledValues: c.locked ? <String>{} : null,
                  callback: c.selectPaymentMode,
                ),
                if (c.paymentMode.value == 'دریافت کامل') ...[
                  Dropdown(
                    key: const ValueKey('sale-payment-method'),
                    name: 'روش دریافت',
                    search: false,
                    itemValue: true,
                    disable: c.locked,
                    defaultValue: methods.firstWhere(
                      (m) => m.data == c.paymentMethod.value,
                    ),
                    items_Value: methods,
                    onChange: (v) =>
                        c.selectPaymentMethod((v as ItemValue).data as String),
                  ),
                  if (c.paymentLoading.value)
                    const LinearProgressIndicator()
                  else
                    Dropdown(
                      key: ValueKey(
                        'sale-payment-target-${c.paymentMethod.value}',
                      ),
                      name: 'مقصد دریافت وجه',
                      require: true,
                      itemValue: true,
                      disable: c.locked,
                      defaultValue: targets.firstWhereOrNull(
                        (t) => t.data == c.paymentTarget.value?.id,
                      ),
                      items_Value: targets,
                      onChange: (v) {
                        c.paymentTarget.value = c.paymentTargets.firstWhere(
                          (t) => t.id == (v as ItemValue).data,
                        );
                        c.error.value = null;
                      },
                    ),
                  if (!c.paymentLoading.value && c.paymentTargets.isEmpty)
                    MiniBTN(
                      name: 'دریافت مجدد مقصدهای پرداخت',
                      noFlex: true,
                      icon: IconsaxPlusLinear.refresh,
                      onTap: c.locked ? null : c.loadPaymentTargets,
                    ),
                ],
              ],
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'مبلغ کل:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        c.total == null
                            ? 'مبلغ نامعتبر'
                            : Price.showWithCurrency(c.total!),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),
              BTN(
                name: 'ثبت فاکتور',
                icon: IconsaxPlusLinear.tick_square,
                navigate: true,
                disabled: c.locked,
                onTap: () {
                  if (!amountsValid || !metadataValid) {
                    Alert.error(
                      'مبالغ، نوع مالیات، سررسید و توضیحات فاکتور را بررسی کنید.',
                      context: context,
                    );
                    return;
                  }
                  confirm();
                },
              ),
            ],
          );
        }),
      ),
    );
  }

  void confirm() {
    if (!c.canSubmit) {
      c.reportError(c.validationMessage);
      return;
    }
    Confirm.con(
      context,
      type: ConfirmType.SAVE,
      confirmText: 'ثبت نهایی',
      subtext: c.proforma
          ? 'پیش‌فاکتور برای ${c.customer.value!.name} ثبت می‌شود؛ هیچ وجه یا موجودی جابه‌جا نمی‌شود. مبلغ فعلی: ${Price.showWithCurrency(c.total!)}'
          : 'فاکتور فروش برای ${c.customer.value!.name} با وضعیت تحویل‌شده ثبت می‌شود. خروج کالا از انبار پیش‌فرض شعبه انجام می‌شود. مبلغ فعلی: ${Price.showWithCurrency(c.total!)}\n${c.paymentMode.value == 'دریافت کامل' && c.total! > 0 ? 'تایید می‌کنید تمام این مبلغ واقعاً دریافت شده و در ${c.paymentTarget.value!.name} ثبت شود؟ این دکمه پرداخت کارتخوان یا انتقال بانکی انجام نمی‌دهد.' : 'فاکتور بدون دریافت وجه ثبت می‌شود؛ مانده آن مشمول قوانین فروش اعتباری است.'}',
      onTapConfirm: () async {
        Get.back();
        // Close the completion sheet before showing the server result on the page.
        Get.back();
        await c.submit(receiptConfirmed: c.paymentMode.value == 'دریافت کامل');
      },
    );
  }

  String operationText() => switch (c.operation.value?.status) {
    'PENDING' => 'درخواست پذیرفته شد؛ ثبت قطعی هنوز انجام نشده است.',
    'PROCESSING' => 'ثبت فاکتور در حال انجام است.',
    'RETRY' => 'سرور در حال تلاش مجدد برای تکمیل ثبت است.',
    'ACTION_REQUIRED' =>
      'تکمیل عملیات به بررسی مدیر نیاز دارد؛ فاکتور تازه نسازید.',
    'FAILED' =>
      'ثبت فاکتور ناموفق بود: ${c.operation.value?.errorCode ?? 'کد خطا اعلام نشده'}',
    'SUCCEEDED' => 'ثبت فاکتور قطعی شد. شناسه: ${c.operation.value!.invoiceId}',
    _ => 'نتیجه درخواست قبلی مشخص نیست؛ همان درخواست را پیگیری کنید.',
  };

  @override
  Widget build(BuildContext context) => Obx(() {
    branchField.text = c.branchName;
    final customer = c.customer.value;
    partyField.text = customer == null
        ? ''
        : customer.phone == null
        ? customer.name
        : '${customer.name} (${customer.phone})';
    final groups = <String, List<SaleInvoiceLine>>{};
    for (final row in c.lines) {
      (groups[row.product.id] ??= []).add(row);
    }
    return Column(
      children: [
        Input(controller: branchField, name: 'شعبه', readOnly: true),
        if (c.error.value != null)
          Text(c.error.value!, textAlign: TextAlign.center),
        Input(
          key: const ValueKey('invoice-party-picker'),
          controller: partyField,
          name: 'مشتری',
          hintText: 'انتخاب مشتری',
          require: true,
          readOnly: true,
          onTap: c.locked || c.loading.value ? null : pickCustomer,
          suffixIcon: const Icon(IconsaxPlusLinear.arrow_down, size: 18),
        ),
        if (c.loading.value || c.saving.value) const LinearProgressIndicator(),
        if (c.lines.length > 30)
          const Text('حداکثر ۳۰ تنوع در هر فاکتور قابل ثبت است.'),
        if (c.error.value != null)
          MiniBTN(
            name: 'تلاش مجدد',
            icon: IconsaxPlusLinear.refresh,
            noFlex: true,
            onTap: c.loading.value || c.locked ? null : c.load,
          ),
        Expanded(
          child: c.pendingSale.value != null && c.lines.isEmpty
              ? ListView(
                  children: [
                    MyDivider(text: 'درخواست ذخیره‌شده'),
                    Text('مشتری: ${c.pendingSale.value!.body['customerId']}'),
                    if (c.pendingSale.value!.body['dueAt'] != null)
                      Text(
                        'سررسید: ${DateConvertor.grigoriToJalali(DateTime.parse(c.pendingSale.value!.body['dueAt'] as String).toLocal())} ${DateConvertor.showTime(DateTime.parse(c.pendingSale.value!.body['dueAt'] as String).toLocal())}',
                      ),
                    if (c.pendingSale.value!.body['note'] != null)
                      Text(c.pendingSale.value!.body['note'] as String),
                    for (final row
                        in c.pendingSale.value!.body['lines'] as List)
                      ListTile(
                        title: Text('تنوع: ${row['variantId']}'),
                        subtitle: Text('تعداد: ${row['quantity']}'),
                      ),
                  ],
                )
              : c.lines.isEmpty
              ? EmptyList(
                  text: 'محصولی انتخاب نشده است.',
                  icon: IconsaxPlusLinear.box_remove,
                )
              : ListView(
                  children: [
                    MyDivider(text: 'اقلام فاکتور:'),
                    for (final rows in groups.values)
                      for (final row in rows) ...[
                        ProductItemInvoice.remote(
                          key: ValueKey(row.variant.id),
                          name: row.product.name,
                          showHeader: row == rows.first,
                          showDivider: row == rows.last,
                          variant: row.variant.optionValues.isEmpty
                              ? null
                              : row.variantName,
                          quantity: AmountChangeInvoice.remote(
                            key: ValueKey('sale-quantity-${row.variant.id}'),
                            quantity: row.quantity,
                            locked: c.locked,
                            onChanged: (value) =>
                                c.setQuantity(row.variant.id, value),
                            onRemove: () {
                              if (c.locked) return;
                              c.lines.remove(row);
                              c.quantityErrors.remove(row.variant.id);
                            },
                          ),
                          warehouse: c.proforma
                              ? null
                              : WarehouseChangeInvoice.remote(
                                  value: 'پیش‌فرض شعبه',
                                ),
                          price: PriceChangeInvoice.remote(
                            value: Price.showWithCurrency(row.price.amount),
                            onTap: c.locked ? null : () => changePrice(row),
                          ),
                          total:
                              '${row.priceName} — ${Price.showWithCurrency(row.amount)}',
                        ),
                        if (c.quantityErrors[row.variant.id] != null)
                          Text(c.quantityErrors[row.variant.id]!),
                      ],
                  ],
                ),
        ),
        BTN(
          name: 'افزودن کالا',
          color: darkMode.isFalse ? Colors.grey.shade900 : Colors.grey.shade700,
          icon: IconsaxPlusLinear.box,
          navigate: true,
          disabled: c.loading.value || c.locked,
          onTap: pick,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مبلغ سفارش: ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                c.pendingSale.value != null && c.lines.isEmpty
                    ? 'در انتظار مبلغ قطعی سرور'
                    : c.total == null
                    ? 'تعداد یا مبلغ نامعتبر'
                    : Price.showWithCurrency(c.total!),
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
        if (c.pendingSale.value != null)
          Text(operationText(), textAlign: TextAlign.center),
        if (c.issued.value != null) ...[
          Text('شماره فاکتور: ${c.issued.value!.number}'),
          Text('مبلغ قطعی: ${Price.showWithCurrency(c.issued.value!.total)}'),
          if (!c.proforma)
            Text(
              'تسویه: ${c.issued.value!.paymentStatus == 'PAID'
                  ? 'تسویه‌شده'
                  : c.issued.value!.paymentStatus == 'UNPAID'
                  ? 'پرداخت‌نشده'
                  : 'پرداخت جزئی'}',
            ),
          BTN(
            name: 'فاکتور جدید',
            onTap: c.resetFinished,
            disabled: c.saving.value,
          ),
        ] else if (c.operation.value?.status == 'FAILED')
          BTN(
            name: 'اصلاح فاکتور',
            onTap: c.resetFinished,
            disabled: c.saving.value,
          )
        else if (c.pendingSale.value != null)
          BTN(
            name: 'پیگیری ثبت فاکتور',
            icon: IconsaxPlusLinear.refresh,
            disabled:
                c.saving.value ||
                c.operation.value?.status == 'ACTION_REQUIRED',
            onTap: c.submit,
          )
        else
          BTN(
            name: 'ادامه',
            icon: IconsaxPlusLinear.tick_square,
            navigate: true,
            disabled: c.locked || c.loading.value,
            onTap: () {
              complete();
            },
          ),
      ],
    );
  });
}

class _SaleProductPicker extends StatefulWidget {
  final SaleProductsController c;
  const _SaleProductPicker({required this.c});
  @override
  State<_SaleProductPicker> createState() => _SaleProductPickerState();
}

class _SaleProductPickerController extends GetxController {
  _SaleProductPickerController(this.widget);
  _SaleProductPicker widget;
  late final rowFacts = ProductFactsFX(PimFX.forContext(c.check()));
  final search = TextEditingController();
  late final selected = {for (final row in widget.c.lines) row.variant.id: row};
  PimProduct? product;
  String query = '';
  List<PimCategory> categories = [];
  String? category;
  SaleProductsController get c => widget.c;
}

class _SaleProductPickerState extends State<_SaleProductPicker> {
  late final _page = _SaleProductPickerController(widget);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final fx = PimFX.forContext(_page.c.check());
        if (fx.has('pim.category.read')) {
          final rows = (await fx.all(PimResource.categories))
              .cast<PimCategory>();
          _page.c.check();
          if (mounted) {
            {
              _page.categories = rows
                  .where(
                    (row) => _page.c.products.any(
                      (p) => p.categoryIds.contains(row.id),
                    ),
                  )
                  .toList();
              _page.update();
            }
          }
        }
      } catch (failure) {
        if (mounted) _page.c.reportError(PimFX.message(failure));
      }
    });
  }

  @override
  void dispose() {
    _page.search.dispose();
    super.dispose();
  }

  Future<bool> choose(PimVariant variant, {PimPrice? price}) async {
    final result = await _page.c.choose(_page.product!, variant, price: price);
    if (mounted && result != null) {
      {
        _page.selected[variant.id] = result.copy(
          quantity: _page.selected[variant.id]?.quantity,
        );
        _page.update();
      }
      return true;
    }
    return false;
  }

  Future<void> selectPrice(PimVariant variant) async {
    await MyBottomSheet.view(
      context,
      title: 'قیمت فروش تنوع',
      child: (scroll) => Obx(
        () => SingleChildScrollView(
          controller: scroll,
          child: Column(
            children: [
              BTN(
                name: 'انتخاب با قیمت پیش‌فرض',
                disabled: _page.c.loading.value || _page.c.choosing.value,
                onTap: () async {
                  if (await choose(variant) && mounted) {
                    Get.back();
                  }
                },
              ),
              for (final price in _page.c.prices)
                BTN(
                  name: price.name,
                  disabled: _page.c.loading.value || _page.c.choosing.value,
                  onTap: () async {
                    if (await choose(variant, price: price) && mounted) {
                      Get.back();
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_SaleProductPickerController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => SelectProductForInvoice.remote(
        search: MySearchBar(
          type: SearchBarType.product,
          controller: _page.search,
          enableScanner: false,
          hintText: 'جستجوی نام محصول',
          callback: (value) {
            _page.query = value.toString().trim();
            _page.update();
          },
        ),
        categories: _page.categories,
        selectedCategory: _page.category,
        onCategory: (id) {
          _page.category = id;
          _page.product = null;
          _page.update();
        },
        products: ListView(
          children: [
            if (_page.c.loading.value || _page.c.choosing.value)
              const LinearProgressIndicator(),
            if (_page.c.error.value != null)
              Text(_page.c.error.value!, textAlign: TextAlign.center),
            if (!_page.c.loading.value &&
                !_page.c.products.any(
                  (p) =>
                      p.name.contains(_page.query) &&
                      (_page.category == null ||
                          p.categoryIds.contains(_page.category)),
                ))
              const Center(child: Text('محصولی یافت نشد.')),
            for (final row in _page.c.products.where(
              (p) =>
                  p.name.contains(_page.query) &&
                  (_page.category == null ||
                      p.categoryIds.contains(_page.category)),
            ))
              ProductItemSelect.remote(
                key: ValueKey('invoice-product-${row.id}'),
                isSelected: _page.selected.values.any(
                  (line) => line.product.id == row.id,
                ),
                content: PimProductItem(
                  row,
                  facts: _page.rowFacts,
                  categories: _page.categories
                      .where((cat) => row.categoryIds.contains(cat.id))
                      .map((cat) => cat.name)
                      .join('، '),
                  onTap: _page.c.loading.value || _page.c.choosing.value
                      ? null
                      : () async {
                          if (_page.product?.id == row.id) {
                            {
                              _page.product = null;
                              _page.update();
                            }
                            return;
                          }
                          {
                            _page.product = row;
                            _page.update();
                          }
                          await _page.c.open(row);
                        },
                ),
                variants: _page.product?.id != row.id
                    ? null
                    : Column(
                        children: [
                          if (!_page.c.loading.value &&
                              _page.c.variants.isEmpty)
                            const Text('تنوع فعالی یافت نشد.'),

                          for (final variant in _page.c.variants)
                            ProductItemSelect.variant(
                              key: ValueKey('invoice-variant-${variant.id}'),
                              variant: variant,
                              attributes: _page.c.attributes,
                              isSelected: _page.selected.containsKey(
                                variant.id,
                              ),
                              details: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (_page.selected[variant.id] != null)
                                    Text(
                                      '${_page.selected[variant.id]!.priceName}: ${Price.showWithCurrency(_page.selected[variant.id]!.price.amount)}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  MiniBTN(
                                    name: 'قیمت',
                                    noFlex: true,
                                    icon: IconsaxPlusLinear.arrow_down_1,
                                    onTap:
                                        _page.c.loading.value ||
                                            _page.c.choosing.value
                                        ? null
                                        : () {
                                            selectPrice(variant);
                                          },
                                  ),
                                ],
                              ),
                              onTap:
                                  _page.c.loading.value ||
                                      _page.c.choosing.value
                                  ? null
                                  : () {
                                      if (_page.selected.containsKey(
                                        variant.id,
                                      )) {
                                        {
                                          _page.selected.remove(variant.id);
                                          _page.update();
                                        }
                                      } else {
                                        choose(variant);
                                      }
                                    },
                            ),
                        ],
                      ),
              ),
          ],
        ),
        footer: BTN(
          name: 'تایید انتخاب شده‌ها',
          icon: IconsaxPlusLinear.tick_square,
          disabled:
              _page.c.loading.value ||
              _page.c.choosing.value ||
              _page.c.error.value != null,
          onTap: () {
            try {
              _page.c.check();
              Get.back(result: _page.selected.values.toList());
            } catch (failure) {
              _page.c.reportError(PimFX.message(failure));
            }
          },
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant _SaleProductPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

class _SaleCustomerPicker extends StatefulWidget {
  final RemoteCustomersController controller;
  final ScrollController scroll;
  const _SaleCustomerPicker({required this.controller, required this.scroll});
  @override
  State<_SaleCustomerPicker> createState() => _SaleCustomerPickerState();
}

class _SaleCustomerPickerState extends State<_SaleCustomerPicker> {
  RemoteCustomersController get c => widget.controller;
  final search = TextEditingController();
  Worker? errors;
  @override
  void initState() {
    super.initState();
    errors = ever(c.error, (value) {
      if (mounted && value != null) Alert.error(value, context: context);
    });
  }

  @override
  void dispose() {
    errors?.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> add() async {
    final fx = c.fx;
    if (fx == null || c.loading.value || c.editing) return;
    c.editing = true;
    try {
      fx.check();
      await Get.toNamed<dynamic>(
        nav_routes.RoutesName.CUSTOMER_FORM,
        arguments: {'fx': fx, 'customerId': fx.pending?.customerId},
        preventDuplicates: false,
      );
      if (mounted) await c.load();
    } catch (failure) {
      if (mounted) Alert.error(CustomersFX.message(failure), context: context);
    } finally {
      c.editing = false;
    }
  }

  @override
  Widget build(BuildContext context) => Obx(
    () => Column(
      children: [
        MySearchBar(
          type: SearchBarType.user,
          hintText: 'جستجو',
          controller: search,
          enableScanner: false,
          callback: (value) => c.search(value.toString()),
        ),
        if (c.loading.value || c.moreLoading.value)
          const LinearProgressIndicator(),
        if (c.searchHint.value != null) Text(c.searchHint.value!),
        if (c.error.value != null) ...[
          Text(c.error.value!, textAlign: TextAlign.center),
          MiniBTN(
            name: 'تلاش مجدد',
            noFlex: true,
            icon: IconsaxPlusLinear.refresh,
            onTap: c.loading.value
                ? null
                : () => c.load(more: c.items.isNotEmpty),
          ),
        ],
        Expanded(
          child: ListView(
            controller: widget.scroll,
            children: [
              if (!c.loading.value &&
                  c.items.isEmpty &&
                  c.error.value == null &&
                  c.searchHint.value == null)
                const Center(
                  child: Text(
                    'شخصی با این مشخصات وجود ندارد!',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              for (final customer in c.items)
                InvoicePersonItem(
                  key: ValueKey('sale-customer-${customer.id}'),
                  name: customer.name,
                  phone: customer.phone,
                  role: 'مشتری',
                  icon: customer.kind == 'ORGANIZATION'
                      ? SvgIcon.orgCustomer
                      : SvgIcon.customer,
                  onTap: () {
                    try {
                      c.fx!.check();
                      Get.back(result: customer);
                    } catch (failure) {
                      c.error.value = CustomersFX.message(failure);
                    }
                  },
                ),
              if (c.next.value != null)
                MiniBTN(
                  name: 'نمایش بیشتر',
                  noFlex: true,
                  icon: IconsaxPlusLinear.arrow_down,
                  onTap: c.moreLoading.value ? null : () => c.load(more: true),
                ),
            ],
          ),
        ),
        Row(
          children: [
            if (c.fx?.has('ucrm.customer.create') == true)
              Expanded(
                flex: 2,
                child: BTN(
                  name: 'مشتری جدید',
                  icon: IconsaxPlusLinear.add,
                  navigate: true,
                  disabled: c.loading.value || c.editing,
                  onTap: () {
                    add();
                  },
                ),
              ),
            Expanded(
              child: BTN(
                name: 'انصراف',
                type: BTNType.cancel,
                onTap: () => Get.back(),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildSaleProductPickerRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _SaleProductPicker(c: args.required<SaleProductsController>('c'));
}
