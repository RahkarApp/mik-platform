import 'dart:convert';

import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class ProductPropertyTabDashboardController extends GetxController {
  static const kinds = {
    'COLOR': 'رنگ',
    'SIZE': 'سایز',
    'PART_NUMBER': 'شماره فنی',
    'GENERAL': 'عمومی',
  };
  static const types = {
    'TEXT': 'متنی',
    'NUMBER': 'عددی',
    'BOOLEAN': 'بله/خیر',
    'SELECT': 'تک‌انتخابی',
    'MULTI_SELECT': 'چندانتخابی',
  };
  final pro = <PimAttribute>[].obs;
  final loading = false.obs,
      saving = false.obs,
      conflict = false.obs,
      showArchived = false.obs;
  final error = RxnString(), commandError = RxnString();
  final query = ''.obs;
  final pending = Rxn<PimCommand>();
  final units = <CatalogUnit>[];
  PimFX? fx;
  bool _attached = false;
  int _generation = 0;
  bool get valid => _attached && fx?.context.valid == true;
  bool get locked =>
      !valid ||
      loading.value ||
      saving.value ||
      conflict.value ||
      error.value != null ||
      pending.value != null;
  bool get canCreate => !locked && fx!.has('pim.attribute.create');
  bool canEdit(PimAttribute item) =>
      !locked &&
      item.status == 'ACTIVE' &&
      fx!.canChange(PimResource.attributes, item);
  bool canStatus(PimAttribute item) =>
      !locked &&
      fx!.canChange(
        PimResource.attributes,
        item,
        archive: item.status == 'ACTIVE',
      );
  bool get pendingHere {
    final p = pending.value;
    return p?.resource == PimResource.attributes &&
        ['create', 'update'].contains(p?.operation) &&
        (p?.id == null || pro.any((v) => v.id == p!.id)) &&
        p!.body.keys.every(
          {
            'name',
            'kind',
            'dataType',
            'usableForVariant',
            'unitId',
            'values',
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
    _generation++;
    _attached = false;
    pro.clear();
    units.clear();
    pending.value = null;
    loading.value = false;
    error.value = null;
    commandError.value = null;
    showArchived.value = false;
  }

  void search(Object? value) {
    if (_attached && value != null && value != '-1') {
      query.value = value.toString();
    }
  }

  List<PimAttribute> get visible {
    String normalize(String value) =>
        value.replaceAll(' ', '').toLowerCase().toEnglishDigit();
    final q = normalize(query.value);
    return pro
        .where(
          (v) =>
              v.status == (showArchived.value ? 'ARCHIVED' : 'ACTIVE') &&
              (q.isEmpty ||
                  normalize(v.name).contains(q) ||
                  normalize(v.id).contains(q) ||
                  v.values.any((o) => normalize(o.name).contains(q))),
        )
        .toList();
  }

  Future<void> init() async {
    if (!_attached || saving.value) return;
    final generation = ++_generation, client = fx;
    loading.value = true;
    error.value = null;
    commandError.value = null;
    pro.clear();
    try {
      if (client == null) throw const AuthError(401, 'SESSION_INVALID');
      await client.authorize();
      final rows = (await client.all(PimResource.attributes))
          .cast<PimAttribute>();
      if (rows.map((v) => v.id).toSet().length != rows.length ||
          rows.any(
            (v) =>
                !kinds.containsKey(v.kind) ||
                !types.containsKey(v.dataType) ||
                !['ACTIVE', 'ARCHIVED'].contains(v.status),
          )) {
        throw const FormatException('Unexpected attributes');
      }
      final command = await client.restore();
      client.context.check();
      if (generation != _generation) return;
      pro.assignAll(rows);
      pending.value = command;
      conflict.value = false;
    } catch (failure) {
      if (generation == _generation) error.value = message(failure);
    } finally {
      if (generation == _generation) loading.value = false;
    }
  }

  Future<void> loadUnits() async {
    final client = fx, generation = _generation;
    if (client == null || !valid || units.isNotEmpty) return;
    final catalog = await client.catalog();
    client.context.check();
    if (generation != _generation) return;
    if (catalog.units.map((v) => v.id).toSet().length != catalog.units.length) {
      throw const FormatException('Duplicate attribute units');
    }
    units.addAll(catalog.units.where((v) => v.id != 0));
  }

  void validate({
    required String name,
    required String kind,
    required String dataType,
    required bool usableForVariant,
    required List<PimOption> values,
    int? unitId,
    PimAttribute? item,
  }) {
    if (name.isEmpty ||
        name.length > 200 ||
        RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]').hasMatch(name)) {
      throw StateError('عنوان ویژگی را تا ۲۰۰ نویسه وارد کنید.');
    }
    if (!kinds.containsKey(kind) ||
        !types.containsKey(dataType) ||
        (usableForVariant || ['COLOR', 'SIZE'].contains(kind)) &&
            dataType != 'SELECT') {
      throw StateError('ویژگی تنوع، رنگ و سایز باید تک‌انتخابی باشند.');
    }
    if (values.length > 200 ||
        values.map((v) => v.valueId).toSet().length != values.length ||
        !['SELECT', 'MULTI_SELECT'].contains(dataType) && values.isNotEmpty) {
      throw StateError(
        'گزینه‌ها فقط برای ویژگی انتخابی و حداکثر ۲۰۰ گزینه هستند.',
      );
    }
    for (final v in values) {
      if (!RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
          ).hasMatch(v.valueId) ||
          v.name.trim().isEmpty ||
          v.name.trim().length > 200 ||
          v.code != null && (v.code!.trim().isEmpty || v.code!.length > 100) ||
          RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]')
              .hasMatch('${v.name}${v.code ?? ''}')) {
        throw StateError('نام و کد گزینه را بررسی کنید.');
      }
      if (kind == 'COLOR' && v.colorHex == null ||
          v.colorHex != null &&
              !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v.colorHex!)) {
        throw StateError('رنگ هر گزینه را انتخاب کنید.');
      }
    }
    if (unitId != null &&
        unitId != item?.unitId &&
        !units.any((v) => v.id == unitId)) {
      throw StateError('واحد معتبر سرور را انتخاب کنید.');
    }
  }

  Future<bool> save({
    PimAttribute? item,
    required String name,
    required String kind,
    required String dataType,
    required bool usableForVariant,
    required List<PimOption> values,
    int? unitId,
  }) async {
    if (locked) return false;
    commandError.value = null;
    try {
      if (item == null ? !canCreate : !canEdit(item)) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      name = name.trim();
      validate(
        name: name,
        kind: kind,
        dataType: dataType,
        usableForVariant: usableForVariant,
        values: values,
        unitId: unitId,
        item: item,
      );
      final fields = <String, dynamic>{
        if (item == null || name != item.name) 'name': name,
        if (item == null || kind != item.kind) 'kind': kind,
        if (item == null || dataType != item.dataType) 'dataType': dataType,
        if (item == null || usableForVariant != item.usableForVariant)
          'usableForVariant': usableForVariant,
        if (item == null ? unitId != null : unitId != item.unitId)
          'unitId': unitId,
        if (item == null ||
            jsonEncode(values.map((v) => v.toJson()).toList()) !=
                jsonEncode(item.values.map((v) => v.toJson()).toList()))
          'values': values.map((v) => v.toJson()).toList(),
      };
      if (fields.isEmpty) return true;
      return await execute(
        fx!.change(PimResource.attributes, fields, item: item),
      );
    } catch (failure) {
      commandError.value = message(failure);
      return false;
    }
  }

  Future<void> changeStatus(PimAttribute item) async {
    if (!canStatus(item)) return;
    try {
      await execute(
        fx!.change(PimResource.attributes, {
          'status': item.status == 'ACTIVE' ? 'ARCHIVED' : 'ACTIVE',
        }, item: item),
      );
    } catch (failure) {
      commandError.value = message(failure);
    }
  }

  Future<bool> execute(PimCommand command) async {
    if (!valid || saving.value || loading.value || conflict.value) return false;
    final client = fx!, generation = _generation;
    saving.value = true;
    commandError.value = null;
    var success = false;
    try {
      pending.value = command;
      if (!pendingHere) {
        throw StateError('درخواست به مدیریت ویژگی‌ها مربوط نیست.');
      }
      await client.execute(command);
      client.context.check();
      if (generation != _generation) return false;
      pending.value = null;
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

  String message(Object failure) {
    if (failure is StateError) return failure.message.toString();
    if (failure is AuthError && failure.code == 'RECORD_IN_USE') {
      return 'این ویژگی یا گزینه در محصول استفاده شده است؛ تغییر نوع، آرشیو یا غیرفعال‌سازی آن مجاز نیست.';
    }
    return PimFX.message(failure);
  }
}
