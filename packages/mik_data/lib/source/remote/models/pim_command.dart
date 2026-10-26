import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'pim_resource.dart';
import 'remote_json.dart';

class PimCommand {
  final PimResource? resource;
  final String operation, idempotencyKey;
  final String? id, creatorIdentityId;
  // Immutable serialized payload preserves the exact user's intent on retries.
  final String _body;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  PimCommand({
    this.resource,
    required this.operation,
    this.id,
    this.creatorIdentityId,
    required Map<String, dynamic> body,
  }) : idempotencyKey = const Uuid().v4(),
       _body = jsonEncode(body);
  PimCommand.fromJson(Object? value) : this._(RemoteJson(value));
  PimCommand._(RemoteJson json)
    : resource = json.optionalText('resource') == null
          ? null
          : PimResource.values.byName(json.text('resource')),
      operation = json.text('operation'),
      id = json.optionalText('id'),
      creatorIdentityId = json.optionalText('creatorIdentityId'),
      idempotencyKey = json.text('idempotencyKey'),
      _body = jsonEncode(RemoteJson(json.value['body']).value);
  Map<String, Object?> toJson() => {
    'resource': resource?.name,
    'operation': operation,
    'id': id,
    'creatorIdentityId': creatorIdentityId,
    'idempotencyKey': idempotencyKey,
    'body': body,
  };
}
