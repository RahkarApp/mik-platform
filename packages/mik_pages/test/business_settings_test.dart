import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/business_settings.dart';
import 'package:mik_pages/settings/business_settings_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

class SettingsServer {
  final String app;
  SettingsServer(this.app);
  bool allowWrite = true, lose = false, wrongTenant = false;
  final writes = <http.Request>[];
  final receipts = <String, Map<String, dynamic>>{};
  Map<String, dynamic> value = {
    'businessId': 12345678,
    'revision': 1,
    'schemaVersion': 1,
    'defaultBranchId': branch,
    'accounting': {
      'allowCreditSales': false,
      'allocationPolicy': 'OLDEST_DUE_FIRST',
      'invoiceNotificationsEnabled': true,
      'invoiceNotificationPatterns': {'SALE_ISSUED': 'pattern'},
    },
    'tax': {'taxpayerSystemEnabled': false},
    'inventory': {
      'itemFulfillmentMode': 'SINGLE_WAREHOUSE',
      'reservation': {
        'posTimeoutMinutes': 30,
        'onlineTimeoutMinutes': 10,
        'maxExtensions': 2,
        'maxLifetimeMinutes': 120,
      },
      'supplyAllocation': {
        'mode': 'AUTO',
        'priority': 'PAYMENT_FIRST',
        'eligiblePaymentStatuses': ['PAID', 'PARTIALLY_PAID'],
      },
    },
  };
  Future<http.Response> respond(http.Request request) async {
    expect(request.headers['x-app-id'], app);
    if (request.url.path.endsWith('/authorization')) {
      expect(request.url.queryParameters, {
        'scopeType': 'BUSINESS',
        'scopeId': '12345678',
      });
      return jsonResponse(
        fixtureAuthorization([
          'business.business.read',
          if (allowWrite) 'business.business.settings.update',
        ]),
      );
    }
    expect(request.url.path, '/v1/businesses/12345678/settings');
    if (request.method == 'GET') {
      return jsonResponse({
        'item': {...value, if (wrongTenant) 'businessId': 87654321},
      });
    }
    expect(request.method, 'PATCH');
    writes.add(request);
    final key = request.headers['idempotency-key']!;
    if (receipts[key] != null) return jsonResponse(receipts[key]!);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (body['expectedRevision'] != value['revision']) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    void merge(Map<String, dynamic> target, Map<String, dynamic> patch) {
      for (final entry in patch.entries) {
        if (entry.key == 'expectedRevision') continue;
        if (entry.value is Map<String, dynamic>) {
          merge(
            target[entry.key] as Map<String, dynamic>,
            entry.value as Map<String, dynamic>,
          );
        } else {
          target[entry.key] = entry.value;
        }
      }
    }

    merge(value, body);
    value['revision'] = (value['revision'] as int) + 1;
    final result = jsonDecode(
      jsonEncode({'businessId': 12345678, 'item': value}),
    ) as Map<String, dynamic>;
    receipts[key] = result;
    if (lose) {
      lose = false;
      throw TimeoutException('reply lost');
    }
    return jsonResponse(result);
  }

  BusinessContext activate() =>
      pimFixture(MockClient(respond), appId: app).context;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var dir = Directory.current;
    while (!File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      if (dir.path == dir.parent.path) throw StateError('Workspace not found');
      dir = dir.parent;
    }
    await (FontLoader('ravi')..addFont(
          File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });
  tearDown(() {
    toastification.dismissAll(delayForAnimation: false);
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app settings partial patch, durable retry, conflict and permission',
      () async {
        final server = SettingsServer(app);
        final context = server.activate();
        final fx = BusinessSettingsFX(context);
        final before = await fx.load();
        final invalid = {
          ...before.editable,
          'inventory.reservation.maxLifetimeMinutes': 5,
        };
        expect(() => before.changes(invalid), throwsFormatException);
        expect(server.writes, isEmpty);
        server.lose = true;
        await expectLater(
          fx.save(before, {
            ...before.editable,
            'accounting.allowCreditSales': true,
          }),
          throwsA(isA<TimeoutException>()),
        );
        expect(fx.hasPending, isTrue);
        final resumed = BusinessSettingsFX(context);
        final newer = await resumed.load();
        expect(newer.revision, 2);
        expect(resumed.hasPending, isTrue);
        final result = await resumed.save(newer, newer.editable);
        expect(result.revision, 2);
        expect(resumed.hasPending, isFalse);
        expect(server.writes[0].body, server.writes[1].body);
        expect(
          server.writes[0].headers['idempotency-key'],
          server.writes[1].headers['idempotency-key'],
        );
        expect(jsonDecode(server.writes[0].body), {
          'expectedRevision': 1,
          'accounting': {'allowCreditSales': true},
        });
        expect(
          (result.json['accounting'] as Map)['invoiceNotificationPatterns'],
          {'SALE_ISSUED': 'pattern'},
        );
        await expectLater(
          resumed.save(before, {
            ...before.editable,
            'tax.taxpayerSystemEnabled': true,
          }),
          throwsA(isA<AuthError>()),
        );
        expect(resumed.hasPending, isFalse);
        server.allowWrite = false;
        final readonly = await resumed.load();
        expect(resumed.canEdit, isFalse);
        final count = server.writes.length;
        await expectLater(
          resumed.save(readonly, {
            ...readonly.editable,
            'accounting.allowCreditSales': false,
          }),
          throwsA(isA<AuthError>()),
        );
        expect(server.writes.length, count);
        server.wrongTenant = true;
        await expectLater(resumed.load(), throwsFormatException);
      },
    );

    testWidgets(
      '$app native settings screen reads silently and confirms save',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = SettingsServer(app)..activate();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              theme: ThemeData(fontFamily: 'ravi'),
              home: BusinessSettingsScreen(appId: app),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('فروش اعتباری'), findsOneWidget);
        expect(find.text('تنظیمات کسب‌وکار با موفقیت ذخیره شد.'), findsNothing);
        final toggle = find.byKey(
          const ValueKey('accounting.allowCreditSales'),
        );
        await tester.tap(
          find.descendant(of: toggle, matching: find.text('فعال')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('ذخیره تنظیمات'));
        await tester.pumpAndSettle();
        expect(server.writes, hasLength(1));
        expect(jsonDecode(server.writes.single.body), {
          'expectedRevision': 1,
          'accounting': {'allowCreditSales': true},
        });
        expect(
          find.text('تنظیمات کسب‌وکار با موفقیت ذخیره شد.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
