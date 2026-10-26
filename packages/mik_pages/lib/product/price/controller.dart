import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class ProductPriceController extends GetxController {
  final PimFX fx;
  final String productId;
  final loading = false.obs, saving = false.obs, conflict = false.obs;
  final error = RxnString(),
      loadError = RxnString(),
      variantsError = RxnString(),
      metadataError = RxnString();
  final prices = <PimPrice>[].obs, overrides = <PimPriceOverride>[].obs;
  final variants = <PimVariant>[].obs;
  final attributes = <PimAttribute>[], categories = <PimCategory>[];
  final pending = Rxn<PimCommand>();
  PimProduct? product;
  ProductPriceController(this.fx, this.productId);
  bool get writable =>
      fx.context.valid && product?.status != 'ARCHIVED' && product != null;
  bool get canCreate => writable && fx.has('pim.price.create');
  bool canEdit(PimRecord item) =>
      writable &&
      item.status == 'ACTIVE' &&
      (item is! PimPriceOverride ||
          prices.any(
            (p) => p.id == item.productPriceId && p.status == 'ACTIVE',
          )) &&
      fx.canChange(
        item is PimPrice ? PimResource.prices : PimResource.overrides,
        item,
      );
  bool canArchive(PimRecord item) =>
      writable &&
      item.status == 'ACTIVE' &&
      !(item is PimPrice &&
          item.isDefault &&
          (product?.status == 'ACTIVE' || !canDefault)) &&
      fx.canChange(
        item is PimPrice ? PimResource.prices : PimResource.overrides,
        item,
        archive: true,
      );
  PimCommand archiveCommand(PimRecord item) {
    if (!canArchive(item)) throw const AuthError(403, 'FORBIDDEN');
    return fx.change(
      item is PimPrice ? PimResource.prices : PimResource.overrides,
      {
        'status': 'ARCHIVED',
        if (item is PimPrice && item.isDefault) 'isDefault': false,
      },
      item: item,
    );
  }

  String variantName(PimVariant item) => item.optionValues.isEmpty
      ? item.name
      : item.optionValues
            .map((pair) {
              final attribute = attributes
                  .where((a) => a.id == pair.attributeId)
                  .firstOrNull;
              final option = attribute?.values
                  .where((v) => v.valueId == pair.valueId)
                  .firstOrNull;
              return attribute != null && option != null
                  ? '${attribute.name}: ${option.name}'
                  : 'نام ویژگی در دسترس نیست';
            })
            .join('، ');
  bool get canDefault => fx.has('pim.price.default.update');
  bool get pendingHere {
    final p = pending.value;
    return p != null && _belongs(p);
  }

  bool _belongs(PimCommand p) {
    if (!['create', 'update'].contains(p.operation)) return false;
    if (p.body.containsKey('status') &&
        (p.operation != 'update' ||
            p.body['status'] != 'ARCHIVED' ||
            p.body.keys.any(
              (k) => !{
                'status',
                'expectedRevision',
                if (p.resource == PimResource.prices) 'isDefault',
              }.contains(k),
            ))) {
      return false;
    }
    if (p.resource == PimResource.prices) {
      if (p.body.keys.any(
        (k) => !{
          'productId',
          'name',
          'amount',
          'isDefault',
          'validFrom',
          'validUntil',
          'status',
          'expectedRevision',
        }.contains(k),
      )) {
        return false;
      }
      return p.id == null
          ? p.body['productId'] == productId
          : prices.any((v) => v.id == p.id);
    }
    if (p.resource == PimResource.overrides) {
      if (p.body.keys.any(
        (k) => !{
          'productPriceId',
          'variantId',
          'amount',
          'status',
          'expectedRevision',
        }.contains(k),
      )) {
        return false;
      }
      return p.id == null
          ? prices.any((v) => v.id == p.body['productPriceId'])
          : overrides.any((v) => v.id == p.id);
    }
    return false;
  }

  Future<void> load() async {
    if (saving.value) return;
    loading.value = true;
    error.value = null;
    loadError.value = null;
    variantsError.value = null;
    metadataError.value = null;
    attributes.clear();
    categories.clear();
    prices.clear();
    overrides.clear();
    variants.clear();
    product = null;
    try {
      await fx.authorize();
      fx.require('pim.price.read');
      final owner = await fx.get(PimResource.products, productId) as PimProduct;
      try {
        if (fx.has('pim.attribute.read')) {
          attributes.addAll(
            (await fx.all(PimResource.attributes)).cast<PimAttribute>(),
          );
        }
        if (fx.has('${PimResource.categories.permission}.read')) {
          categories.addAll(
            (await fx.all(PimResource.categories)).cast<PimCategory>(),
          );
        }
      } catch (failure) {
        metadataError.value = message(failure);
      }
      final rows = (await fx.all(
        PimResource.prices,
        filters: {'productId': productId},
      )).cast<PimPrice>();
      if (rows.map((v) => v.id).toSet().length != rows.length ||
          rows.any(
            (v) =>
                v.productId != productId ||
                v.currency != 'TOMAN' ||
                !_moneyValid(v.amount) ||
                !['ACTIVE', 'ARCHIVED'].contains(v.status) ||
                v.validFrom != null &&
                    v.validUntil != null &&
                    !v.validUntil!.isAfter(v.validFrom!),
          )) {
        throw const FormatException('Unexpected product prices');
      }
      final variantRows = <PimVariant>[];
      if (fx.has('pim.variant.read')) {
        try {
          variantRows.addAll(
            (await fx.all(
              PimResource.variants,
              filters: {'productId': productId},
            )).cast<PimVariant>(),
          );
          if (variantRows.any((v) => v.productId != productId) ||
              variantRows.map((v) => v.id).toSet().length !=
                  variantRows.length) {
            throw const FormatException('Unexpected price variants');
          }
        } catch (failure) {
          if (failure is AuthError &&
              (failure.statusCode == 403 || failure.requiresLogin)) {
            rethrow;
          }
          variantRows.clear();
          variantsError.value = PimFX.message(failure);
        }
      } else {
        variantsError.value = 'اجازهٔ مشاهدهٔ تنوع‌ها را ندارید.';
      }
      final specific = <PimPriceOverride>[];
      for (final price in rows) {
        final values = (await fx.all(
          PimResource.overrides,
          filters: {'productPriceId': price.id},
        )).cast<PimPriceOverride>();
        if (values.any(
          (v) =>
              v.productPriceId != price.id ||
              !_moneyValid(v.amount) ||
              !['ACTIVE', 'ARCHIVED'].contains(v.status) ||
              variantsError.value == null &&
                  !variantRows.any((item) => item.id == v.variantId),
        )) {
          throw const FormatException('Unexpected price overrides');
        }
        specific.addAll(values);
      }
      if (specific.map((v) => v.id).toSet().length != specific.length) {
        throw const FormatException('Duplicate price overrides');
      }
      final command = await fx.restore();
      fx.context.check();
      product = owner;
      prices.assignAll(rows);
      variants.assignAll(variantRows);
      overrides.assignAll(specific);
      pending.value = command;
    } catch (failure) {
      loadError.value = message(failure);
    } finally {
      loading.value = false;
    }
  }

  bool _moneyValid(int amount) => amount >= 0 && amount <= 9000000000000;
  int amount(String text) {
    text = text
        .toEnglishDigit()
        .replaceAll('تومان', '')
        .replaceAll(',', '')
        .trim();
    final value = RegExp(r'^\d+$').hasMatch(text) ? int.tryParse(text) : null;
    if (value == null || !_moneyValid(value)) {
      throw StateError(
        'قیمت صحیح تومان را بین صفر و ۹٬۰۰۰٬۰۰۰٬۰۰۰٬۰۰۰ وارد کنید.',
      );
    }
    return value;
  }

  PimCommand priceCommand({
    PimPrice? item,
    required String name,
    required String input,
    required bool isDefault,
    DateTime? from,
    DateTime? until,
  }) {
    if (!writable) throw const AuthError(403, 'FORBIDDEN');
    name = name.trim();
    if (name.isEmpty ||
        name.length > 200 ||
        RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]').hasMatch(name)) {
      throw StateError('عنوان قیمت معتبر را تا ۲۰۰ نویسه وارد کنید.');
    }
    if (from != null && until != null && !until.isAfter(from)) {
      throw StateError('پایان اعتبار باید بعد از شروع اعتبار باشد.');
    }
    if (item != null && (item.productId != productId || !canEdit(item))) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final value = amount(input);
    final fields = <String, dynamic>{
      if (item == null) 'productId': productId,
      if (item == null || name != item.name) 'name': name,
      if (item == null || value != item.amount) 'amount': value,
      if (isDefault != (item?.isDefault ?? false)) 'isDefault': isDefault,
      if (item == null || from != item.validFrom)
        'validFrom': from?.toUtc().toIso8601String(),
      if (item == null || until != item.validUntil)
        'validUntil': until?.toUtc().toIso8601String(),
    };
    return fx.change(PimResource.prices, fields, item: item);
  }

  PimCommand overrideCommand({
    PimPriceOverride? item,
    required String priceId,
    required String variantId,
    required String input,
  }) {
    if (!writable ||
        !prices.any((p) => p.id == priceId && p.status == 'ACTIVE') ||
        item == null &&
            !variants.any((v) => v.id == variantId && v.status == 'ACTIVE') ||
        item != null &&
            (item.productPriceId != priceId ||
                item.variantId != variantId ||
                !canEdit(item))) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final value = amount(input);
    return fx.change(PimResource.overrides, {
      if (item == null) ...{'productPriceId': priceId, 'variantId': variantId},
      if (item == null || value != item.amount) 'amount': value,
    }, item: item);
  }

  Future<bool> save(PimCommand command) async {
    if (saving.value || conflict.value) return false;
    saving.value = true;
    error.value = null;
    try {
      fx.context.check();
      if (!_belongs(command)) {
        throw StateError(
          'درخواست قیمت به این محصول یا عملیات این صفحه مربوط نیست.',
        );
      }
      if (command.operation == 'update' &&
          command.body.keys.every((k) => k == 'expectedRevision')) {
        return true;
      }
      pending.value = command;
      await fx.execute(command);
      pending.value = null;
      return true;
    } catch (failure) {
      conflict.value =
          failure is AuthError && failure.code == 'REVISION_CONFLICT';
      if (failure is AuthError &&
          failure.statusCode < 500 &&
          !failure.retryable &&
          !failure.requiresLogin &&
          failure.statusCode != 403) {
        pending.value = null;
      }
      error.value = message(failure);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<void> resume() async {
    if (!pendingHere) return;
    final command = pending.value!;
    if (await save(command)) await load();
  }

  String message(Object failure) => failure is StateError
      ? failure.message.toString()
      : PimFX.message(failure);
}
