import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_store.dart';
import 'package:mik_data/source/remote/onboarding_store.dart';
import 'package:mik_data/source/remote/models/auth_session.dart';
import 'package:mik_data/source/remote/models/onboarding_attempt.dart';
import 'package:mik_data/source/remote/models/onboarding_data.dart';
import 'package:mik_data/source/remote/models/business_activity.dart';
import 'package:mik_data/source/remote/models/business_acquisition.dart';
import 'package:mik_data/utils/fx/auth.dart';

const identity = '11111111-1111-4111-8111-111111111111';
const branch = '22222222-2222-4222-8222-222222222222';
const warehouse = '33333333-3333-4333-8333-333333333333';
const membership = '44444444-4444-4444-8444-444444444444';

class MemorySessionStore implements AuthSessionStore {
  AuthSession? value;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class MemoryOnboardingStore implements OnboardingStore {
  final values = <String, OnboardingAttempt>{};
  @override
  Future<OnboardingAttempt?> read(String key) async => values[key];
  @override
  Future<void> write(String key, OnboardingAttempt attempt) async {
    values[key] = attempt;
  }

  @override
  Future<void> clear(String key) async {
    values.remove(key);
  }
}

AuthFX fixtureSession(http.Client client, {String appId = 'mik'}) {
  final value = AuthSession(
    identityId: identity,
    sessionId: 'session',
    accessToken: 'access',
    refreshToken: 'refresh',
    accessExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
  );
  return AuthFX(
    appId: appId,
    store: MemorySessionStore()..value = value,
    client: client,
  )..current = value;
}

OnboardingData fixtureData({String businessName = 'فروشگاه نمونه'}) =>
    OnboardingData(
      firstName: 'امین',
      businessName: businessName,
      activities: [
        BusinessActivity(fieldCode: '09', subfieldCodes: ['0902']),
      ],
      acquisition: const BusinessAcquisition(
        sourceCode: 'SEARCH',
        description: 'جستجو در اینترنت',
      ),
    );
http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(data)),
      status,
      headers: {'content-type': 'application/json'},
    );
Map<String, Object?> fixtureResult({bool replayed = false}) => {
  'business': {
    'businessId': 12345678,
    'name': 'فروشگاه نمونه',
    'status': 'ACTIVE',
    'revision': 1,
  },
  'profile': {
    'identityId': identity,
    'firstName': 'امین',
    'lastName': null,
    'revision': 1,
  },
  'settings': {
    'businessId': 12345678,
    'defaultBranchId': branch,
    'schemaVersion': 1,
    'revision': 1,
  },
  'membership': {
    'membershipId': membership,
    'businessId': 12345678,
    'identityId': identity,
    'membershipType': 'OWNER',
    'personnelId': null,
    'status': 'ACTIVE',
    'revision': 1,
  },
  'branch': {
    'branchId': branch,
    'businessId': 12345678,
    'name': 'شعبه اصلی',
    'defaultWarehouseId': warehouse,
    'status': 'ACTIVE',
    'revision': 1,
  },
  'warehouse': {
    'warehouseId': warehouse,
    'businessId': 12345678,
    'name': 'انبار اصلی',
    'status': 'ACTIVE',
    'revision': 1,
  },
  'branchAccess': {
    'branchAccessId': 'access-id',
    'businessId': 12345678,
    'branchId': branch,
    'warehouseId': warehouse,
    'canReadStock': true,
    'canReceiveStock': true,
    'canIssueStock': true,
    'status': 'ACTIVE',
    'revision': 1,
  },
  'authorization': {
    'businessId': 12345678,
    'catalogVersion': 15,
    'permissionCodes': ['business.read'],
  },
  'defaultCustomerId': 'customer-id',
  'replayed': replayed,
};
Map<String, Object?> fixtureCatalog({String? parent, String? after}) => {
  'version': 1,
  'items': parent == null
      ? [
          {'id': '09', 'name': 'پوشاک', 'parent': null},
        ]
      : [
          {'id': '0902', 'name': 'پوشاک زنانه', 'parent': '09'},
        ],
  'nextCursor': after,
  'units': [
    {'id': 1, 'name': 'عدد'},
  ],
};

void resetOnboardingStorage() => FlutterSecureStorage.setMockInitialValues({});
