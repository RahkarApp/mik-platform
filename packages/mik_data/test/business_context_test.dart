import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business.dart';
import 'package:mik_data/utils/fx/business_context.dart';

import 'support/onboarding_fixtures.dart';

const secondBranch = '55555555-5555-4555-8555-555555555555';
Map<String, Object?> branchRow(
  String id, {
  int businessId = 12345678,
  String status = 'ACTIVE',
}) => {
  'businessId': businessId,
  'branchId': id,
  'name': id == branch ? 'شعبه اصلی' : 'شعبه دوم',
  'defaultWarehouseId': warehouse,
  'status': status,
  'revision': 1,
};
Map<String, Object?> authorization(
  http.Request request, {
  String member = membership,
}) => {
  'businessId': 12345678,
  'membershipId': member,
  'personnelId': null,
  'scopeType': request.url.queryParameters['scopeType'],
  'scopeId': request.url.queryParameters['scopeId'],
  'allowed': true,
  'permissionCodes': [
    request.url.queryParameters['scopeType'] == 'BUSINESS'
        ? 'pim.product.read'
        : 'business.branch.read',
  ],
};
BusinessSession entry(String app) => BusinessSession(
  identityId: identity,
  business: BusinessSummary(
    businessId: 12345678,
    name: 'فروشگاه',
    membershipId: membership,
    membershipType: app == 'mik' ? 'OWNER' : 'PERSONNEL',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app lists actual branches, resolves separate scopes and forwards branch header',
      () async {
        final requests = <http.Request>[];
        final auth = fixtureSession(
          MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/authorization')) {
              return jsonResponse(authorization(request));
            }
            if (request.url.path.endsWith('/branches')) {
              return jsonResponse({
                'items': [
                  branchRow(branch),
                  branchRow(secondBranch, status: 'ARCHIVED'),
                ],
                'nextCursor': null,
              });
            }
            return jsonResponse({'ok': true});
          }),
          appId: app,
        );
        final context = BusinessContext.activate(auth, entry(app));
        await context.authorize();
        final branches = await context.branches();
        expect(branches.map((b) => b.branchId), [branch]);
        await context.selectBranch(branches.single);
        expect(context.hasPermission('pim.product.read'), isTrue);
        expect(
          context.hasPermission('pim.product.read', inBranch: true),
          isFalse,
        );
        expect(
          context.hasPermission('business.branch.read', inBranch: true),
          isTrue,
        );
        await context.request('GET', '/v1/businesses/12345678');
        expect(requests.last.headers['x-branch-id'], branch);
        expect(requests.map((r) => r.headers['x-app-id']), everyElement(app));
        await auth.clear();
        expect(context.hasPermission('pim.product.read'), isFalse);
        expect(BusinessContext.forApp(app), isNull);
      },
    );

    test(
      '$app branches paginate with UUID cursors and reject cross-business rows',
      () async {
        var foreign = false;
        final context = BusinessContext.activate(
          fixtureSession(
            MockClient(
              (request) async => jsonResponse({
                'items': [
                  branchRow(
                    request.url.queryParameters['after'] == null
                        ? branch
                        : secondBranch,
                    businessId: foreign ? 87654321 : 12345678,
                  ),
                ],
                'nextCursor': request.url.queryParameters['after'] == null
                    ? branch
                    : null,
              }),
            ),
            appId: app,
          ),
          entry(app),
        );
        expect((await context.branches()).map((b) => b.branchId), [
          branch,
          secondBranch,
        ]);
        foreign = true;
        await expectLater(context.branches(), throwsFormatException);
        expect(context.selectedBranch, isNull);
      },
    );

    test(
      '$app refuses mismatched membership and clears previous access on forbidden',
      () async {
        var wrongMember = true;
        var forbidden = false;
        final context = BusinessContext.activate(
          fixtureSession(
            MockClient((request) async {
              if (forbidden) {
                return jsonResponse({
                  'error': {'code': 'FORBIDDEN'},
                }, 403);
              }
              return jsonResponse(
                authorization(
                  request,
                  member: wrongMember ? 'other' : membership,
                ),
              );
            }),
            appId: app,
          ),
          entry(app),
        );
        await expectLater(context.authorize(), throwsFormatException);
        expect(context.hasPermission('pim.product.read'), isFalse);
        wrongMember = false;
        await context.authorize();
        forbidden = true;
        await expectLater(
          context.request('GET', '/v1/businesses/12345678'),
          throwsA(isA<AuthError>()),
        );
        expect(context.hasPermission('pim.product.read'), isFalse);
        expect(context.selectedBranch, isNull);
      },
    );

    test(
      '$app stale branch selection cannot activate after switching businesses',
      () async {
        final response = Completer<http.Response>();
        final started = Completer<void>();
        final auth = fixtureSession(
          MockClient((request) async {
            if (request.url.path.endsWith('/branches')) {
              return jsonResponse({
                'items': [branchRow(branch)],
                'nextCursor': null,
              });
            }
            started.complete();
            return response.future;
          }),
          appId: app,
        );
        final old = BusinessContext.activate(auth, entry(app));
        final branches = await old.branches();
        final selecting = old.selectBranch(branches.single);
        final assertion = expectLater(selecting, throwsA(isA<AuthError>()));
        await started.future;
        final next = BusinessContext.activate(auth, entry(app));
        response.complete(
          jsonResponse({
            'businessId': 12345678,
            'membershipId': membership,
            'personnelId': null,
            'scopeType': 'BRANCH',
            'scopeId': branch,
            'allowed': true,
            'permissionCodes': [],
          }),
        );
        await assertion;
        expect(next.selectedBranch, isNull);
        expect(old.branchAuthorization, isNull);
      },
    );

    test('$app business list cannot be reused after logout', () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final auth = fixtureSession(
        MockClient((_) async {
          started.complete();
          return response.future;
        }),
        appId: app,
      );
      final loading = BusinessFX(session: auth).businesses();
      final assertion = expectLater(loading, throwsA(isA<AuthError>()));
      await started.future;
      await auth.clear();
      response.complete(jsonResponse({'items': [], 'nextCursor': null}));
      await assertion;
    });
  }
}
