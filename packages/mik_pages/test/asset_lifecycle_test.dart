import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_pages/assets/lifecycle_form.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'asset_create_test.dart' show CreateAssetServer;
import 'invoice_payment_test.dart' show fundId, sourceId;

class LifecycleServer extends CreateAssetServer {
  LifecycleServer(super.app) {
    currentAsset = {
      ...super.asset(fundId),
      'status': 'REGISTERED',
      'inServiceOn': null,
      'depreciationMethod': 'STRAIGHT_LINE',
      'usefulLifeMonths': 24,
      'residualValue': 100,
    };
  }
  late Map<String, dynamic> currentAsset;
  final lifecycleWrites = <http.Request>[];
  final lifecycleReceipts = <String, Map<String, dynamic>>{};
  bool allowLifecycle = true,
      loseLifecycleReply = false,
      wrongLifecycleReply = false;
  @override
  Map<String, dynamic> asset(String id) => {
    ...currentAsset,
    'fixedAssetId': id,
  };
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final row = jsonDecode(response.body) as Map<String, dynamic>;
      if (allowLifecycle ||
          request.url.queryParameters['scopeType'] == 'BUSINESS') {
        (row['permissionCodes'] as List).addAll([
          'accounting.asset.update',
          'accounting.asset.depreciate',
        ]);
      }
      return jsonResponse(row);
    }
    if (path.endsWith('/assets/commission') ||
        path.endsWith('/assets/depreciate')) {
      lifecycleWrites.add(request);
      expect(request.method, 'POST');
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!,
          body = jsonDecode(request.body) as Map<String, dynamic>;
      if (!lifecycleReceipts.containsKey(key)) {
        final commission = path.endsWith('/commission');
        expect(body.keys.toSet(), {
          'fixedAssetId',
          'expectedRevision',
          commission ? 'inServiceOn' : 'throughOn',
          'reason',
        });
        expect(body['fixedAssetId'], fundId);
        expect(body['expectedRevision'], currentAsset['revision']);
        final on = body[commission ? 'inServiceOn' : 'throughOn'] as String;
        final unchanged =
            !commission &&
            on == currentAsset['depreciatedThrough'] &&
            on == currentAsset['financialThrough'];
        const serverAmount = 100;
        final amount = unchanged ? 0 : serverAmount;
        if (!unchanged) {
          currentAsset = {
            ...currentAsset,
            'revision': (currentAsset['revision'] as int) + 1,
            'financialThrough': on,
            'depreciatedThrough': on,
            if (commission) ...{
              'inServiceOn': on,
              'status': 'IN_USE',
            } else ...{
              'bookValue': (currentAsset['bookValue'] as int) - amount,
              'accumulatedDepreciation':
                  (currentAsset['accumulatedDepreciation'] as int) + amount,
            },
          };
        }
        lifecycleReceipts[key] = {
          'businessId': 12345678,
          'asset': {...currentAsset},
          if (!commission) 'amount': amount,
          if (!unchanged)
            'movement': {
              'assetMovementId': sourceId,
              'fixedAssetId': fundId,
              'businessId': 12345678,
              'branchId': branch,
              'number': currentAsset['revision'],
              'kind': commission ? 'COMMISSION' : 'DEPRECIATE',
              'financial': true,
              'reason': body['reason'],
              'effectiveOn': commission
                  ? on
                  : DateTime.parse(on)
                        .subtract(const Duration(days: 1))
                        .toIso8601String()
                        .substring(0, 10),
            },
        };
      }
      if (loseLifecycleReply) {
        loseLifecycleReply = false;
        throw TimeoutException('Lost lifecycle reply');
      }
      final reply = lifecycleReceipts[key]!;
      return jsonResponse(
        wrongLifecycleReply ? {...reply, 'businessId': 87654321} : reply,
      );
    }
    return super.respond(request);
  }
}

AssetCommand operation(String action, RemoteFixedAsset row, String on) =>
    AssetCommand(action, {
      'fixedAssetId': row.id,
      'expectedRevision': row.revision,
      action == 'commission' ? 'inServiceOn' : 'throughOn': on,
      'reason': 'ثبت واقعی عملیات',
    }, before: row.json);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var root = Directory.current;
    while (!File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      if (root.path == root.parent.path) {
        throw StateError('Workspace missing');
      }
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
      '$app commission, server depreciation amount, no-op and chronological guard',
      () async {
        final server = LifecycleServer(app);
        final service = FixedAssetsFX(await server.prepare());
        var row = await service.detail(fundId);
        expect(
          await service.send(operation('commission', row, '2026-10-02')),
          isNull,
        );
        row = await service.detail(fundId);
        expect(row.status, 'IN_USE');
        expect(
          await service.send(operation('depreciate', row, '2026-10-20')),
          100,
        );
        row = await service.detail(fundId);
        expect(row.money('bookValue'), 900);
        expect(row.money('accumulatedDepreciation'), 100);
        expect(
          await service.send(operation('depreciate', row, '2026-10-20')),
          0,
        );
        final count = server.lifecycleWrites.length;
        await expectLater(
          service.send(operation('depreciate', row, '2026-10-19')),
          throwsFormatException,
        );
        expect(server.lifecycleWrites.length, count);
      },
    );
    test(
      '$app exact replay after lost commission response and permission isolation',
      () async {
        final server = LifecycleServer(app);
        final context = await server.prepare();
        final service = FixedAssetsFX(context);
        final row = await service.detail(fundId);
        server.loseLifecycleReply = true;
        await expectLater(
          service.send(operation('commission', row, '2026-10-02')),
          throwsA(isA<TimeoutException>()),
        );
        final resumed = FixedAssetsFX(service.context),
            pending = await service.restore();
        await resumed.send(pending!);
        expect(server.lifecycleWrites[0].body, server.lifecycleWrites[1].body);
        expect(
          server.lifecycleWrites[0].headers['idempotency-key'],
          server.lifecycleWrites[1].headers['idempotency-key'],
        );
        expect(server.currentAsset['revision'], 2);
        final updated = await resumed.detail(fundId);
        server.allowLifecycle = false;
        await expectLater(
          resumed.send(operation('depreciate', updated, '2026-10-20')),
          throwsA(isA<AuthError>()),
        );
        expect(server.lifecycleWrites.length, 2);
        server.allowLifecycle = true;
        server.wrongLifecycleReply = true;
        await expectLater(
          resumed.send(operation('depreciate', updated, '2026-10-20')),
          throwsFormatException,
        );
        expect((await resumed.restore())?.action, 'depreciate');
      },
    );
    testWidgets('$app native lifecycle form posts exact date and reason', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = LifecycleServer(app);
      final service = FixedAssetsFX(await server.prepare());
      final commission = app == 'mik';
      if (!commission) {
        server.currentAsset.addAll({
          'inServiceOn': '2026-10-02',
          'status': 'IN_USE',
        });
      }
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            home: AssetLifecycleForm(
              fx: service,
              assetId: fundId,
              action: commission ? 'commission' : 'depreciate',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final date = tester.widget<Input>(
        find.byWidgetPredicate(
          (w) =>
              w is Input &&
              w.name ==
                  (commission
                      ? 'تاریخ شروع بهره‌برداری'
                      : 'تاریخ پایان انحصاری'),
        ),
      );
      date.controller.text = commission ? '1405/7/10' : '1405/7/28';
      tester
              .widget<Input>(
                find.byWidgetPredicate(
                  (w) => w is Input && w.name == 'دلیل عملیات',
                ),
              )
              .controller
              .text =
          'ثبت واقعی عملیات';
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('asset-lifecycle-save')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('asset-lifecycle-save')));
      await tester.pumpAndSettle();
      expect(server.lifecycleWrites.length, 1);
      final body = jsonDecode(server.lifecycleWrites.single.body) as Map;
      expect(
        body[commission ? 'inServiceOn' : 'throughOn'],
        commission ? '2026-10-02' : '2026-10-20',
      );
      expect(body.containsKey('amount'), isFalse);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
