import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class ProductBrandController extends GetxController {
  final pro = <PimBrand>[].obs;
  final loading = false.obs,
      saving = false.obs,
      conflict = false.obs,
      showArchived = false.obs;
  final error = RxnString(), commandError = RxnString();
  final query = ''.obs;
  final pending = Rxn<PimCommand>();
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
  bool get canCreate => !locked && fx!.has('pim.brand.create');
  bool canEdit(PimBrand item) =>
      !locked &&
      item.status == 'ACTIVE' &&
      fx!.canChange(PimResource.brands, item);
  bool canStatus(PimBrand item) =>
      !locked &&
      fx!.canChange(PimResource.brands, item, archive: item.status == 'ACTIVE');
  bool get pendingHere {
    final p = pending.value;
    return p?.resource == PimResource.brands &&
        ['create', 'update'].contains(p?.operation) &&
        (p?.id == null || pro.any((v) => v.id == p!.id)) &&
        p!.body.keys.every(
          {
            'name',
            'latinName',
            'description',
            'website',
            'status',
            'expectedRevision',
          }.contains,
        );
  }

  Future<void> attach(String appId) async {
    detach();
    final context = BusinessContext.forApp(appId);
    fx = context == null ? null : PimFX.forContext(context);
    _attached = true;
    query.value = '';
    await init();
  }

  Future<bool> attachClient(PimFX client) async {
    detach();
    fx = client;
    _attached = true;
    await init();
    return true;
  }

  void detach() {
    _generation++;
    _attached = false;
    pro.clear();
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

  List<PimBrand> get visible {
    String normalize(String value) =>
        value.replaceAll(' ', '').toLowerCase().toEnglishDigit();
    final q = normalize(query.value);
    return pro
        .where(
          (v) =>
              v.status == (showArchived.value ? 'ARCHIVED' : 'ACTIVE') &&
              (q.isEmpty ||
                  normalize(v.name).contains(q) ||
                  normalize(v.id).contains(q)),
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
      final rows = (await client.all(PimResource.brands)).cast<PimBrand>();
      if (rows.map((v) => v.id).toSet().length != rows.length ||
          rows.any((v) => !['ACTIVE', 'ARCHIVED'].contains(v.status))) {
        throw const FormatException('Unexpected brands');
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

  Future<bool> save({
    PimBrand? item,
    required String name,
    String latinName = '',
    String description = '',
    String website = '',
  }) async {
    if (locked) return false;
    commandError.value = null;
    try {
      if (item == null ? !canCreate : !canEdit(item)) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      final values = <String, String?>{
        'name': name.trim(),
        'latinName': latinName.trim().isEmpty ? null : latinName.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
        'website': website.trim().isEmpty ? null : website.trim(),
      };
      for (final entry in values.entries) {
        final value = entry.value;
        final max = entry.key == 'description'
            ? 10000
            : entry.key == 'website'
            ? 1000
            : 200;
        if (entry.key == 'name' && (value == null || value.isEmpty) ||
            value != null &&
                (value.length > max ||
                    RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]')
                        .hasMatch(value))) {
          throw StateError('عنوان برند و طول مجاز فیلدها را بررسی کنید.');
        }
      }
      if (values['website'] != null) {
        final uri = Uri.tryParse(values['website']!);
        if (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw StateError(
            'نشانی وب‌سایت باید با http یا https و بدون نام کاربری و رمز باشد.',
          );
        }
      }
      final before = {
        'name': item?.name,
        'latinName': item?.latinName,
        'description': item?.description,
        'website': item?.website,
      };
      final fields = <String, dynamic>{
        for (final v in values.entries)
          if (item == null ? v.value != null : v.value != before[v.key])
            v.key: v.value,
      };
      if (fields.isEmpty) return true;
      return await execute(fx!.change(PimResource.brands, fields, item: item));
    } catch (failure) {
      commandError.value = message(failure);
      return false;
    }
  }

  Future<void> changeStatus(PimBrand item) async {
    if (!canStatus(item)) return;
    try {
      await execute(
        fx!.change(PimResource.brands, {
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
        throw StateError('درخواست به مدیریت برندها مربوط نیست.');
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
      return 'این برند در محصول استفاده شده است و قابل آرشیو نیست.';
    }
    return PimFX.message(failure);
  }
}
