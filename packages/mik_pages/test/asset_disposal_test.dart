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
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_pages/assets/disposal_form.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'asset_edit_test.dart' show EditAssetServer;
import 'invoice_payment_test.dart' show fundId, bankId, sourceId;

class DisposalServer extends EditAssetServer {
  DisposalServer(super.app) {
    currentAsset.addAll({
      'paidAmount': 700,
      'liabilityAmount': 300,
      'paymentStatus': 'PARTIALLY_PAID',
    });
  }
  bool disposeAllowed = true,
      bankAllowed = true,
      lostDisposal = false,
      invalidDisposal = false;
  final disposalRequests = <http.Request>[];
  final disposalReceipts = <String, Map<String, dynamic>>{};
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final row = jsonDecode(response.body) as Map<String, dynamic>;
      final codes = row['permissionCodes'] as List;
      if (disposeAllowed || row['scopeType'] == 'BUSINESS') {
        codes.add('accounting.asset.dispose');
      }
      if (!bankAllowed) codes.remove('accounting.bank.use');
      return jsonResponse(row);
    }
    if (path.endsWith('/assets/dispose')) {
      disposalRequests.add(request);
      expect(request.method, 'POST');
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!,
          body = jsonDecode(request.body) as Map<String, dynamic>;
      if (!disposalReceipts.containsKey(key)) {
        expect(body['confirmed'], true);
        expect(body['expectedRevision'], currentAsset['revision']);
        final received = body['proceeds'] as int? ?? 0;
        final accumulated =
            (currentAsset['accumulatedDepreciation'] as int) + 50;
        final gain = received - ((currentAsset['cost'] as int) - accumulated);
        currentAsset = {
          ...currentAsset,
          'revision': (currentAsset['revision'] as int) + 2,
          'status': {
            'SALE': 'SOLD',
            'SCRAP': 'SCRAPPED',
            'LOSS': 'LOST',
          }[body['kind']],
          'bookValue': 0,
          'custodian': null,
          'accumulatedDepreciation': accumulated,
          'financialThrough': body['effectiveOn'],
          'depreciatedThrough': body['effectiveOn'],
        };
        final receipt = body['receipt'] as Map?;
        final route = receipt?['routing'] as Map?;
        disposalReceipts[key] = {
          'businessId': 12345678,
          'asset': {...currentAsset},
          'movement': {
            'assetMovementId': sourceId,
            'fixedAssetId': fundId,
            'businessId': 12345678,
            'branchId': branch,
            'number': currentAsset['revision'],
            'kind': 'DISPOSE',
            'financial': true,
            'reason': body['reason'],
            'effectiveOn': body['effectiveOn'],
            'details': {
              'proceeds': received,
              'gain': gain,
              if (body.containsKey('buyerName')) 'buyerName': body['buyerName'],
              if (receipt != null)
                'receipt': {
                  'method': receipt['method'],
                  'routing': {
                    'fundId': route!['fundId'],
                    'fundName': 'مقصد نمونه',
                    'kind': receipt['method'] == 'CASH' ? 'CASH' : 'BANK',
                  },
                  if (receipt.containsKey('transactionReference'))
                    'transactionReference': receipt['transactionReference'],
                },
            },
          },
        };
      }
      if (lostDisposal) {
        lostDisposal = false;
        throw TimeoutException('Lost disposal reply');
      }
      final result = disposalReceipts[key]!;
      return jsonResponse(
        invalidDisposal
            ? {
                ...result,
                'asset': {...result['asset'] as Map, 'liabilityAmount': 0},
              }
            : result,
      );
    }
    return super.respond(request);
  }
}

AssetCommand disposeCommand(
  RemoteFixedAsset row, {
  String kind = 'SALE',
  String method = 'CASH',
  int proceeds = 1200,
}) => AssetCommand('dispose', {
  'fixedAssetId': row.id,
  'expectedRevision': row.revision,
  'kind': kind,
  'effectiveOn': '2026-10-20',
  'reason': 'خروج واقعی دارایی',
  'confirmed': true,
  if (kind == 'SALE') ...{
    'proceeds': proceeds,
    'buyerName': 'خریدار نمونه',
    if (proceeds > 0)
      'receipt': {
        'method': method,
        'routing': {'fundId': method == 'CASH' ? fundId : bankId},
        'confirmed': true,
        'transactionReference': 'REF-1',
      },
  },
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
      '$app sale cash/bank, zero proceeds, scrap and loss preserve supplier debt',
      () async {
        for (final scenario in [
          'CASH',
          'BANK_TRANSFER',
          'ZERO',
          'SCRAP',
          'LOSS',
        ]) {
          final server = DisposalServer(app);
          final fx = FixedAssetsFX(await server.prepare());
          final row = await fx.detail(fundId);
          final sale = ['CASH', 'BANK_TRANSFER', 'ZERO'].contains(scenario);
          final command = disposeCommand(
            row,
            kind: sale ? 'SALE' : scenario,
            method: scenario == 'BANK_TRANSFER' ? scenario : 'CASH',
            proceeds: scenario == 'ZERO' ? 0 : 1200,
          );
          if (sale) {
            expect(
              (await fx.disposalTargets(
                scenario == 'BANK_TRANSFER' ? scenario : 'CASH',
              )).single.id,
              scenario == 'BANK_TRANSFER' ? bankId : fundId,
            );
          }
          final gain = await fx.send(command);
          expect(gain, (sale && scenario != 'ZERO' ? 1200 : 0) - 950);
          final saved = await fx.detail(fundId);
          expect(
            saved.status,
            sale
                ? 'SOLD'
                : scenario == 'SCRAP'
                ? 'SCRAPPED'
                : 'LOST',
          );
          expect(saved.money('bookValue'), 0);
          expect(saved.money('liabilityAmount'), 300);
          expect(saved.json['paymentStatus'], 'PARTIALLY_PAID');
          expect(fx.canOperate('dispose', saved), isFalse);
          expect(fx.context.selectedBranch!.branchId, branch);
        }
      },
    );
    test(
      '$app disposal guards and uncertain replay retain a single financial command',
      () async {
        final server = DisposalServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        var row = await fx.detail(fundId);
        server.disposeAllowed = false;
        await expectLater(
          fx.send(disposeCommand(row)),
          throwsA(isA<AuthError>()),
        );
        server.disposeAllowed = true;
        server.bankAllowed = false;
        await expectLater(
          fx.send(disposeCommand(row, method: 'BANK_TRANSFER')),
          throwsA(isA<AuthError>()),
        );
        server.bankAllowed = true;
        server.currentAsset['pendingAmount'] = 100;
        row = await fx.detail(fundId);
        await expectLater(
          fx.send(disposeCommand(row)),
          throwsA(isA<AuthError>()),
        );
        server.currentAsset['pendingAmount'] = 0;
        row = await fx.detail(fundId);
        final command = disposeCommand(row);
        await expectLater(
          fx.send(
            AssetCommand('dispose', {
              ...command.body,
              'confirmed': false,
            }, before: row.json),
          ),
          throwsA(isA<FormatException>()),
        );
        final receipt = command.body['receipt'] as Map;
        await expectLater(
          fx.send(
            AssetCommand('dispose', {
              ...command.body,
              'receipt': {...receipt, 'confirmed': false},
            }, before: row.json),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(server.disposalRequests, isEmpty);
        server.invalidDisposal = true;
        await expectLater(fx.send(command), throwsA(isA<FormatException>()));
        expect(await fx.restore(), isNotNull);
        server.invalidDisposal = false;
        server.lostDisposal = true;
        await expectLater(
          fx.send(fx.pending!),
          throwsA(isA<TimeoutException>()),
        );
        await fx.send(fx.pending!);
        expect(server.disposalReceipts.length, 1);
        expect(server.disposalRequests.map((r) => r.body).toSet().length, 1);
        expect(
          server.disposalRequests
              .map((r) => r.headers['idempotency-key'])
              .toSet(),
          {command.key},
        );
        expect(await fx.restore(), isNull);
      },
    );
    testWidgets(
      '$app native disposal form submits confirmed sale or scrapping',
      (tester) async {
        final server = DisposalServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              home: AssetDisposalForm(fx: fx, assetId: fundId),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (app == 'mikyar') {
          tester
              .widget<MyTab>(
                find.byWidgetPredicate(
                  (w) => w is MyTab && w.tab.contains('اسقاط'),
                ),
              )
              .callback('اسقاط');
          await tester.pumpAndSettle();
        }
        Input input(String name) => tester.widget<Input>(
          find.byWidgetPredicate((w) => w is Input && w.name == name),
        );
        await tester.scrollUntilVisible(
          find.byWidgetPredicate((w) => w is Input && w.name == 'تاریخ خروج'),
          200,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        input('تاریخ خروج').controller.text = '1405/7/28';
        if (app == 'mik') {
          input('مبلغ واقعی فروش').controller.text = '1200';
          final target = find.byWidgetPredicate(
            (w) => w is Dropdown && w.name == 'مقصد دریافت وجه',
          );
          await tester.scrollUntilVisible(
            target,
            200,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .first,
          );
          final dropdown = tester.widget<Dropdown>(target);
          dropdown.onChange(dropdown.items_Value!.single);
          await tester.scrollUntilVisible(
            find.text('کل مبلغ فروش را دریافت کرده‌ام.'),
            200,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .first,
          );
          tester
              .widget<MyTab>(
                find
                    .byWidgetPredicate(
                      (w) => w is MyTab && w.tab.contains('بله'),
                    )
                    .first,
              )
              .callback('بله');
          await tester.pump();
        }
        await tester.scrollUntilVisible(
          find.byWidgetPredicate((w) => w is Input && w.name == 'دلیل خروج'),
          200,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        tester
            .widget<MyTab>(
              find
                  .byWidgetPredicate((w) => w is MyTab && w.tab.contains('بله'))
                  .last,
            )
            .callback('بله');
        await tester.pump();
        input('دلیل خروج').controller.text = 'خروج واقعی';
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('asset-dispose-save')),
          200,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await tester.tap(find.byKey(const ValueKey('asset-dispose-save')));
        await tester.pumpAndSettle();
        expect(server.disposalRequests.length, 1);
        final body = jsonDecode(server.disposalRequests.single.body) as Map;
        expect(body['kind'], app == 'mik' ? 'SALE' : 'SCRAP');
        expect(body['confirmed'], true);
        expect(body.containsKey('receipt'), app == 'mik');
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
