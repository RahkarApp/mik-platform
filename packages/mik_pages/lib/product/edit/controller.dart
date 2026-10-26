import 'dart:convert';

import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';

import '../components/attribute_values.dart';

class ProductEditController extends GetxController {
  final PimFX fx;
  final String productId;
  final String? variantId;
  final loading = false.obs,
      saving = false.obs,
      frozen = false.obs,
      conflict = false.obs;
  final error = RxnString(), loadError = RxnString();
  final categories = <PimCategory>[].obs;
  final units = <CatalogUnit>[].obs;
  final attributes = <PimAttribute>[].obs;
  final attributeDraft = <Map<String, dynamic>>[].obs;
  final attributeError = RxnString();
  final brands = <PimBrand>[].obs;
  final brandError = RxnString();
  bool get canBrands => brandError.value == null && fx.has('pim.brand.read');
  PimRecord? item;
  PimCommand? _command;
  ProductEditController(this.fx, {required this.productId, this.variantId});
  bool get isVariant => variantId != null;
  PimResource get resource =>
      isVariant ? PimResource.variants : PimResource.products;
  String get id => variantId ?? productId;
  bool get canDescribe => isVariant || fx.has('pim.product.shop.update');
  bool get canCategories => !isVariant && fx.has('pim.product.category.read');
  bool get canAttributes =>
      !isVariant &&
      attributeError.value == null &&
      fx.has('pim.attribute.read') &&
      fx.has('pim.attribute.assign');
  Set<String> get axisIds => item is PimProduct
      ? (item as PimProduct).variantAxes.map((a) => a.attributeId).toSet()
      : {};
  Set<String> get _keys => isVariant
      ? {'sku', 'barcodes', 'description', 'expectedRevision'}
      : {
          'name',
          'slug',
          'model',
          'brandId',
          'categoryIds',
          'primaryCategoryId',
          'unitId',
          'description',
          'shortDescription',
          'attributeValues',
          'expectedRevision',
        };

  Map<String, dynamic> get values {
    final current = item;
    final fields = switch (current) {
      PimProduct p => <String, dynamic>{
        'name': p.name,
        'slug': p.slug,
        'model': p.model,
        'brandId': p.brandId,
        'categoryIds': p.categoryIds,
        'primaryCategoryId': p.primaryCategoryId,
        'unitId': p.unitId,
        'description': p.description,
        'shortDescription': p.shortDescription,
        'attributeValues': p.attributeValues.map((v) => v.toJson()).toList(),
      },
      PimVariant v => <String, dynamic>{
        'sku': v.sku,
        'barcodes': v.barcodes,
        'description': v.description,
      },
      _ => <String, dynamic>{},
    };
    // A retry displays and replays the saved intent, even if its first response was lost.
    return {...fields, ...?_command?.body}..remove('expectedRevision');
  }

  Future<void> load() async {
    if (saving.value) return;
    loading.value = true;
    loadError.value = null;
    error.value = null;
    conflict.value = false;
    item = null;
    categories.clear();
    units.clear();
    attributes.clear();
    attributeDraft.clear();
    attributeError.value = null;
    brandError.value = null;
    brands.clear();
    try {
      await fx.authorize();
      fx.require('${resource.permission}.read');
      fx.require('${resource.permission}.update');
      _command = await fx.restore();
      frozen.value = _command != null;
      if (_command != null &&
          (_command!.id != id ||
              _command!.resource != resource ||
              _command!.operation != 'update' ||
              _command!.body.keys.any((k) => !_keys.contains(k)))) {
        throw StateError(
          'درخواست باز مربوط به عملیات دیگری است؛ ابتدا همان عملیات را تعیین تکلیف کنید.',
        );
      }
      if (isVariant) {
        final parent =
            await fx.get(PimResource.products, productId) as PimProduct;
        if (parent.status == 'ARCHIVED') {
          throw StateError('محصول آرشیوشده فعلاً قابل ویرایش نیست.');
        }
      }
      final current = await fx.get(resource, id);
      if (current is PimVariant && current.productId != productId) {
        throw const FormatException('Unexpected variant product');
      }
      if (current.status == 'ARCHIVED') {
        throw StateError('رکورد آرشیوشده فعلاً قابل ویرایش نیست.');
      }
      if (_command == null && !isVariant) {
        if (canCategories) {
          categories.assignAll(
            (await fx.all(
              PimResource.categories,
              filters: {'status': 'ACTIVE'},
            )).cast<PimCategory>(),
          );
          if (categories.any((c) => c.status != 'ACTIVE') ||
              categories.map((c) => c.id).toSet().length != categories.length) {
            throw const FormatException('Unexpected edit categories');
          }
        }
        units.assignAll((await fx.catalog()).units.where((u) => u.id != 0));
        if (units.map((u) => u.id).toSet().length != units.length) {
          throw const FormatException('Duplicate edit units');
        }
      }
      if (_command == null && current is PimProduct && canAttributes) {
        try {
          final rows = (await fx.all(
            PimResource.attributes,
            filters: {'status': 'ACTIVE'},
          )).cast<PimAttribute>();
          if (rows.any(
                (v) =>
                    v.status != 'ACTIVE' ||
                    ![
                      'TEXT',
                      'NUMBER',
                      'BOOLEAN',
                      'SELECT',
                      'MULTI_SELECT',
                    ].contains(v.dataType),
              ) ||
              rows.map((v) => v.id).toSet().length != rows.length) {
            throw const FormatException('Unexpected descriptive attributes');
          }
          attributes.assignAll(rows);
          for (final value in current.attributeValues) {
            if (!attributes.any((v) => v.id == value.attributeId)) {
              attributes.add(
                await fx.get(PimResource.attributes, value.attributeId)
                    as PimAttribute,
              );
            }
          }
        } catch (failure) {
          if (failure is AuthError && failure.requiresLogin) rethrow;
          attributes.clear();
          attributeError.value = _message(failure);
        }
      }
      if (_command == null && !isVariant && canBrands) {
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
      item = current;
      if (!isVariant) {
        attributeDraft.assignAll(
          (values['attributeValues'] as List).map(
            (v) => Map<String, dynamic>.from(v as Map),
          ),
        );
      }
    } catch (failure) {
      loadError.value = _message(failure);
    } finally {
      loading.value = false;
    }
  }

  String _text(Object? value, int maximum, {bool required = false}) {
    if (value != null && value is! String) {
      throw StateError('متن واردشده معتبر نیست.');
    }
    final text = (value as String? ?? '').trim();
    if (required && text.isEmpty ||
        text.length > maximum ||
        RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]').hasMatch(text)) {
      throw StateError('فیلدهای متنی و طول مجاز آن‌ها را بررسی کنید.');
    }
    return text;
  }

  Map<String, dynamic> _patch(Map<String, dynamic> input) {
    if (input.keys.any(
      (key) => !_keys.contains(key) || key == 'expectedRevision',
    )) {
      throw StateError('فیلد ویرایش معتبر نیست.');
    }
    final before = values;
    final normalized = <String, dynamic>{};
    for (final field in input.entries) {
      final key = field.key, value = field.value;
      if (jsonEncode(value) == jsonEncode(before[key])) continue;
      if (key == 'barcodes') {
        if (value is! List || value.length > 20) {
          throw StateError('حداکثر ۲۰ بارکد مجاز است.');
        }
        final codes = value.map((v) => _text(v, 100, required: true)).toList();
        if (codes.toSet().length != codes.length) {
          throw StateError('بارکد تکراری وارد شده است.');
        }
        normalized[key] = codes;
      } else if (key == 'categoryIds') {
        if (value is! List ||
            value.isEmpty ||
            value.length > 30 ||
            value.toSet().length != value.length ||
            value.any(
              (id) =>
                  !categories.any((c) => c.id == id && c.status == 'ACTIVE'),
            )) {
          throw StateError('دسته‌بندی‌های معتبر را انتخاب کنید.');
        }
        normalized[key] = List<String>.from(value);
      } else if (key == 'attributeValues') {
        if (!canAttributes) throw const AuthError(403, 'FORBIDDEN');
        normalized[key] = normalizeProductAttributeValues(
          value,
          attributes: attributes,
          axisIds: axisIds,
        );
      } else if (key == 'brandId') {
        if (!canBrands ||
            value != null &&
                !brands.any((v) => v.id == value && v.status == 'ACTIVE')) {
          throw StateError('برند فعال و معتبر را انتخاب کنید.');
        }
        normalized[key] = value;
      } else if (key == 'unitId') {
        if (!units.any((u) => u.id == value)) {
          throw StateError('واحد معتبر را انتخاب کنید.');
        }
        normalized[key] = value;
      } else {
        final text = _text(
          value,
          key == 'description'
              ? 10000
              : key == 'shortDescription'
              ? 2000
              : key == 'sku'
              ? 100
              : 200,
          required: ['name', 'slug', 'primaryCategoryId'].contains(key),
        );
        normalized[key] = text.isEmpty ? null : text;
      }
    }
    final patch = {
      for (final field in normalized.entries)
        if (jsonEncode(field.value) != jsonEncode(before[field.key]))
          field.key: field.value,
    };
    if (patch.keys.any(['description', 'shortDescription'].contains) &&
        !canDescribe) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    if (patch.keys.any(['categoryIds', 'primaryCategoryId'].contains)) {
      if (!canCategories) throw const AuthError(403, 'FORBIDDEN');
      final selected = patch['categoryIds'] ?? before['categoryIds'];
      if (!(selected as List).contains(
        patch['primaryCategoryId'] ?? before['primaryCategoryId'],
      )) {
        throw StateError(
          'دسته‌بندی اصلی باید در دسته‌بندی‌های انتخاب‌شده باشد.',
        );
      }
    }
    return patch;
  }

  Future<bool> save(Map<String, dynamic> fields) async {
    if (saving.value || loading.value || item == null || conflict.value) {
      return false;
    }
    saving.value = true;
    error.value = null;
    try {
      fx.context.check();
      if (_command == null) {
        final patch = _patch(fields);
        if (patch.isEmpty) return true;
        _command = fx.change(resource, patch, item: item);
      }
      final result = await fx.execute(_command!);
      if (result.item is PimVariant &&
          (result.item as PimVariant).productId != productId) {
        throw const FormatException('Unexpected variant product');
      }
      item = result.item;
      _command = null;
      frozen.value = false;
      return true;
    } catch (failure) {
      conflict.value =
          failure is AuthError && failure.code == 'REVISION_CONFLICT';
      // Definitively rejected commands can be corrected; uncertain results retain their original key.
      if (failure is AuthError &&
          failure.statusCode < 500 &&
          !failure.retryable &&
          !failure.requiresLogin &&
          failure.statusCode != 403) {
        _command = null;
      }
      error.value = _message(failure);
      return false;
    } finally {
      frozen.value = _command != null;
      saving.value = false;
    }
  }

  String _message(Object failure) => failure is StateError
      ? failure.message.toString()
      : PimFX.message(failure);
}
