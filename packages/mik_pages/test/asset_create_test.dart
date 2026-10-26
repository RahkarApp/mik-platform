import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_pages/assets/create_form.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'fixed_assets_test.dart' show AssetServer;
import 'invoice_payment_test.dart' show fundId, sourceId;

class CreateAssetServer extends AssetServer {
  CreateAssetServer(super.app);
  bool loseAssetReply = false, allowCreate = true, wrongReply = false;
  final assetWrites = <http.Request>[];
  final assetReceipts = <String, Map<String, dynamic>>{};
  int created = 0;
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final row = jsonDecode(response.body) as Map<String, dynamic>;
      (row['permissionCodes'] as List).addAll(
        request.url.queryParameters['scopeType'] == 'BUSINESS'
            ? ['accounting.asset.category.manage', 'accounting.supplier.read']
            : [if (allowCreate) 'accounting.asset.create'],
      );
      return jsonResponse(row);
    }
    if (path.endsWith('/assets/categories') && request.method == 'GET') {
      return jsonResponse({
        'businessId': 12345678,
        'items': [
          {
            'assetCategoryId': sourceId,
            'businessId': 12345678,
            'revision': 1,
            'name': 'تجهیزات',
            'status': 'ACTIVE',
          },
        ],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/suppliers')) {
      return jsonResponse({
        'businessId': 12345678,
        'items': [
          {
            'supplierId': fundId,
            'businessId': 12345678,
            'revision': 1,
            'name': 'تأمین‌کننده نمونه',
            'status': 'ACTIVE',
            'phone': '09121234567',
            'kind': 'PERSON',
          },
        ],
        'nextCursor': null,
      });
    }
    if (request.method == 'POST' && path.contains('/accounting/assets')) {
      assetWrites.add(request);
      expect(request.headers['x-branch-id'], branch);
      expect(request.headers['x-app-id'], app);
      final key = request.headers['idempotency-key']!;
      if (!assetReceipts.containsKey(key)) {
        created++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (path.endsWith('/categories')) {
          assetReceipts[key] = {
            'businessId': 12345678,
            'item': {
              'assetCategoryId': fundId,
              'businessId': 12345678,
              'revision': 1,
              'name': body['name'],
              'status': 'ACTIVE',
            },
          };
        } else {
          final plan = body['depreciation'] as Map;
          assetReceipts[key] = {
            'businessId': 12345678,
            'asset': {
              ...asset(fundId),
              'name': body['name'],
              'assetCategoryId': body['assetCategoryId'],
              'supplierId': body['supplierId'],
              'source': 'PURCHASE',
              'status': body['inServiceOn'] == null ? 'REGISTERED' : 'IN_USE',
              'paidAmount': 0,
              'pendingAmount': 0,
              'paymentStatus': 'UNPAID',
              'liabilityAmount': body['cost'],
              'cost': body['cost'],
              'acquisitionCost': body['cost'],
              'bookValue': body['cost'],
              'depreciationMethod': plan['method'],
              if (plan['usefulLifeMonths'] != null)
                'usefulLifeMonths': plan['usefulLifeMonths'],
              'residualValue': plan['residualValue'] ?? 0,
              'acquiredOn': body['acquiredOn'],
              'inServiceOn': body['inServiceOn'],
              for (final key in [
                'code',
                'note',
                'serialNumber',
                'location',
                'dueOn',
              ])
                if (body.containsKey(key)) key: body[key],
            },
          };
        }
      }
      if (loseAssetReply) {
        loseAssetReply = false;
        throw TimeoutException('Lost response');
      }
      final response = assetReceipts[key]!;
      return jsonResponse(
        wrongReply ? {...response, 'businessId': 87654321} : response,
      );
    }
    return super.respond(request);
  }
}

Map<String, dynamic> purchase() => {
  'source': 'PURCHASE',
  'name': 'رایانه',
  'assetCategoryId': sourceId,
  'supplierId': fundId,
  'cost': 1000,
  'acquiredOn': '2026-10-01',
  'confirmed': true,
  'depreciation': {
    'method': 'STRAIGHT_LINE',
    'usefulLifeMonths': 24,
    'residualValue': 100,
  },
};

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
      '$app create category and recover exact purchase after lost reply',
      () async {
        final server = CreateAssetServer(app);
        final context = await server.prepare();
        final fx = FixedAssetsFX(context);
        expect((await fx.categories()).single.name, 'تجهیزات');
        await fx.send(AssetCommand('category', {'name': 'تجهیزات جدید'}));
        final command = AssetCommand('create', purchase());
        server.loseAssetReply = true;
        await expectLater(fx.send(command), throwsA(isA<TimeoutException>()));
        final resumed = FixedAssetsFX(context);
        final pending = await resumed.restore();
        expect(pending!.body, purchase());
        await resumed.send(pending);
        expect(server.created, 2);
        expect(server.assetWrites[1].body, server.assetWrites[2].body);
        expect(
          server.assetWrites[1].headers['idempotency-key'],
          server.assetWrites[2].headers['idempotency-key'],
        );
        expect(await resumed.restore(), isNull);
      },
    );
    test(
      '$app permission and invalid confirmation preserve an uncertain request',
      () async {
        final server = CreateAssetServer(app);
        final context = await server.prepare();
        final fx = FixedAssetsFX(context);
        server.allowCreate = false;
        await expectLater(
          fx.send(AssetCommand('create', purchase())),
          throwsA(isA<AuthError>()),
        );
        expect(server.assetWrites, isEmpty);
        server.allowCreate = true;
        server.wrongReply = true;
        await expectLater(
          fx.send(AssetCommand('create', purchase())),
          throwsFormatException,
        );
        expect((await fx.restore())?.action, 'create');
        await expectLater(
          fx.send(AssetCommand('category', {'name': 'جدید'})),
          throwsA(isA<AuthError>()),
        );
        expect(server.created, 1);
      },
    );
    testWidgets(
      '$app native purchase form validates and submits unpaid asset',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = CreateAssetServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(home: AssetCreateForm(fx: fx)),
          ),
        );
        await tester.pumpAndSettle();
        Input input(String label) => tester.widget<Input>(
          find.byWidgetPredicate((w) => w is Input && w.name == label),
        );
        input('نام دارایی').controller.text = 'رایانه';
        for (final entry in {
          'دسته‌بندی دارایی': 'تجهیزات',
          'تأمین‌کننده': 'تأمین‌کننده نمونه',
        }.entries) {
          final dropdown = find.byWidgetPredicate(
            (w) => w is Dropdown && w.name == entry.key,
          );
          await tester.ensureVisible(dropdown);
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          await tester.tap(find.text(entry.value).last);
          await tester.pumpAndSettle();
        }
        input('بهای خرید (تومان)').controller.text = '1000';
        input('تاریخ تحصیل').controller.text = '1405/7/9';
        final confirm = tester.widget<MyTab>(
          find.byWidgetPredicate((w) => w is MyTab && w.tab.contains('بله')),
        );
        confirm.callback('بله');
        await tester.scrollUntilVisible(
          find.text('ثبت نهایی'),
          450,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('ثبت نهایی'));
        await tester.pumpAndSettle();
        expect(server.created, 1);
        final body = jsonDecode(server.assetWrites.single.body) as Map;
        expect(body['source'], 'PURCHASE');
        expect(body['confirmed'], true);
        expect(body.containsKey('payments'), isFalse);
        expect(body.containsKey('code'), isFalse);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
