import 'remote_json.dart';

class Business {
  final int businessId;
  final String name;
  final String status;
  final int revision;
  const Business({
    required this.businessId,
    required this.name,
    required this.status,
    required this.revision,
  });
  factory Business.fromJson(Object? value) {
    final json = RemoteJson(value);
    return Business(
      businessId: json.number('businessId'),
      name: json.text('name'),
      status: json.text('status'),
      revision: json.number('revision'),
    );
  }
}
