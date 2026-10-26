import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/personnel.dart';
import '../../source/remote/models/business_branch.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'branches.dart';
import 'warehouse_management.dart';

class PersonnelFX {
  static final _clients = Expando<Map<String, PersonnelFX>>();
  static PersonnelFX forContext(BusinessContext context) {
    final clients = _clients[context] ??= {};
    return clients[context.selectedBranch?.branchId ?? ''] ??= PersonnelFX(
      context,
    );
  }

  final BusinessContext context;
  final FlutterSecureStorage storage;
  late final access = WarehouseManagementFX(context: context);
  PersonnelCommand? pending;
  Future<PersonnelEntry>? _sending;
  String? _sendingKey;
  PersonnelFX(this.context, {this.storage = const FlutterSecureStorage()});
  int get businessId => context.session.business.businessId;
  String get base => '/v1/businesses/$businessId';
  String get _key =>
      'personnel.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId';
  void check() {
    access.check();
    if (!identical(context, BusinessContext.forApp(context.auth.appId))) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<void> authorize() async {
    check();
    await access.authorize();
    check();
  }

  Future<List<BusinessBranch>> branches() async {
    check();
    // BusinessContext.branches resets the app's selected branch; access editing must not.
    final rows = await BranchesFX.forContext(context).all();
    check();
    return rows;
  }

  bool has(String code) => access.has(code);
  void require(String code) {
    check();
    if (!has(code)) throw const AuthError(403, 'FORBIDDEN');
  }

  Future<Object?> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? data,
    String? key,
  }) async {
    check();
    final result = await context.request(
      method,
      path,
      query: query,
      data: data,
      idempotencyKey: key,
    );
    check();
    return result;
  }

  PersonnelEntry _parse(Object? value, PersonnelResource resource) {
    final row = PersonnelEntry(value, resource);
    if (row.businessId != businessId) {
      throw const FormatException('Unexpected personnel business');
    }
    return row;
  }

  Future<List<PersonnelEntry>> list(
    PersonnelResource resource, {
    String? membershipId,
  }) async {
    require(resource.readPermission);
    final result = <PersonnelEntry>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await request(
          'GET',
          '$base/${resource.path}',
          query: {
            'limit': '100',
            'after': ?after,
            'membershipId': ?membershipId,
          },
        ),
      );
      final rows = json.items('items', (value) => _parse(value, resource));
      if (rows.any(
        (row) =>
            !ids.add(row.id) ||
            membershipId != null && row.data['membershipId'] != membershipId,
      )) {
        throw const FormatException('Unexpected personnel page');
      }
      result.addAll(rows);
      after = json.optionalText('nextCursor');
      if (after != null && !cursors.add(after)) {
        throw const FormatException('Repeated personnel cursor');
      }
    } while (after != null);
    return result;
  }

  Future<PersonnelEntry> get(PersonnelResource resource, String id) async {
    require(resource.readPermission);
    final row = _parse(
      RemoteJson(
        await request(
          'GET',
          '$base/${resource.path}/${Uri.encodeComponent(id)}',
        ),
      ).value['item'],
      resource,
    );
    if (row.id != id) {
      throw const FormatException('Unexpected personnel record');
    }
    return row;
  }

  Future<List<Map<String, dynamic>>> catalog() async {
    final json = RemoteJson(await request('GET', '/v1/permissions'));
    final ids = <String>{};
    return json.items('permissions', (value) {
      final row = RemoteJson(value);
      if (!ids.add(row.text('code'))) {
        throw const FormatException('Repeated permission');
      }
      row.text('title');
      row.text('domain');
      row.text('resource');
      return row.value;
    });
  }

  Future<PersonnelCommand?> restore() async {
    check();
    if (_sending != null) return pending;
    final value = await storage.read(key: _key);
    check();
    return pending = value == null
        ? null
        : PersonnelCommand.fromJson(jsonDecode(value));
  }

  Future<PersonnelEntry> send(PersonnelCommand command) {
    if (_sending != null) {
      return _sendingKey == command.key
          ? _sending!
          : Future.error(const AuthError(409, 'PERSONNEL_PENDING'));
    }
    _sendingKey = command.key;
    _sending = _send(command);
    return _sending!.whenComplete(() {
      _sending = null;
      _sendingKey = null;
    });
  }

  Future<PersonnelEntry> _send(PersonnelCommand command) async {
    if (pending != null && pending!.key != command.key) {
      throw const AuthError(409, 'PERSONNEL_PENDING');
    }
    await authorize();
    require(command.resource.writePermission(command.id != null));
    pending = command;
    // A lost reply may follow a committed membership or access change; preserve body/key.
    await storage.write(key: _key, value: jsonEncode(command.toJson()));
    try {
      final json = RemoteJson(
        await request(
          command.id == null ? 'POST' : 'PATCH',
          '$base/${command.resource.path}${command.id == null ? '' : '/${command.id}'}',
          data: command.body,
          key: command.key,
        ),
      );
      final row = _parse(json.value['item'], command.resource);
      if (json.number('businessId') != businessId ||
          command.id != null &&
              (row.id != command.id ||
                  row.revision <= command.body['expectedRevision'])) {
        throw const FormatException('Unexpected personnel result');
      }
      // Phone belongs to Identity and is deliberately absent from the personnel response.
      for (final field in command.body.entries) {
        if (['phone', 'expectedRevision'].contains(field.key)) continue;
        final actual = row.data[field.key];
        final expected = field.value;
        if (expected is List && actual is List) {
          final wanted = expected.cast<String>().toSet().toList()..sort();
          final received = actual.cast<String>().toSet().toList()..sort();
          if (jsonEncode(wanted) != jsonEncode(received)) {
            throw const FormatException('Unexpected personnel fields');
          }
        } else if (actual !=
            (expected is String ? expected.trim() : expected)) {
          throw const FormatException('Unexpected personnel fields');
        }
      }
      if (command.resource == PersonnelResource.person) {
        final membership = RemoteJson(json.value['membership']);
        if (membership.text('membershipId') != row.data['membershipId'] ||
            membership.number('businessId') != businessId ||
            membership.text('personnelId') != row.id ||
            membership.text('membershipType') != 'PERSONNEL' ||
            membership.text('status') !=
                {
                  'ACTIVE': 'ACTIVE',
                  'SUSPENDED': 'SUSPENDED',
                  'ENDED': 'REMOVED',
                }[row.status]) {
          throw const FormatException('Unexpected personnel membership result');
        }
      }
      await storage.delete(key: _key);
      pending = null;
      return row;
    } on AuthError catch (failure) {
      if (failure.statusCode < 500 &&
          !failure.retryable &&
          !failure.requiresLogin &&
          failure.statusCode != 403 &&
          ![
            'IDEMPOTENCY_CONFLICT',
            'SELECTION_CHANGED',
          ].contains(failure.code)) {
        await storage.delete(key: _key);
        pending = null;
      }
      rethrow;
    }
  }

  static String message(Object error) {
    if (error is AuthError) {
      switch (error.code) {
        case 'FORBIDDEN':
          return 'مجوز انجام این عملیات را ندارید.';
        case 'REVISION_CONFLICT':
          return 'اطلاعات تغییر کرده؛ فرم را ببندید و نسخه جدید را دریافت کنید.';
        case 'DUPLICATE_RECORD':
          return 'این فرد یا عنوان قبلاً در کسب‌وکار ثبت شده است.';
        case 'VALIDATION_FAILED':
          return 'مشخصات، وضعیت همکاری و دسترسی‌های انتخاب‌شده را بررسی کنید.';
        case 'PERSONNEL_PENDING':
        case 'IDEMPOTENCY_CONFLICT':
          return 'درخواست قبلی تعیین تکلیف نشده؛ همان درخواست را ادامه دهید.';
        case 'SELECTION_CHANGED':
          return 'نشست یا شعبه تغییر کرده؛ صفحه را دوباره باز کنید.';
        case 'RECORD_NOT_FOUND':
          return 'رکورد در این کسب‌وکار پیدا نشد.';
      }
    }
    if (error is FormatException) {
      return 'پاسخ سرور معتبر نیست؛ دوباره تلاش کنید.';
    }
    return API.loginError(error);
  }
}
