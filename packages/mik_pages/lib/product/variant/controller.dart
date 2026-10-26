import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';

class ProductVariantController extends GetxController {
  final PimFX fx;
  final String productId;
  ProductVariantController(this.fx, this.productId);
  final loading = false.obs, saving = false.obs, previewing = false.obs;
  final conflict = false.obs;
  final error = RxnString(), loadError = RxnString(), notice = RxnString();
  final variants = <PimVariant>[].obs;
  final attributes = <String, PimAttribute>{}.obs;
  final selected = <String, List<String>>{}.obs;
  final preview = Rxn<PimPreview>(), pending = Rxn<PimCommand>();
  PimProduct? product;
  List<PimAxis>? _previewAxes;
  int _selection = 0;
  bool get writable =>
      fx.context.valid && product != null && product!.status != 'ARCHIVED';
  bool get busy => loading.value || saving.value || previewing.value;
  bool get canGenerate =>
      writable && fx.has('pim.variant.create') && fx.has('pim.variant.read');
  bool get canEditAxes =>
      writable &&
      fx.has('pim.product.update') &&
      fx.has('pim.attribute.assign') &&
      fx.has('pim.attribute.read') &&
      fx.has('pim.variant.read');
  bool get pendingAxes {
    final p = pending.value;
    if (p?.resource == PimResource.attributes &&
        p?.operation == 'update' &&
        p!.body['values'] is List &&
        p.body.keys.every({'values', 'expectedRevision'}.contains)) {
      return true;
    }
    return p?.resource == PimResource.products &&
        p?.id == productId &&
        ['update', 'convert-to-variable'].contains(p?.operation) &&
        p!.body.containsKey('variantAxes') &&
        p.body.keys.every(
          {
            'variantAxes',
            'expectedRevision',
            'variantId',
            'expectedVariantRevision',
            'optionValues',
          }.contains,
        );
  }

  bool get pendingHere {
    final p = pending.value;
    if (p == null) return false;
    if (p.resource == null) {
      return p.operation == 'variants/generate' &&
          p.body['productId'] == productId &&
          p.body.keys.every({'productId', 'axes'}.contains);
    }
    return p.resource == PimResource.variants &&
        p.operation == 'update' &&
        variants.any((v) => v.id == p.id) &&
        ['ACTIVE', 'ARCHIVED'].contains(p.body['status']) &&
        p.body.keys.every({'status', 'expectedRevision'}.contains);
  }

  Future<void> load() async {
    if (busy) return;
    loading.value = true;
    loadError.value = null;
    error.value = null;
    preview.value = null;
    _previewAxes = null;
    _selection++;
    product = null;
    variants.clear();
    attributes.clear();
    selected.clear();
    try {
      await fx.authorize();
      fx.require('pim.variant.read');
      final owner = await fx.get(PimResource.products, productId) as PimProduct;
      final rows = (await fx.all(
        PimResource.variants,
        filters: {'productId': productId},
      )).cast<PimVariant>();
      if (rows.any(
            (v) =>
                v.productId != productId ||
                !['ACTIVE', 'ARCHIVED'].contains(v.status),
          ) ||
          rows.map((v) => v.id).toSet().length != rows.length ||
          rows.map((v) => key(v.optionValues)).toSet().length != rows.length) {
        throw const FormatException('Unexpected product variants');
      }
      final names = <String, PimAttribute>{};
      if (fx.has('pim.attribute.read')) {
        final ids = {
          ...owner.variantAxes.map((a) => a.attributeId),
          ...rows.expand((v) => v.optionValues.map((o) => o.attributeId)),
        };
        for (final id in ids) {
          names[id] = await fx.get(PimResource.attributes, id) as PimAttribute;
        }
      }
      final command = await fx.restore();
      fx.context.check();
      product = owner;
      variants.assignAll(rows);
      attributes.assignAll(names);
      selected.assignAll({
        for (final axis in owner.variantAxes)
          axis.attributeId: List.of(axis.valueIds),
      });
      pending.value = command;
      conflict.value = false;
    } catch (failure) {
      loadError.value = message(failure);
    } finally {
      loading.value = false;
    }
  }

  String key(List<PimOptionPair> options) {
    final sorted = List.of(options)
      ..sort((a, b) => a.attributeId.compareTo(b.attributeId));
    return sorted.isEmpty
        ? 'BASE'
        : sorted.map((o) => '${o.attributeId}:${o.valueId}').join('|');
  }

  String label(String id) => attributes[id]?.name ?? id;
  String option(String attributeId, String valueId) =>
      attributes[attributeId]?.values
          .where((v) => v.valueId == valueId)
          .firstOrNull
          ?.name ??
      valueId;
  String title(List<PimOptionPair> options) => options.isEmpty
      ? 'تنوع پایه'
      : options
            .map(
              (o) =>
                  '${label(o.attributeId)}: ${option(o.attributeId, o.valueId)}',
            )
            .join('، ');
  PimVariant? existing(List<PimOptionPair> options) =>
      variants.where((v) => key(v.optionValues) == key(options)).firstOrNull;

  void select(String attributeId, String valueId, bool checked) {
    if (busy || pending.value != null || conflict.value || !canGenerate) return;
    final axis = product!.variantAxes
        .where((a) => a.attributeId == attributeId)
        .firstOrNull;
    if (axis == null || !axis.valueIds.contains(valueId)) return;
    final values = List<String>.of(selected[attributeId] ?? <String>[]);
    if (checked && !values.contains(valueId)) values.add(valueId);
    if (!checked) values.remove(valueId);
    selected[attributeId] = values;
    _selection++;
    preview.value = null;
    _previewAxes = null;
    error.value = null;
    notice.value = null;
  }

  List<PimAxis> axes() {
    final owner = product;
    if (owner == null) throw StateError('محصول در دسترس نیست.');
    var count = 1;
    final axes = <PimAxis>[];
    for (final axis in owner.variantAxes) {
      final ids = selected[axis.attributeId] ?? [];
      if (ids.isEmpty) {
        throw StateError('برای هر ویژگی حداقل یک گزینه انتخاب کنید.');
      }
      if (ids.any((id) => !axis.valueIds.contains(id))) {
        throw StateError('گزینهٔ انتخاب‌شده متعلق به محصول نیست.');
      }
      count *= ids.length;
      axes.add(PimAxis(attributeId: axis.attributeId, valueIds: List.of(ids)));
    }
    if (count > 100) {
      throw StateError('در هر درخواست حداکثر ۱۰۰ ترکیب انتخاب کنید.');
    }
    return axes;
  }

  Future<void> showPreview() async {
    if (busy || !canGenerate || pending.value != null || conflict.value) return;
    previewing.value = true;
    error.value = null;
    notice.value = null;
    preview.value = null;
    _previewAxes = null;
    final selection = _selection;
    try {
      final chosen = axes();
      final result = await fx.preview(productId, axes: chosen);
      final count = chosen.fold<int>(1, (n, a) => n * a.valueIds.length);
      if (result.combinations.length != count ||
          result.combinations.map(key).toSet().length != count ||
          result.combinations.any(
            (row) =>
                row.length != chosen.length ||
                row.map((o) => o.attributeId).toSet().length != row.length ||
                row.any(
                  (o) => !chosen.any(
                    (a) =>
                        a.attributeId == o.attributeId &&
                        a.valueIds.contains(o.valueId),
                  ),
                ),
          )) {
        throw const FormatException('Unexpected variant preview');
      }
      fx.context.check();
      if (selection != _selection) return;
      _previewAxes = chosen;
      preview.value = result;
    } catch (failure) {
      error.value = message(failure);
    } finally {
      previewing.value = false;
    }
  }

  bool canChange(PimVariant item) =>
      writable &&
      !busy &&
      pending.value == null &&
      !conflict.value &&
      variants.any((v) => identical(v, item)) &&
      fx.canChange(
        PimResource.variants,
        item,
        archive: item.status == 'ACTIVE',
      ) &&
      !(item.status == 'ACTIVE' &&
          product!.status == 'ACTIVE' &&
          variants.where((v) => v.status == 'ACTIVE').length == 1);

  Future<void> changeStatus(PimVariant item) async {
    if (!canChange(item)) return;
    await save(
      fx.change(PimResource.variants, {
        'status': item.status == 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE',
      }, item: item),
    );
  }

  Future<void> generate() async {
    if (busy ||
        !canGenerate ||
        pending.value != null ||
        conflict.value ||
        preview.value == null ||
        _previewAxes == null) {
      return;
    }
    await save(
      fx.operation('variants/generate', {
        'productId': productId,
        'axes': _previewAxes!.map((a) => a.toJson()).toList(),
      }),
    );
  }

  Future<void> resume() async {
    if (pendingHere) await save(pending.value!);
  }

  Future<void> save(PimCommand command) async {
    if (busy || conflict.value || !writable) return;
    saving.value = true;
    error.value = null;
    notice.value = null;
    try {
      // Preserve the original request key after uncertain network results.
      final previous = pending.value;
      pending.value = command;
      if (!pendingHere) {
        pending.value = previous;
        throw StateError('درخواست به عملیات تنوع‌های این محصول مربوط نیست.');
      }
      final result = await fx.execute(command);
      pending.value = null;
      notice.value = command.operation == 'variants/generate'
          ? '${result.createdCount} تنوع جدید ساخته شد؛ تنوع‌های آرشیوشده تغییری نکردند.'
          : 'وضعیت تنوع ذخیره شد.';
    } catch (failure) {
      conflict.value =
          failure is AuthError && failure.code == 'REVISION_CONFLICT';
      pending.value = await fx.restore();
      error.value = message(failure);
      return;
    } finally {
      saving.value = false;
    }
    await load();
  }

  String message(Object failure) {
    if (failure is StateError) return failure.message.toString();
    if (failure is AuthError && failure.code == 'RECORD_IN_USE') {
      return 'این تنوع در استفاده است و سرور اجازهٔ تغییر وضعیت نمی‌دهد.';
    }
    return PimFX.message(failure);
  }
}
