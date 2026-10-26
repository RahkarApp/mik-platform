import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'remote_json.dart';

class RemoteCustomer {
  final String id, name, kind, status;
  final String? phone, creatorIdentityId;
  final int businessId, revision;
  final bool isDefault;
  final List<String> assignedMembershipIds;
  final String _profile;
  Map<String, dynamic> get profile =>
      jsonDecode(_profile) as Map<String, dynamic>;
  RemoteCustomer.fromJson(Object? value) : this._(RemoteJson(value));
  RemoteCustomer._(RemoteJson json)
    : id = json.text('customerId'),
      name = json.text('name'),
      phone = json.optionalText('phone'),
      kind = json.text('kind'),
      status = json.text('status'),
      businessId = json.number('businessId'),
      revision = json.number('revision'),
      isDefault = json.flag('isDefault'),
      creatorIdentityId = json.value['createdBy'] == null
          ? null
          : RemoteJson(json.value['createdBy']).optionalText('identityId'),
      assignedMembershipIds = json.strings('assignedMembershipIds'),
      _profile = jsonEncode({
        for (final field in CustomerCommand.fields)
          if (json.value.containsKey(field)) field: json.value[field],
      }) {
    if (!Uuid.isValidUUID(fromString: id) ||
        revision < 1 ||
        !['PERSON', 'ORGANIZATION'].contains(kind) ||
        !['ACTIVE', 'ARCHIVED'].contains(status)) {
      throw const FormatException('Invalid customer');
    }
  }
}

class CustomerCommand {
  static const fields = [
    'name',
    'phone',
    'kind',
    'email',
    'telephone',
    'birthDate',
    'nationalId',
    'registrationNumber',
    'economicCode',
    'contactName',
    'description',
    'addresses',
    'groupIds',
    'tagIds',
  ];
  final String key;
  final String? customerId;
  final String _body;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  CustomerCommand({this.customerId, required Map<String, dynamic> body})
    : key = const Uuid().v4(),
      _body = jsonEncode(body);
  CustomerCommand.fromJson(Object? value) : this._(RemoteJson(value));
  CustomerCommand._(RemoteJson json)
    : key = json.text('key'),
      customerId = json.optionalText('customerId'),
      _body = jsonEncode(RemoteJson(json.value['body']).value) {
    if (!Uuid.isValidUUID(fromString: key) ||
        customerId != null && !Uuid.isValidUUID(fromString: customerId!)) {
      throw const FormatException('Invalid customer command');
    }
  }
  Map<String, Object?> toJson() => {
    'key': key,
    'customerId': customerId,
    'body': body,
  };
}
