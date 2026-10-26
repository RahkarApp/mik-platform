import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/personnel.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/personnel.dart';

class PersonnelController extends GetxController {
  final String appId;
  final void Function(String, bool) onNotice;
  PersonnelController({required this.appId, required this.onNotice});
  PersonnelFX? fx;
  final tab = 0.obs, loading = false.obs, saving = false.obs;
  final rows = <PersonnelEntry>[].obs;
  final error = RxnString();
  final pending = Rxn<PersonnelCommand>();
  bool closed = false;
  PersonnelResource get resource =>
      tab.value == 0 ? PersonnelResource.person : PersonnelResource.role;
  bool get locked => loading.value || saving.value || pending.value != null;
  bool canWrite(PersonnelResource resource, {bool update = false}) =>
      !locked && fx?.has(resource.writePermission(update)) == true;
  void fail(Object failure) {
    if (closed) return;
    error.value = PersonnelFX.message(failure);
    if (failure is AuthError &&
        (failure.requiresLogin ||
            failure.statusCode == 403 ||
            failure.code == 'SELECTION_CHANGED')) {
      rows.clear();
    }
    onNotice(error.value!, false);
  }

  Future<void> load() async {
    if (closed || loading.value || saving.value) return;
    loading.value = true;
    rows.clear();
    error.value = null;
    try {
      final context = BusinessContext.forApp(appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      fx ??= PersonnelFX.forContext(context);
      await fx!.authorize();
      pending.value = await fx!.restore();
      final result = await fx!.list(resource);
      if (!closed) rows.assignAll(result);
    } catch (failure) {
      fail(failure);
    } finally {
      if (!closed) loading.value = false;
    }
  }

  Future<PersonnelEntry?> details(PersonnelEntry row) async {
    if (locked) {
      onNotice('عملیات قبلی هنوز تمام نشده است.', false);
      return null;
    }
    try {
      await fx!.authorize();
      final item = await fx!.get(row.resource, row.id);
      return closed ? null : item;
    } catch (failure) {
      fail(failure);
      return null;
    }
  }

  Future<PersonnelEntry?> save(
    PersonnelResource resource,
    Map<String, dynamic> body, {
    PersonnelEntry? item,
  }) async {
    if (closed) return null;
    if (saving.value || loading.value) {
      onNotice('عملیات قبلی هنوز تمام نشده است.', false);
      return null;
    }
    saving.value = true;
    error.value = null;
    try {
      final client = fx;
      if (client == null) throw const AuthError(401, 'SESSION_INVALID');
      final command =
          pending.value ??
          client.pending ??
          PersonnelCommand(resource, {
            ...body,
            if (item != null) 'expectedRevision': item.revision,
          }, id: item?.id);
      final result = await client.send(command);
      if (closed) return null;
      pending.value = client.pending;
      if (result.resource == this.resource &&
          client.has(this.resource.readPermission)) {
        final index = rows.indexWhere((row) => row.id == result.id);
        if (index < 0) {
          rows.add(result);
        } else {
          rows[index] = result;
        }
      }
      onNotice('اطلاعات با موفقیت ثبت شد.', true);
      return result;
    } catch (failure) {
      if (!closed) {
        pending.value = fx?.pending;
        fail(failure);
      }
      return null;
    } finally {
      if (!closed) saving.value = false;
    }
  }

  @override
  void onClose() {
    closed = true;
    super.onClose();
  }
}
