import 'remote_json.dart';

class PimMedia {
  final String mediaId;
  final String? alt;
  final num sortOrder;
  PimMedia.fromJson(Object? value) : this._(RemoteJson(value));
  PimMedia._(RemoteJson json)
    : mediaId = json.text('mediaId'),
      alt = json.optionalText('alt'),
      sortOrder = (json.value['sortOrder'] as num?) ?? 0;
}
