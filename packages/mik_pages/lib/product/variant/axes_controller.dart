import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:uuid/uuid.dart';

class ProductAxesController extends GetxController {
  final PimFX fx;
  final String productId;
  ProductAxesController(this.fx, this.productId);
  final loading = false.obs, saving = false.obs, conflict = false.obs;
  final error = RxnString(), loadError = RxnString(), notice = RxnString();
  final attributes = <PimAttribute>[].obs;
  final axes = <String, List<String>>{}.obs;
  final pending = Rxn<PimCommand>();
  final variants = <PimVariant>[];
  PimProduct? product;
  bool get writable =>
      fx.context.valid &&
      product != null &&
      product!.status != 'ARCHIVED' &&
      fx.has('pim.product.update') &&
      fx.has('pim.attribute.assign') &&
      fx.has('pim.attribute.read') &&
      fx.has('pim.variant.read');
  bool get locked =>
      loading.value ||
      saving.value ||
      conflict.value ||
      pending.value != null ||
      !writable;
  bool get hasActive => variants.any((v) => v.status == 'ACTIVE');
  final existingOptions = <String, String>{}.obs;
  bool get simpleBase =>
      product != null &&
      product!.variantAxes.isEmpty &&
      variants.length == 1 &&
      variants.single.status == 'ACTIVE' &&
      variants.single.combinationKey == 'BASE' &&
      variants.single.optionValues.isEmpty;
  bool get canConvert => simpleBase && fx.has('pim.variant.update');

  bool get pendingAxes =>
      pending.value?.resource == PimResource.products &&
      pending.value?.id == productId &&
      ['update', 'convert-to-variable'].contains(pending.value?.operation) &&
      pending.value!.body.containsKey('variantAxes') &&
      pending.value!.body.keys.every(
        {
          'variantAxes',
          'expectedRevision',
          'variantId',
          'expectedVariantRevision',
          'optionValues',
        }.contains,
      );

  bool get pendingOption =>
      pending.value?.resource == PimResource.attributes &&
      pending.value?.operation == 'update' &&
      attributes.any((a) => a.id == pending.value?.id) &&
      pending.value!.body['values'] is List &&
      pending.value!.body.keys.every({'values', 'expectedRevision'}.contains);
  bool get pendingHere => pendingAxes || pendingOption;
  bool canAddOption(PimAttribute a) =>
      !locked &&
      a.status == 'ACTIVE' &&
      a.usableForVariant &&
      a.dataType == 'SELECT' &&
      fx.canChange(PimResource.attributes, a) &&
      a.values.length < 200 &&
      !product!.attributeValues.any((v) => v.attributeId == a.id) &&
      (!hasActive ||
          canConvert ||
          product!.variantAxes.any((v) => v.attributeId == a.id));

  Future<void> load() async {
    if (loading.value || saving.value) return;
    loading.value = true;
    loadError.value = null;
    error.value = null;
    product = null;
    axes.clear();
    existingOptions.clear();
    attributes.clear();
    variants.clear();
    try {
      await fx.authorize();
      for (final permission in [
        'pim.product.read',
        'pim.product.update',
        'pim.attribute.read',
        'pim.attribute.assign',
        'pim.variant.read',
      ]) {
        fx.require(permission);
      }
      final owner = await fx.get(PimResource.products, productId) as PimProduct;
      if (owner.status == 'ARCHIVED') {
        throw StateError('محصول آرشیوشده قابل ویرایش نیست.');
      }
      final rows = (await fx.all(
        PimResource.variants,
        filters: {'productId': productId},
      )).cast<PimVariant>();
      if (rows.any(
            (v) =>
                v.productId != productId ||
                !['ACTIVE', 'ARCHIVED'].contains(v.status),
          ) ||
          rows.map((v) => v.id).toSet().length != rows.length) {
        throw const FormatException('Unexpected product variants');
      }
      final catalog = (await fx.all(
        PimResource.attributes,
        filters: {'status': 'ACTIVE'},
      )).cast<PimAttribute>();
      if (catalog.any((a) => a.status != 'ACTIVE') ||
          catalog.map((a) => a.id).toSet().length != catalog.length) {
        throw const FormatException('Unexpected variant attributes');
      }
      final available = catalog
          .where((a) => a.usableForVariant && a.dataType == 'SELECT')
          .toList();
      // Retain unavailable selections visibly; never silently drop a stored axis.
      for (final axis in owner.variantAxes) {
        if (!available.any((a) => a.id == axis.attributeId)) {
          available.add(
            await fx.get(PimResource.attributes, axis.attributeId)
                as PimAttribute,
          );
        }
      }
      final command = await fx.restore();
      fx.context.check();
      product = owner;
      variants.addAll(rows);
      attributes.assignAll(available);
      axes.assignAll({
        for (final axis in owner.variantAxes)
          axis.attributeId: List.of(axis.valueIds),
      });
      pending.value = command;
      if (pendingAxes) {
        final values = pending.value!.body['variantAxes'];
        if (values is! List) {
          throw const FormatException('Invalid pending axes');
        }
        final parsed = values.map(PimAxis.fromJson).toList();
        axes.assignAll({
          for (final axis in parsed) axis.attributeId: axis.valueIds,
        });
        if (pending.value!.operation == 'convert-to-variable') {
          final pairs = (pending.value!.body['optionValues'] as List).map(
            PimOptionPair.fromJson,
          );
          existingOptions.assignAll({
            for (final pair in pairs) pair.attributeId: pair.valueId,
          });
        }
      }
      conflict.value = false;
    } catch (failure) {
      loadError.value = message(failure);
    } finally {
      loading.value = false;
    }
  }

  bool used(String attributeId, String valueId) => variants.any(
    (v) =>
        v.status == 'ACTIVE' &&
        v.optionValues.any(
          (o) => o.attributeId == attributeId && o.valueId == valueId,
        ),
  );
  bool selected(String attributeId, String valueId) =>
      axes[attributeId]?.contains(valueId) == true;
  bool canSelect(PimAttribute attribute, String valueId) {
    if (locked) return false;
    if (selected(attribute.id, valueId)) {
      if (used(attribute.id, valueId)) return false;
      // Removing the final option would remove an axis; active variants retain their identity.
      if (hasActive && !canConvert && axes[attribute.id]!.length == 1) {
        return false;
      }
      return true;
    }
    return attribute.status == 'ACTIVE' &&
        attribute.usableForVariant &&
        attribute.dataType == 'SELECT' &&
        !product!.attributeValues.any((v) => v.attributeId == attribute.id) &&
        (!hasActive ||
            canConvert ||
            product!.variantAxes.any((a) => a.attributeId == attribute.id)) &&
        attribute.values.any((v) => v.valueId == valueId && v.active);
  }

  void select(PimAttribute attribute, String valueId, bool checked) {
    if (!canSelect(attribute, valueId)) return;
    final values = List<String>.of(axes[attribute.id] ?? <String>[]);
    if (checked && !values.contains(valueId)) values.add(valueId);
    if (!checked) values.remove(valueId);
    if (values.isEmpty) {
      axes.remove(attribute.id);
    } else {
      axes[attribute.id] = values;
    }
    error.value = null;
  }

  List<PimAxis> validated() {
    if (!writable) throw const AuthError(403, 'FORBIDDEN');
    if (axes.length > 6) throw StateError('حداکثر ۶ ویژگی تنوع مجاز است.');
    final result = <PimAxis>[];
    for (final entry in axes.entries) {
      final a = attributes.where((a) => a.id == entry.key).firstOrNull;
      if (a == null ||
          a.status != 'ACTIVE' ||
          !a.usableForVariant ||
          a.dataType != 'SELECT' ||
          product!.attributeValues.any((v) => v.attributeId == entry.key) ||
          entry.value.isEmpty ||
          entry.value.length > 100 ||
          entry.value.toSet().length != entry.value.length ||
          entry.value.any(
            (id) => !a.values.any((v) => v.valueId == id && v.active),
          )) {
        throw StateError(
          'هر ویژگی باید بین ۱ تا ۱۰۰ گزینهٔ فعال و معتبر داشته باشد.',
        );
      }
      result.add(
        PimAxis(attributeId: entry.key, valueIds: List.of(entry.value)),
      );
    }
    if (hasActive && !canConvert) {
      final before = product!.variantAxes.map((a) => a.attributeId).toSet();
      if (before.length != axes.length || !before.every(axes.containsKey)) {
        throw StateError(
          'تا وقتی تنوع فعال وجود دارد، ویژگی‌های تنوع محصول تغییر نمی‌کنند.',
        );
      }
      for (final variant in variants.where((v) => v.status == 'ACTIVE')) {
        if (variant.optionValues.any(
          (v) => !selected(v.attributeId, v.valueId),
        )) {
          throw StateError('گزینهٔ استفاده‌شده در تنوع فعال قابل حذف نیست.');
        }
      }
    }
    return result;
  }

  Future<bool> save() async {
    if (loading.value || saving.value || conflict.value || !writable) {
      return false;
    }
    saving.value = true;
    error.value = null;
    try {
      fx.context.check();
      if (pending.value != null && !pendingAxes) {
        throw StateError('درخواست باز مربوط به عملیات دیگری است.');
      }
      if (pending.value == null) {
        final values = validated();
        final before = {
          for (final axis in product!.variantAxes)
            axis.attributeId: axis.valueIds.toSet(),
        };
        if (values.length == before.length &&
            values.every(
              (a) =>
                  before[a.attributeId]?.length == a.valueIds.length &&
                  a.valueIds.every((id) => before[a.attributeId]!.contains(id)),
            )) {
          return true;
        }
        if (canConvert) {
          if (values.isEmpty ||
              values.any(
                (axis) =>
                    !axis.valueIds.contains(existingOptions[axis.attributeId]),
              )) {
            throw StateError(
              'برای هر ویژگی، گزینه مربوط به موجودی و سوابق فعلی کالا را انتخاب کنید.',
            );
          }
          final base = variants.single;
          pending.value = PimCommand(
            resource: PimResource.products,
            operation: 'convert-to-variable',
            id: productId,
            body: {
              'expectedRevision': product!.revision,
              'variantId': base.id,
              'expectedVariantRevision': base.revision,
              'variantAxes': values.map((axis) => axis.toJson()).toList(),
              'optionValues': [
                for (final axis in values)
                  {
                    'attributeId': axis.attributeId,
                    'valueId': existingOptions[axis.attributeId],
                  },
              ],
            },
          );
        } else {
          pending.value = fx.change(PimResource.products, {
            'variantAxes': values.map((a) => a.toJson()).toList(),
          }, item: product);
        }
      }
      final result = await fx.execute(pending.value!);
      if (result.item is! PimProduct || result.item!.id != productId) {
        throw const FormatException('Unexpected axes result');
      }
      product = result.item as PimProduct;
      if (result.baseVariant != null) {
        variants
          ..clear()
          ..add(result.baseVariant!);
      }
      pending.value = null;
      return true;
    } catch (failure) {
      conflict.value =
          failure is AuthError && failure.code == 'REVISION_CONFLICT';
      // A retry always uses the saved body/revision/key, even after re-opening the form.
      pending.value = await fx.restore();
      error.value = message(failure);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> addOption({
    PimAttribute? attribute,
    String name = '',
    String? colorHex,
  }) async {
    if (loading.value || saving.value || conflict.value || !writable) {
      return false;
    }
    error.value = null;
    notice.value = null;
    try {
      fx.context.check();
      if (pending.value != null && !pendingOption) {
        throw StateError('درخواست باز مربوط به عملیات دیگری است.');
      }
      if (pending.value == null) {
        if (attribute == null ||
            !canAddOption(attribute) ||
            !attributes.any((a) => identical(a, attribute))) {
          throw const AuthError(403, 'FORBIDDEN');
        }
        name = name.trim();
        if (name.isEmpty ||
            name.length > 200 ||
            RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]')
                .hasMatch(name)) {
          throw StateError('عنوان گزینه را تا ۲۰۰ نویسه وارد کنید.');
        }
        if (colorHex != null &&
                !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(colorHex) ||
            attribute.kind == 'COLOR' && colorHex == null) {
          throw StateError('رنگ گزینه را انتخاب کنید.');
        }
        final option = PimOption(
          valueId: const Uuid().v4(),
          name: name,
          colorHex: colorHex?.toUpperCase(),
        );
        pending.value = fx.change(PimResource.attributes, {
          'values': [
            ...attribute.values.map((v) => v.toJson()),
            option.toJson(),
          ],
        }, item: attribute);
      }
      saving.value = true;
      final command = pending.value!;
      final result = await fx.execute(command);
      if (result.item is! PimAttribute || result.item!.id != command.id) {
        throw const FormatException('Unexpected attribute option result');
      }
      final updated = result.item as PimAttribute;
      final values = command.body['values'] as List;
      final optionId = (values.last as Map)['valueId'] as String;
      if (!updated.values.any((v) => v.valueId == optionId)) {
        throw const FormatException('Missing added option');
      }
      attributes[attributes.indexWhere((a) => a.id == updated.id)] = updated;
      pending.value = null;
      saving.value = false;
      if (canSelect(updated, optionId)) select(updated, optionId, true);
      notice.value = 'گزینه در فهرست مشترک ثبت شد؛ برای افزودن آن به محصول، گزینه‌های محصول را ذخیره کنید.';
      return true;
    } catch (failure) {
      conflict.value =
          failure is AuthError && failure.code == 'REVISION_CONFLICT';
      pending.value = await fx.restore();
      error.value = message(failure);
      return false;
    } finally {
      saving.value = false;
    }
  }

  String message(Object failure) {
    if (failure is StateError) return failure.message.toString();
    if (failure is AuthError && failure.code == 'RECORD_IN_USE') {
      return 'گزینه یا ویژگی در تنوع فعال استفاده شده است؛ نسخهٔ جدید محصول را دریافت کنید.';
    }
    return PimFX.message(failure);
  }
}
