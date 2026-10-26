import 'business_summary.dart';
import 'onboarding_result.dart';

class BusinessSession {
  final String identityId;
  final BusinessSummary business;
  final OnboardingResult? onboarding;
  const BusinessSession({
    required this.identityId,
    required this.business,
    this.onboarding,
  });

  factory BusinessSession.fromOnboarding(OnboardingResult result) =>
      BusinessSession(
        identityId: result.profile.identityId,
        business: BusinessSummary(
          businessId: result.business.businessId,
          name: result.business.name,
          membershipId: result.membership.membershipId,
          membershipType: result.membership.membershipType,
        ),
        onboarding: result,
      );
}
