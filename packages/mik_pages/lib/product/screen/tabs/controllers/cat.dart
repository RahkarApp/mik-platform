import 'package:get/get.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';

class CatTabDashboardController extends GetxController {
  final cat = <PimCategory>[].obs;
  final loading = false.obs, saving = false.obs, conflict = false.obs;
  final error = RxnString(), commandError = RxnString(), notice = RxnString();
  final pending = Rxn<PimCommand>();
  final query = ''.obs, showArchived = false.obs;
  final catalog = <String, List<CatalogCategory>>{}.obs;
  final catalogLoading = <String>{}.obs;
  final catalogErrors = <String, String>{}.obs;
  PimFX? fx;
  int _generation = 0;
  bool _attached = false;
  bool get valid => _attached && fx?.context.valid == true;
  bool get locked =>
      !valid ||
      error.value != null ||
      loading.value ||
      saving.value ||
      conflict.value ||
      pending.value != null;
  bool get canCreate => !locked && fx!.has('pim.product.category.create');
  bool get canImport => !locked && fx!.has('pim.product.category.import');
  bool canEdit(PimCategory item) =>
      !locked &&
      item.status == 'ACTIVE' &&
      fx!.canChange(PimResource.categories, item);
  bool canStatus(PimCategory item) =>
      !locked &&
      fx!.canChange(
        PimResource.categories,
        item,
        archive: item.status == 'ACTIVE',
      );
  bool get pendingHere {
    final p = pending.value;
    if (p == null) return false;
    if (p.resource == null) {
      return p.operation == 'categories/import' &&
          p.body.keys.every({'codes'}.contains);
    }
    return p.resource == PimResource.categories &&
        ['create', 'update'].contains(p.operation) &&
        (p.id == null || cat.any((v) => v.id == p.id)) &&
        p.body.keys.every(
          {
            'name',
            'parentId',
            'description',
            'status',
            'expectedRevision',
          }.contains,
        );
  }

  Future<void> attach(String appId, {String search = ''}) async {
    detach();
    final context = BusinessContext.forApp(appId);
    fx = context == null ? null : PimFX.forContext(context);
    _attached = true;
    query.value = search;
    await init();
  }

  void detach() {
    _attached = false;
    _generation++;
    cat.clear();
    catalog.clear();
    catalogLoading.clear();
    catalogErrors.clear();
    loading.value = false;
    error.value = null;
    pending.value = null;
    showArchived.value = false;
  }

  void search(Object? value) {
    if (_attached && value != null && value != '-1') {
      query.value = value.toString();
    }
  }

  Future<void> init() async {
    if (!_attached || saving.value) return;
    final generation = ++_generation, client = fx;
    loading.value = true;
    error.value = null;
    commandError.value = null;
    cat.clear();
    catalogLoading.clear();
    try {
      if (client == null) throw const AuthError(401, 'SESSION_INVALID');
      await client.authorize();
      final rows = (await client.all(PimResource.categories))
          .cast<PimCategory>();
      final ids = rows.map((v) => v.id).toSet();
      if (ids.length != rows.length ||
          rows.any(
            (v) =>
                !['ACTIVE', 'ARCHIVED'].contains(v.status) ||
                !['CATALOG', 'CUSTOM'].contains(v.source),
          )) {
        throw const FormatException('Unexpected categories');
      }
      for (final row in rows) {
        final seen = {row.id};
        var parent = row.parentId;
        while (parent != null) {
          if (!seen.add(parent) || seen.length > 21 || !ids.contains(parent)) {
            throw const FormatException('Invalid category tree');
          }
          parent = rows.firstWhere((v) => v.id == parent).parentId;
        }
      }
      final command = await client.restore();
      client.context.check();
      if (generation != _generation) return;
      cat.assignAll(rows);
      pending.value = command;
      conflict.value = false;
    } catch (failure) {
      if (generation == _generation) error.value = message(failure);
    } finally {
      if (generation == _generation) loading.value = false;
    }
  }

  String normalize(String text) =>
      text.replaceAll(' ', '').toLowerCase().toEnglishDigit();
  Set<String> get visibleIds {
    final rows = cat
        .where((v) => v.status == (showArchived.value ? 'ARCHIVED' : 'ACTIVE'))
        .toList();
    final q = normalize(query.value);
    if (q.isEmpty) return rows.map((v) => v.id).toSet();
    final result = <String>{};
    for (final row in rows.where(
      (v) =>
          normalize(v.name).contains(q) ||
          normalize(v.id).contains(q) ||
          normalize(v.templateCode ?? '').contains(q),
    )) {
      result.add(row.id);
      var parent = row.parentId;
      while (parent != null &&
          rows.any((v) => v.id == parent) &&
          result.add(parent)) {
        parent = rows.firstWhere((v) => v.id == parent).parentId;
      }
    }
    return result;
  }

  List<PimCategory> parents(PimCategory? item) => cat.where((candidate) {
    if (candidate.status != 'ACTIVE') return false;
    var current = candidate;
    var depth = 0;
    while (true) {
      if (current.id == item?.id || depth++ >= 20) return false;
      if (current.parentId == null) return true;
      final parent = cat.where((v) => v.id == current.parentId).firstOrNull;
      if (parent == null || parent.status != 'ACTIVE') return false;
      current = parent;
    }
  }).toList();

  Future<bool> saveCategory({
    PimCategory? item,
    required String name,
    required String description,
    String? parentId,
  }) async {
    if (locked) return false;
    try {
      if (item == null ? !canCreate : !canEdit(item)) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      name = name.trim();
      description = description.trim();
      if (name.isEmpty ||
          name.length > 200 ||
          description.length > 10000 ||
          RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]')
              .hasMatch('$name$description')) {
        throw StateError(
          'نام معتبر تا ۲۰۰ نویسه و توضیحات تا ۱۰۰۰۰ نویسه وارد کنید.',
        );
      }
      if (parentId == null
          ? item?.source != 'CATALOG'
          : !parents(item).any((p) => p.id == parentId)) {
        throw StateError(
          'والد فعال و معتبر انتخاب کنید. دستهٔ سفارشی به والد نیاز دارد.',
        );
      }
      final fields = <String, dynamic>{
        if (item == null || name != item.name) 'name': name,
        if (item == null || parentId != item.parentId) 'parentId': parentId,
        if (item == null
            ? description.isNotEmpty
            : description != (item.description ?? ''))
          'description': description.isEmpty ? null : description,
      };
      if (fields.isEmpty) return true;
      return await execute(
        fx!.change(PimResource.categories, fields, item: item),
      );
    } catch (failure) {
      commandError.value = message(failure);
      return false;
    }
  }

  Future<void> changeStatus(PimCategory item) async {
    if (!canStatus(item)) return;
    await execute(
      fx!.change(PimResource.categories, {
        'status': item.status == 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE',
      }, item: item),
    );
  }

  Future<void> importCategory(CatalogCategory item) async {
    if (!canImport) return;
    await execute(
      fx!.operation('categories/import', {
        'codes': [item.id],
      }),
    );
  }

  Future<bool> execute(PimCommand command) async {
    if (!valid || saving.value || conflict.value || loading.value) return false;
    final generation = _generation, client = fx!;
    saving.value = true;
    commandError.value = null;
    notice.value = null;
    var success = false;
    try {
      pending.value = command;
      if (!pendingHere) {
        throw StateError('درخواست مربوط به مدیریت دسته‌بندی‌ها نیست.');
      }
      await client.execute(command);
      client.context.check();
      if (generation != _generation) return false;
      pending.value = null;
      notice.value = 'دسته‌بندی‌ها ذخیره شدند.';
      success = true;
    } catch (failure) {
      if (generation == _generation) {
        pending.value = client.pending;
        conflict.value =
            failure is AuthError && failure.code == 'REVISION_CONFLICT';
        commandError.value = message(failure);
      }
    } finally {
      saving.value = false;
    }
    if (success && generation == _generation) await init();
    return success;
  }

  Future<void> resume() async {
    if (pendingHere) await execute(pending.value!);
  }

  Future<void> loadCatalog({String? parent}) async {
    final key = parent ?? '', client = fx, generation = _generation;
    if (!valid ||
        client == null ||
        catalogLoading.contains(key) ||
        catalog.containsKey(key)) {
      return;
    }
    catalogLoading.add(key);
    catalogErrors.remove(key);
    try {
      final rows = <CatalogCategory>[], cursors = <String>{};
      String? after;
      int? version;
      do {
        final page = await client.catalog(parentCode: parent, after: after);
        if (version != null && version != page.version ||
            page.items.any((v) => v.parent != parent)) {
          throw const FormatException('Unexpected catalog page');
        }
        version = page.version;
        rows.addAll(page.items);
        after = page.nextCursor;
        if (after != null && !cursors.add(after)) {
          throw const FormatException('Repeated catalog cursor');
        }
      } while (after != null);
      if (rows.map((v) => v.id).toSet().length != rows.length) {
        throw const FormatException('Duplicate catalog codes');
      }
      client.context.check();
      if (generation == _generation) catalog[key] = rows;
    } catch (failure) {
      if (generation == _generation) catalogErrors[key] = message(failure);
    } finally {
      if (generation == _generation) catalogLoading.remove(key);
    }
  }

  String message(Object failure) {
    if (failure is StateError) return failure.message.toString();
    if (failure is AuthError && failure.code == 'RECORD_IN_USE') {
      return 'این دسته‌بندی محصول یا زیر‌دستهٔ فعال دارد و قابل آرشیو نیست.';
    }
    if (failure is AuthError && failure.code == 'VALIDATION_FAILED') {
      return 'اطلاعات، والد و عمق دسته‌بندی را بررسی کنید؛ والد آرشیوشده ابتدا باید فعال شود.';
    }
    return PimFX.message(failure);
  }
}
