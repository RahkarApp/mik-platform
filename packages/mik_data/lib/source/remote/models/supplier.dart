import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'remote_json.dart';

// These parties share profile UI, but keep their server contracts explicit.
enum AccountingPersonType {
  supplier,
  serviceProvider,
  partner;

  String get idField => switch (this) {
    supplier => 'supplierId',
    serviceProvider => 'payeeId',
    partner => 'partnerId',
  };
  String get permission => switch (this) {
    supplier => 'accounting.supplier',
    serviceProvider => 'accounting.service-provider',
    partner => 'accounting.partner',
  };
  String get createPermission =>
      this == partner ? '$permission.manage' : '$permission.create';
  String get updatePermission =>
      this == partner ? '$permission.manage' : '$permission.update';
  String get path => switch (this) {
    supplier => 'suppliers',
    serviceProvider => 'expenses/payees',
    partner => 'capital/partners',
  };
  String get resultField => this == serviceProvider
      ? 'item'
      : this == partner
      ? 'partner'
      : 'supplier';
  String get storage => switch (this) {
    supplier => 'suppliers.v1',
    serviceProvider => 'service-providers.v1',
    partner => 'partners.v1',
  };
  String get singular => switch (this) {
    supplier => 'تامین‌کننده',
    serviceProvider => 'سرویس‌دهنده',
    partner => 'شریک',
  };
  String get plural => switch (this) {
    supplier => 'تامین‌کنندگان',
    serviceProvider => 'سرویس‌دهندگان',
    partner => 'شرکا',
  };
  List<String> get profileFields => this == partner
      ? ['name', 'phone', 'kind', 'legalName', 'reference', 'note']
      : SupplierCommand.fields;
}

class RemoteSupplier {
  final AccountingPersonType type;
  final String id, name, status;
  final String? phone, kind, creatorIdentityId;
  final String _profile;
  Map<String, dynamic> get profile =>
      jsonDecode(_profile) as Map<String, dynamic>;
  final int businessId, revision;
  final int? capitalBalance, currentBalance;
  RemoteSupplier.fromJson(
    Object? value, {
    AccountingPersonType type = AccountingPersonType.supplier,
  }) : this._(RemoteJson(value), type);
  RemoteSupplier._(RemoteJson json, this.type)
    : id = json.text(type.idField),
      name = json.text('name'),
      status = json.text('status'),
      phone = json.optionalText('phone'),
      kind = json.optionalText('kind'),
      creatorIdentityId = json.value['createdBy'] == null
          ? null
          : RemoteJson(json.value['createdBy']).optionalText('identityId'),
      _profile = jsonEncode({
        for (final key in type.profileFields)
          if (json.value.containsKey(key)) key: json.value[key],
      }),
      businessId = json.number('businessId'),
      revision = json.number('revision'),
      capitalBalance = type == AccountingPersonType.partner
          ? json.optionalNumber('capitalBalance')
          : null,
      currentBalance = type == AccountingPersonType.partner
          ? json.optionalNumber('currentBalance')
          : null {
    if (capitalBalance != null &&
            (capitalBalance! < 0 || capitalBalance! > 9007199254740991) ||
        currentBalance != null && currentBalance!.abs() > 9007199254740991 ||
        !Uuid.isValidUUID(fromString: id) ||
        revision < 1 ||
        kind != null && !['PERSON', 'ORGANIZATION'].contains(kind) ||
        !['ACTIVE', 'ARCHIVED'].contains(status)) {
      throw const FormatException('Invalid supplier');
    }
    for (final field in type.profileFields.where((key) => key != 'addresses')) {
      json.optionalText(field);
    }
    if (json.value['addresses'] != null) {
      json.items('addresses', (value) {
        final address = RemoteJson(value);
        if (!Uuid.isValidUUID(fromString: address.text('addressId'))) {
          throw const FormatException('Invalid supplier address');
        }
        address.text('title');
        address.text('fullAddress');
        for (final key in [
          'recipientName',
          'recipientPhone',
          'countryCode',
          'provinceCode',
          'provinceName',
          'cityCode',
          'cityName',
          'district',
          'postalCode',
        ]) {
          address.optionalText(key);
        }
        if (address.value['isDefault'] != null) address.flag('isDefault');
        for (final key in ['latitude', 'longitude']) {
          final coordinate = address.value[key];
          if (coordinate != null &&
              (coordinate is! num || !coordinate.isFinite)) {
            throw const FormatException('Invalid supplier address coordinate');
          }
        }
        return address.value;
      });
    }
  }
}

class SupplierCommand {
  static const fields = [
    'name',
    'phone',
    'kind',
    'legalName',
    'email',
    'telephone',
    'nationalId',
    'registrationNumber',
    'economicCode',
    'addresses',
  ];
  final AccountingPersonType type;
  final int version;
  bool get updating => body[type.idField] != null;
  final String key, _body;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  SupplierCommand({required String name, String? phone})
    : type = AccountingPersonType.supplier,
      version = 1,
      key = const Uuid().v4(),
      _body = jsonEncode({'name': name, 'phone': ?phone});
  SupplierCommand.profile(
    Map<String, dynamic> body, {
    this.type = AccountingPersonType.supplier,
  }) : version = 2,
       key = const Uuid().v4(),
       _body = jsonEncode(body);
  SupplierCommand.fromJson(Object? value) : this._(RemoteJson(value));
  SupplierCommand._(RemoteJson json)
    : type = AccountingPersonType.values.byName(
        json.optionalText('type') ?? 'supplier',
      ),
      version = json.optionalNumber('version') ?? 1,
      key = json.text('key'),
      _body = jsonEncode(RemoteJson(json.value['body']).value) {
    if (![1, 2].contains(version) ||
        type != AccountingPersonType.supplier && version != 2 ||
        !Uuid.isValidUUID(fromString: key) ||
        body.keys.any(
          (k) =>
              !(version == 1
                      ? ['name', 'phone']
                      : [
                          ...type.profileFields,
                          type.idField,
                          'expectedRevision',
                          'status',
                        ])
                  .contains(k),
        ) ||
        updating &&
            (version != 2 ||
                body[type.idField] is! String ||
                !Uuid.isValidUUID(fromString: body[type.idField]) ||
                body['expectedRevision'] is! int ||
                body['expectedRevision'] < 1) ||
        body['name'] is! String ||
        (body['name'] as String).trim().isEmpty) {
      throw const FormatException('Invalid supplier command');
    }
  }
  Map<String, Object> toJson() => {
    'type': type.name,
    'version': version,
    'key': key,
    'body': body,
  };
}
