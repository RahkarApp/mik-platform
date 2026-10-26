import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/pim_group.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:uuid/uuid.dart';

import '../components/attribute_values.dart';

class PimProductAddController extends GetxController {
  final PimGroupFX group;
  PimFX get fx => group.products;
  final loading = false.obs, saving = false.obs, locked = false.obs;
  final error = RxnString(), loadError = RxnString();
  final categories = <PimCategory>[].obs;
  final attributes = <PimAttribute>[].obs;
  final descriptiveAttributes = <PimAttribute>[].obs;
  final attributeDraft = <Map<String, dynamic>>[].obs;
  final attributeError = RxnString();
  final brands = <PimBrand>[].obs;
  final brandError = RxnString();
  bool get canBrands => brandError.value == null && fx.has('pim.brand.read');
  final brandId = RxnString();
  final units = <CatalogUnit>[].obs;
  final selectedCategories = <String>[].obs;
  final primaryCategory = RxnString();
  final unitId = RxnInt();
  final axes = <String, List<String>>{}.obs;
  final _draftId = const Uuid().v4();
  PimGroupState recovery = const PimGroupState();
  PimProductAddController(this.group);
  bool get canPrice =>
      fx.has('pim.price.create') && fx.has('pim.price.default.update');
  bool get canAttributes =>
      attributeError.value == null &&
      fx.has('pim.attribute.assign') &&
      fx.has('pim.attribute.read');
  bool get canAxes =>
      canAttributes &&
      fx.has('pim.variant.create') &&
      fx.has('pim.variant.read');
  bool get canActivate => fx.has('pim.product.update');
  bool get canDescribe => fx.has('pim.product.shop.update');
  bool get canBarcode => fx.has('pim.variant.update') && axes.isEmpty;
  int get combinations =>
      axes.values.fold(1, (count, values) => count * values.length);

  Future<void> load() async {
    loading.value = true;
    loadError.value = null;
    attributeError.value = null;
    brandError.value = null;
    brands.clear();
    try {
      await fx.authorize();
      fx.require('pim.product.create');
      recovery = await group.read();
      locked.value = recovery.pending || await fx.restore() != null;
      if (locked.value) return;
      final rows = (await fx.all(
        PimResource.categories,
        filters: {'status': 'ACTIVE'},
      )).cast<PimCategory>();
      if (rows.any((c) => c.status != 'ACTIVE') ||
          rows.map((c) => c.id).toSet().length != rows.length) {
        throw const FormatException('Unexpected product categories');
      }
      categories.assignAll(rows);
      final catalog = await fx.catalog();
      if (catalog.units.map((u) => u.id).toSet().length !=
          catalog.units.length) {
        throw const FormatException('Duplicate catalog units');
      }
      units.assignAll(catalog.units.where((u) => u.id != 0));
      attributes.clear();
      descriptiveAttributes.clear();
      if (canAttributes) {
        try {
          final values = (await fx.all(
            PimResource.attributes,
            filters: {'status': 'ACTIVE'},
          )).cast<PimAttribute>();
          if (values.any(
                (a) =>
                    a.status != 'ACTIVE' ||
                    ![
                      'TEXT',
                      'NUMBER',
                      'BOOLEAN',
                      'SELECT',
                      'MULTI_SELECT',
                    ].contains(a.dataType),
              ) ||
              values.map((a) => a.id).toSet().length != values.length) {
            throw const FormatException('Unexpected add attributes');
          }
          descriptiveAttributes.assignAll(values);
          attributes.assignAll(
            values.where(
              (a) =>
                  a.usableForVariant &&
                  a.dataType == 'SELECT' &&
                  a.values.any((v) => v.active),
            ),
          );
        } catch (failure) {
          if (failure is AuthError && failure.requiresLogin) rethrow;
          attributes.clear();
          descriptiveAttributes.clear();
          attributeError.value = PimFX.message(failure);
        }
      }
      if (canBrands) {
        try {
          final rows = (await fx.all(
            PimResource.brands,
            filters: {'status': 'ACTIVE'},
          )).cast<PimBrand>();
          if (rows.any((v) => v.status != 'ACTIVE') ||
              rows.map((v) => v.id).toSet().length != rows.length) {
            throw const FormatException('Unexpected active brands');
          }
          brands.assignAll(rows);
        } catch (failure) {
          if (failure is AuthError && failure.requiresLogin) rethrow;
          brands.clear();
          brandError.value = PimFX.message(failure);
        }
      }
      fx.context.check();
    } catch (failure) {
      loadError.value = PimFX.message(failure);
    } finally {
      loading.value = false;
    }
  }

  void category(String id, bool checked) {
    if (locked.value || saving.value) return;
    if (checked && !selectedCategories.contains(id)) selectedCategories.add(id);
    if (!checked) selectedCategories.remove(id);
    if (!selectedCategories.contains(primaryCategory.value)) {
      primaryCategory.value = selectedCategories.isEmpty
          ? null
          : selectedCategories.first;
    }
  }

  void option(String attributeId, String valueId, bool checked) {
    if (locked.value || saving.value) return;
    if (checked && attributeDraft.any((v) => v['attributeId'] == attributeId)) {
      error.value = 'این ویژگی در مشخصات محصول انتخاب شده است؛ ابتدا آن را از مشخصات بردارید.';
      return;
    }
    final values = [...?axes[attributeId]];
    if (checked && !values.contains(valueId)) values.add(valueId);
    if (!checked) values.remove(valueId);
    if (values.isEmpty) {
      axes.remove(attributeId);
    } else {
      axes[attributeId] = values;
    }
  }

  void _validateText(String value, int maximum, String message) {
    if (value.isEmpty ||
        value.length > maximum ||
        RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]').hasMatch(value)) {
      throw StateError(message);
    }
  }

  PimProductDraft draft({
    required String name,
    required String price,
    String barcode = '',
    String description = '',
  }) {
    fx.context.check();
    name = name.trim();
    price = price.trim().toEnglishDigit();
    barcode = barcode.trim();
    description = description.trim();
    _validateText(name, 200, 'نام محصول را تا ۲۰۰ نویسه وارد کنید.');
    if (selectedCategories.isEmpty ||
        selectedCategories.length > 30 ||
        !selectedCategories.contains(primaryCategory.value) ||
        selectedCategories.any((id) => !categories.any((c) => c.id == id)) ||
        !units.any((u) => u.id == unitId.value)) {
      throw StateError(
        'دسته‌بندی، دسته‌بندی اصلی و واحد معتبر را انتخاب کنید.',
      );
    }
    if (axes.length > 6 || combinations > 100) {
      throw StateError('حداکثر ۶ ویژگی و ۱۰۰ ترکیب تنوع مجاز است.');
    }
    if (axes.isNotEmpty && !canAxes) throw const AuthError(403, 'FORBIDDEN');
    for (final axis in axes.entries) {
      final attribute = attributes.where((a) => a.id == axis.key).firstOrNull;
      if (attribute == null ||
          axis.value.isEmpty ||
          axis.value.length > 100 ||
          axis.value.any(
            (id) => !attribute.values.any((v) => v.valueId == id && v.active),
          )) {
        throw StateError('گزینه‌های معتبر تنوع را انتخاب کنید.');
      }
    }
    if (attributeDraft.isNotEmpty && !canAttributes) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final descriptive = normalizeProductAttributeValues(
      attributeDraft.toList(),
      attributes: descriptiveAttributes,
      axisIds: axes.keys.toSet(),
    );
    if (brandId.value != null &&
        (!canBrands ||
            !brands.any(
              (v) => v.id == brandId.value && v.status == 'ACTIVE',
            ))) {
      throw StateError('برند فعال و معتبر را انتخاب کنید.');
    }
    int? amount;
    if (price.isNotEmpty) {
      if (!canPrice) throw const AuthError(403, 'FORBIDDEN');
      amount = RegExp(r'^\d+$').hasMatch(price) ? int.tryParse(price) : null;
      if (amount == null || amount > 9000000000000) {
        throw StateError(
          'قیمت باید تومان صحیح بین صفر و ۹٬۰۰۰٬۰۰۰٬۰۰۰٬۰۰۰ باشد.',
        );
      }
    }
    if (barcode.isNotEmpty) {
      if (!canBarcode) {
        throw StateError(
          'بارکد اولیه فقط برای محصول بدون تنوع و با مجوز ویرایش تنوع ثبت می‌شود.',
        );
      }
      _validateText(barcode, 100, 'بارکد باید حداکثر ۱۰۰ نویسه باشد.');
    }
    if (description.isNotEmpty) {
      if (!canDescribe) throw const AuthError(403, 'FORBIDDEN');
      _validateText(
        description,
        10000,
        'توضیحات باید حداکثر ۱۰۰۰۰ نویسه باشد.',
      );
    }
    return PimProductDraft(
      id: _draftId,
      name: name,
      fields: {
        'categoryIds': selectedCategories.toList(),
        'primaryCategoryId': primaryCategory.value,
        'unitId': unitId.value,
        if (brandId.value != null) 'brandId': brandId.value,
        if (axes.isNotEmpty)
          'variantAxes': [
            for (final a in axes.entries)
              {'attributeId': a.key, 'valueIds': a.value},
          ],
        if (description.isNotEmpty) 'description': description,
        if (descriptive.isNotEmpty) 'attributeValues': descriptive,
      },
      barcode: barcode.isEmpty ? null : barcode,
      prices: amount == null
          ? []
          : [PimDraftPrice(name: 'فروش', amount: amount, isDefault: true)],
    );
  }

  Future<bool> save({
    String name = '',
    String price = '',
    String barcode = '',
    String description = '',
  }) async {
    if (saving.value || loading.value) return false;
    saving.value = true;
    error.value = null;
    try {
      fx.context.check();
      final PimProductDraft? value = locked.value
          ? null
          : draft(
              name: name,
              price: price,
              barcode: barcode,
              description: description,
            );
      if (locked.value && !recovery.pending) {
        throw StateError(
          'درخواست قبلی این کسب‌وکار باید در صفحهٔ مربوط تعیین تکلیف شود.',
        );
      }
      await group.save(value == null ? [] : [value]);
      return true;
    } catch (failure) {
      error.value = failure is StateError
          ? failure.message.toString()
          : PimFX.message(failure);
      return false;
    } finally {
      try {
        recovery = await group.read();
        locked.value = recovery.pending || await fx.restore() != null;
      } catch (_) {
        // A lost session/storage read cannot unlock a possibly committed request.
        locked.value = true;
      }
      saving.value = false;
    }
  }
}
