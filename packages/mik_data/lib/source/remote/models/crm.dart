import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'remote_json.dart';

enum CrmKind {
  interaction,
  followup;

  String get idField => this == interaction ? 'interactionId' : 'followupId';
  String get path =>
      this == interaction ? 'customer-interactions' : 'customer-followups';
  String get permission =>
      this == interaction ? 'ucrm.interaction' : 'ucrm.followup';
}

class CrmEntry {
  final CrmKind type;
  final String id, customerId, status, creator;
  final int businessId, revision;
  final String _json;
  Map<String, dynamic> get data => jsonDecode(_json) as Map<String, dynamic>;
  String get title =>
      data[type == CrmKind.interaction ? 'body' : 'title'] as String;
  CrmEntry(Object? value, CrmKind type) : this._(RemoteJson(value), type);
  CrmEntry._(RemoteJson json, this.type)
    : id = json.text(type.idField),
      customerId = json.text('customerId'),
      businessId = json.number('businessId'),
      revision = json.number('revision'),
      status = json.text('status'),
      creator = RemoteJson(json.value['createdBy']).text('identityId'),
      _json = jsonEncode(json.value) {
    if ([
          id,
          customerId,
          creator,
        ].any((id) => !Uuid.isValidUUID(fromString: id)) ||
        revision < 1) {
      throw const FormatException('Invalid CRM record');
    }
    final date = json.text(
      type == CrmKind.interaction ? 'occurredAt' : 'dueAt',
    );
    if (DateTime.tryParse(date) == null) {
      throw const FormatException('Invalid CRM date');
    }
    if (type == CrmKind.interaction) {
      json.text('body');
      if (![
            'NOTE',
            'CALL',
            'VISIT',
            'EMAIL',
            'OTHER',
          ].contains(json.text('kind')) ||
          !['ACTIVE', 'ARCHIVED'].contains(status)) {
        throw const FormatException('Invalid interaction');
      }
    } else {
      json.text('title');
      json.optionalText('note');
      if (json.value.containsKey('overdue')) json.flag('overdue');
      if (!['OPEN', 'DONE', 'CANCELLED'].contains(status) ||
          !Uuid.isValidUUID(fromString: json.text('responsibleMembershipId'))) {
        throw const FormatException('Invalid followup');
      }
    }
  }
}

class CrmCommand {
  final CrmKind type;
  final String key, customerId, _body;
  final String? id;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  CrmCommand(this.type, this.customerId, Map<String, dynamic> body, {this.id})
    : key = const Uuid().v4(),
      _body = jsonEncode(body);
  CrmCommand.fromJson(Object? value) : this._(RemoteJson(value));
  CrmCommand._(RemoteJson json)
    : type = CrmKind.values.byName(json.text('type')),
      key = json.text('key'),
      customerId = json.text('customerId'),
      id = json.optionalText('id'),
      _body = jsonEncode(RemoteJson(json.value['body']).value) {
    if ([
      key,
      customerId,
      ?id,
    ].any((id) => !Uuid.isValidUUID(fromString: id))) {
      throw const FormatException('Invalid CRM command');
    }
  }
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'key': key,
    'customerId': customerId,
    'id': id,
    'body': body,
  };
}
