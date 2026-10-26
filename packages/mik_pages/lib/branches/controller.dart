import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/business_branch.dart';
import 'package:mik_data/utils/fx/branches.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class BranchManagementController extends GetxController {
  final String appId;
  final void Function(String message, bool success)? onNotice;
  BranchManagementController({required this.appId, this.onNotice});
  BranchesFX? fx;
  final rows = <BusinessBranch>[].obs;
  final query = ''.obs, loading = false.obs, saving = false.obs;
  final error = RxnString();
  final pending = Rxn<BranchCommand>();
  bool _closed = false;
  bool get locked => loading.value || saving.value || pending.value != null;
  bool get canCreate => !locked && fx?.canCreate == true;
  List<BusinessBranch> get visible {
    String normalize(String v) =>
        v.trim().toEnglishDigit().toLowerCase().replaceAll(' ', '');
    final q = normalize(query.value);
    return rows
        .where(
          (r) =>
              q.isEmpty ||
              [
                r.name,
                r.code ?? '',
                r.branchId,
              ].any((s) => normalize(s).contains(q)),
        )
        .toList();
  }

  void fail(Object failure) {
    if (_closed) return;
    error.value = BranchesFX.message(failure);
    if (failure is AuthError &&
        (failure.statusCode == 403 ||
            failure.requiresLogin ||
            failure.code == 'SELECTION_CHANGED')) {
      rows.clear();
      pending.value = null;
    }
    onNotice?.call(error.value!, false);
  }

  Future<void> load() async {
    if (_closed || loading.value || saving.value) return;
    loading.value = true;
    error.value = null;
    rows.clear();
    try {
      final context = BusinessContext.forApp(appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      fx ??= BranchesFX.forContext(context);
      await fx!.authorize();
      pending.value = await fx!.restore();
      final items = await fx!.all();
      if (!_closed) rows.assignAll(items);
    } catch (failure) {
      fail(failure);
    } finally {
      if (!_closed) loading.value = false;
    }
  }

  Future<BusinessBranch?> details(String id) async {
    if (locked) {
      onNotice?.call('عملیات قبلی هنوز تمام نشده است.', false);
      return null;
    }
    loading.value = true;
    error.value = null;
    try {
      await fx!.authorize(id: id);
      final row = await fx!.get(id);
      return _closed ? null : row;
    } catch (failure) {
      fail(failure);
      return null;
    } finally {
      if (!_closed) loading.value = false;
    }
  }

  Future<BusinessBranch?> save(
    String name,
    String fullAddress, {
    BusinessBranch? row,
  }) async {
    if (_closed || saving.value || loading.value) return null;
    error.value = null;
    final saved = pending.value ?? fx?.pending;
    final title = name.trim(), address = fullAddress.trim();
    if (saved == null &&
        (title.isEmpty || title.length > 200 || address.length > 1000)) {
      error.value =
          'نام شعبه الزامی و حداکثر ۲۰۰ حرف است؛ آدرس حداکثر ۱۰۰۰ حرف است.';
      onNotice?.call(error.value!, false);
      return null;
    }
    saving.value = true;
    try {
      final client = fx;
      if (client == null) throw const AuthError(401, 'SESSION_INVALID');
      // Updating the visible address must preserve the other structured address fields.
      final location = {...?row?.address}..remove('fullAddress');
      if (address.isNotEmpty) location['fullAddress'] = address;
      final result = await client.send(
        saved ??
            BranchCommand({
              'name': title,
              if (row != null || location.isNotEmpty)
                'address': location.isEmpty ? null : location,
              if (row != null) 'expectedRevision': row.revision,
            }, id: row?.branchId),
      );
      if (_closed) return null;
      pending.value = client.pending;
      final index = rows.indexWhere((r) => r.branchId == result.branchId);
      if (index < 0) {
        rows.add(result);
      } else {
        rows[index] = result;
      }
      onNotice?.call(
        row == null && saved?.id == null
            ? 'شعبه جدید با موفقیت ایجاد شد.'
            : 'ویرایش شعبه با موفقیت انجام شد.',
        true,
      );
      return result;
    } catch (failure) {
      pending.value = fx?.pending;
      fail(failure);
      return null;
    } finally {
      if (!_closed) saving.value = false;
    }
  }

  @override
  void onClose() {
    _closed = true;
    super.onClose();
  }
}
