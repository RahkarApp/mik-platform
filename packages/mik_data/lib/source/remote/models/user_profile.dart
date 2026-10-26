import 'remote_json.dart';

class UserProfile {
  final String identityId;
  final String firstName;
  final String? lastName;
  final int revision;
  const UserProfile({
    required this.identityId,
    required this.firstName,
    required this.lastName,
    required this.revision,
  });
  factory UserProfile.fromJson(Object? value) {
    final json = RemoteJson(value);
    return UserProfile(
      identityId: json.text('identityId'),
      firstName: json.text('firstName'),
      lastName: json.optionalText('lastName'),
      revision: json.number('revision'),
    );
  }
}
