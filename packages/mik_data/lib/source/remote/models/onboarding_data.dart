import 'business_activity.dart';
import 'business_acquisition.dart';
import 'remote_json.dart';

class OnboardingData {
  final String firstName, businessName;
  final String? lastName, referralCode;
  final List<BusinessActivity> activities;
  final BusinessAcquisition acquisition;
  OnboardingData({
    required this.firstName,
    required this.businessName,
    this.lastName,
    this.referralCode,
    required List<BusinessActivity> activities,
    required this.acquisition,
  }) : activities = List.unmodifiable(activities);
  factory OnboardingData.fromJson(Object? value) {
    final json = RemoteJson(value);
    return OnboardingData(
      firstName: json.text('firstName'),
      lastName: json.optionalText('lastName'),
      businessName: json.text('businessName'),
      referralCode: json.optionalText('referralCode'),
      activities: json.items('activities', BusinessActivity.fromJson),
      acquisition: BusinessAcquisition.fromJson(json.value['acquisition']),
    );
  }
  Map<String, Object> toJson() => {
    'firstName': firstName,
    'lastName': ?lastName,
    'businessName': businessName,
    'activities': activities.map((e) => e.toJson()).toList(),
    'acquisition': acquisition.toJson(),
    'referralCode': ?referralCode,
  };
}
