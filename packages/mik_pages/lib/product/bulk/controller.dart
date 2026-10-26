import 'package:get/get.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/pim_group.dart';
import 'package:uuid/uuid.dart';

import '../add/controller.dart';

class BulkProductRow {
  final String id;
  String name, price;
  List<String> categoryIds;
  String? primaryCategoryId, brandId;
  int? unitId;
  final error = RxnString();
  BulkProductRow({
    String? id,
    this.name = '',
    this.price = '',
    this.categoryIds = const [],
    this.primaryCategoryId,
    this.brandId,
    this.unitId,
  }) : id = id ?? const Uuid().v4();

  factory BulkProductRow.fromDraft(PimProductDraft draft) => BulkProductRow(
    id: draft.id,
    name: draft.name,
    price: draft.prices.isEmpty
        ? ''
        : draft.prices.single.input ??
              draft.prices.single.amount?.toString() ??
              '',
    categoryIds: List<String>.from(draft.fields['categoryIds'] as List? ?? []),
    primaryCategoryId: draft.fields['primaryCategoryId'] as String?,
    brandId: draft.fields['brandId'] as String?,
    unitId: draft.fields['unitId'] as int?,
  );

  PimProductDraft toDraft() => PimProductDraft(
    id: id,
    name: name,
    fields: {
      'categoryIds': categoryIds.toList(),
      'primaryCategoryId': primaryCategoryId,
      'unitId': unitId,
      if (brandId != null) 'brandId': brandId,
    },
    prices: price.trim().isEmpty
        ? []
        : [
            PimDraftPrice(
              name: 'فروش',
              amount: null,
              input: price,
              isDefault: true,
            ),
          ],
  );
}

class ProductBulkController extends GetxController {
  final PimProductAddController form;
  ProductBulkController(PimGroupFX group)
    : form = PimProductAddController(group);
  PimGroupFX get group => form.group;
  final rows = <BulkProductRow>[].obs;
  final loading = false.obs, saving = false.obs, done = false.obs;
  final loadError = RxnString(),
      error = RxnString(),
      storageError = RxnString();
  final state = const PimGroupState().obs;
  bool get locked => form.locked.value || done.value;
  bool get editable => !loading.value && !saving.value && !locked;

  Future<void> load() async {
    if (saving.value) return;
    loading.value = true;
    loadError.value = null;
    error.value = null;
    try {
      await form.load();
      if (form.loadError.value != null) throw StateError(form.loadError.value!);
      state.value = form.recovery;
      final drafts = form.recovery.drafts;
      // A richer single-product draft must never lose its variants or descriptive fields here.
      if (drafts.any(
        (d) =>
            d.barcode != null ||
            d.fields.keys.any(
              (k) => !{
                'name',
                'categoryIds',
                'primaryCategoryId',
                'unitId',
                'brandId',
              }.contains(k),
            ) ||
            d.prices.length > 1 ||
            d.prices.any((p) => p.name != 'فروش' || !p.isDefault),
      )) {
        throw StateError(
          'پیش‌نویس موجود اطلاعات بیشتری دارد؛ آن را از افزودن تکی محصول ادامه دهید.',
        );
      }
      rows.assignAll(drafts.map(BulkProductRow.fromDraft));
      if (!locked && rows.isEmpty) rows.add(BulkProductRow());
    } catch (failure) {
      loadError.value = message(failure);
    } finally {
      loading.value = false;
    }
  }

  Future<void> persist() async {
    if (!editable) return;
    final snapshot = rows.map((r) => r.toDraft()).toList();
    try {
      await group.updateDrafts((_) => snapshot);
      storageError.value = null;
    } catch (failure) {
      storageError.value = message(failure);
    }
  }

  void changed(BulkProductRow row) {
    if (!editable) return;
    row.error.value = null;
    persist();
  }

  Future<void> addRow() async {
    if (!editable) return;
    rows.add(BulkProductRow());
    await persist();
  }

  Future<void> removeRow(BulkProductRow row) async {
    if (!editable || rows.length <= 1) return;
    rows.remove(row);
    await persist();
  }

  void requireFinalRegistration(BulkProductRow row) {
    if (row.price.trim().isEmpty) {
      throw StateError('برای ثبت نهایی، قیمت فروش این محصول را وارد کنید.');
    }
    if (!form.canPrice || !form.canActivate) {
      throw StateError(
        'ثبت نهایی به مجوز ثبت قیمت پیش‌فرض و فعال‌سازی محصول نیاز دارد.',
      );
    }
  }

  PimProductDraft validate(BulkProductRow row) {
    requireFinalRegistration(row);
    form.selectedCategories.assignAll(row.categoryIds);
    form.primaryCategory.value = row.primaryCategoryId;
    form.unitId.value = row.unitId;
    form.brandId.value = row.brandId;
    final draft = form.draft(
      name: row.name,
      price: row.price.replaceAll('تومان', '').replaceAll(',', '').trim(),
    );
    return PimProductDraft(
      id: row.id,
      name: draft.name,
      fields: draft.fields,
      prices: draft.prices,
    );
  }

  Future<bool> save() async {
    if (loading.value ||
        saving.value ||
        done.value ||
        loadError.value != null) {
      return false;
    }
    saving.value = true;
    error.value = null;
    try {
      group.products.context.check();
      if (locked && !state.value.pending) {
        throw StateError(
          'درخواست باز مربوط به عملیات دیگری است؛ ابتدا همان عملیات را تعیین تکلیف کنید.',
        );
      }
      final drafts = <PimProductDraft>[];
      if (locked) {
        for (final row in rows) {
          requireFinalRegistration(row);
          final created = state.value.steps.indexed.any(
            (entry) =>
                entry.$1 < state.value.next &&
                entry.$2.draftId == row.id &&
                entry.$2.command.resource == PimResource.products &&
                entry.$2.command.operation == 'create',
          );
          final activates = state.value.steps.any(
            (step) =>
                step.draftId == row.id &&
                step.command.resource == PimResource.products &&
                step.command.operation == 'update' &&
                step.command.body['status'] == 'ACTIVE',
          );
          if (created && !activates) {
            throw StateError(
              'ثبت قبلی شامل فعال‌سازی نبوده است؛ آن را از افزودن تکی ادامه دهید و سپس قیمت و وضعیت محصول را تکمیل کنید.',
            );
          }
        }
      }
      if (!locked) {
        // Validate every row before the first server mutation, using the single-product rules.
        for (final row in rows) {
          row.error.value = null;
          try {
            drafts.add(validate(row));
          } catch (failure) {
            row.error.value = message(failure);
          }
        }
        if (drafts.isEmpty || rows.any((r) => r.error.value != null)) {
          error.value =
              'خطاهای ردیف‌ها را اصلاح کنید؛ هنوز محصولی ارسال نشده است.';
          return false;
        }
      }
      await group.save(drafts);
      done.value = true;
      for (final row in rows) {
        row.error.value = null;
      }
      return true;
    } catch (failure) {
      error.value = message(failure);
      return false;
    } finally {
      try {
        state.value = await group.read();
        form.locked.value =
            state.value.pending || await group.products.restore() != null;
        if (error.value != null &&
            state.value.pending &&
            state.value.next < state.value.steps.length) {
          final id = state.value.steps[state.value.next].draftId;
          rows.where((r) => r.id == id).firstOrNull?.error.value = error.value;
        }
      } catch (failure) {
        form.locked.value = true;
        storageError.value = message(failure);
      }
      saving.value = false;
    }
  }

  String progress(BulkProductRow row) {
    if (done.value) return 'ثبت نهایی انجام شد';
    if (saving.value) return 'در حال ثبت گروه…';
    final current = state.value;
    final steps = current.steps.indexed
        .where((e) => e.$2.draftId == row.id)
        .toList();
    if (steps.isEmpty) return 'ارسال نشده';
    final remaining = steps.where((e) => e.$1 >= current.next).toList();
    if (remaining.isEmpty) {
      final activated = steps.any(
        (entry) =>
            entry.$2.command.resource == PimResource.products &&
            entry.$2.command.operation == 'update' &&
            entry.$2.command.body['status'] == 'ACTIVE',
      );
      return activated
          ? 'ثبت نهایی انجام شد'
          : 'محصول ایجاد شده؛ فعال‌سازی انجام نشده است.';
    }
    final command = remaining.first.$2.command;
    if (command.resource == PimResource.prices) {
      return 'محصول ایجاد شده؛ ثبت قیمت باقی مانده است.';
    }
    if (command.operation == 'update') {
      return 'تأیید فعال‌سازی محصول باقی مانده است.';
    }
    return 'ثبت محصول کامل نشده است؛ ادامه با همان درخواست انجام می‌شود.';
  }

  String message(Object failure) => failure is StateError
      ? failure.message.toString()
      : PimFX.message(failure);
  @override
  void onClose() {
    form.onClose();
    super.onClose();
  }
}
