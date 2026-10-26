import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_pages/assets/repair_form.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'asset_edit_test.dart' show EditAssetServer;
import 'expenses_test.dart' show ExpenseServer, categoryId, payeeId;
import 'invoice_payment_test.dart' show fundId, sourceId;

class RepairServer extends EditAssetServer {
  RepairServer(super.app);
  bool repairAllowed = true,
      capitalAllowed = true,
      loseRepair = false,
      wrongRepair = false;
  final repairRequests = <http.Request>[];
  final repairReceipts = <String, Map<String, dynamic>>{};
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final row = jsonDecode(response.body) as Map<String, dynamic>;
      final business = request.url.queryParameters['scopeType'] == 'BUSINESS';
      (row['permissionCodes'] as List).addAll([
        'accounting.expense.category.read',
        'accounting.service-provider.read',
        if (repairAllowed || business) ...[
          'accounting.asset.maintain',
          'accounting.expense.create',
        ],
        if (capitalAllowed || business) 'accounting.asset.capitalize',
      ]);
      return jsonResponse(row);
    }
    if (path.endsWith('/expenses/payees') ||
        path.endsWith('/expenses/categories')) {
      return ExpenseServer(app).respond(request);
    }
    if (path.endsWith('/assets/repair')) {
      repairRequests.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!,
          body = jsonDecode(request.body) as Map<String, dynamic>;
      if (!repairReceipts.containsKey(key)) {
        expect(body['expectedRevision'], currentAsset['revision']);
        final capital = body['kind'] == 'CAPITALIZE';
        final added = body['amount'] as int;
        currentAsset = {
          ...currentAsset,
          'revision': (currentAsset['revision'] as int) + (capital ? 2 : 1),
          if (body.containsKey('status')) 'status': body['status'],
          if (capital) ...{
            'cost': (currentAsset['cost'] as int) + added,
            'bookValue': (currentAsset['bookValue'] as int) + added - 50,
            'accumulatedDepreciation':
                (currentAsset['accumulatedDepreciation'] as int) + 50,
            'financialThrough': body['occurredOn'],
            'depreciatedThrough': body['occurredOn'],
            if (body.containsKey('remainingLifeMonths'))
              'usefulLifeMonths': body['remainingLifeMonths'],
          },
        };
        repairReceipts[key] = {
          'businessId': 12345678,
          'asset': {...currentAsset},
          'expense': {
            ...ExpenseServer(app).expense,
            'fixedAssetId': fundId,
            if (capital) 'capitalizedAssetId': fundId,
            'amount': added,
            'title': body['title'],
            'occurredAt': '${body['occurredOn']}T00:00:00.000Z',
          },
          'payments': [],
          'movement': {
            'assetMovementId': sourceId,
            'fixedAssetId': fundId,
            'businessId': 12345678,
            'branchId': branch,
            'number': currentAsset['revision'],
            'kind': capital ? 'CAPITALIZE' : 'REPAIR',
            'financial': capital,
            'reason': body['reason'],
            'effectiveOn': body['occurredOn'],
          },
        };
      }
      if (loseRepair) {
        loseRepair = false;
        throw TimeoutException('Lost repair response');
      }
      final result = repairReceipts[key]!;
      return jsonResponse(
        wrongRepair
            ? {
                ...result,
                'expense': {...result['expense'] as Map, 'amount': 999},
              }
            : result,
      );
    }
    return super.respond(request);
  }
}

AssetCommand repair(
  RemoteFixedAsset row, {
  bool capital = false,
}) => AssetCommand('repair', {
  'fixedAssetId': row.id,
  'expectedRevision': row.revision,
  'kind': capital ? 'CAPITALIZE' : 'ROUTINE',
  'amount': 200,
  'title': 'تعمیر نمونه',
  'occurredOn': '2026-10-20',
  'reason': 'ثبت تعمیر',
  'categoryId': categoryId,
  'payeeId': payeeId,
  'status': 'UNDER_REPAIR',
  if (capital) ...{'capitalizationConfirmed': true, 'remainingLifeMonths': 12},
}, before: row.json);

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
      '$app repair and capitalization preserve acquisition and validate separate grants',
      () async {
        final server = RepairServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        final before = await fx.detail(fundId);
        server.repairAllowed = false;
        await expectLater(fx.send(repair(before)), throwsA(isA<AuthError>()));
        expect(server.repairRequests, isEmpty);
        server.repairAllowed = true;
        await fx.send(repair(before));
        final routine = await fx.detail(fundId);
        for (final field in RemoteFixedAsset.amounts.keys) {
          expect(routine.json[field], before.json[field]);
        }
        expect(routine.status, 'UNDER_REPAIR');
        server.capitalAllowed = false;
        await expectLater(
          fx.send(repair(routine, capital: true)),
          throwsA(isA<AuthError>()),
        );
        server.capitalAllowed = true;
        final unconfirmed = repair(routine, capital: true);
        await expectLater(
          fx.send(
            AssetCommand('repair', {
              ...unconfirmed.body,
              'capitalizationConfirmed': false,
            }, before: routine.json),
          ),
          throwsA(isA<FormatException>()),
        );
        await fx.send(repair(routine, capital: true));
        final saved = await fx.detail(fundId);
        expect(saved.money('cost'), routine.money('cost') + 200);
        expect(
          saved.money('acquisitionCost'),
          routine.money('acquisitionCost'),
        );
        expect(saved.money('bookValue'), routine.money('bookValue') + 150);
        expect(saved.json['usefulLifeMonths'], 12);
        expect(fx.context.selectedBranch!.branchId, branch);
      },
    );
    test(
      '$app repair retains invalid and lost responses for exact replay',
      () async {
        final server = RepairServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        final command = repair(await fx.detail(fundId));
        server.wrongRepair = true;
        await expectLater(fx.send(command), throwsA(isA<FormatException>()));
        expect(await fx.restore(), isNotNull);
        server.wrongRepair = false;
        server.loseRepair = true;
        await expectLater(
          fx.send(fx.pending!),
          throwsA(isA<TimeoutException>()),
        );
        await fx.send(fx.pending!);
        expect(server.repairReceipts.length, 1);
        expect(server.repairRequests.map((r) => r.body).toSet().length, 1);
        expect(
          server.repairRequests
              .map((r) => r.headers['idempotency-key'])
              .toSet(),
          {command.key},
        );
        expect(await fx.restore(), isNull);
      },
    );
    testWidgets('$app native repair form submits a linked expense', (
      tester,
    ) async {
      final server = RepairServer(app);
      final fx = FixedAssetsFX(await server.prepare());
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            home: AssetRepairForm(fx: fx, assetId: fundId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Input input(String name) => tester.widget<Input>(
        find.byWidgetPredicate((w) => w is Input && w.name == name),
      );
      input('عنوان تعمیر یا بهسازی').controller.text = 'تعمیر نمونه';
      input('مبلغ هزینه').controller.text = '200';
      input('تاریخ انجام').controller.text = '1405/7/28';
      for (final name in ['دسته‌بندی هزینه', 'سرویس‌دهنده']) {
        final finder = find.byWidgetPredicate(
          (w) => w is Dropdown && w.name == name,
        );
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        final dropdown = tester.widget<Dropdown>(finder);
        dropdown.onChange(dropdown.items_Value!.first);
      }
      await tester.scrollUntilVisible(
        find.byWidgetPredicate((w) => w is Input && w.name == 'دلیل عملیات'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      input('دلیل عملیات').controller.text = 'ثبت تعمیر';
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('asset-repair-save')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('asset-repair-save')));
      await tester.pumpAndSettle();
      expect(server.repairRequests.length, 1);
      expect(jsonDecode(server.repairRequests.single.body)['kind'], 'ROUTINE');
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
