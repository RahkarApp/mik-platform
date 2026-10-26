import 'package:get/get.dart';
import 'package:mik_consts/permission_names.dart';
export 'package:mik_consts/permission_names.dart';

/// Named grants for the active account, shared by both hosts and shared pages.
abstract final class PermissionAccess {
  static final _names = <String>{}.obs;
  static final _owner = false.obs;
  static int? _personnelId;

  static Set<String> get permissionList => Set.unmodifiable(_names);
  static bool get isOwner => _owner.value;

  static void load(String? stored, {required int? personnelId}) {
    _owner.value = false;
    _personnelId = personnelId;
    _names.assignAll(PermissionCatalog.decode(stored));
  }

  /// Only the MiK owner host invokes this, never the MiKYar staff login.
  static void useOwner() {
    _personnelId = 0;
    _names.assignAll(PermissionCatalog.byName.keys);
    _owner.value = true;
  }

  static void clear() {
    _owner.value = false;
    _personnelId = null;
    _names.clear();
  }

  static bool hasPermission(String name) {
    final owner = _owner.value;
    final granted = _names.contains(name);
    return PermissionCatalog.byName.containsKey(name) && (owner || granted);
  }

  static bool hasAny(Iterable<String> names) => names.any(hasPermission);

  static bool canAccessRecord({
    required String own,
    required String all,
    required int? inserter,
  }) =>
      hasPermission(all) ||
      (inserter != null &&
          _personnelId != null &&
          inserter == _personnelId &&
          hasPermission(own));
}
