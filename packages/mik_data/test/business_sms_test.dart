import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/business_session.dart';
import 'package:mik_data/source/remote/models/business_summary.dart';
import 'package:mik_data/source/remote/models/business_sms.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/business_sms.dart';

import 'support/onboarding_fixtures.dart';

const templateId = '55555555-5555-4555-8555-555555555555';
Map<String, Object?> template({int businessId = 12345678}) => {
  'templateId': templateId,
  'businessId': businessId,
  'platformId': 'mik',
  'name': 'ثبت فروش',
  'eventKey': 'SALE_ISSUED',
  'body': 'سلام {{customerName}}',
  'active': true,
  'revision': 1,
  'default': null,
};
BusinessContext activate(
  String app,
  Future<http.Response> Function(http.Request) handler,
) => BusinessContext.activate(
  fixtureSession(MockClient(handler), appId: app),
  BusinessSession(
    identityId: identity,
    business: BusinessSummary(
      businessId: 12345678,
      name: 'فروشگاه',
      membershipId: membership,
      membershipType: app == 'mik' ? 'OWNER' : 'PERSONNEL',
    ),
  ),
);
http.Response grants(http.Request r, {bool allowed = true}) => jsonResponse({
  'businessId': 12345678,
  'membershipId': membership,
  'personnelId': null,
  'scopeType': 'BUSINESS',
  'scopeId': '12345678',
  'allowed': true,
  'permissionCodes': allowed
      ? [
          for (final p in [
            'template.read',
            'template.create',
            'template.update',
            'template.delete',
            'template.default',
            'balance.read',
            'history.read',
          ])
            'notification.notification.$p',
        ]
      : [],
});
void resetStorage() => FlutterSecureStorage.setMockInitialValues({});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  test(
    'update, deletion and default use their distinct server revision contracts',
    () async {
      final writes = <http.Request>[];
      final fx = BusinessSmsFX(
        activate('mik', (r) async {
          if (r.url.path.endsWith('/authorization')) return grants(r);
          writes.add(r);
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          if (r.url.path.endsWith('/default')) {
            expect(body, {'expectedRevision': 3});
            return jsonResponse({
              'default': {
                'platformId': 'mik',
                'businessId': 12345678,
                'templateId': templateId,
                'eventKey': 'SALE_ISSUED',
                'revision': 4,
              },
            });
          }
          expect(body['expectedRevision'], 1);
          return jsonResponse({
            'template': {
              ...template(),
              'revision': 2,
              if (r.method == 'DELETE') ...{
                'active': false,
                'deletedAt': DateTime.now().toUtc().toIso8601String(),
              },
            },
            'replayed': false,
          });
        }),
      );
      await fx.send(
        SmsTemplateCommand('PATCH', 'templates/$templateId', {
          'name': 'ثبت فروش',
          'body': 'سلام {{customerName}}',
          'active': true,
          'expectedRevision': 1,
        }),
      );
      await fx.send(
        SmsTemplateCommand('DELETE', 'templates/$templateId', {
          'expectedRevision': 1,
        }),
      );
      await fx.setDefault(SmsTemplate(template(), 12345678), 3);
      expect(writes.map((r) => r.method), ['PATCH', 'DELETE', 'POST']);
      expect(
        writes.take(2).every((r) => r.headers['idempotency-key'] != null),
        isTrue,
      );
      expect(await fx.restore(), isNull);
    },
  );
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app reads the business wallet and paginated templates using actual SMS contracts',
      () async {
        final requests = <http.Request>[];
        final context = activate(app, (r) async {
          requests.add(r);
          if (r.url.path.endsWith('/authorization')) return grants(r);
          if (r.url.path.endsWith('/events')) {
            return jsonResponse({
              'events': {
                'SALE_ISSUED': ['customerName'],
              },
              'clubIntegrationActive': false,
            });
          }
          if (r.url.path.endsWith('/wallet')) {
            return jsonResponse({
              'accounts': [
                {
                  'accountId': warehouse,
                  'platformId': 'mik',
                  'businessId': 12345678,
                  'kind': 'SMS',
                  'balance': 12000,
                  'held': 2000,
                  'available': 10000,
                  'currency': 'TOMAN',
                  'revision': 1,
                },
              ],
            });
          }
          return jsonResponse({
            'items': r.url.queryParameters.containsKey('after')
                ? []
                : [template()],
            'nextCursor': r.url.queryParameters.containsKey('after')
                ? null
                : templateId,
          });
        });
        final fx = BusinessSmsFX(context);
        await fx.authorize();
        expect((await fx.wallet())!.available, 10000);
        expect((await fx.events())['SALE_ISSUED'], ['customerName']);
        expect((await fx.templates()).single.id, templateId);
        expect(requests.last.url.queryParameters['after'], templateId);
        expect(requests.every((r) => r.headers['x-app-id'] == app), isTrue);
        expect(
          requests.every(
            (r) => r.url.path.startsWith('/v1/businesses/12345678/'),
          ),
          isTrue,
        );
      },
    );
  }
  test('permission denied does not issue an SMS GET', () async {
    final requests = <http.Request>[];
    final fx = BusinessSmsFX(
      activate('mik', (r) async {
        requests.add(r);
        return grants(r, allowed: false);
      }),
    );
    await fx.authorize();
    await expectLater(
      fx.wallet(),
      throwsA(isA<AuthError>().having((e) => e.code, 'code', 'FORBIDDEN')),
    );
    expect(requests.length, 1);
  });
  test('foreign template and repeated page cursor are rejected', () async {
    var wrong = true;
    final fx = BusinessSmsFX(
      activate('mik', (r) async {
        if (r.url.path.endsWith('/authorization')) return grants(r);
        return jsonResponse({
          'items': wrong ? [template(businessId: 87654321)] : [],
          'nextCursor': templateId,
        });
      }),
    );
    await fx.authorize();
    await expectLater(fx.templates(), throwsFormatException);
    wrong = false;
    await expectLater(fx.templates(), throwsFormatException);
  });
  test('uncertain create restores and replays exactly the same command before clearing storage', () async {
    final writes = <http.Request>[];
    var lost = true;
    final context = activate('mik', (r) async {
      if (r.url.path.endsWith('/authorization')) return grants(r);
      if (r.url.path.endsWith('/events')) {
        return jsonResponse({
          'events': {
            'SALE_ISSUED': ['customerName'],
          },
          'clubIntegrationActive': false,
        });
      }
      writes.add(r);
      if (lost) {
        lost = false;
        throw TimeoutException('lost response');
      }
      return jsonResponse({'template': template(), 'replayed': true});
    });
    final first = BusinessSmsFX(context);
    final command = SmsTemplateCommand('POST', 'templates', {
      'name': 'ثبت فروش',
      'body': 'سلام {{customerName}}',
      'eventKey': 'SALE_ISSUED',
    });
    await expectLater(first.send(command), throwsA(anything));
    final next = BusinessSmsFX(context);
    final restored = await next.restore();
    expect(restored!.key, command.key);
    await next.send(restored);
    expect(writes.length, 2);
    expect(
      writes.first.headers['idempotency-key'],
      writes.last.headers['idempotency-key'],
    );
    expect(jsonDecode(writes.first.body), jsonDecode(writes.last.body));
    expect(await next.restore(), isNull);
  });
}
