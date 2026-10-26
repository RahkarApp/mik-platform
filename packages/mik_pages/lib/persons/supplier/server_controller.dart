import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/suppliers.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class SuppliersController extends GetxController {
  final String appId;
  final AccountingPersonType type;
  final void Function(String message, bool success)? onNotice;
  SuppliersController({
    required this.appId,
    this.onNotice,
    this.type = AccountingPersonType.supplier,
  });
  SuppliersFX? fx;
  final items = <RemoteSupplier>[].obs;
  final query = ''.obs, loading = false.obs, saving = false.obs;
  final status = 'فعال'.obs;
  final error = RxnString(), commandError = RxnString();
  final pending = Rxn<SupplierCommand>();
  int _generation = 0;
  bool _closed = false;
  bool get canCreate =>
      !loading.value &&
      !saving.value &&
      pending.value == null &&
      fx?.has(type.createPermission) == true;
  List<RemoteSupplier> get visible {
    String normalize(String text) =>
        text.trim().toLowerCase().toEnglishDigit().replaceAll(' ', '');
    final q = normalize(query.value);
    return items
        .where(
          (row) =>
              q.isEmpty ||
              normalize(row.name).contains(q) ||
              row.phone != null && normalize(row.phone!).contains(q) ||
              normalize(row.id).contains(q),
        )
        .toList();
  }

  void search(Object? value) => query.value = value?.toString() ?? '';
  void _failure(Object failure, {bool command = false}) {
    final message = SuppliersFX.message(failure, type: type);
    if (command) {
      commandError.value = message;
    } else {
      error.value = message;
    }
    if (failure is AuthError &&
        (failure.statusCode == 403 ||
            failure.requiresLogin ||
            failure.code == 'SELECTION_CHANGED')) {
      items.clear();
      pending.value = null;
    }
    onNotice?.call(message, false);
  }

  Future<void> load() async {
    if (_closed) return;
    if (saving.value) {
      onNotice?.call('ثبت درخواست در حال انجام است؛ کمی صبر کنید.', false);
      return;
    }
    final generation = ++_generation;
    loading.value = true;
    error.value = null;
    items.clear();
    try {
      final context = BusinessContext.forApp(appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      fx ??= SuppliersFX.forContext(context, type: type);
      await fx!.authorize();
      pending.value = await fx!.restore();
      if (!fx!.has('${type.permission}.read')) {
        if (!_closed && generation == _generation) {
          error.value = 'مجوز مشاهده فهرست ${type.plural} را ندارید.';
          onNotice?.call(error.value!, false);
        }
        return;
      }
      final rows = await fx!.all(
        status: status.value == 'آرشیو' ? 'ARCHIVED' : 'ACTIVE',
      );
      if (_closed || generation != _generation) return;
      items.assignAll(rows);
    } catch (failure) {
      if (!_closed && generation == _generation) _failure(failure);
    } finally {
      if (!_closed && generation == _generation) loading.value = false;
    }
  }

  Future<RemoteSupplier?> details(RemoteSupplier row) async {
    if (saving.value || loading.value) {
      onNotice?.call('عملیات قبلی هنوز در حال انجام است.', false);
      return null;
    }
    try {
      final client = fx;
      if (client == null) throw const AuthError(401, 'SESSION_INVALID');
      await client.authorize();
      final result = await client.get(row.id);
      if (_closed) return null;
      return result;
    } catch (failure) {
      if (!_closed) _failure(failure);
      return null;
    }
  }

  bool canEdit(RemoteSupplier row) =>
      !loading.value &&
      !saving.value &&
      pending.value == null &&
      fx?.canEdit(row) == true;

  Future<RemoteSupplier?> create(
    String name,
    String phone, {
    String? kind,
    Map<String, dynamic> details = const {},
    RemoteSupplier? item,
    String status = 'ACTIVE',
  }) async {
    if (_closed) return null;
    if (saving.value || loading.value) {
      onNotice?.call('عملیات قبلی هنوز در حال انجام است.', false);
      return null;
    }
    commandError.value = null;
    final client = fx;
    final saved = pending.value ?? client?.pending;
    Map<String, dynamic>? body;
    if (saved == null) {
      try {
        if (type == AccountingPersonType.partner && item != null) {
          for (final key in ['reference', 'note']) {
            if (item.profile[key] != null &&
                details[key] is String &&
                (details[key] as String).trim().isEmpty) {
              throw const FormatException(
                'سرور حذف کد مرجع یا یادداشت ثبت‌شده را پشتیبانی نمی‌کند؛ مقدار را ویرایش کنید.',
              );
            }
          }
        }
        body = _profile(name, phone, kind, details);
        if (item != null) {
          body.addAll({
            type.idField: item.id,
            'expectedRevision': item.revision,
            'status': status,
          });
        }
      } on FormatException catch (failure) {
        commandError.value = failure.message.replaceAll(
          'تامین‌کننده',
          type.singular,
        );
        onNotice?.call(commandError.value!, false);
        return null;
      }
    }
    saving.value = true;
    try {
      if (client == null) throw const AuthError(401, 'SESSION_INVALID');
      final result = await client.send(
        saved ?? SupplierCommand.profile(body!, type: type),
      );
      if (_closed) return null;
      pending.value = client.pending;
      if (client.has('${type.permission}.read')) {
        final index = items.indexWhere((row) => row.id == result.id);
        if (result.status !=
            (this.status.value == 'آرشیو' ? 'ARCHIVED' : 'ACTIVE')) {
          items.removeWhere((row) => row.id == result.id);
        } else if (index < 0) {
          items.add(result);
        } else {
          items[index] = result;
        }
      }
      onNotice?.call(
        (saved?.updating ?? item != null)
            ? 'اطلاعات ${type.singular} با موفقیت ویرایش شد.'
            : '${type.singular} با موفقیت ثبت شد.',
        true,
      );
      return result;
    } catch (failure) {
      if (!_closed) {
        pending.value = client?.pending;
        _failure(failure, command: true);
      }
      return null;
    } finally {
      if (!_closed) saving.value = false;
    }
  }

  Map<String, dynamic> _profile(
    String name,
    String phone,
    String? kind,
    Map<String, dynamic> details,
  ) {
    Never invalid(String message) => throw FormatException(message);
    String digits(String value) => value.trim().toEnglishDigit();
    String mobile(String value) {
      final normalized = digits(value)
          .replaceFirst(RegExp(r'^0098'), '+98')
          .replaceFirst(RegExp(r'^98(?=9)'), '+98')
          .replaceFirst(RegExp(r'^0(?=9)'), '+98');
      if (!RegExp(r'^\+989\d{9}$').hasMatch(normalized)) {
        invalid('شماره موبایل معتبر با ۰۹ یا +۹۸ وارد کنید.');
      }
      return normalized;
    }

    final title = name.trim();
    if (title.isEmpty ||
        title.length > 200 ||
        RegExp(r'[\u0000-\u0008]').hasMatch(title)) {
      invalid('نام تامین‌کننده الزامی و حداکثر ۲۰۰ حرف است.');
    }
    final telephone = mobile(phone);
    if (!['PERSON', 'ORGANIZATION'].contains(kind)) {
      invalid('نوع تامین‌کننده را مشخص کنید.');
    }
    final result = <String, dynamic>{
      'name': title,
      'phone': telephone,
      'kind': kind,
    };
    if (type == AccountingPersonType.partner) {
      String text(String key, int limit) {
        final raw = details[key];
        if (raw != null && raw is! String) invalid('مشخصات شریک معتبر نیست.');
        final value = (raw as String? ?? '').trim();
        if (value.length > limit ||
            RegExp(r'[\u0000-\u0008]').hasMatch(value)) {
          invalid('طول یا محتوای مشخصات شریک معتبر نیست.');
        }
        return value;
      }

      final legalName = text('legalName', 200);
      if (kind == 'ORGANIZATION' && legalName.isEmpty ||
          legalName.length > 200) {
        invalid('نام قانونی شرکت الزامی و حداکثر ۲۰۰ حرف است.');
      }
      if (legalName.isNotEmpty) result['legalName'] = legalName;
      for (final field in const {'reference': 100, 'note': 1000}.entries) {
        final value = text(field.key, field.value);
        if (value.isNotEmpty) result[field.key] = value;
      }
      return result;
    }
    for (final field in const {
      'legalName': 200,
      'email': 254,
      'telephone': 32,
      'nationalId': 11,
      'registrationNumber': 64,
      'economicCode': 32,
    }.entries) {
      if (!details.containsKey(field.key)) continue;
      final raw = details[field.key];
      if (raw != null && raw is! String) {
        invalid('مشخصات تامین‌کننده معتبر نیست.');
      }
      final value = raw == null ? '' : digits(raw as String);
      if (value.length > field.value ||
          RegExp(r'[\u0000-\u0008]').hasMatch(value)) {
        invalid('طول اطلاعات واردشده بیش از حد مجاز است.');
      }
      result[field.key] = value.isEmpty ? null : value;
    }
    if (kind == 'ORGANIZATION' &&
        (result['legalName'] as String? ?? '').isEmpty) {
      invalid('نام قانونی شرکت الزامی است.');
    }
    if (result['email'] != null &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(result['email'])) {
      invalid('ایمیل معتبر وارد کنید.');
    }
    if (result['nationalId'] != null &&
        !RegExp(r'^\d{10,11}$').hasMatch(result['nationalId'])) {
      invalid('کد یا شناسه ملی باید ۱۰ یا ۱۱ رقم باشد.');
    }
    if (details.containsKey('addresses')) {
      final addresses = details['addresses'];
      if (addresses is! List || addresses.length > 10) {
        invalid('حداکثر ۱۰ آدرس می‌توانید ثبت کنید.');
      }
      final ids = <String>{};
      var defaults = 0;
      result['addresses'] = addresses.map((raw) {
        if (raw is! Map<String, dynamic>) {
          invalid('آدرس معتبر نیست.');
        }
        final row = Map<String, dynamic>.from(raw);
        final id = row['addressId'];
        if (id is! String ||
            !Uuid.isValidUUID(fromString: id) ||
            !ids.add(id)) {
          invalid('شناسه آدرس معتبر نیست.');
        }
        for (final field in const {'title': 100, 'fullAddress': 1000}.entries) {
          final value = row[field.key];
          if (value is! String ||
              value.trim().isEmpty ||
              value.trim().length > field.value) {
            invalid('عنوان و متن آدرس الزامی است.');
          }
          row[field.key] = value.trim();
        }
        for (final field in const {
          'recipientName': 200,
          'provinceCode': 32,
          'provinceName': 100,
          'cityCode': 32,
          'cityName': 100,
          'district': 100,
        }.entries) {
          if (!row.containsKey(field.key)) continue;
          final value = row[field.key];
          if (value is! String ||
              value.trim().isEmpty ||
              value.length > field.value) {
            invalid('مشخصات آدرس معتبر نیست.');
          }
          row[field.key] = value.trim();
        }
        if (row.values.whereType<String>().any(
              (value) => RegExp(r'[\u0000-\u0008]').hasMatch(value),
            ) ||
            row['countryCode'] != null &&
                (row['countryCode'] is! String ||
                    !RegExp(r'^[A-Z]{2}$').hasMatch(row['countryCode'])) ||
            row['isDefault'] != null && row['isDefault'] is! bool) {
          invalid('مشخصات آدرس یا کد کشور معتبر نیست.');
        }
        if (row['isDefault'] == true) {
          defaults++;
        }
        if (defaults > 1) {
          invalid('فقط یک آدرس پیش‌فرض انتخاب کنید.');
        }
        if (row['recipientPhone'] != null) {
          row['recipientPhone'] = mobile(row['recipientPhone'] as String);
        }
        if (row['postalCode'] != null) {
          row['postalCode'] = digits(row['postalCode'] as String);
          if (!RegExp(r'^\d{10}$').hasMatch(row['postalCode'])) {
            invalid('کدپستی باید ۱۰ رقم باشد.');
          }
        }
        final lat = row['latitude'], lng = row['longitude'];
        if ((lat == null) != (lng == null) ||
            lat != null &&
                (lat is! num ||
                    !lat.isFinite ||
                    lat.abs() > 90 ||
                    lng is! num ||
                    !lng.isFinite ||
                    lng.abs() > 180)) {
          invalid(
            'مختصات آدرس معتبر نیست؛ طول و عرض جغرافیایی را با هم وارد کنید.',
          );
        }
        return row;
      }).toList();
    }
    return result;
  }

  @override
  void onClose() {
    _closed = true;
    _generation++;
    super.onClose();
  }
}
