import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'remote_json.dart';

enum PersonnelResource {
  person,
  role,
  access;

  String get path => switch (this) {
    person => 'personnel',
    role => 'roles',
    access => 'ext-permissions',
  };
  String get idField => switch (this) {
    person => 'personnelId',
    role => 'roleId',
    access => 'accessId',
  };
  String get readPermission => switch (this) {
    person => 'business.personnel.read',
    role => 'business.role.read',
    access => 'business.personnel.access.update',
  };
  String writePermission(bool update) => switch (this) {
    person => 'business.personnel.${update ? 'update' : 'create'}',
    role => 'business.role.update',
    access => 'business.personnel.access.update',
  };
}

class PersonnelEntry {
  final PersonnelResource resource;
  final String id, name, status;
  final int businessId, revision;
  final String _json;
  Map<String, dynamic> get data => jsonDecode(_json) as Map<String, dynamic>;
  PersonnelEntry(Object? value, PersonnelResource resource)
    : this._(RemoteJson(value), resource);
  PersonnelEntry._(RemoteJson json, this.resource)
    : id = json.text(resource.idField),
      businessId = json.number('businessId'),
      revision = json.number('revision'),
      name = resource == PersonnelResource.person
          ? json.text('displayName')
          : resource == PersonnelResource.role
          ? json.text('name')
          : json.text('scopeId'),
      status = json.text(
        resource == PersonnelResource.person ? 'employmentStatus' : 'status',
      ),
      _json = jsonEncode(json.value) {
    if (!Uuid.isValidUUID(fromString: id) ||
        revision < 1 ||
        !(resource == PersonnelResource.person
                ? ['ACTIVE', 'SUSPENDED', 'ENDED']
                : ['ACTIVE', 'SUSPENDED', 'ARCHIVED'])
            .contains(status)) {
      throw const FormatException('Invalid personnel entry');
    }
    if (resource == PersonnelResource.person) {
      if (!Uuid.isValidUUID(fromString: json.text('membershipId')) ||
          DateTime.tryParse(json.text('startedAt')) == null ||
          json.value['endedAt'] != null &&
              DateTime.tryParse(json.text('endedAt')) == null) {
        throw const FormatException('Invalid personnel membership');
      }
      json.optionalText('personnelCode');
      json.optionalText('jobTitle');
    } else if (resource == PersonnelResource.role) {
      json.strings('permissionCodes');
      json.optionalText('description');
    } else {
      if (!Uuid.isValidUUID(fromString: json.text('membershipId')) ||
          ![
            'BUSINESS',
            'BRANCH',
            'WAREHOUSE',
          ].contains(json.text('scopeType')) ||
          (json.text('scopeType') == 'BUSINESS'
              ? name != '$businessId'
              : !Uuid.isValidUUID(fromString: name)) ||
          json
              .strings('roleIds')
              .any((id) => !Uuid.isValidUUID(fromString: id))) {
        throw const FormatException('Invalid personnel access');
      }
    }
  }
}

class PersonnelCommand {
  final PersonnelResource resource;
  final String key, _body;
  final String? id;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  PersonnelCommand(this.resource, Map<String, dynamic> body, {this.id})
    : key = const Uuid().v4(),
      _body = jsonEncode(body);
  PersonnelCommand.fromJson(Object? value) : this._(RemoteJson(value));
  PersonnelCommand._(RemoteJson json)
    : resource = PersonnelResource.values.byName(json.text('resource')),
      key = json.text('key'),
      id = json.optionalText('id'),
      _body = jsonEncode(RemoteJson(json.value['body']).value) {
    if (!Uuid.isValidUUID(fromString: key) ||
        id != null && !Uuid.isValidUUID(fromString: id!)) {
      throw const FormatException('Invalid personnel command');
    }
  }
  Map<String, dynamic> toJson() => {
    'resource': resource.name,
    'key': key,
    'id': id,
    'body': body,
  };
}
