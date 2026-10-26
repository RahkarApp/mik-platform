import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/partnership.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/partner_ownership.dart';
import 'package:mik_pages/persons/partner/ownership_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'partner_movements_test.dart' as base;

const otherPartner = '22222222-2222-4222-8222-222222222229';
const partnershipId = '99999999-9999-4999-8999-999999999998';

class OwnershipServer extends base.PartnerServer {
  OwnershipServer(super.app);
  bool manage = true, lost = false, wrong = false, zero = false;
  Map<String, dynamic>? settings;
  final ownershipReceipts = <String, Map<String, dynamic>>{};
  final ownershipRequests = <http.Request>[];
  List<Map<String, dynamic>> get contributionShares => [
    {'partnerId': base.partnerId, 'basisPoints': zero ? null : 3333},
    {'partnerId': otherPartner, 'basisPoints': zero ? null : 6667},
  ];
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final row = jsonDecode(response.body) as Map<String, dynamic>;
      if (manage || row['scopeType'] != 'BUSINESS') {
        (row['permissionCodes'] as List).add('accounting.partner.manage');
      }
      return jsonResponse(row);
    }
    if (path.endsWith('/capital/partners') && request.method == 'GET') {
      return jsonResponse({
        'businessId': 12345678,
        'items': [
          partnerRow,
          {
            ...partnerRow,
            'partnerId': otherPartner,
            'name': 'شریک دوم',
            'capitalBalance': 1000,
          },
        ],
        'nextCursor': null,
      });
    }
    if (!path.endsWith('/capital/ownership')) return super.respond(request);
    if (request.method == 'GET') {
      return jsonResponse({
        'businessId': 12345678,
        'partnership': settings,
        'configured': settings != null,
        'shares': settings?['mode'] == 'FIXED'
            ? settings!['allocations']
            : contributionShares,
      });
    }
    ownershipRequests.add(request);
    expect(request.headers['x-app-id'], app);
    expect(request.headers['x-branch-id'], branch);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final key = request.headers['idempotency-key']!;
    if (!ownershipReceipts.containsKey(key)) {
      expect(body['expectedRevision'], settings?['revision'] ?? 0);
      settings = {
        ...body,
        'businessId': 12345678,
        'partnershipId': partnershipId,
        'revision': (settings?['revision'] as int? ?? 0) + 1,
      }..remove('expectedRevision');
      ownershipReceipts[key] = {
        'businessId': 12345678,
        'partnership': settings,
      };
    }
    if (lost) {
      lost = false;
      throw TimeoutException('Lost configuration response');
    }
    final saved = ownershipReceipts[key]!;
    return jsonResponse(
      wrong
          ? {
              ...saved,
              'partnership': {
                ...saved['partnership'] as Map,
                'reason': 'دلیل متفاوت',
              },
            }
          : saved,
    );
  }
}

OwnershipCommand fixed({
  int revision = 0,
  int first = 3333,
  int second = 6667,
}) => OwnershipCommand({
  'mode': 'FIXED',
  'allocations': [
    {'partnerId': base.partnerId, 'basisPoints': first},
    {'partnerId': otherPartner, 'basisPoints': second},
  ],
  'expectedRevision': revision,
  'reason': 'توافق شرکا',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var root = Directory.current;
    while (!File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      if (root.path == root.parent.path) throw StateError('Workspace missing');
      root = root.parent;
    }
    for (final family in ['ravi', 'raviLight']) {
      await (FontLoader(family)..addFont(
            File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
          ))
          .load();
    }
  });
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app ownership reads server shares and rejects invalid configurations and scope',
      () async {
        final server = OwnershipServer(app);
        final fx = PartnerOwnershipFX(await server.prepare());
        final initial = await fx.get();
        expect(initial.partnership, isNull);
        expect(initial.shares.first.number('basisPoints'), 3333);
        server.zero = true;
        expect(
          (await fx.get()).shares.every((r) => r.value['basisPoints'] == null),
          isTrue,
        );
        server.readPartner = false;
        await expectLater(fx.get(), throwsA(isA<AuthError>()));
        server.readPartner = true;
        server.manage = false;
        await expectLater(fx.send(fixed()), throwsA(isA<AuthError>()));
        server.manage = true;
        await expectLater(
          fx.send(fixed(first: 3334)),
          throwsA(isA<FormatException>()),
        );
        final duplicate = fixed();
        await expectLater(
          fx.send(
            OwnershipCommand({
              ...duplicate.body,
              'allocations': [
                {'partnerId': base.partnerId, 'basisPoints': 5000},
                {'partnerId': base.partnerId, 'basisPoints': 5000},
              ],
            }),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(server.ownershipRequests, isEmpty);
        final saved = await fx.send(fixed());
        expect(saved.mode, 'FIXED');
        expect((await fx.get()).shares.last.number('basisPoints'), 6667);
        final contributions = await fx.send(
          OwnershipCommand({
            'mode': 'CONTRIBUTIONS',
            'allocations': [],
            'expectedRevision': saved.revision,
            'reason': 'تغییر روش',
          }),
        );
        expect(contributions.mode, 'CONTRIBUTIONS');
        expect(server.partnerRow['capitalBalance'], 500);
        final malformed = {
          'businessId': 12345678,
          'configured': false,
          'partnership': null,
          'shares': [
            {'partnerId': base.partnerId, 'basisPoints': 5000},
          ],
        };
        expect(
          () => PartnerOwnership(malformed, 12345678),
          throwsA(isA<FormatException>()),
        );
      },
    );
    test(
      '$app ownership keeps exact command after lost or mismatched response',
      () async {
        final server = OwnershipServer(app);
        final fx = PartnerOwnershipFX(await server.prepare());
        server.wrong = true;
        await expectLater(fx.send(fixed()), throwsA(isA<FormatException>()));
        expect(fx.pending, isNotNull);
        final restored = PartnerOwnershipFX(fx.partners.context);
        await restored.restore();
        final command = restored.pending!;
        server.wrong = false;
        server.lost = true;
        await expectLater(
          restored.send(command),
          throwsA(isA<TimeoutException>()),
        );
        await expectLater(restored.send(fixed()), throwsA(isA<AuthError>()));
        await restored.send(command);
        expect(restored.pending, isNull);
        expect(server.ownershipRequests.map((r) => r.body).toSet().length, 1);
        expect(
          server.ownershipRequests
              .map((r) => r.headers['idempotency-key'])
              .toSet()
              .length,
          1,
        );
        expect(server.settings!['revision'], 1);
      },
    );
    testWidgets(
      '$app native ownership form validates exact percentages and saves settings',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = OwnershipServer(app);
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(home: PartnerOwnershipScreen(appId: app)),
          ),
        );
        await tester.pumpAndSettle();
        tester
            .widget<MyTab>(find.byKey(const ValueKey('ownership-mode')))
            .callback('سهم ثابت');
        await tester.pumpAndSettle();
        Future<void> fill(String name, String value) async {
          final finder = find.byWidgetPredicate(
            (w) => w is Input && w.name == name,
          );
          final input = tester.widget<Input>(finder);
          input.controller.text = value;
          if (input.onChanged != null) input.onChanged(value);
          await tester.pump();
        }

        await fill('درصد شریک نمونه', '۳۳٫۳۳');
        await fill('درصد شریک دوم', '۶۶٫۶۶');
        await fill('دلیل تنظیم سهم', 'توافق نهایی');
        await tester.tap(find.byKey(const ValueKey('ownership-save')));
        await tester.pumpAndSettle();
        expect(server.ownershipRequests, isEmpty);
        toastification.dismissAll(delayForAnimation: false);
        await fill('درصد شریک دوم', '۶۶٫۶۷');
        expect(find.text('جمع درصدها: 100.00٪'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('ownership-save')));
        await tester.pumpAndSettle();
        expect(server.settings!['mode'], 'FIXED');
        expect(
          (server.settings!['allocations'] as List).first['basisPoints'],
          3333,
        );
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
