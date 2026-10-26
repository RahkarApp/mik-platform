import 'onboarding_data.dart';
import 'remote_json.dart';

class OnboardingAttempt {
  final String idempotencyKey;
  final OnboardingData data;
  const OnboardingAttempt({required this.idempotencyKey, required this.data});
  factory OnboardingAttempt.fromJson(Object? value) {
    final json = RemoteJson(value);
    return OnboardingAttempt(
      idempotencyKey: json.text('idempotencyKey'),
      data: OnboardingData.fromJson(json.value['data']),
    );
  }
  Map<String, Object> toJson() => {
    'idempotencyKey': idempotencyKey,
    'data': data.toJson(),
  };
}
