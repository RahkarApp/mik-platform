import 'dart:async';

import 'realtime.dart';
import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/business_session.dart';
import '../../source/remote/models/scope_authorization.dart';
import '../../source/remote/models/business_branch.dart';
import '../../source/remote/models/remote_json.dart';
import 'auth.dart';

class BusinessContext {
  static final _changes = StreamController<String>.broadcast();
  static Stream<String> get changes => _changes.stream;
  void _notify() => _changes.add(auth.appId);

  ScopeAuthorization? _businessAuthorization;
  ScopeAuthorization? _branchAuthorization;
  BusinessBranch? _selectedBranch;
  List<BusinessBranch> _branches = const [];
  ScopeAuthorization? get businessAuthorization => _businessAuthorization;
  ScopeAuthorization? get branchAuthorization => _branchAuthorization;
  BusinessBranch? get selectedBranch => _selectedBranch;

  /// Apply an already validated server reply without clearing the selected scope.
  void updateSelectedBranch(BusinessBranch branch) {
    check();
    if (branch.branchId != _selectedBranch?.branchId ||
        branch.businessId != session.business.businessId ||
        branch.revision < _selectedBranch!.revision ||
        branch.status != 'ACTIVE') {
      throw const FormatException('Unexpected selected branch update');
    }
    _selectedBranch = branch;
    _branches = [
      for (final item in _branches)
        if (item.branchId == branch.branchId) branch else item,
    ];
  }

  // The server grants business and branch scopes independently; do not merge them.
  bool hasPermission(String code, {bool inBranch = false}) =>
      valid &&
      (inBranch ? _branchAuthorization : _businessAuthorization)
              ?.permissionCodes
              .contains(code) ==
          true;

  void clearAccess() {
    RealtimeFX.pauseFor(this);
    _selection++;
    _businessAuthorization = null;
    _branchAuthorization = null;
    _selectedBranch = null;
    _branches = const [];
    _notify();
  }

  Future<ScopeAuthorization> _authorize(String type, String id) async {
    check();
    final result = ScopeAuthorization.fromJson(
      await request(
        'GET',
        '/v1/businesses/${session.business.businessId}/authorization',
        query: {'scopeType': type, 'scopeId': id},
      ),
    );
    check();
    if (!result.allowed ||
        result.businessId != session.business.businessId ||
        result.membershipId != session.business.membershipId ||
        result.scopeType != type ||
        result.scopeId != id) {
      throw const FormatException('Unexpected scope authorization');
    }
    return result;
  }

  Future<void> authorize() async {
    clearAccess();
    final selection = _selection;
    final authorization = await _authorize(
      'BUSINESS',
      '${session.business.businessId}',
    );
    if (selection != _selection) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
    _businessAuthorization = authorization;
  }

  Future<List<BusinessBranch>> branches() async {
    check();
    RealtimeFX.pauseFor(this);
    final selection = ++_selection;
    _selectedBranch = null;
    _branchAuthorization = null;
    _branches = const [];
    _notify();
    final items = <BusinessBranch>[];
    final cursors = <String>{};
    String? after;
    do {
      final page = RemoteJson(
        await request(
          'GET',
          '/v1/businesses/${session.business.businessId}/branches',
          query: {'limit': '100', 'after': ?after},
        ),
      );
      check();
      if (selection != _selection) {
        throw const AuthError(409, 'SELECTION_CHANGED');
      }
      final rows = page.items('items', BusinessBranch.fromJson);
      if (rows.any((row) => row.businessId != session.business.businessId)) {
        throw const FormatException('Unexpected branch business');
      }
      items.addAll(rows.where((row) => row.status == 'ACTIVE'));
      after = page.optionalText('nextCursor');
      if (after != null && !cursors.add(after)) {
        throw const FormatException('Repeated branch cursor');
      }
    } while (after != null);
    return _branches = List.unmodifiable(items);
  }

  // Ignore late results after the user changes or clears the selected scope.
  int _selection = 0;
  Future<void> selectBranch(BusinessBranch branch) async {
    check();
    RealtimeFX.pauseFor(this);
    final selection = ++_selection;
    _selectedBranch = null;
    _branchAuthorization = null;
    _notify();
    if (!_branches.any((item) => identical(item, branch))) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final authorization = await _authorize('BRANCH', branch.branchId);
    if (selection != _selection) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
    _branchAuthorization = authorization;
    _selectedBranch = branch;
    RealtimeFX.resumeFor(this);
    _notify();
  }

  /// Revalidate grants after a stream reset without resetting the user's branch.
  Future<void> refreshAccess() async {
    check();
    final branch = _selectedBranch;
    final selection = _selection;
    _businessAuthorization = _branchAuthorization = null;
    try {
      final business = await _authorize(
        'BUSINESS',
        '${session.business.businessId}',
      );
      final access = branch == null
          ? null
          : await _authorize('BRANCH', branch.branchId);
      check();
      if (selection != _selection ||
          branch?.branchId != _selectedBranch?.branchId) {
        throw const AuthError(409, 'SELECTION_CHANGED');
      }
      _businessAuthorization = business;
      _branchAuthorization = access;
    } on AuthError catch (failure) {
      if (failure.statusCode == 403 || failure.requiresLogin) clearAccess();
      rethrow;
    }
  }

  Future<Object?> request(
    String method,
    String path, {
    Object? data,
    Map<String, String>? query,
    String? idempotencyKey,
  }) async {
    check();
    final branchId = _selectedBranch?.branchId;
    try {
      final result = await auth.request(
        method,
        path,
        data: data,
        query: query,
        branchId: branchId,
        idempotencyKey: idempotencyKey,
      );
      check();
      if (branchId != _selectedBranch?.branchId) {
        throw const AuthError(409, 'SELECTION_CHANGED');
      }
      return result;
    } on AuthError catch (error) {
      if (error.statusCode == 403 || error.requiresLogin) clearAccess();
      rethrow;
    }
  }

  static final _active = <String, BusinessContext>{};
  final AuthFX auth;
  final BusinessSession session;
  final String _sessionId, origin;
  BusinessContext._(this.auth, this.session)
    : _sessionId = auth.current!.sessionId,
      origin = API.origin.origin;
  static BusinessContext activate(AuthFX auth, BusinessSession session) {
    if (auth.current?.identityId != session.identityId) {
      throw const AuthError(401, 'SESSION_INVALID');
    }
    clear(auth.appId);
    final context = _active[auth.appId] = BusinessContext._(auth, session);
    context._notify();
    return context;
  }

  static BusinessContext? forApp(String appId) {
    final context = _active[appId];
    return context != null && context.valid ? context : null;
  }

  bool get valid =>
      identical(_active[auth.appId], this) &&
      auth.current?.sessionId == _sessionId &&
      auth.current?.identityId == session.identityId &&
      auth.current!.refreshExpiresAt.isAfter(DateTime.now().toUtc()) &&
      origin == API.origin.origin;
  void check() {
    if (!valid) {
      throw const AuthError(401, 'SESSION_INVALID');
    }
  }

  static void clear(String appId) => _active.remove(appId)?.clearAccess();
}
