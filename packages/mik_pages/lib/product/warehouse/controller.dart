import 'package:mik_data/utils/fx/realtime.dart';
import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/warehouse_management.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class WarehouseManagementController extends GetxController {
  void Function(String message, bool success)? onNotice;
  WarehouseManagementFX? fx;
  final items = <BusinessWarehouse>[].obs, links = <BranchAccess>[].obs;
  final branch = Rxn<BusinessBranch>();
  final loading = false.obs,
      saving = false.obs,
      conflict = false.obs,
      linksAvailable = false.obs;
  final error = RxnString(), commandError = RxnString();
  final pending = Rxn<WarehouseCommand>();
  final query = ''.obs;
  RealtimeWatch? _realtime;
  int _generation = 0;
  bool _attached = false;
  bool get locked =>
      !_attached ||
      loading.value ||
      saving.value ||
      conflict.value ||
      error.value != null ||
      pending.value != null;
  bool get canCreate => !locked && fx?.has('business.warehouse.create') == true;
  bool get canLink =>
      !locked &&
      branch.value?.status == 'ACTIVE' &&
      linksAvailable.value &&
      fx?.has('business.branch-access.update') == true;
  bool canEdit(BusinessWarehouse row) =>
      !locked && fx?.canRename(row.warehouseId) == true;
  BranchAccess? link(BusinessWarehouse row) =>
      links.where((l) => l.warehouseId == row.warehouseId).firstOrNull;
  bool canDefault(BusinessWarehouse row) {
    final access = link(row);
    return !locked &&
        fx?.canDefault == true &&
        branch.value?.status == 'ACTIVE' &&
        row.status == 'ACTIVE' &&
        access?.status == 'ACTIVE' &&
        access!.canReadStock &&
        access.canIssueStock &&
        branch.value?.defaultWarehouseId != row.warehouseId;
  }

  List<BusinessWarehouse> get visible {
    String normalize(String text) =>
        text.toEnglishDigit().replaceAll(' ', '').toLowerCase();
    final q = normalize(query.value);
    return items
        .where(
          (row) =>
              q.isEmpty ||
              normalize(row.name).contains(q) ||
              normalize(row.warehouseId).contains(q),
        )
        .toList();
  }

  void search(Object? value) {
    if (_attached) query.value = value?.toString() ?? '';
  }

  Future<void> attach(String appId, {String? branchId}) async {
    detach();
    _attached = true;
    final context = BusinessContext.forApp(appId);
    fx = context == null
        ? null
        : WarehouseManagementFX.forContext(context, branchId: branchId);
    if (context != null) {
      _realtime = RealtimeWatch(
        RealtimeFX.forContext(context),
        {'business.warehouse', 'business.branch', 'business.branch-access'},
        () => load(background: true),
        busy: () => loading.value || saving.value,
        invalidate: () {
          if (!saving.value) _generation++;
          loading.value = false;
          items.clear();
          links.clear();
          branch.value = null;
          linksAvailable.value = false;
        },
      );
    }
    await load();
  }

  void detach() {
    _realtime?.dispose();
    _realtime = null;
    _attached = false;
    _generation++;
    items.clear();
    links.clear();
    branch.value = null;
    pending.value = null;
    error.value = null;
    commandError.value = null;
    loading.value = false;
    conflict.value = false;
    linksAvailable.value = false;
    query.value = '';
    saving.value = false;
  }

  Future<void> load({bool background = false}) async {
    if (!_attached || saving.value) return;
    final generation = ++_generation;
    if (!background) loading.value = true;
    error.value = null;
    commandError.value = null;
    if (!background) items.clear();
    if (!background) links.clear();
    if (!background) branch.value = null;
    if (!background) linksAvailable.value = false;
    try {
      final client = fx;
      if (client == null) throw const AuthError(401, 'SESSION_INVALID');
      await client.authorize();
      pending.value = await client.restore();
      final rows = await client.warehouses();
      BusinessBranch? selected;
      final access = <BranchAccess>[];
      if (client.branchId != null) {
        if (!client.owner) {
          await client.authorize(scope: 'BRANCH', id: client.branchId);
        }
        if (client.owner ||
            client.has(
              'business.branch.read',
              scope: 'BRANCH',
              id: client.branchId,
            )) {
          selected = await client.branch();
        }
        if (client.has('business.branch-access.read')) {
          access.addAll(await client.links());
        }
      }
      client.check();
      if (generation != _generation || !_attached) return;
      items.assignAll(rows);
      links.assignAll(access);
      branch.value = selected;
      linksAvailable.value =
          client.branchId != null && client.has('business.branch-access.read');
      conflict.value = false;
    } catch (failure) {
      if (generation == _generation && _attached) {
        error.value = WarehouseManagementFX.message(failure);
        onNotice?.call(error.value!, false);
        if (failure is AuthError &&
            (failure.statusCode == 403 ||
                failure.requiresLogin ||
                failure.code == 'SELECTION_CHANGED')) {
          pending.value = null;
        }
      }
    } finally {
      if (generation == _generation && _attached) loading.value = false;
    }
  }

  Future<void> prepare(BusinessWarehouse row) async {
    if (locked) return;
    try {
      fx!.check();
      if (!fx!.owner) {
        await fx!.authorize(scope: 'WAREHOUSE', id: row.warehouseId);
      }
    } catch (failure) {
      commandError.value = WarehouseManagementFX.message(failure);
      onNotice?.call(commandError.value!, false);
      if (failure is AuthError &&
          (failure.statusCode == 403 ||
              failure.requiresLogin ||
              failure.code == 'SELECTION_CHANGED')) {
        items.clear();
        links.clear();
        branch.value = null;
        error.value = commandError.value;
      }
    }
  }

  bool _reject(String message) {
    commandError.value = message;
    onNotice?.call(message, false);
    return false;
  }

  Future<bool> rename(
    String name, {
    BusinessWarehouse? item,
    String status = 'ACTIVE',
  }) async {
    if (locked) {
      return _reject(
        'ابتدا عملیات قبلی را تعیین تکلیف کنید یا اطلاعات صفحه را دوباره دریافت کنید.',
      );
    }
    if (!['ACTIVE', 'SUSPENDED', 'ARCHIVED'].contains(status)) {
      commandError.value = 'وضعیت انبار معتبر نیست.';
      onNotice?.call(commandError.value!, false);
      return false;
    }
    final text = name.trim();
    if (text.isEmpty ||
        text.length > 200 ||
        RegExp(r'[\u0000-\u0008]').hasMatch(text)) {
      commandError.value = 'نام انبار باید بین ۱ تا ۲۰۰ حرف باشد.';
      onNotice?.call(commandError.value!, false);
      return false;
    }
    return _send(
      WarehouseCommand(
        item == null ? WarehouseAction.create : WarehouseAction.rename,
        {
          'name': text,
          if (item != null) ...{
            'expectedRevision': item.revision,
            'status': status,
          },
        },
        id: item?.warehouseId,
      ),
    );
  }

  Future<bool> connect(
    BusinessWarehouse row, {
    required bool read,
    required bool receive,
    required bool issue,
    String status = 'ACTIVE',
  }) async {
    if (!canLink || row.status != 'ACTIVE') {
      return _reject(
        'برای تنظیم ارتباط، شعبه و انبار باید فعال و مجوز تغییر ارتباط موجود باشد.',
      );
    }
    if (!['ACTIVE', 'SUSPENDED', 'ARCHIVED'].contains(status)) {
      commandError.value = 'وضعیت ارتباط شعبه و انبار معتبر نیست.';
      onNotice?.call(commandError.value!, false);
      return false;
    }
    final current = link(row);
    return _send(
      WarehouseCommand(WarehouseAction.link, {
        if (current == null) ...{
          'branchId': branch.value!.branchId,
          'warehouseId': row.warehouseId,
        } else
          'expectedRevision': current.revision,
        'canReadStock': read,
        'canReceiveStock': receive,
        'canIssueStock': issue,
        'status': status,
      }, id: current?.branchAccessId),
    );
  }

  Future<bool> setDefault(BusinessWarehouse row) async {
    if (!canDefault(row)) {
      return _reject(
        'انبار پیش‌فرض باید فعال، دارای ارتباط فعال برای مشاهده و خروج کالا و مجوز تغییر شعبه باشد.',
      );
    }
    return _send(
      WarehouseCommand(WarehouseAction.defaultWarehouse, {
        'defaultWarehouseId': row.warehouseId,
        'expectedRevision': branch.value!.revision,
      }, id: branch.value!.branchId),
    );
  }

  Future<bool> resume() async {
    if (saving.value || pending.value == null) {
      return _reject('درخواست قبلی قابل پیگیری نیست یا هنوز در حال انجام است.');
    }
    return _send(pending.value!);
  }

  Future<bool> _send(WarehouseCommand command) async {
    final client = fx;
    if (client == null || saving.value) return false;
    final generation = _generation;
    saving.value = true;
    commandError.value = null;
    bool success = false;
    try {
      final send = client.send(command);
      final result = await send;
      client.check();
      if (generation != _generation || !_attached) return false;
      pending.value = client.pending;
      if (result is BusinessWarehouse) {
        final index = items.indexWhere(
          (r) => r.warehouseId == result.warehouseId,
        );
        if (index < 0) {
          items.add(result);
        } else {
          items[index] = result;
        }
      } else if (result is BranchAccess) {
        final index = links.indexWhere(
          (r) => r.branchAccessId == result.branchAccessId,
        );
        if (index < 0) {
          links.add(result);
        } else {
          links[index] = result;
        }
      } else if (result is BusinessBranch) {
        branch.value = result;
      }
      success = true;
      onNotice?.call('عملیات انبار با موفقیت انجام شد.', true);
    } catch (failure) {
      if (generation != _generation || !_attached) return false;
      pending.value = client.pending;
      conflict.value =
          failure is AuthError && failure.code == 'REVISION_CONFLICT';
      commandError.value = WarehouseManagementFX.message(failure);
      onNotice?.call(commandError.value!, false);
      if (failure is AuthError &&
          (failure.statusCode == 403 ||
              failure.requiresLogin ||
              failure.code == 'SELECTION_CHANGED')) {
        items.clear();
        links.clear();
        branch.value = null;
        pending.value = null;
        error.value = commandError.value;
      }
    } finally {
      if (generation == _generation && _attached) saving.value = false;
    }
    return success;
  }

  @override
  void onClose() {
    detach();
    super.onClose();
  }
}
