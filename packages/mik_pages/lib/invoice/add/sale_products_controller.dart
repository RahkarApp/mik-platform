import 'package:mik_data/source/remote/models/invoice_amounts.dart';
import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/models/customer.dart';
import 'package:mik_data/source/remote/models/inventory_quantity.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/customers.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/sale_invoice.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class SaleInvoiceLine {
  final PimProduct product;
  final PimVariant variant;
  final PimEffectivePrice price;
  final String priceName, variantName;
  final String quantity;
  const SaleInvoiceLine({
    required this.product,
    required this.variant,
    required this.price,
    required this.priceName,
    required this.variantName,
    this.quantity = '1',
  });

  // Keep UUIDs separate from the obsolete Hive invoice model. The accounting
  // API resolves its own price snapshot again when the invoice is submitted.
  Map<String, Object> toJson() => {
    'variantId': variant.id,
    'quantity': normalizedQuantity(quantity),
    'productPriceId': price.productPriceId,
  };

  static String normalizedQuantity(String value) {
    final quantity = InventoryQuantity.fromJson(
      value.trim().toEnglishDigit().replaceAll('٫', '.'),
    );
    if (quantity.isZero) {
      throw const FormatException('Quantity must be positive');
    }
    return quantity.toString();
  }

  SaleInvoiceLine copy({String? quantity, PimEffectivePrice? price}) =>
      SaleInvoiceLine(
        product: product,
        variant: variant,
        price: price ?? this.price,
        priceName: priceName,
        variantName: variantName,
        quantity: normalizedQuantity(quantity ?? this.quantity),
      );
  int get amount {
    final parts = normalizedQuantity(quantity).split('.');
    final scale = BigInt.from(1000000);
    final units =
        BigInt.parse(parts[0]) * scale +
        BigInt.parse((parts.length == 1 ? '' : parts[1]).padRight(6, '0'));
    // Match accounting/money.js: round each line to integer tomans, using exact millionths.
    final amount =
        (BigInt.from(price.amount) * units + BigInt.from(500000)) ~/ scale;
    if (amount > BigInt.parse('9007199254740991')) {
      throw const FormatException('Money overflow');
    }
    return amount.toInt();
  }
}

class SaleProductsController extends GetxController {
  final String appId;
  final String type;
  bool get proforma => type == 'PROFORMA';
  String get permissionGroup => proforma ? 'proforma' : 'sale';
  final validUntil = Rxn<DateTime>();
  String? validityError;
  final void Function(String message)? onError;
  final void Function(String message)? onSuccess;
  SaleProductsController({
    required this.appId,
    this.type = 'SALE',
    this.onError,
    this.onSuccess,
  });
  void reportError(String message) {
    if (_closed) return;
    error.value = message;
    onError?.call(message);
  }

  String get validationMessage {
    if (lines.isEmpty) return 'حداقل یک کالا به فاکتور اضافه کنید.';
    if (lines.length > 30) return 'حداکثر ۳۰ تنوع در هر فاکتور قابل ثبت است.';
    if (total == null) {
      return 'تعداد اقلام باید مثبت و حداکثر با ۶ رقم اعشار باشد؛ مبلغ اقلام، تخفیف و هزینه‌های فاکتور را هم بررسی کنید.';
    }
    if (customer.value == null) return 'مشتری فاکتور را انتخاب کنید.';
    if (proforma &&
        (validityError != null ||
            validUntil.value != null &&
                !validUntil.value!.isAfter(DateTime.now()))) {
      return 'مهلت اعتبار باید در آینده باشد.';
    }
    if (paymentLoading.value) {
      return 'دریافت مقصدهای پرداخت هنوز تمام نشده است.';
    }
    if (!proforma &&
        paymentMode.value == 'دریافت کامل' &&
        total! > 0 &&
        paymentTarget.value == null) {
      return 'روش دریافت و صندوق، حساب یا پایانه مقصد را انتخاب کنید.';
    }
    return 'عملیات قبلی هنوز تمام نشده است؛ کمی صبر کنید.';
  }

  final loading = false.obs, choosing = false.obs;
  final error = RxnString();
  final products = <PimProduct>[].obs;
  final variants = <PimVariant>[].obs;
  final prices = <PimPrice>[].obs;
  final lines = <SaleInvoiceLine>[].obs;
  final attributes = <PimAttribute>[];
  final customer = Rxn<RemoteCustomer>();
  final paymentMode = 'دریافت کامل'.obs, paymentMethod = 'CASH'.obs;
  final paymentLoading = false.obs;
  final paymentTargets = <SalePaymentTarget>[].obs;
  final paymentTarget = Rxn<SalePaymentTarget>();
  int _paymentGeneration = 0;
  final saving = false.obs;
  final pendingSale = Rxn<SaleInvoiceCommand>();
  final operation = Rxn<SaleOperation>();
  final issued = Rxn<SaleInvoiceResult>();
  final quantityErrors = <String, String>{}.obs;
  final dueAt = Rxn<DateTime>();
  final note = ''.obs;
  final amounts = const InvoiceAmounts().obs;
  bool get canDiscount =>
      invoices?.has('accounting.sale.discount.apply') == true;
  bool get canSurcharge =>
      invoices?.has('accounting.sale.surcharge.apply') == true;
  void requireAmounts() {
    final value = amounts.value;
    if (value.discount > 0) invoices!.require('accounting.sale.discount.apply');
    if (value.shipping > 0 || value.surcharge > 0 || value.tax > 0) {
      invoices!.require('accounting.sale.surcharge.apply');
    }
  }

  SaleInvoiceFX? invoices;
  bool _closed = false;
  bool get locked => saving.value || pendingSale.value != null;
  int? get subtotal {
    if (quantityErrors.isNotEmpty) return null;
    try {
      final total = lines.fold<BigInt>(
        BigInt.zero,
        (sum, row) => sum + BigInt.from(row.amount),
      );
      return total > BigInt.parse('9007199254740991') ? null : total.toInt();
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
      !loading.value &&
      lines.isNotEmpty &&
      lines.length <= 30 &&
      total != null &&
      customer.value != null &&
      (!proforma ||
          validityError == null &&
              (validUntil.value == null ||
                  validUntil.value!.isAfter(DateTime.now()))) &&
      !paymentLoading.value &&
      (proforma ||
          paymentMode.value != 'دریافت کامل' ||
          total == 0 ||
          paymentTarget.value != null);

  Future<void> loadPaymentTargets() async {
    if (proforma) return;
    if (_closed || locked || paymentMode.value != 'دریافت کامل') return;
    final generation = ++_paymentGeneration;
    paymentLoading.value = true;
    error.value = null;
    final previous = paymentTarget.value?.id;
    paymentTarget.value = null;
    paymentTargets.clear();
    try {
      check();
      await invoices!.authorize();
      final rows = await invoices!.paymentTargets(paymentMethod.value);
      check();
      if (_closed || generation != _paymentGeneration) return;
      paymentTargets.assignAll(rows);
      paymentTarget.value = rows.firstWhereOrNull((r) => r.id == previous);
      if (rows.isEmpty) {
        reportError(
          'مقصد فعال برای این روش دریافت وجود ندارد؛ ابتدا صندوق، حساب بانکی یا پایانه مربوط را تعریف کنید.',
        );
      }
    } catch (failure) {
      if (generation == _paymentGeneration) {
        reportError(SaleInvoiceFX.message(failure));
      }
    } finally {
      if (!_closed && generation == _paymentGeneration) {
        paymentLoading.value = false;
      }
    }
  }

  void selectPaymentMode(String mode) {
    if (locked) return;
    _paymentGeneration++;
    paymentLoading.value = false;
    paymentMode.value = mode;
    error.value = null;
    if (mode == 'دریافت کامل') loadPaymentTargets();
  }

  void selectPaymentMethod(String method) {
    if (locked) return;
    paymentMethod.value = method;
    paymentTarget.value = null;
    loadPaymentTargets();
  }

  void setQuantity(String id, String value) {
    if (locked) return;
    final index = lines.indexWhere((r) => r.variant.id == id);
    if (index < 0) return;
    try {
      final row = lines[index].copy(quantity: value);
      row.amount;
      lines[index] = row;
      quantityErrors.remove(id);
    } on FormatException {
      quantityErrors[id] =
          'تعداد باید مثبت، حداکثر با ۶ رقم اعشار و در محدوده مجاز باشد.';
    }
  }

  BusinessContext? _context;
  String? _branchId;
  int _generation = 0;
  String get branchName => _context?.selectedBranch?.name ?? 'شعبه انتخاب نشده';

  void _clearVisibleSale() {
    lines.clear();
    amounts.value = const InvoiceAmounts();
    dueAt.value = null;
    note.value = '';
    customer.value = null;
    quantityErrors.clear();
    products.clear();
    variants.clear();
    prices.clear();
    attributes.clear();
    pendingSale.value = null;
    operation.value = null;
    issued.value = null;
    _paymentGeneration++;
    paymentTargets.clear();
    paymentTarget.value = null;
    paymentLoading.value = false;
    // Keep the durable request in its original scope for later authorized recovery.
  }

  BusinessContext check({bool requireCreate = true}) {
    final context = BusinessContext.forApp(appId);
    if (context == null ||
        !identical(context, _context) ||
        context.selectedBranch?.branchId != _branchId ||
        _branchId == null) {
      _clearVisibleSale();
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
    try {
      context.check();
    } catch (_) {
      _clearVisibleSale();
      rethrow;
    }
    if (requireCreate &&
        !context.hasPermission(
          'accounting.$permissionGroup.create',
          inBranch: true,
        )) {
      _clearVisibleSale();
      throw const AuthError(403, 'FORBIDDEN');
    }
    return context;
  }

  Future<void> load() async {
    if (saving.value || _closed) return;
    final generation = ++_generation;
    loading.value = true;
    error.value = null;
    products.clear();
    variants.clear();
    prices.clear();
    attributes.clear();
    try {
      final context = BusinessContext.forApp(appId);
      if (_context != null) check(requireCreate: false);
      _context ??= context;
      _branchId ??= context?.selectedBranch?.branchId;
      invoices ??= SaleInvoiceFX(
        context: check(requireCreate: false),
        type: type,
      );
      pendingSale.value = await invoices!.restore();
      operation.value = pendingSale.value?.operation;
      if (_closed || generation != _generation || pendingSale.value != null) {
        return;
      }
      final fx = PimFX.forContext(check());
      await fx.authorize();
      fx.require('pim.variant.read');
      fx.require('pim.price.read');
      final rows = (await fx.all(
        PimResource.products,
        filters: {'status': 'ACTIVE'},
      )).cast<PimProduct>();
      check();
      if (rows.any(
            (p) => p.status != 'ACTIVE' || p.businessId != fx.businessId,
          ) ||
          rows.map((p) => p.id).toSet().length != rows.length) {
        throw const FormatException('Unexpected sale product status');
      }
      if (fx.has('pim.attribute.read')) {
        attributes.addAll(
          (await fx.all(PimResource.attributes)).cast<PimAttribute>(),
        );
      }
      check();
      if (generation == _generation) {
        products.assignAll(rows);
        await loadPaymentTargets();
      }
    } catch (failure) {
      if (generation == _generation) reportError(PimFX.message(failure));
    } finally {
      if (generation == _generation) loading.value = false;
    }
  }

  Future<void> open(PimProduct product) async {
    if (locked) return;
    final generation = ++_generation;
    loading.value = true;
    error.value = null;
    variants.clear();
    prices.clear();
    try {
      final fx = PimFX.forContext(check());
      final rows = (await fx.all(
        PimResource.variants,
        filters: {'productId': product.id, 'status': 'ACTIVE'},
      )).cast<PimVariant>();
      final priceRows = (await fx.all(
        PimResource.prices,
        filters: {'productId': product.id, 'status': 'ACTIVE'},
      )).cast<PimPrice>();
      check();
      if (rows.any(
            (v) =>
                v.productId != product.id ||
                v.status != 'ACTIVE' ||
                v.businessId != fx.businessId,
          ) ||
          priceRows.any(
            (p) =>
                p.productId != product.id ||
                p.status != 'ACTIVE' ||
                p.businessId != fx.businessId,
          ) ||
          rows.map((v) => v.id).toSet().length != rows.length ||
          priceRows.map((p) => p.id).toSet().length != priceRows.length) {
        throw const FormatException('Unexpected sale product records');
      }
      if (generation == _generation) {
        variants.assignAll(rows);
        prices.assignAll(priceRows);
      }
    } catch (failure) {
      if (generation == _generation) reportError(PimFX.message(failure));
    } finally {
      if (generation == _generation) loading.value = false;
    }
  }

  String variantName(PimVariant variant) {
    if (variant.optionValues.isEmpty) return variant.name;
    return variant.optionValues
        .map((pair) {
          for (final attribute in attributes) {
            if (attribute.id != pair.attributeId) continue;
            for (final option in attribute.values) {
              if (option.valueId == pair.valueId) {
                return '${attribute.name}: ${option.name}';
              }
            }
          }
          return '${pair.attributeId}: ${pair.valueId}';
        })
        .join('، ');
  }

  Future<SaleInvoiceLine?> choose(
    PimProduct product,
    PimVariant variant, {
    PimPrice? price,
  }) async {
    if (choosing.value || locked) return null;
    choosing.value = true;
    error.value = null;
    try {
      final fx = PimFX.forContext(check());
      if (!products.any((p) => p.id == product.id) ||
          !variants.any(
            (v) => v.id == variant.id && v.productId == product.id,
          ) ||
          price != null && !prices.any((p) => p.id == price.id)) {
        throw const FormatException('Unexpected sale selection');
      }
      final result = await fx.effectivePrice(variant.id, priceId: price?.id);
      check();
      if (result.productId != product.id) {
        throw const FormatException('Unexpected sale price product');
      }
      final title = prices
          .where((p) => p.id == result.productPriceId)
          .firstOrNull;
      if (title == null) {
        throw const FormatException('Missing sale price title');
      }
      return SaleInvoiceLine(
        product: product,
        variant: variant,
        price: result,
        priceName: title.name,
        variantName: variantName(variant),
      );
    } catch (failure) {
      reportError(PimFX.message(failure));
      return null;
    } finally {
      choosing.value = false;
    }
  }

  Future<void> submit({bool receiptConfirmed = false}) async {
    if (saving.value || _closed) return;
    if (!proforma &&
        invoices?.pending == null &&
        paymentMode.value == 'دریافت کامل' &&
        (total ?? 0) > 0 &&
        !receiptConfirmed) {
      reportError('ثبت پرداخت فقط پس از تایید دریافت واقعی وجه مجاز است.');
      return;
    }
    saving.value = true;
    error.value = null;
    try {
      final context = check(requireCreate: invoices?.pending == null);
      final service = invoices ??= SaleInvoiceFX(context: context, type: type);
      await service.authorize();
      var command = service.pending;
      if (command == null) {
        if (lines.isEmpty ||
            lines.length > 30 ||
            total == null ||
            customer.value == null) {
          throw const AuthError(400, 'VALIDATION_FAILED');
        }
        service.require('accounting.$permissionGroup.create');
        service.require('accounting.$permissionGroup.read');
        requireAmounts();
        if (note.value.trim().length > 1000) {
          reportError('یادداشت نباید بیشتر از ۱۰۰۰ نویسه باشد.');
          return;
        }
        if (!proforma) service.require('accounting.sale.status.delivered');
        if (proforma &&
            (validityError != null ||
                validUntil.value != null &&
                    !validUntil.value!.isAfter(DateTime.now()))) {
          reportError('مهلت اعتبار باید در آینده باشد.');
          return;
        }
        final customers = CustomersFX(context: context);
        await customers.authorize();
        final party = await customers.get(customer.value!.id);
        if (party.status != 'ACTIVE') {
          throw const AuthError(409, 'INVALID_STATE');
        }
        if (!proforma &&
            party.isDefault &&
            total! > 0 &&
            paymentMode.value != 'دریافت کامل') {
          throw const AuthError(400, 'DEFAULT_CUSTOMER_CREDIT_FORBIDDEN');
        }
        final fx = PimFX.forContext(context);
        await fx.authorize();
        var changed = false;
        final updated = <SaleInvoiceLine>[];
        for (final line in lines) {
          final price = await fx.effectivePrice(
            line.variant.id,
            priceId: line.price.productPriceId,
          );
          if (price.productId != line.product.id) {
            throw const FormatException('Unexpected invoice price');
          }
          changed |= price.amount != line.price.amount;
          updated.add(line.copy(price: price));
        }
        check();
        if (_closed) return;
        customer.value = party;
        lines.assignAll(updated);
        if (changed) {
          reportError(
            'قیمت اقلام تغییر کرده است؛ مبلغ جدید را بررسی و دوباره ثبت کنید.',
          );
          return;
        }
        if (total == null) throw const AuthError(400, 'VALIDATION_FAILED');
        Map<String, Object>? payment;
        if (!proforma && paymentMode.value == 'دریافت کامل' && total! > 0) {
          final target = paymentTarget.value;
          if (paymentLoading.value ||
              target == null ||
              !target.accepts(paymentMethod.value)) {
            reportError('مقصد دریافت وجه را انتخاب کنید.');
            return;
          }
          final available = await service.paymentTargets(paymentMethod.value);
          if (!available.any((r) => r.id == target.id)) {
            paymentTargets.assignAll(available);
            paymentTarget.value = null;
            reportError(
              'مقصد دریافت وجه دیگر فعال یا قابل دسترس نیست؛ دوباره انتخاب کنید.',
            );
            return;
          }
          // Explicit amount records the receipt the user confirmed; it is not a
          // guessed automatic remainder or an external POS transaction.
          payment = {
            'method': paymentMethod.value,
            'direction': 'IN',
            'amount': total!,
            'confirmed': true,
            'routing': target.routing,
          };
        }
        check();
        if (_closed) return;
        command = SaleInvoiceCommand({
          'type': type,
          ...amounts.value.payload,
          if (dueAt.value != null)
            'dueAt': DateTime.fromMillisecondsSinceEpoch(
              dueAt.value!.millisecondsSinceEpoch,
              isUtc: true,
            ).toIso8601String(),
          if (note.value.trim().isNotEmpty) 'note': note.value.trim(),
          if (proforma && validUntil.value != null)
            'validUntil': validUntil.value!.toUtc().toIso8601String(),
          'customerId': party.id,
          'deliveryStatus': proforma ? 'PENDING' : 'DELIVERED',
          'lines': lines.map((r) => r.toJson()).toList(),
          if (payment != null) 'payments': [payment],
        });
      }
      final send = service.send(command);
      pendingSale.value = service.pending;
      final result = await send;
      if (_closed) return;
      operation.value = result;
      pendingSale.value = service.pending;
      await _follow();
      if (_closed) return;
      if (issued.value != null) {
        onSuccess?.call(
          proforma
              ? 'پیش‌فاکتور با شماره ${issued.value!.number} ثبت شد؛ وجه و موجودی جابه‌جا نشد.'
              : 'فاکتور فروش با شماره ${issued.value!.number} ثبت شد؛ ${issued.value!.paymentStatus == 'PAID'
                    ? 'تسویه‌شده'
                    : issued.value!.paymentStatus == 'PARTIALLY_PAID'
                    ? 'پرداخت جزئی'
                    : 'پرداخت‌نشده'}.',
        );
      } else if (operation.value?.status == 'FAILED') {
        final code = operation.value?.errorCode;
        reportError(
          code == null
              ? 'ثبت فاکتور ناموفق بود؛ سرور دلیل خطا را اعلام نکرده است.'
              : SaleInvoiceFX.message(AuthError(409, code)),
        );
      } else if (operation.value?.status == 'ACTION_REQUIRED') {
        reportError(
          'تکمیل ثبت فاکتور به بررسی مدیر نیاز دارد؛ فاکتور تازه نسازید.',
        );
      } else if (issued.value == null) {
        reportError(
          'ثبت فاکتور هنوز قطعی نشده است؛ همان درخواست را پیگیری کنید.',
        );
      }
    } catch (failure) {
      if (!_closed) {
        pendingSale.value = invoices?.pending;
        reportError(SaleInvoiceFX.message(failure));
        if (failure is AuthError &&
            (failure.statusCode == 403 ||
                failure.requiresLogin ||
                failure.code == 'SELECTION_CHANGED')) {
          _clearVisibleSale();
        }
      }
    } finally {
      if (!_closed) saving.value = false;
    }
  }

  Future<void> _follow() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (_closed) return;
      final status = operation.value?.status;
      if (status == 'SUCCEEDED') {
        final result = await invoices!.invoice();
        if (!_closed) issued.value = result;
        return;
      }
      if (status == 'FAILED' || status == 'ACTION_REQUIRED') return;
      if (attempt > 0) await Future<void>.delayed(Duration(seconds: attempt));
      if (_closed) return;
      final result = await invoices!.refresh();
      if (!_closed) operation.value = result;
    }
    if (operation.value?.status == 'SUCCEEDED' && !_closed) {
      final result = await invoices!.invoice();
      if (!_closed) issued.value = result;
    }
  }

  Future<void> resetFinished() async {
    if (saving.value || invoices == null) return;
    try {
      final succeeded = operation.value?.status == 'SUCCEEDED';
      await invoices!.clearFinished();
      if (_closed) return;
      pendingSale.value = null;
      operation.value = null;
      issued.value = null;
      error.value = null;
      if (succeeded) {
        lines.clear();
        amounts.value = const InvoiceAmounts();
        dueAt.value = null;
        note.value = '';
        customer.value = null;
        quantityErrors.clear();
      }
    } catch (failure) {
      if (!_closed) reportError(SaleInvoiceFX.message(failure));
    }
  }

  @override
  void onClose() {
    _closed = true;
    _paymentGeneration++;
    _generation++;
    super.onClose();
  }
}
