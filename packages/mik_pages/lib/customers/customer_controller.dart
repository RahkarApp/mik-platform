import 'package:mik_data/utils/fx/realtime.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/customer.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/customers.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:uuid/uuid.dart';

class RemoteCustomersController extends GetxController {
  final String appId;
  RemoteCustomersController({required this.appId});
  CustomersFX? fx;
  final items = <RemoteCustomer>[].obs;
  final loading = false.obs, moreLoading = false.obs;
  final error = RxnString(), next = RxnString(), searchHint = RxnString();
  String query = '';
  Timer? _debounce;
  RealtimeWatch? _realtime;
  bool editing = false;
  int _generation = 0;
  bool _closed = false;
  final _cursors = <String>{};
  Future<void> load({bool more = false}) async {
    if (_closed) return;
    if (more && (loading.value || moreLoading.value || next.value == null)) {
      return;
    }
    final generation = more ? _generation : ++_generation;
    if (!more) {
      items.clear();
      next.value = null;
      _cursors.clear();
    }
    if (query.length == 1 || query.length > 80) {
      error.value = null;
      searchHint.value = query.length == 1
          ? 'برای جستجو حداقل دو حرف وارد کنید.'
          : 'جستجو حداکثر ۸۰ حرف است.';
      loading.value = false;
      return;
    }
    searchHint.value = null;
    error.value = null;
    if (more) {
      moreLoading.value = true;
    } else {
      loading.value = true;
    }
    try {
      final context = BusinessContext.forApp(appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      fx ??= CustomersFX(context: context);
      _realtime ??= RealtimeWatch(
        RealtimeFX.forContext(context),
        {'ucrm.customer'},
        refreshFromServer,
        busy: () => loading.value || moreLoading.value || editing,
        invalidate: () {
          _generation++;
          loading.value = false;
          moreLoading.value = false;
          items.clear();
          next.value = null;
        },
      );
      fx!.check();
      if (!more) {
        await fx!.authorize();
        await fx!.restore();
      }
      final page = await fx!.page(
        after: more ? next.value : null,
        query: query,
      );
      if (generation != _generation) return;
      if (page.next != null && _cursors.contains(page.next) ||
          page.items.any((c) => items.any((old) => old.id == c.id))) {
        throw const FormatException('Repeated customer cursor or record');
      }
      items.addAll(page.items);
      if (page.next != null) _cursors.add(page.next!);
      next.value = page.next;
    } catch (failure) {
      if (generation != _generation) return;
      error.value = CustomersFX.message(failure);
      if (failure is AuthError &&
          (failure.statusCode == 403 ||
              failure.requiresLogin ||
              failure.code == 'SELECTION_CHANGED')) {
        items.clear();
        next.value = null;
      }
    } finally {
      if (generation == _generation) {
        loading.value = false;
        moreLoading.value = false;
      }
    }
  }

  Future<void> refreshFromServer() async {
    _debounce?.cancel();
    if (_closed || query.length == 1 || query.length > 80) return;
    final generation = ++_generation, count = items.length;
    final requestedQuery = query;
    final refreshed = <RemoteCustomer>[];
    final ids = <String>{}, cursors = <String>{};
    String? cursor;
    try {
      final client = fx;
      if (client == null) return;
      await client.authorize();
      await client.restore();
      do {
        final page = await client.page(after: cursor, query: requestedQuery);
        if (_closed || generation != _generation) return;
        for (final row in page.items) {
          if (!ids.add(row.id)) {
            throw const FormatException('Repeated customer record');
          }
        }
        if (page.next != null && !cursors.add(page.next!)) {
          throw const FormatException('Repeated customer cursor');
        }
        refreshed.addAll(page.items);
        cursor = page.next;
      } while (refreshed.length < count && cursor != null);
      items.assignAll(refreshed);
      next.value = cursor;
      _cursors
        ..clear()
        ..addAll(cursors);
      error.value = null;
    } catch (failure) {
      if (_closed || generation != _generation) return;
      error.value = CustomersFX.message(failure);
      if (failure is AuthError &&
          (failure.statusCode == 403 ||
              failure.requiresLogin ||
              failure.code == 'SELECTION_CHANGED')) {
        items.clear();
        next.value = null;
      }
    } finally {
      if (!_closed && generation == _generation) {
        loading.value = false;
        moreLoading.value = false;
      }
    }
  }

  void search(String value) {
    _debounce?.cancel();
    query = value.trim().toEnglishDigit();
    _generation++;
    items.clear();
    next.value = null;
    loading.value = false;
    moreLoading.value = false;
    _debounce = Timer(const Duration(milliseconds: 350), load);
  }

  @override
  void onClose() {
    _realtime?.dispose();
    _closed = true;
    _debounce?.cancel();
    _generation++;
    super.onClose();
  }
}

class CustomerEditorController extends GetxController {
  final CustomersFX fx;
  final String? id;
  CustomerEditorController({required this.fx, this.id});
  final fields = {
    for (final name in [
      'name',
      'contactName',
      'phone',
      'telephone',
      'nationalId',
      'economicCode',
      'email',
      'description',
      'title',
      'provinceName',
      'cityName',
      'fullAddress',
      'postalCode',
    ])
      name: TextEditingController(),
  };
  final kind = 'PERSON'.obs,
      loading = false.obs,
      saving = false.obs,
      ready = false.obs;
  final error = RxnString(), conflict = false.obs;
  final item = Rxn<RemoteCustomer>();
  final pending = Rxn<CustomerCommand>();
  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _address;
  Map<String, String> _originalAddress = {};
  bool _closed = false;
  static const addressFields = [
    'title',
    'provinceName',
    'cityName',
    'fullAddress',
    'postalCode',
  ];
  bool get locked =>
      loading.value || saving.value || pending.value != null || conflict.value;
  bool get canSave => item.value == null
      ? fx.has('ucrm.customer.create')
      : fx.canEdit(item.value!);
  String text(String name) => fields[name]!.text.trim();

  Future<void> load() async {
    loading.value = true;
    ready.value = false;
    error.value = null;
    try {
      await fx.authorize();
      await fx.restore();
      final command = fx.pending;
      final target = command?.customerId ?? id;
      final record = target == null ? null : await fx.get(target);
      fx.check();
      if (_closed) return;
      item.value = record;
      final profile = record?.profile ?? <String, dynamic>{};
      for (final field in fields.entries) {
        field.value.text = profile[field.key] as String? ?? '';
      }
      kind.value = record?.kind ?? 'PERSON';
      _addresses = (profile['addresses'] as List? ?? [])
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList();
      _address =
          _addresses.where((a) => a['isDefault'] == true).firstOrNull ??
          _addresses.firstOrNull;
      for (final key in addressFields) {
        fields[key]!.text = _address?[key] as String? ?? '';
      }
      _originalAddress = {for (final key in addressFields) key: text(key)};
      pending.value = command;
      // Display the persisted intent, not a newly constructed body, after an uncertain response.
      if (command != null) {
        for (final field in command.body.entries) {
          if (fields.containsKey(field.key)) {
            fields[field.key]!.text = field.value as String? ?? '';
          }
        }
        kind.value = command.body['kind'] as String? ?? kind.value;
        final requestedAddresses = command.body['addresses'];
        if (requestedAddresses is List && requestedAddresses.isNotEmpty) {
          final address =
              requestedAddresses
                  .cast<Map>()
                  .where((a) => a['addressId'] == _address?['addressId'])
                  .firstOrNull ??
              requestedAddresses.first as Map;
          for (final key in addressFields) {
            fields[key]!.text = address[key] as String? ?? '';
          }
        }
      }
      conflict.value = false;
      ready.value = true;
    } catch (failure) {
      if (!_closed) {
        error.value = CustomersFX.message(failure);
        for (final field in fields.values) {
          field.clear();
        }
      }
    } finally {
      if (!_closed) loading.value = false;
    }
  }

  Map<String, dynamic> body() {
    final name = text('name');
    var phone = text('phone')
        .toEnglishDigit()
        .replaceFirst(RegExp(r'^0098'), '+98')
        .replaceFirst(RegExp(r'^98(?=9)'), '+98')
        .replaceFirst(RegExp(r'^0(?=9)'), '+98');
    if (name.isEmpty || name.length > 200) {
      throw const FormatException('نام مشتری را وارد کنید (حداکثر ۲۰۰ حرف).');
    }
    if (!RegExp(r'^\+989\d{9}$').hasMatch(phone)) {
      throw const FormatException('شماره همراه معتبر وارد کنید.');
    }
    final result = <String, dynamic>{
      'name': name,
      'phone': phone,
      'kind': kind.value,
    };
    final original = item.value?.profile ?? {};
    for (final field in {
      'contactName': 200,
      'telephone': 32,
      'nationalId': 11,
      'economicCode': 32,
      'email': 254,
      'description': 5000,
    }.entries) {
      var value = text(field.key);
      if (['nationalId', 'economicCode', 'telephone'].contains(field.key)) {
        value = value.toEnglishDigit();
      }
      if (value.length > field.value) {
        throw const FormatException('طول یکی از مشخصات بیشتر از حد مجاز است.');
      }
      if (value.isNotEmpty &&
          field.key == 'email' &&
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
        throw const FormatException('ایمیل معتبر وارد کنید.');
      }
      if (value.isNotEmpty &&
          field.key == 'nationalId' &&
          !RegExp(r'^\d{10,11}$').hasMatch(value)) {
        throw const FormatException('کد یا شناسه ملی باید ۱۰ یا ۱۱ رقم باشد.');
      }
      if (value.isNotEmpty) {
        result[field.key] = value;
      } else if (original[field.key] != null) {
        result[field.key] = null;
      }
    }
    final addressChanged = addressFields.any(
      (key) => text(key) != _originalAddress[key],
    );
    if (addressChanged) {
      final address = <String, dynamic>{...?_address};
      if (text('fullAddress').isEmpty || text('title').isEmpty) {
        throw const FormatException(
          'برای آدرس، عنوان و ادامه آدرس را وارد کنید.',
        );
      }
      for (final key in addressFields) {
        final value = key == 'postalCode'
            ? text(key).toEnglishDigit()
            : text(key);
        final max = key == 'fullAddress' ? 1000 : 100;
        if (value.length > max) {
          throw const FormatException('طول آدرس بیشتر از حد مجاز است.');
        }
        if (value.isNotEmpty) {
          address[key] = value;
        } else {
          address.remove(key);
        }
      }
      if (address['postalCode'] != null &&
          !RegExp(r'^\d{10}$').hasMatch(address['postalCode'] as String)) {
        throw const FormatException('کدپستی باید ۱۰ رقم باشد.');
      }
      address['addressId'] ??= const Uuid().v4();
      final index = _addresses.indexWhere(
        (a) => a['addressId'] == _address?['addressId'],
      );
      final rows = [..._addresses];
      if (index < 0) {
        rows.add(address);
      } else {
        rows[index] = address;
      }
      if (rows.length > 10) {
        throw const FormatException('حداکثر ۱۰ آدرس قابل ثبت است.');
      }
      // Patch only the displayed address; keep all other addresses and metadata intact.
      result['addresses'] = rows;
    }
    if (item.value != null) result['expectedRevision'] = item.value!.revision;
    return result;
  }

  Future<RemoteCustomer?> save() async {
    if (!ready.value || saving.value || loading.value || conflict.value) {
      return null;
    }
    saving.value = true;
    error.value = null;
    try {
      fx.check();
      if (!canSave) throw const AuthError(403, 'FORBIDDEN');
      CustomerCommand command;
      try {
        command =
            pending.value ??
            CustomerCommand(customerId: item.value?.id, body: body());
      } on FormatException catch (failure) {
        error.value = failure.message;
        return null;
      }
      final result = await fx.send(command);
      if (_closed) return null;
      pending.value = fx.pending;
      return result;
    } catch (failure) {
      if (_closed) return null;
      pending.value = fx.pending;
      conflict.value =
          failure is AuthError && failure.code == 'REVISION_CONFLICT';
      error.value = CustomersFX.message(failure);
      if (failure is AuthError &&
          (failure.statusCode == 403 ||
              failure.requiresLogin ||
              failure.code == 'SELECTION_CHANGED')) {
        ready.value = false;
        for (final field in fields.values) {
          field.clear();
        }
      }
      return null;
    } finally {
      if (!_closed) saving.value = false;
    }
  }

  @override
  void onClose() {
    _closed = true;
    for (final field in fields.values) {
      field.dispose();
    }
    super.onClose();
  }
}
