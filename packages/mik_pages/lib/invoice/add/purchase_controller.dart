import 'package:mik_data/source/remote/models/invoice_amounts.dart';
import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/sale_invoice.dart';
import 'package:mik_data/utils/fx/suppliers.dart';
import 'package:mik_data/utils/fx/warehouse_management.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import 'sale_products_controller.dart' show SaleInvoiceLine;

class PurchaseLine {
  final PimProduct product;
  final PimVariant variant;
  String quantity, price;
  PurchaseLine(
    this.product,
    this.variant, {
    this.quantity = '1',
    this.price = '',
  });
  int get unitPrice {
    final value = price.trim().toEnglishDigit();
    if (!RegExp(r'^(0|[1-9]\d*)$').hasMatch(value)) {
      throw const FormatException('Invalid purchase price');
    }
    final number = BigInt.parse(value);
    if (number > BigInt.parse('9007199254740991')) {
      throw const FormatException('Unsafe purchase price');
    }
    return number.toInt();
  }

  int get amount {
    final parts = SaleInvoiceLine.normalizedQuantity(quantity).split('.');
    final units =
        BigInt.parse(parts[0]) * BigInt.from(1000000) +
        BigInt.parse((parts.length == 1 ? '' : parts[1]).padRight(6, '0'));
    final total =
        (BigInt.from(unitPrice) * units + BigInt.from(500000)) ~/
        BigInt.from(1000000);
    if (total > BigInt.parse('9007199254740991')) {
      throw const FormatException('Unsafe purchase amount');
    }
    return total.toInt();
  }

  Map<String, Object> toJson(String warehouseId) => {
    'variantId': variant.id,
    'quantity': SaleInvoiceLine.normalizedQuantity(quantity),
    'unitPrice': unitPrice,
    'warehouseIds': [warehouseId],
  };
}

class PurchaseController extends GetxController {
  final String appId;
  final void Function(String message, bool success)? onNotice;
  PurchaseController({required this.appId, this.onNotice});
  final loading = false.obs, saving = false.obs;
  final error = RxnString();
  final products = <PimProduct>[].obs, variants = <PimVariant>[].obs;
  final attributes = <PimAttribute>[];
  final suppliers = <RemoteSupplier>[].obs;
  final warehouses = <BusinessWarehouse>[].obs;
  final supplier = Rxn<RemoteSupplier>(), warehouse = Rxn<BusinessWarehouse>();
  final lines = <PurchaseLine>[].obs;
  final pending = Rxn<SaleInvoiceCommand>();
  final operation = Rxn<SaleOperation>();
  final issued = Rxn<SaleInvoiceResult>();
  final dueAt = Rxn<DateTime>();
  final note = ''.obs;
  final amounts = const InvoiceAmounts().obs;
  bool get canDiscount =>
      invoices?.has('accounting.purchase.discount.apply') == true;
  bool get canSurcharge =>
      invoices?.has('accounting.purchase.surcharge.apply') == true;
  void requireAmounts() {
    final value = amounts.value;
    if (value.discount > 0) {
      invoices!.require('accounting.purchase.discount.apply');
    }
    if (value.shipping > 0 || value.surcharge > 0 || value.tax > 0) {
      invoices!.require('accounting.purchase.surcharge.apply');
    }
  }

  final paymentMode = 'بدون پرداخت'.obs, paymentMethod = 'CASH'.obs;
  final paymentTab = 'اقساطی'.obs;
  final chequePayments =
      <({Map<String, Object> payment, String sourceName})>[].obs;
  final paymentAmount = ''.obs, paymentReference = ''.obs;
  final cheque = <String, String>{}.obs;
  final chequeDueAt = Rxn<DateTime>();
  final paymentLoading = false.obs;
  final paymentTargets = <SalePaymentTarget>[].obs;
  final paymentTarget = Rxn<SalePaymentTarget>();
  int _paymentGeneration = 0;
  bool get hasPayment {
    if ((total ?? 0) <= 0 || paymentMode.value == 'بدون پرداخت') return false;
    if (paymentMode.value == 'پرداخت کامل') return true;
    try {
      return InvoiceAmounts.parse(paymentAmount.value) > 0;
    } on FormatException {
      return true;
    }
  }

  int get scheduledAmount =>
      (hasPayment ? outgoingAmount : 0) +
      chequePayments.fold<int>(
        0,
        (sum, row) => sum + (row.payment['amount'] as int),
      );
  String? get chequeError {
    final bank = cheque['bankName']?.trim() ?? '',
        number = cheque['number']?.trim() ?? '';
    if (bank.isEmpty ||
        bank.length > 100 ||
        number.isEmpty ||
        number.length > 64 ||
        chequeDueAt.value == null) {
      return 'نام بانک، شماره و سررسید چک را کامل کنید.';
    }
    final sayad = (cheque['sayadId'] ?? '').trim().toEnglishDigit();
    if (sayad.isNotEmpty && !RegExp(r'^\d{16}$').hasMatch(sayad)) {
      return 'شناسه صیادی باید ۱۶ رقم باشد.';
    }
    if ((cheque['drawerName']?.trim().length ?? 0) > 200 ||
        cheque.values.any((v) => RegExp(r'[\x00-\x1f]').hasMatch(v))) {
      return 'اطلاعات چک معتبر نیست.';
    }
    return null;
  }

  Map<String, Object> get chequeData => {
    'bankName': cheque['bankName']!.trim(),
    'number': cheque['number']!.trim().toEnglishDigit(),
    'dueAt': chequeDueAt.value!.toUtc().toIso8601String(),
    if ((cheque['sayadId'] ?? '').trim().isNotEmpty)
      'sayadId': cheque['sayadId']!.trim().toEnglishDigit(),
    if ((cheque['drawerName'] ?? '').trim().isNotEmpty)
      'drawerName': cheque['drawerName']!.trim(),
  };
  bool addChequePayment(SalePaymentTarget target, String amountText) {
    if (locked) return false;
    try {
      check();
      final amount = InvoiceAmounts.parse(amountText);
      if (chequeError != null) {
        notice(chequeError!, false);
        return false;
      }
      if (target.kind != 'BANK' ||
          amount <= 0 ||
          total == null ||
          scheduledAmount + amount > total! ||
          chequePayments.length + (hasPayment ? 1 : 0) >= 10) {
        notice(
          'مبلغ و حساب چک را بررسی کنید؛ مجموع پرداخت‌ها نباید از مبلغ فاکتور بیشتر باشد و حداکثر ۱۰ پرداخت مجاز است.',
          false,
        );
        return false;
      }
      chequePayments.add((
        payment: Map.unmodifiable({
          'method': 'CHEQUE',
          'direction': 'OUT',
          'amount': amount,
          'routing': target.routing,
          'cheque': chequeData,
        }),
        sourceName: target.name,
      ));
      cheque.clear();
      chequeDueAt.value = null;
      notice(
        'چک به پیش‌نویس فاکتور اضافه شد؛ هنوز در سرور ثبت نشده است.',
        true,
      );
      return true;
    } on FormatException {
      notice('مبلغ چک معتبر نیست.', false);
      return false;
    }
  }

  int get outgoingAmount => paymentMode.value == 'پرداخت کامل'
      ? total!
      : InvoiceAmounts.parse(paymentAmount.value);
  String? get paymentError {
    try {
      if (total != null && scheduledAmount > total! ||
          chequePayments.length + (hasPayment ? 1 : 0) > 10) {
        return 'مجموع یا تعداد پرداخت‌های فاکتور معتبر نیست.';
      }
    } on FormatException {
      return 'مبلغ پرداخت اولیه معتبر نیست.';
    }
    if (!hasPayment) return null;
    if (paymentLoading.value) {
      return 'دریافت مبداهای پرداخت هنوز تمام نشده است.';
    }
    if (paymentTarget.value == null ||
        !paymentTarget.value!.accepts(paymentMethod.value, direction: 'OUT')) {
      return 'حساب یا صندوق مبدا پرداخت را انتخاب کنید.';
    }
    try {
      final amount = outgoingAmount;
      if (amount <= 0 ||
          amount > total! ||
          paymentMode.value == 'بخشی از مبلغ' && amount >= total!) {
        return 'مبلغ پرداخت جزئی باید مثبت و کمتر از کل فاکتور باشد.';
      }
    } on FormatException {
      return 'مبلغ پرداخت را به تومان و به صورت عدد صحیح وارد کنید.';
    }
    if (paymentReference.value.trim().length > 200 ||
        RegExp(r'[\x00-\x1f]').hasMatch(paymentReference.value)) {
      return 'شماره پیگیری معتبر نیست؛ حداکثر ۲۰۰ نویسه.';
    }
    if (paymentMethod.value == 'CHEQUE') return chequeError;
    return null;
  }

  void clearPayment() {
    _paymentGeneration++;
    paymentMode.value = 'بدون پرداخت';
    paymentTab.value = 'اقساطی';
    chequePayments.clear();
    paymentMethod.value = 'CASH';
    paymentAmount.value = '';
    paymentReference.value = '';
    paymentTarget.value = null;
    paymentTargets.clear();
    paymentLoading.value = false;
    cheque.clear();
    chequeDueAt.value = null;
  }

  Future<void> loadPaymentTargets() async {
    if (_closed || locked || !hasPayment) return;
    final generation = ++_paymentGeneration, previous = paymentTarget.value?.id;
    paymentLoading.value = true;
    paymentTarget.value = null;
    paymentTargets.clear();
    error.value = null;
    try {
      await invoices!.authorize();
      final rows = await invoices!.paymentTargets(paymentMethod.value);
      check();
      if (_closed || generation != _paymentGeneration) return;
      paymentTargets.assignAll(rows);
      paymentTarget.value = rows.firstWhereOrNull((row) => row.id == previous);
      if (rows.isEmpty) {
        notice(
          'صندوق یا حساب بانکی فعال و مجاز برای این روش پرداخت وجود ندارد.',
          false,
        );
      }
    } catch (failure) {
      if (generation == _paymentGeneration) fail(failure);
    } finally {
      if (!_closed && generation == _paymentGeneration) {
        paymentLoading.value = false;
      }
    }
  }

  void selectPaymentMode(String mode) {
    if (locked) return;
    if (!['بدون پرداخت', 'پرداخت کامل', 'بخشی از مبلغ'].contains(mode)) return;
    if (mode == 'پرداخت کامل' && chequePayments.isNotEmpty) {
      notice('برای پرداخت کامل، ابتدا چک‌های پیش‌نویس را حذف کنید.', false);
      return;
    }
    _paymentGeneration++;
    paymentLoading.value = false;
    paymentMode.value = mode;
    paymentTab.value = mode == 'پرداخت کامل' ? 'نقدی' : 'اقساطی';
    error.value = null;
    if (hasPayment) loadPaymentTargets();
  }

  void setPaymentAmount(String value) {
    if (locked) return;
    paymentAmount.value = value;
    if (paymentTab.value == 'اقساطی') paymentMode.value = 'بخشی از مبلغ';
    if (hasPayment && paymentTargets.isEmpty && !paymentLoading.value) {
      loadPaymentTargets();
    }
  }

  void selectPaymentMethod(String method) {
    if (locked || !['CASH', 'CARD', 'BANK_TRANSFER', 'CHEQUE'].contains(method)) {
      return;
    }
    paymentMethod.value = method;
    paymentTarget.value = null;
    loadPaymentTargets();
  }

  SaleInvoiceFX? invoices;
  BusinessContext? _context;
  String? _branch;
  bool _closed = false;
  bool get locked => loading.value || saving.value || pending.value != null;
  String get branchName => _context?.selectedBranch?.name ?? 'شعبه انتخاب نشده';
  int? get subtotal {
    try {
      final value = lines.fold<BigInt>(
        BigInt.zero,
        (sum, row) => sum + BigInt.from(row.amount),
      );
      return value > BigInt.parse('9007199254740991') ? null : value.toInt();
    } on FormatException {
      return null;
    }
  }

  int? get total {
    try {
      return subtotal == null ? null : amounts.value.total(subtotal!);
    } on FormatException {
      return null;
    }
  }

  bool get canSubmit =>
      !locked &&
      lines.isNotEmpty &&
      lines.length <= 30 &&
      total != null &&
      (amounts.value.tax == 0 || amounts.value.purchaseTaxTreatment != null) &&
      supplier.value != null &&
      warehouse.value != null &&
      paymentError == null;
  BusinessContext check() {
    final context = BusinessContext.forApp(appId);
    if (context == null ||
        !identical(context, _context) ||
        _branch == null ||
        context.selectedBranch?.branchId != _branch) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
    context.check();
    return context;
  }

  void notice(String message, bool success) {
    if (!_closed) onNotice?.call(message, success);
  }

  void fail(Object failure) {
    if (_closed) return;
    error.value =
        failure is AuthError && failure.code == 'RECEIVE_WAREHOUSE_UNAVAILABLE'
        ? 'برای این شعبه انبار مجاز ورود کالا وجود ندارد؛ فعال‌بودن انبار، ارتباط شعبه و مجوز ورود کالا را بررسی کنید.'
        : failure is AuthError && failure.code == 'VALIDATION_FAILED'
        ? 'تامین‌کننده و انبار مقصد را انتخاب و تعداد و قیمت خرید اقلام را کامل کنید.'
        : failure is AuthError &&
              !failure.requiresLogin &&
              failure.code != 'FORBIDDEN' &&
              failure.code != 'SELECTION_CHANGED' &&
              failure.statusCode < 500
        ? 'عملیات خرید انجام نشد؛ کد خطای سرور: ${failure.code}'
        : failure is FormatException
        ? 'اطلاعات یا پاسخ سرور معتبر نیست؛ تعداد مثبت با حداکثر ۶ رقم اعشار و قیمت صحیح به تومان وارد کنید.'
        : SaleInvoiceFX.message(failure);
    if (failure is AuthError &&
        (failure.requiresLogin ||
            failure.statusCode == 403 ||
            failure.code == 'SELECTION_CHANGED')) {
      clearPayment();
      products.clear();
      variants.clear();
      attributes.clear();
      suppliers.clear();
      warehouses.clear();
      lines.clear();
      amounts.value = const InvoiceAmounts();
      dueAt.value = null;
      note.value = '';
      supplier.value = null;
      warehouse.value = null;
      pending.value = null;
      operation.value = null;
      issued.value = null;
    }
    notice(error.value!, false);
  }

  Future<void> _warehouses() async {
    final fx = WarehouseManagementFX.forContext(check());
    final selected = await fx.branch();
    if (selected.status != 'ACTIVE') throw const AuthError(403, 'FORBIDDEN');
    final rows = await fx.warehouses();
    final allowed = <BusinessWarehouse>[];
    for (final row in rows.where((w) => w.status == 'ACTIVE')) {
      if (await fx.canReceive(row.warehouseId)) allowed.add(row);
    }
    if (allowed.isEmpty) {
      throw const AuthError(403, 'RECEIVE_WAREHOUSE_UNAVAILABLE');
    }
    check();
    if (_closed) return;
    warehouses.assignAll(allowed);
  }

  Future<void> load() async {
    if (loading.value || saving.value || _closed) return;
    loading.value = true;
    error.value = null;
    try {
      _context ??= BusinessContext.forApp(appId);
      _branch ??= _context?.selectedBranch?.branchId;
      invoices ??= SaleInvoiceFX(context: check(), type: 'PURCHASE');
      await invoices!.authorize();
      invoices!.require('accounting.purchase.read');
      pending.value = await invoices!.restore();
      operation.value = pending.value?.operation;
      if (pending.value != null) {
        return;
      }
      invoices!.require('accounting.purchase.create');
      final parties = SuppliersFX.forContext(check());
      await parties.authorize();
      final people = await parties.all();
      await _warehouses();
      final fx = PimFX.forContext(check());
      await fx.authorize();
      fx.require('pim.variant.read');
      attributes.clear();
      if (fx.has('pim.attribute.read')) {
        attributes.addAll(
          (await fx.all(PimResource.attributes)).cast<PimAttribute>(),
        );
      }
      final rows = (await fx.all(
        PimResource.products,
        filters: {'status': 'ACTIVE'},
      )).cast<PimProduct>();
      if (rows.any(
        (p) => p.status != 'ACTIVE' || p.businessId != fx.businessId,
      )) {
        throw const FormatException('Unexpected purchase products');
      }
      check();
      if (_closed) return;
      products.assignAll(rows);
      suppliers.assignAll(people);
      final defaultId = check().selectedBranch?.defaultWarehouseId;
      warehouse.value =
          warehouses.firstWhereOrNull(
            (w) => w.warehouseId == warehouse.value?.warehouseId,
          ) ??
          warehouses.firstWhereOrNull((w) => w.warehouseId == defaultId);
      supplier.value = suppliers.firstWhereOrNull(
        (p) => p.id == supplier.value?.id,
      );
    } catch (failure) {
      fail(failure);
    } finally {
      if (!_closed) loading.value = false;
    }
  }

  Future<void> open(PimProduct product) async {
    if (locked) {
      notice('عملیات قبلی هنوز در حال انجام است.', false);
      return;
    }
    loading.value = true;
    variants.clear();
    error.value = null;
    try {
      final fx = PimFX.forContext(check());
      final rows = (await fx.all(
        PimResource.variants,
        filters: {'productId': product.id, 'status': 'ACTIVE'},
      )).cast<PimVariant>();
      check();
      if (rows.any(
        (v) =>
            v.productId != product.id ||
            v.status != 'ACTIVE' ||
            v.businessId != fx.businessId,
      )) {
        throw const FormatException('Unexpected purchase variants');
      }
      if (!_closed) {
        variants.assignAll(rows);
      }
    } catch (failure) {
      fail(failure);
    } finally {
      if (!_closed) loading.value = false;
    }
  }

  void add(PimProduct product, PimVariant variant) {
    try {
      check();
      if (locked) throw const AuthError(409, 'SALE_PENDING');
      if (!products.any((p) => p.id == product.id) ||
          !variants.any(
            (v) => v.id == variant.id && v.productId == product.id,
          )) {
        throw const FormatException('Invalid purchase selection');
      }
      if (lines.any((l) => l.variant.id == variant.id)) {
        notice('این تنوع قبلاً به فاکتور اضافه شده است.', false);
        return;
      }
      if (lines.length >= 30) {
        notice('حداکثر ۳۰ تنوع در هر فاکتور قابل ثبت است.', false);
        return;
      }
      lines.add(PurchaseLine(product, variant));
      notice('کالا به فاکتور اضافه شد.', true);
    } catch (failure) {
      fail(failure);
    }
  }

  void setLine(PurchaseLine row, {String? quantity, String? price}) {
    if (locked) return;
    error.value = null;
    row.quantity = quantity ?? row.quantity;
    row.price = price ?? row.price;
    lines.refresh();
  }

  Future<void> submit() async {
    if (saving.value || _closed) return;
    if (loading.value) {
      notice('دریافت اطلاعات هنوز تمام نشده است.', false);
      return;
    }
    saving.value = true;
    error.value = null;
    try {
      final context = check();
      final service = invoices!;
      await service.authorize();
      if (_closed) return;
      var command = service.pending;
      if (command == null) {
        service.require('accounting.purchase.create');
        service.require('accounting.purchase.read');
        requireAmounts();
        if (note.value.trim().length > 1000) {
          notice('یادداشت نباید بیشتر از ۱۰۰۰ نویسه باشد.', false);
          return;
        }
        if (amounts.value.tax > 0 &&
            amounts.value.purchaseTaxTreatment == null) {
          notice('نوع مالیات خرید را مشخص کنید.', false);
          return;
        }
        if (lines.isEmpty ||
            lines.length > 30 ||
            total == null ||
            supplier.value == null ||
            warehouse.value == null) {
          throw const AuthError(400, 'VALIDATION_FAILED');
        }
        if (paymentError != null) {
          notice(paymentError!, false);
          return;
        }
        final parties = SuppliersFX.forContext(context);
        await parties.authorize();
        final party = await parties.get(supplier.value!.id);
        if (party.status != 'ACTIVE') {
          throw const AuthError(409, 'INVALID_STATE');
        }
        final warehouseId = warehouse.value!.warehouseId;
        await _warehouses();
        if (!warehouses.any((w) => w.warehouseId == warehouseId)) {
          throw const AuthError(403, 'FORBIDDEN');
        }
        check();
        if (_closed) return;
        final paymentRows = <Map<String, Object>>[];
        if (hasPayment) {
          final target = paymentTarget.value!;
          final available = await service.paymentTargets(paymentMethod.value);
          check();
          if (_closed) return;
          if (!available.any(
            (row) =>
                row.id == target.id &&
                row.kind == target.kind &&
                row.fundId == target.fundId,
          )) {
            paymentTargets.assignAll(available);
            paymentTarget.value = null;
            notice(
              'مبدا پرداخت دیگر فعال یا مجاز نیست؛ دوباره انتخاب کنید.',
              false,
            );
            return;
          }
          // Keep invoice and outgoing payment in one durable server command.
          paymentRows.add({
            'method': paymentMethod.value,
            'direction': 'OUT',
            'amount': outgoingAmount,
            'routing': target.routing,
            if (paymentMethod.value != 'CHEQUE') 'confirmed': true,
            if (paymentReference.value.trim().isNotEmpty)
              'transactionReference': paymentReference.value.trim(),
            if (paymentMethod.value == 'CHEQUE')
              'cheque': {
                'bankName': cheque['bankName']!.trim(),
                'number': cheque['number']!.trim().toEnglishDigit(),
                'dueAt': chequeDueAt.value!.toUtc().toIso8601String(),
                if ((cheque['sayadId'] ?? '').trim().isNotEmpty)
                  'sayadId': cheque['sayadId']!.trim().toEnglishDigit(),
                if ((cheque['drawerName'] ?? '').trim().isNotEmpty)
                  'drawerName': cheque['drawerName']!.trim(),
              },
          });
        }
        if (chequePayments.isNotEmpty) {
          final banks = await service.paymentTargets('CHEQUE');
          check();
          if (_closed) return;
          for (final row in chequePayments) {
            final routing = row.payment['routing'] as Map;
            if (!banks.any(
              (bank) => bank.id == routing['fundId'] && bank.kind == 'BANK',
            )) {
              notice(
                'حساب یکی از چک‌ها دیگر فعال یا مجاز نیست؛ چک را دوباره انتخاب کنید.',
                false,
              );
              return;
            }
            paymentRows.add(row.payment);
          }
        }
        command = SaleInvoiceCommand({
          'type': 'PURCHASE',
          if (paymentRows.isNotEmpty) 'payments': paymentRows,
          ...amounts.value.payload,
          if (dueAt.value != null)
            'dueAt': DateTime.fromMillisecondsSinceEpoch(
              dueAt.value!.millisecondsSinceEpoch,
              isUtc: true,
            ).toIso8601String(),
          if (note.value.trim().isNotEmpty) 'note': note.value.trim(),
          'supplierId': party.id,
          'deliveryStatus': 'DELIVERED',
          'lines': lines.map((l) => l.toJson(warehouseId)).toList(),
        });
      }
      operation.value = await service.send(command);
      pending.value = service.pending;
      for (var attempt = 0; attempt < 3 && !_closed; attempt++) {
        final status = operation.value?.status;
        if (['SUCCEEDED', 'FAILED', 'ACTION_REQUIRED'].contains(status)) break;
        if (attempt > 0) await Future<void>.delayed(Duration(seconds: attempt));
        if (_closed) return;
        operation.value = await service.refresh();
      }
      check();
      if (_closed) return;
      if (operation.value?.status == 'SUCCEEDED') {
        final result = await service.invoice();
        if (_closed) return;
        issued.value = result;
        notice(
          'فاکتور خرید با شماره ${result.number} و ورود کالا به انبار ثبت شد؛ ${result.paymentStatus == 'PAID'
              ? 'تسویه شده'
              : result.paymentStatus == 'PARTIALLY_PAID'
              ? 'تسویه جزئی'
              : 'تسویه نشده'}.',
          true,
        );
      } else if (operation.value?.status == 'FAILED') {
        notice(
          'ثبت خرید ناموفق بود: ${operation.value?.errorCode ?? 'کد خطا اعلام نشده'}',
          false,
        );
      } else {
        notice(
          operation.value?.status == 'ACTION_REQUIRED'
              ? 'ثبت خرید به بررسی مدیر نیاز دارد؛ درخواست جدید نسازید.'
              : 'ثبت خرید هنوز قطعی نشده؛ همین درخواست را پیگیری کنید.',
          false,
        );
      }
    } catch (failure) {
      pending.value = invoices?.pending;
      fail(failure);
    } finally {
      if (!_closed) saving.value = false;
    }
  }

  Future<void> reset() async {
    if (saving.value || _closed) return;
    try {
      await invoices!.clearFinished();
      check();
      pending.value = null;
      operation.value = null;
      issued.value = null;
      lines.clear();
      clearPayment();
      amounts.value = const InvoiceAmounts();
      dueAt.value = null;
      note.value = '';
      supplier.value = null;
      warehouse.value = null;
      await load();
    } catch (failure) {
      fail(failure);
    }
  }

  @override
  void onClose() {
    _closed = true;
    _paymentGeneration++;
    super.onClose();
  }
}
