import 'package:mik_router/mik_router.dart' as nav_routes;

import 'components/selectproduct.dart';

import 'package:mik_pages/product/screen/screen.dart' show PimProductItem;
import 'package:mik_data/utils/fx/product_facts.dart';
import 'package:mik_data/utils/fx/pim.dart';

import 'components/item/item.dart';
import 'components/item/components/amount.dart';
import 'components/item/components/price.dart';
import 'components/item/components/warehouse.dart';

import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:mik_data/source/remote/models/invoice_amounts.dart';

import '../selection_sheet.dart';

import 'package:mik_consts/svgIcon.dart';
import 'package:mik_data/utils/fx/suppliers.dart';
import 'package:mik_pages/persons/supplier/server_controller.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_utils/public/date.dart';

import 'metadata_editor.dart';
import 'amounts_editor.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_utils/public/price.dart';

import 'purchase_controller.dart';

class PurchaseInvoiceProducts extends StatefulWidget {
  final String appId;
  const PurchaseInvoiceProducts({required this.appId, super.key});
  @override
  State<PurchaseInvoiceProducts> createState() =>
      _PurchaseInvoiceProductsState();
}

class _PurchaseInvoiceProductsState extends State<PurchaseInvoiceProducts> {
  late final c = PurchaseController(
    appId: widget.appId,
    onNotice: (message, success) {
      if (!mounted) return;
      if (success) {
        Alert.success(message);
      } else {
        Alert.error(message, context: context);
      }
    },
  );
  static const paymentMethods = [
    ItemValue(text: 'نقدی', data: 'CASH'),
    ItemValue(text: 'کارت بانکی', data: 'CARD'),
    ItemValue(text: 'انتقال بانکی', data: 'BANK_TRANSFER'),
  ];
  final paymentFields = {
    for (final key in [
      'amount',
      'reference',
      'bankName',
      'number',
      'sayadId',
      'drawerName',
      'dueAt',
      'chequeAmount',
    ])
      key: TextEditingController(),
  };
  final branchField = TextEditingController();
  final partyField = TextEditingController();
  final warehouseField = TextEditingController();
  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  void dispose() {
    for (final field in paymentFields.values) {
      field.dispose();
    }
    branchField.dispose();
    partyField.dispose();
    warehouseField.dispose();
    c.onClose();
    super.dispose();
  }

  Future<void> select(bool supplier) async {
    if (c.locked) return;
    final String? selected;
    try {
      c.check();
      if (supplier) {
        final parties = SuppliersFX.forContext(c.check());
        selected = await MyBottomSheet.view(
          context,
          title: 'تامین‌کنندگان',
          titleWidget: Obx(
            () => Text(
              'تامین‌کنندگان (${c.suppliers.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          initialChildSize: 0.8,
          child: (scroll) => _PurchaseSelection(
            c: c,
            scroll: scroll,
            canCreate: parties.has('accounting.supplier.create'),
          ),
        ) as String?;
      } else {
        selected = (await selectInvoiceWarehouse(
          context,
          warehouses: c.warehouses.toList(),
          branchName: c.branchName,
          selectedId: c.warehouse.value?.warehouseId,
        ))?.warehouseId;
      }
    } catch (failure) {
      c.fail(failure);
      return;
    }
    if (!mounted || selected == null) return;
    try {
      c.check();
      if (supplier) {
        c.supplier.value = c.suppliers.singleWhere((r) => r.id == selected);
      } else {
        c.warehouse.value = c.warehouses.singleWhere(
          (r) => r.warehouseId == selected,
        );
      }
      c.notice(
        supplier ? 'تامین‌کننده انتخاب شد.' : 'انبار مقصد انتخاب شد.',
        true,
      );
    } catch (failure) {
      c.fail(failure);
    }
  }

  bool editingCheque = false;
  Widget chequeFields() => Column(
    children: [
      Input(
        controller: paymentFields['bankName']!,
        name: 'نام بانک',
        style: 2,
        fillColor: darkMode.value ? null : Colors.grey.shade300,
        maxLength: 100,
        require: true,
        onChanged: (String v) => c.cheque['bankName'] = v,
      ),
      Input(
        controller: paymentFields['number']!,
        name: 'شماره چک',
        style: 2,
        fillColor: darkMode.value ? null : Colors.grey.shade300,
        maxLength: 64,
        require: true,
        onChanged: (String v) => c.cheque['number'] = v,
      ),
      DateInput(
        controller: paymentFields['dueAt']!,
        name: 'تاریخ سررسید',
        require: true,
        fillColor: darkMode.value ? null : Colors.grey.shade300,
        onChanged: (_) {
          try {
            final parts = paymentFields['dueAt']!.text
                .toEnglishDigit()
                .split('/')
                .map(int.parse)
                .toList();
            c.chequeDueAt.value = Jalali(
              parts[0],
              parts[1],
              parts[2],
            ).toDateTime().toUtc();
          } catch (_) {
            c.chequeDueAt.value = null;
            Alert.error('سررسید چک معتبر نیست.', context: context);
          }
        },
      ),
      Input(
        controller: paymentFields['sayadId']!,
        name: 'شناسه صیادی (اختیاری)',
        style: 2,
        fillColor: darkMode.value ? null : Colors.grey.shade300,
        maxLength: 16,
        keyboardType: TextInputType.number,
        onChanged: (String v) => c.cheque['sayadId'] = v,
      ),
      Input(
        controller: paymentFields['drawerName']!,
        name: 'صادرکننده (اختیاری)',
        style: 2,
        fillColor: darkMode.value ? null : Colors.grey.shade300,
        maxLength: 200,
        onChanged: (String v) => c.cheque['drawerName'] = v,
      ),
    ],
  );

  Future<void> addCheque() async {
    if (c.locked || editingCheque) return;
    editingCheque = true;
    try {
      c.check();
      await c.invoices!.authorize();
      final sources = await c.invoices!.paymentTargets('CHEQUE');
      c.check();
      if (!mounted) return;
      if (sources.isEmpty) {
        Alert.error(
          'حساب بانکی فعال و مجاز برای صدور چک وجود ندارد.',
          context: context,
        );
        return;
      }
      final sheet = _PurchaseChequeSheetController();
      c.cheque.clear();
      c.chequeDueAt.value = null;
      for (final key in [
        'bankName',
        'number',
        'sayadId',
        'drawerName',
        'dueAt',
        'chequeAmount',
      ]) {
        paymentFields[key]!.clear();
      }
      await MyBottomSheet.view(
        context,
        title: 'افزودن چک',
        child: (scroll) => GetBuilder<_PurchaseChequeSheetController>(
          init: sheet,
          global: false,
          dispose: (state) => state.controller?.onDelete(),
          builder: (_) => SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                Dropdown(
                  name: 'حساب بانکی مبدا',
                  itemValue: true,
                  require: true,
                  items_Value: [
                    for (final row in sources)
                      ItemValue(text: row.name, data: row.id),
                  ],
                  defaultValue: sheet.sourceId == null
                      ? null
                      : ItemValue(text: '', data: sheet.sourceId),
                  onChange: (v) {
                    sheet.sourceId = (v as ItemValue).data as String;
                    sheet.update();
                  },
                ),
                PriceInput(
                  key: const ValueKey('purchase-cheque-amount'),
                  controller: paymentFields['chequeAmount']!,
                  name: 'مبلغ چک',
                  currency: 'تومان',
                  require: true,
                  fillColor: darkMode.value ? null : Colors.grey.shade300,
                ),
                chequeFields(),
                BTN(
                  name: 'افزودن چک به فاکتور',
                  onTap: () {
                    if (sheet.sourceId == null) {
                      Alert.error(
                        'حساب بانکی چک را انتخاب کنید.',
                        context: context,
                      );
                      return;
                    }
                    try {
                      if (c.addChequePayment(
                        sources.firstWhere((row) => row.id == sheet.sourceId),
                        paymentFields['chequeAmount']!.text,
                      )) {
                        Get.back();
                      }
                    } catch (failure) {
                      c.fail(failure);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } catch (failure) {
      c.fail(failure);
    } finally {
      editingCheque = false;
    }
  }

  Widget paymentFieldsView() {
    final targets = [
      for (final row in c.paymentTargets)
        ItemValue(text: row.name, data: row.id),
    ];
    int? remaining;
    try {
      if (c.total != null) remaining = c.total! - c.scheduledAmount;
    } on FormatException {
      /* Invalid draft amounts are shown by paymentError. */
    }
    return Column(
      children: [
        MyDivider(text: 'تسویه و پرداخت فاکتور'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مبلغ کل: ',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
        MyTab(
          tab: const ['نقدی', 'اقساطی'],
          value: c.paymentTab,
          enabledValues: c.locked ? <String>{} : null,
          callback: (String value) => c.selectPaymentMode(
            value == 'نقدی' ? 'پرداخت کامل' : 'بخشی از مبلغ',
          ),
        ),
        const SizedBox(height: 10),
        if (c.paymentTab.value == 'اقساطی')
          PriceInput(
            key: const ValueKey('purchase-payment-amount'),
            controller: paymentFields['amount']!,
            name: 'پرداخت اولیه',
            rightPadding: 110,
            fillColor: darkMode.value ? null : Colors.grey.shade300,
            currency: 'تومان',
            readOnly: c.locked,
            onChanged: (String value) => c.setPaymentAmount(value),
          ),
        if (c.hasPayment) ...[
          Dropdown(
            key: const ValueKey('purchase-payment-method'),
            name: 'روش پرداخت',
            itemValue: true,
            search: false,
            disable: c.locked,
            items_Value: paymentMethods,
            defaultValue: paymentMethods.firstWhere(
              (row) => row.data == c.paymentMethod.value,
            ),
            onChange: (v) =>
                c.selectPaymentMethod((v as ItemValue).data as String),
          ),
          if (c.paymentLoading.value)
            const LinearProgressIndicator()
          else
            Dropdown(
              key: ValueKey('purchase-payment-target-${c.paymentMethod.value}'),
              name: c.paymentMethod.value == 'CASH'
                  ? 'صندوق مبدا'
                  : 'حساب بانکی مبدا',
              require: true,
              itemValue: true,
              disable: c.locked,
              items_Value: targets,
              defaultValue: targets.firstWhereOrNull(
                (row) => row.data == c.paymentTarget.value?.id,
              ),
              onChange: (v) {
                c.paymentTarget.value = c.paymentTargets.firstWhere(
                  (row) => row.id == (v as ItemValue).data,
                );
                c.error.value = null;
              },
            ),
          if (!c.paymentLoading.value && c.paymentTargets.isEmpty)
            MiniBTN(
              name: 'دریافت مجدد مبداهای پرداخت',
              noFlex: true,
              icon: IconsaxPlusLinear.refresh,
              onTap: c.locked ? null : c.loadPaymentTargets,
            ),
          Input(
            controller: paymentFields['reference']!,
            name: 'شماره پیگیری (اختیاری)',
            fillColor: darkMode.value ? null : Colors.grey.shade300,
            maxLength: 200,
            readOnly: c.locked,
            onChanged: (String value) => c.paymentReference.value = value,
          ),
        ],
        if (c.paymentTab.value == 'اقساطی') ...[
          for (var i = 0; i < c.chequePayments.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  const Icon(IconsaxPlusLinear.money_4, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'چک ${(c.chequePayments[i].payment['cheque'] as Map)['bankName']}',
                    ),
                  ),
                  Expanded(
                    child: Text(
                      Price.showWithCurrency(
                        c.chequePayments[i].payment['amount'] as int,
                      ),
                    ),
                  ),
                  Text(
                    DateConvertor.grigoriToJalali(
                      DateTime.parse(
                        (c.chequePayments[i].payment['cheque'] as Map)['dueAt']
                            as String,
                      ).toLocal(),
                    ),
                  ),
                  InkWell(
                    onTap: c.locked
                        ? null
                        : () {
                            Confirm.con(
                              context,
                              type: ConfirmType.DELETE,
                              confirmText: 'تایید و حذف',
                              onTapConfirm: () {
                                c.chequePayments.removeAt(i);
                                Get.back();
                              },
                            );
                          },
                    child: const SizedBox(
                      width: 40,
                      child: Icon(IconsaxPlusLinear.trash_square, size: 25),
                    ),
                  ),
                ],
              ),
            ),
            EndLine(show: i + 1 < c.chequePayments.length, rightPadding: 40),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 5, bottom: 5),
            child: Row(
              children: [
                const Spacer(flex: 2),
                Expanded(
                  child: BTN(
                    name: 'افزودن چک',
                    icon: IconsaxPlusLinear.money_4,
                    disabled: c.locked,
                    onTap: () {
                      addCheque();
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'مانده برنامه پرداخت: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Flexible(
                  child: Text(
                    remaining == null || remaining < 0
                        ? 'مبلغ نامعتبر'
                        : Price.showWithCurrency(remaining),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
          if (c.chequePayments.isNotEmpty)
            const Text(
              'چک تا وصول، تسویه قطعی نیست. مانده نهایی پس از اعمال اعتبارهای قبلی و وصول چک از سرور دریافت می‌شود.',
            ),
        ],
        if (c.paymentError != null)
          Text(c.paymentError!, textAlign: TextAlign.center),
      ],
    );
  }

  Future<void> complete() async {
    if (c.locked) return;
    if (c.supplier.value == null ||
        c.warehouse.value == null ||
        c.subtotal == null ||
        c.lines.isEmpty) {
      Alert.error(
        'تامین‌کننده، انبار مقصد، تعداد و قیمت خرید اقلام را کامل کنید.',
        context: context,
      );
      return;
    }
    paymentFields['amount']!.text = c.paymentAmount.value;
    paymentFields['reference']!.text = c.paymentReference.value;
    for (final key in ['bankName', 'number', 'sayadId', 'drawerName']) {
      paymentFields[key]!.text = c.cheque[key] ?? '';
    }
    paymentFields['dueAt']!.text = c.chequeDueAt.value == null
        ? ''
        : DateConvertor.grigoriToJalali(c.chequeDueAt.value!.toLocal());
    var amountsValid = true, metadataValid = true;
    await MyBottomSheet.view(
      context,
      title: 'تکمیل فاکتور',
      child: (scroll) => SingleChildScrollView(
        controller: scroll,
        child: Obx(() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InvoiceAmountsEditor(
                embedded: true,
                initial: c.amounts.value,
                subtotal: c.subtotal!,
                canDiscount: c.canDiscount,
                canSurcharge: c.canSurcharge,
                purchase: true,
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
              paymentFieldsView(),
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
      Alert.error(
        c.paymentError ??
            (c.subtotal != null && c.total == null
                ? 'مبلغ تخفیف و هزینه‌های فاکتور را بررسی کنید؛ تخفیف نباید بیشتر از جمع اقلام باشد.'
                : 'تامین‌کننده، انبار مقصد، تعداد و قیمت خرید اقلام را کامل کنید.'),
        context: context,
      );
      return;
    }
    Confirm.con(
      context,
      type: ConfirmType.SAVE,
      confirmText: 'ثبت نهایی',
      subtext:
          'فاکتور خرید از ${c.supplier.value!.name} به مبلغ ${Price.showWithCurrency(c.total!)} ثبت می‌شود. ${c.hasPayment
              ? c.paymentMethod.value == 'CHEQUE'
                    ? 'چک به مبلغ ${Price.showWithCurrency(c.outgoingAmount)} از حساب ${c.paymentTarget.value!.name} ثبت خواهد شد و تا وصول، تسویه قطعی نیست.'
                    : 'پرداخت واقعی ${Price.showWithCurrency(c.outgoingAmount)} از ${c.paymentTarget.value!.name} را تأیید می‌کنید.'
              : 'پرداخت اولیه جدیدی ثبت نمی‌شود.'} ${c.chequePayments.isEmpty ? '' : '${c.chequePayments.length} چک در انتظار وصول ثبت می‌شود.'} کالاها وارد ${c.warehouse.value!.name} می‌شوند.',
      onTapConfirm: () async {
        Get.back();
        // Close the completion sheet before showing the server result on the page.
        Get.back();
        await c.submit();
      },
    );
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    branchField.text = c.branchName;
    final supplier = c.supplier.value;
    partyField.text = supplier == null
        ? ''
        : supplier.phone == null
        ? supplier.name
        : '${supplier.name} (${supplier.phone})';
    warehouseField.text = c.warehouse.value?.name ?? '';
    final groups = <String, List<PurchaseLine>>{};
    for (final row in c.lines) {
      (groups[row.product.id] ??= []).add(row);
    }
    return Column(
      children: [
        Input(controller: branchField, name: 'شعبه', readOnly: true),
        if (c.loading.value || c.saving.value) const LinearProgressIndicator(),
        if (c.error.value != null)
          Text(c.error.value!, textAlign: TextAlign.center),
        if (c.error.value != null && c.pending.value == null)
          MiniBTN(
            name: 'تلاش مجدد',
            icon: IconsaxPlusLinear.refresh,
            noFlex: true,
            onTap: c.locked ? null : c.load,
          ),
        Input(
          key: const ValueKey('invoice-party-picker'),
          controller: partyField,
          name: 'تامین‌کننده',
          hintText: 'انتخاب تامین‌کننده',
          require: true,
          readOnly: true,
          onTap: c.locked ? null : () => select(true),
          suffixIcon: const Icon(IconsaxPlusLinear.arrow_down, size: 18),
        ),
        Input(
          key: const ValueKey('invoice-warehouse-picker'),
          controller: warehouseField,
          name: 'انبار مقصد',
          hintText: 'انتخاب انبار مقصد',
          require: true,
          readOnly: true,
          onTap: c.locked ? null : () => select(false),
          suffixIcon: const Icon(IconsaxPlusLinear.arrow_down, size: 18),
        ),
        if (!c.loading.value && c.warehouses.isEmpty && c.pending.value == null)
          const Text(
            'انبار فعال با مجوز ورود کالا برای این شعبه موجود نیست.',
            textAlign: TextAlign.center,
          ),
        Expanded(
          child: ListView(
            children: [
              if (c.lines.isEmpty && c.pending.value == null)
                const Center(child: Text('محصولی انتخاب نشده است.')),
              if (c.pending.value != null && c.lines.isEmpty) ...[
                MyDivider(text: 'درخواست ذخیره‌شده'),
                Text('تامین‌کننده: ${c.pending.value!.body['supplierId']}'),
                if (c.pending.value!.body['dueAt'] != null)
                  Text(
                    'سررسید: ${DateConvertor.grigoriToJalali(DateTime.parse(c.pending.value!.body['dueAt'] as String).toLocal())} ${DateConvertor.showTime(DateTime.parse(c.pending.value!.body['dueAt'] as String).toLocal())}',
                  ),
                if (c.pending.value!.body['note'] != null)
                  Text(c.pending.value!.body['note'] as String),
                for (final row in c.pending.value!.body['lines'] as List)
                  ListTile(
                    title: Text('تنوع: ${row['variantId']}'),
                    subtitle: Text(
                      'تعداد: ${row['quantity']} — قیمت خرید: ${row['unitPrice']} تومان\nانبار: ${(row['warehouseIds'] as List).single}',
                    ),
                  ),
              ],
              for (final rows in groups.values)
                for (final row in rows)
                  _PurchaseRow(
                    key: ValueKey(row.variant.id),
                    row: row,
                    c: c,
                    showHeader: row == rows.first,
                    showDivider: row == rows.last,
                    onWarehouse: () => select(false),
                  ),
            ],
          ),
        ),
        BTN(
          name: 'افزودن کالا',
          color: darkMode.isFalse ? Colors.grey.shade900 : Colors.grey.shade700,
          icon: IconsaxPlusLinear.box,
          navigate: true,
          disabled: c.locked || c.error.value != null,
          onTap: () async {
            try {
              c.check();
              await Get.toNamed(
                nav_routes.RoutesName.PURCHASE_PRODUCTS,
                arguments: {'c': c},
                preventDuplicates: false,
              );
            } catch (failure) {
              c.fail(failure);
            }
          },
        ),
        if (c.pending.value == null || c.lines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'مبلغ سفارش: ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Flexible(
                  child: Text(
                    c.total == null
                        ? 'تعداد یا قیمت خرید اقلام را بررسی کنید.'
                        : Price.showWithCurrency(c.total!),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        if (c.pending.value != null)
          Text(
            'وضعیت ثبت: ${switch (c.operation.value?.status) {
              'PENDING' => 'در انتظار ثبت',
              'PROCESSING' => 'در حال ثبت',
              'RETRY' => 'تلاش مجدد سرور',
              'ACTION_REQUIRED' => 'نیازمند بررسی مدیر',
              'FAILED' => 'ناموفق: ${c.operation.value?.errorCode ?? 'کد خطا اعلام نشده'}',
              'SUCCEEDED' => c.issued.value == null ? 'ثبت قطعی؛ در انتظار دریافت مشخصات فاکتور' : 'ثبت قطعی',
              _ => 'پاسخ دریافت نشده؛ همان درخواست را پیگیری کنید',
            }}',
            textAlign: TextAlign.center,
          ),
        if (c.issued.value != null) ...[
          Text('شماره فاکتور: ${c.issued.value!.number}'),
          Text('مبلغ قطعی: ${Price.showWithCurrency(c.issued.value!.total)}'),
          const Text('ورود کالا به انبار ثبت شد.'),
          BTN(name: 'فاکتور جدید', disabled: c.saving.value, onTap: c.reset),
        ] else if (c.operation.value?.status == 'FAILED')
          BTN(name: 'فاکتور جدید', disabled: c.saving.value, onTap: c.reset)
        else if (c.pending.value != null)
          BTN(
            name: 'پیگیری ثبت فاکتور',
            disabled:
                c.saving.value ||
                c.loading.value ||
                c.operation.value?.status == 'ACTION_REQUIRED',
            onTap: c.submit,
          )
        else
          BTN(
            name: 'ادامه',
            navigate: true,
            disabled: c.locked,
            onTap: () {
              complete();
            },
          ),
      ],
    );
  });
}

class _PurchaseRow extends StatefulWidget {
  final PurchaseLine row;
  final PurchaseController c;
  final VoidCallback onWarehouse;
  final bool showHeader, showDivider;
  const _PurchaseRow({
    required this.row,
    required this.c,
    required this.onWarehouse,
    required this.showHeader,
    required this.showDivider,
    super.key,
  });
  @override
  State<_PurchaseRow> createState() => _PurchaseRowState();
}

class _PurchaseRowState extends State<_PurchaseRow> {
  late final price = TextEditingController(text: widget.row.price);
  @override
  void dispose() {
    price.dispose();
    super.dispose();
  }

  void remove() {
    if (widget.c.locked) return;
    try {
      widget.c.check();
      widget.c.lines.remove(widget.row);
      widget.c.notice('کالا از فاکتور حذف شد.', true);
    } catch (failure) {
      widget.c.fail(failure);
    }
  }

  Future<void> editPrice() async {
    if (widget.c.locked) return;
    await MyBottomSheet.view(
      context,
      title: 'قیمت خرید محصول',
      child: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PriceInput(
            key: ValueKey('purchase-price-${widget.row.variant.id}'),
            controller: price,
            name: 'قیمت خرید واحد',
            currency: 'تومان',
          ),
          BTN(
            name: 'تایید قیمت',
            onTap: () {
              try {
                if (price.text.trim().isEmpty) {
                  throw const FormatException('Missing purchase price');
                }
                widget.c.check();
                widget.c.setLine(
                  widget.row,
                  price: InvoiceAmounts.parse(price.text).toString(),
                );
                Get.back();
              } catch (failure) {
                widget.c.fail(failure);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ProductItemInvoice.remote(
    name: widget.row.product.name,
    showHeader: widget.showHeader,
    showDivider: widget.showDivider,
    variant: widget.row.variant.optionValues.isEmpty
        ? null
        : widget.row.variant.name,
    quantity: AmountChangeInvoice.remote(
      key: ValueKey('purchase-quantity-${widget.row.variant.id}'),
      quantity: widget.row.quantity,
      locked: widget.c.locked,
      onChanged: (value) => widget.c.setLine(widget.row, quantity: value),
      onRemove: remove,
    ),
    warehouse: WarehouseChangeInvoice.remote(
      value: widget.c.warehouse.value?.name ?? 'انتخاب انبار',
      onTap: widget.c.locked ? null : widget.onWarehouse,
    ),
    price: PriceChangeInvoice.remote(
      key: ValueKey('purchase-price-control-${widget.row.variant.id}'),
      value: widget.row.price.isEmpty
          ? 'انتخاب قیمت خرید'
          : Price.showWithCurrency(widget.row.unitPrice),
      onTap: widget.c.locked ? null : editPrice,
    ),
  );
}

class _PurchaseSelection extends StatefulWidget {
  final PurchaseController c;
  final ScrollController scroll;
  final bool canCreate;
  const _PurchaseSelection({
    required this.c,
    required this.scroll,
    required this.canCreate,
  });
  @override
  State<_PurchaseSelection> createState() => _PurchaseSelectionState();
}

class _PurchaseSelectionController extends GetxController {
  final search = TextEditingController();
  String query = '';
  bool adding = false;
}

class _PurchaseSelectionState extends State<_PurchaseSelection> {
  late final _page = _PurchaseSelectionController();

  @override
  void dispose() {
    _page.search.dispose();
    super.dispose();
  }

  Future<void> add() async {
    if (_page.adding || widget.c.locked) return;
    {
      _page.adding = true;
      _page.update();
    }
    final form = SuppliersController(
      appId: widget.c.appId,
      onNotice: (message, success) {
        if (!mounted) return;
        if (success) {
          Alert.success(message);
        } else {
          Alert.error(message, context: context);
        }
      },
    );
    try {
      widget.c.check();
      await form.load();
      if (!mounted) return;
      if (!form.canCreate) {
        Alert.error(
          form.error.value ?? 'اجازه افزودن تامین‌کننده ندارید یا درخواست قبلی تعیین‌تکلیف نشده است.',
          context: context,
        );
        return;
      }
      await Get.toNamed(
        nav_routes.RoutesName.SUPPLIER_FORM,
        arguments: {'c': form},
        preventDuplicates: false,
      );
      if (mounted) await widget.c.load();
    } catch (failure) {
      if (mounted) widget.c.fail(failure);
    } finally {
      form.onClose();
      if (mounted) {
        _page.adding = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      GetBuilder<_PurchaseSelectionController>(
        init: _page,
        global: false,
        dispose: (state) => state.controller?.onDelete(),
        builder: (_) => Obx(() {
          final rows = widget.c.suppliers
              .where(
                (row) => '${row.name} ${row.phone ?? ''}'
                    .toLowerCase()
                    .toEnglishDigit()
                    .contains(_page.query),
              )
              .toList();
          return Column(
            children: [
              MySearchBar(
                controller: _page.search,
                type: SearchBarType.user,
                enableScanner: false,
                hintText: 'جستجو',
                callback: (value) {
                  _page.query = value
                      .toString()
                      .trim()
                      .toLowerCase()
                      .toEnglishDigit();
                  _page.update();
                },
              ),
              if (_page.adding || widget.c.loading.value)
                const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  controller: widget.scroll,
                  children: [
                    if (rows.isEmpty && !widget.c.loading.value)
                      const Center(
                        child: Text(
                          'شخصی با این مشخصات وجود ندارد!',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    for (final row in rows)
                      InvoicePersonItem(
                        key: ValueKey('invoice-supplier-${row.id}'),
                        name: row.name,
                        phone: row.phone,
                        role: 'تامین‌کننده',
                        icon: SvgIcon.supplier,
                        onTap: () {
                          if (_page.adding ||
                              widget.c.loading.value ||
                              widget.c.locked) {
                            return;
                          }
                          try {
                            widget.c.check();
                            Get.back(result: row.id);
                          } catch (failure) {
                            widget.c.fail(failure);
                          }
                        },
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (widget.canCreate)
                    Expanded(
                      flex: 2,
                      child: BTN(
                        name: 'تامین‌کننده جدید',
                        icon: IconsaxPlusLinear.add,
                        navigate: true,
                        disabled:
                            _page.adding ||
                            widget.c.loading.value ||
                            widget.c.locked,
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
          );
        }),
      );
}

class _PurchaseProducts extends StatefulWidget {
  final PurchaseController c;
  const _PurchaseProducts({required this.c});
  @override
  State<_PurchaseProducts> createState() => _PurchaseProductsState();
}

class _PurchaseProductsController extends GetxController {
  _PurchaseProductsController(this.widget);
  _PurchaseProducts widget;
  late final rowFacts = ProductFactsFX(PimFX.forContext(widget.c.check()));
  final search = TextEditingController();
  String query = '';
  PimProduct? product;
  List<PimCategory> categories = [];
  String? category;
}

class _PurchaseProductsState extends State<_PurchaseProducts> {
  late final _page = _PurchaseProductsController(widget);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final fx = PimFX.forContext(widget.c.check());
        if (fx.has('pim.category.read')) {
          final rows = (await fx.all(PimResource.categories))
              .cast<PimCategory>();
          widget.c.check();
          if (mounted) {
            {
              _page.categories = rows
                  .where(
                    (row) => widget.c.products.any(
                      (p) => p.categoryIds.contains(row.id),
                    ),
                  )
                  .toList();
              _page.update();
            }
          }
        }
      } catch (failure) {
        if (mounted) widget.c.fail(failure);
      }
    });
  }

  @override
  void dispose() {
    _page.search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_PurchaseProductsController>(
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
            if (widget.c.loading.value) const LinearProgressIndicator(),
            if (widget.c.error.value != null)
              Text(widget.c.error.value!, textAlign: TextAlign.center),
            if (!widget.c.loading.value &&
                !widget.c.products.any(
                  (p) =>
                      p.name.contains(_page.query) &&
                      (_page.category == null ||
                          p.categoryIds.contains(_page.category)),
                ))
              const Center(child: Text('محصولی یافت نشد.')),
            for (final row in widget.c.products.where(
              (p) =>
                  p.name.contains(_page.query) &&
                  (_page.category == null ||
                      p.categoryIds.contains(_page.category)),
            ))
              ProductItemSelect.remote(
                key: ValueKey('invoice-product-${row.id}'),
                isSelected: widget.c.lines.any(
                  (line) => line.product.id == row.id,
                ),
                content: PimProductItem(
                  row,
                  facts: _page.rowFacts,
                  categories: _page.categories
                      .where((cat) => row.categoryIds.contains(cat.id))
                      .map((cat) => cat.name)
                      .join('، '),
                  onTap: widget.c.loading.value
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
                          await widget.c.open(row);
                        },
                ),
                variants: _page.product?.id != row.id
                    ? null
                    : Column(
                        children: [
                          if (!widget.c.loading.value &&
                              widget.c.variants.isEmpty)
                            const Text('تنوع فعالی یافت نشد.'),

                          for (final variant in widget.c.variants)
                            ProductItemSelect.variant(
                              key: ValueKey('invoice-variant-${variant.id}'),
                              variant: variant,
                              attributes: widget.c.attributes,
                              isSelected: widget.c.lines.any(
                                (line) => line.variant.id == variant.id,
                              ),
                              onTap: widget.c.loading.value
                                  ? null
                                  : () {
                                      try {
                                        widget.c.check();
                                        final existing = widget.c.lines
                                            .where(
                                              (row) =>
                                                  row.variant.id == variant.id,
                                            )
                                            .firstOrNull;
                                        if (existing != null) {
                                          widget.c.lines.remove(existing);
                                        } else {
                                          widget.c.add(_page.product!, variant);
                                        }
                                      } catch (failure) {
                                        widget.c.fail(failure);
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
          disabled: widget.c.loading.value || widget.c.error.value != null,
          onTap: () {
            try {
              widget.c.check();
              Get.back();
            } catch (failure) {
              widget.c.fail(failure);
            }
          },
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant _PurchaseProducts oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

class _PurchaseChequeSheetController extends GetxController {
  String? sourceId;
}

Widget buildPurchaseProductsRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _PurchaseProducts(c: args.required<PurchaseController>('c'));
}
