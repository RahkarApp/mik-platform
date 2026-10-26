import 'remote_json.dart';
import 'business.dart';
import 'user_profile.dart';
import 'business_settings.dart';
import 'business_membership.dart';
import 'business_branch.dart';
import 'business_warehouse.dart';
import 'branch_access.dart';
import 'business_authorization.dart';

class OnboardingResult {
  final Business business;
  final UserProfile profile;
  final BusinessSettings settings;
  final BusinessMembership membership;
  final BusinessBranch branch;
  final BusinessWarehouse warehouse;
  final BranchAccess branchAccess;
  final BusinessAuthorization authorization;
  final String defaultCustomerId;
  final bool replayed;
  const OnboardingResult({
    required this.business,
    required this.profile,
    required this.settings,
    required this.membership,
    required this.branch,
    required this.warehouse,
    required this.branchAccess,
    required this.authorization,
    required this.defaultCustomerId,
    required this.replayed,
  });
  factory OnboardingResult.fromJson(Object? value) {
    final json = RemoteJson(value);
    final result = OnboardingResult(
      business: Business.fromJson(json.value['business']),
      profile: UserProfile.fromJson(json.value['profile']),
      settings: BusinessSettings.fromJson(json.value['settings']),
      membership: BusinessMembership.fromJson(json.value['membership']),
      branch: BusinessBranch.fromJson(json.value['branch']),
      warehouse: BusinessWarehouse.fromJson(json.value['warehouse']),
      branchAccess: BranchAccess.fromJson(json.value['branchAccess']),
      authorization: BusinessAuthorization.fromJson(
        json.value['authorization'],
      ),
      defaultCustomerId: json.text('defaultCustomerId'),
      replayed: json.flag('replayed'),
    );
    final id = result.business.businessId;
    if (result.settings.businessId != id ||
        result.membership.businessId != id ||
        result.branch.businessId != id ||
        result.warehouse.businessId != id ||
        result.branchAccess.businessId != id ||
        result.authorization.businessId != id ||
        result.profile.identityId != result.membership.identityId ||
        result.membership.membershipType != 'OWNER' ||
        result.settings.defaultBranchId != result.branch.branchId ||
        result.branch.defaultWarehouseId != result.warehouse.warehouseId ||
        result.branchAccess.branchId != result.branch.branchId ||
        result.branchAccess.warehouseId != result.warehouse.warehouseId) {
      throw const FormatException('Inconsistent onboarding response');
    }
    return result;
  }
}
