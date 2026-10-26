import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/utils/fx/settlement_profiles.dart';

import 'support/onboarding_fixtures.dart';
import 'support/pim_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app settlement creation retries exact receipt and preserves branch scope',
      () async {
        final requests = <http.Request>[];
        var lose = true;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/branches')) {
            return jsonResponse({
              'items': [fixtureResult()['branch']],
              'nextCursor': null,
            });
          }
          if (request.url.path.endsWith('/authorization')) {
            return jsonResponse({
              ...fixtureAuthorization(['accounting.payout.read']),
              'scopeType': 'BRANCH',
              'scopeId': branch,
            });
          }
          requests.add(request);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.headers['x-branch-id'], branch);
          expect(request.headers['x-app-id'], app);
          if (lose) {
            lose = false;
            throw TimeoutException('response lost');
          }
          return jsonResponse({
            'businessId': 12345678,
            'profile': {
              ...body,
              'settlementProfileId': productId,
              'businessId': 12345678,
              'branchId': branch,
              'status': 'ACTIVE',
            },
          });
        });
        final context = pimFixture(client, appId: app).context;
        await context.selectBranch((await context.branches()).single);
        final fx = SettlementProfilesFX(context);
        final body = <String, dynamic>{
          'name': 'online',
          'adapterProducer': 'payment',
          'connectionId': warehouse,
          'fundId': warehouse,
          'kind': 'ONLINE',
        };
        await expectLater(fx.create(body), throwsA(isA<TimeoutException>()));
        final resumed = SettlementProfilesFX(context);
        expect(await resumed.restore(), isNotNull);
        expect(await resumed.create(null), productId);
        expect(requests.first.body, requests.last.body);
        expect(
          requests.first.headers['idempotency-key'],
          requests.last.headers['idempotency-key'],
        );
        expect(await resumed.restore(), isNull);
      },
    );
  }
}
