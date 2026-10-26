import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/api.dart';
import '../../source/remote/models/customer.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/scope_authorization.dart';
import 'business_context.dart';

class CustomerPage {
  final List<RemoteCustomer> items;
  final String? next;
  const CustomerPage(this.items, this.next);
}

class CustomersFX {
  final BusinessContext context;
  final FlutterSecureStorage storage;
  final String? branchId;
  final accessVersion = 0.obs;
  ScopeAuthorization? _authorization;
  CustomerCommand? pending;
  Future<RemoteCustomer>? _sending;
  String? _sendingKey;
  CustomersFX({
    required this.context,
    this.storage = const FlutterSecureStorage(),
  }) : branchId = context.selectedBranch?.branchId;
  int get businessId => context.session.business.businessId;
  String get _base => '/v1/businesses/$businessId/customers';
  String get _storeKey =>
      'customers.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId';
  void check() {
    context.check();
    if (!identical(BusinessContext.forApp(context.auth.appId), context) ||
        branchId == null ||
        context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  bool has(String permission) {
    accessVersion.value;
    return context.valid &&
        context.selectedBranch?.branchId == branchId &&
        branchId != null &&
        _authorization?.permissionCodes.contains(permission) == true;
  }

  bool get canRead =>
      has('ucrm.customer.read') || has('ucrm.customer.read.all');
  bool canEdit(RemoteCustomer item) =>
      !item.isDefault &&
      item.businessId == businessId &&
      has('ucrm.customer.update') &&
      (item.creatorIdentityId == context.session.identityId ||
          item.assignedMembershipIds.contains(
            context.session.business.membershipId,
          ) ||
          has('ucrm.customer.update.all'));
  void require(String permission) {
    check();
    if (!has(permission)) throw const AuthError(403, 'FORBIDDEN');
  }

  Future<void> authorize() async {
    check();
    _authorization = null;
    accessVersion.value++;
    final result = ScopeAuthorization.fromJson(
      await context.auth.request(
        'GET',
        '/v1/businesses/$businessId/authorization',
        query: {'scopeType': 'BUSINESS', 'scopeId': '$businessId'},
      ),
    );
    check();
    if (!result.allowed ||
        result.businessId != businessId ||
        result.membershipId != context.session.business.membershipId ||
        result.scopeType != 'BUSINESS' ||
        result.scopeId != '$businessId') {
      throw const FormatException('Unexpected customer authorization');
    }
    _authorization = result;
    accessVersion.value++;
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? data,
    String? key,
  }) async {
    check();
    try {
      final result = await context.request(
        method,
        path,
        query: query,
        data: data,
        idempotencyKey: key,
      );
      check();
      return result;
    } on AuthError catch (error) {
      if (error.statusCode == 403 || error.requiresLogin) {
        _authorization = null;
        accessVersion.value++;
      }
      rethrow;
    }
  }

  RemoteCustomer _customer(Object? value) {
    final customer = RemoteCustomer.fromJson(value);
    if (customer.businessId != businessId) {
      throw const FormatException('Unexpected customer business');
    }
    return customer;
  }

  Future<CustomerPage> page({String? after, String query = ''}) async {
    check();
    if (!canRead) throw const AuthError(403, 'FORBIDDEN');
    final result = RemoteJson(
      await _request(
        'GET',
        _base,
        query: {
          'limit': '50',
          'status': 'ACTIVE',
          'after': ?after,
          if (query.isNotEmpty) 'q': query,
        },
      ),
    );
    final rows = result.items('items', _customer);
    if (result.number('businessId') != businessId ||
        rows.any((c) => c.status != 'ACTIVE') ||
        rows.map((c) => c.id).toSet().length != rows.length) {
      throw const FormatException('Unexpected customer page');
    }
    return CustomerPage(rows, result.optionalText('nextCursor'));
  }

  Future<RemoteCustomer> get(String id) async {
    check();
    if (!canRead) throw const AuthError(403, 'FORBIDDEN');
    final result = RemoteJson(
      await _request('GET', '$_base/${Uri.encodeComponent(id)}'),
    );
    final item = _customer(result.value['customer']);
    if (result.number('businessId') != businessId || item.id != id) {
      throw const FormatException('Unexpected customer result');
    }
    return item;
  }

  Future<CustomerCommand?> restore() async {
    check();
    final value = await storage.read(key: _storeKey);
    check();
    return pending = value == null
        ? null
        : CustomerCommand.fromJson(jsonDecode(value));
  }

  Future<RemoteCustomer> send(CustomerCommand command) {
    if (_sending != null) {
      if (_sendingKey != command.key) {
        return Future.error(const AuthError(409, 'CUSTOMER_PENDING'));
      }
      return _sending!;
    }
    _sendingKey = command.key;
    final sending = _send(command);
    _sending = sending;
    return sending.whenComplete(() {
      _sending = null;
      _sendingKey = null;
    });
  }

  Future<RemoteCustomer> _send(CustomerCommand command) async {
    require(
      command.customerId == null
          ? 'ucrm.customer.create'
          : 'ucrm.customer.update',
    );
    if (pending != null && pending!.key != command.key) {
      throw const AuthError(409, 'CUSTOMER_PENDING');
    }
    await storage.write(key: _storeKey, value: jsonEncode(command.toJson()));
    pending = command;
    try {
      final result = RemoteJson(
        await _request(
          command.customerId == null ? 'POST' : 'PATCH',
          command.customerId == null
              ? _base
              : '$_base/${Uri.encodeComponent(command.customerId!)}',
          data: command.body,
          key: command.key,
        ),
      );
      final item = _customer(result.value['customer']);
      if (result.number('businessId') != businessId ||
          command.customerId != null && item.id != command.customerId ||
          item.isDefault) {
        throw const FormatException('Unexpected saved customer');
      }
      await storage.delete(key: _storeKey);
      pending = null;
      return item;
    } on AuthError catch (error) {
      // An uncertain response must retain the exact body/key, including after reopening the form.
      if (error.statusCode < 500 &&
          !error.retryable &&
          !error.requiresLogin &&
          error.statusCode != 403 &&
          error.code != 'IDEMPOTENCY_CONFLICT') {
        await storage.delete(key: _storeKey);
        pending = null;
      }
      rethrow;
    }
  }

  static String message(Object error) {
    if (error is AuthError) {
      switch (error.code) {
        case 'FORBIDDEN':
          return 'اجازه دسترسی به این مشتری یا انجام این عملیات را ندارید.';
        case 'CUSTOMER_PENDING':
        case 'IDEMPOTENCY_CONFLICT':
          return 'درخواست قبلی تعیین تکلیف نشده؛ همان درخواست را ادامه دهید.';
        case 'DUPLICATE_RECORD':
          return 'این شماره همراه قبلاً ثبت شده است.';
        case 'VALIDATION_FAILED':
          return 'مشخصات مشتری و شماره همراه را بررسی کنید.';
        case 'REVISION_CONFLICT':
          return 'مشخصات مشتری تغییر کرده؛ نسخه جدید را دریافت کنید.';
        case 'SELECTION_CHANGED':
          return 'نشست یا شعبه تغییر کرده؛ صفحه را دوباره باز کنید.';
      }
    }
    if (error is FormatException) {
      return 'پاسخ سرور کامل نیست. دوباره تلاش کنید.';
    }
    return API.loginError(error);
  }
}
