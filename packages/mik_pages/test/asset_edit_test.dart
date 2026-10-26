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
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_pages/assets/edit_form.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'asset_lifecycle_test.dart' show LifecycleServer;
import 'invoice_payment_test.dart' show fundId, bankId, sourceId;

class EditAssetServer extends LifecycleServer {
  EditAssetServer(super.app) {
    currentAsset.addAll({
      'status': 'IN_USE',
      'inServiceOn': '2026-10-02',
      'financialThrough': '2026-10-02',
      'depreciatedThrough': '2026-10-02',
      'paidAmount': 1000,
      'pendingAmount': 0,
      'liabilityAmount': 0,
      'paymentStatus': 'PAID',
      'location': 'محل قبلی',
      'warrantyUntil': '2027-01-01',
      'dueOn': '2026-11-01',
    });
  }
  bool includeDestinations = false,
      destinationAllowed = true,
      sourceAllowed = true;
  bool loseEditReply = false, wrongEditReply = false;
  final editWrites = <http.Request>[];
  final editReceipts = <String, Map<String, dynamic>>{};
  @override
  Future<BusinessContext> prepare() async {
    final context = await super.prepare();
    includeDestinations = true;
    return context;
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/branches')) {
      final origin = fixtureResult()['branch'] as Map<String, dynamic>;
      return jsonResponse({
        'items': [
          origin,
          if (includeDestinations) ...[
            {...origin, 'branchId': bankId, 'name': 'شعبه مقصد'},
            {
              ...origin,
              'branchId': sourceId,
              'name': 'آرشیو',
              'status': 'ARCHIVED',
            },
          ],
        ],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final row = jsonDecode(response.body) as Map<String, dynamic>;
      final destination = request.url.queryParameters['scopeId'] == bankId;
      if (destination) row['scopeId'] = bankId;
      if ((destination ? destinationAllowed : sourceAllowed) ||
          row['scopeType'] == 'BUSINESS') {
        (row['permissionCodes'] as List).add('accounting.asset.transfer');
      }
      return jsonResponse(row);
    }
    if (path.endsWith('/assets/update') || path.endsWith('/assets/transfer')) {
      editWrites.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!,
          body = jsonDecode(request.body) as Map<String, dynamic>;
      if (!editReceipts.containsKey(key)) {
        expect(body['fixedAssetId'], fundId);
        expect(body['expectedRevision'], currentAsset['revision']);
        final transfer = path.endsWith('/transfer');
        if (transfer) {
          expect(body['toBranchId'], bankId);
          expect(
            body.keys.toSet().difference({
              'fixedAssetId',
              'expectedRevision',
              'reason',
              'toBranchId',
              'effectiveOn',
              'location',
            }),
            isEmpty,
          );
          currentAsset = {
            ...currentAsset,
            'branchId': bankId,
            'custodian': null,
            'location': body['location'],
            'bookValue': (currentAsset['bookValue'] as int) - 50,
            'accumulatedDepreciation':
                (currentAsset['accumulatedDepreciation'] as int) + 50,
            'financialThrough': body['effectiveOn'],
            'depreciatedThrough': body['effectiveOn'],
            'revision': (currentAsset['revision'] as int) + 2,
          };
        } else {
          currentAsset = {
            ...currentAsset,
            for (final field in [
              'name',
              'code',
              'serialNumber',
              'location',
              'note',
              'assetCategoryId',
              'warrantyUntil',
              'dueOn',
            ])
              if (body.containsKey(field)) field: body[field],
            'revision': (currentAsset['revision'] as int) + 1,
          };
        }
        editReceipts[key] = {
          'businessId': 12345678,
          'asset': {...currentAsset},
          'movement': {
            'assetMovementId': sourceId,
            'fixedAssetId': fundId,
            'businessId': 12345678,
            'branchId': branch,
            if (transfer) 'toBranchId': bankId,
            'number': currentAsset['revision'],
            'kind': transfer ? 'TRANSFER' : 'UPDATE',
            'financial': transfer,
            'reason': body['reason'],
            'effectiveOn': transfer ? body['effectiveOn'] : '2026-10-24',
          },
        };
      }
      if (loseEditReply) {
        loseEditReply = false;
        throw TimeoutException('Lost edit reply');
      }
      final response = editReceipts[key]!;
      return jsonResponse(
        wrongEditReply
            ? {
                ...response,
                'asset': {...response['asset'] as Map, 'branchId': sourceId},
              }
            : response,
      );
    }
    return super.respond(request);
  }
}

AssetCommand transfer(RemoteFixedAsset row) => AssetCommand('transfer', {
  'fixedAssetId': row.id,
  'expectedRevision': row.revision,
  'toBranchId': bankId,
  'effectiveOn': '2026-10-20',
  'reason': 'انتقال واقعی',
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
      '$app metadata preserves money and branch picker preserves selection',
      () async {
        final server = EditAssetServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        final row = await fx.detail(fundId);
        await fx.send(
          AssetCommand('update', {
            'fixedAssetId': row.id,
            'expectedRevision': row.revision,
            'reason': 'اصلاح مشخصات',
            'name': 'نام جدید',
            'warrantyUntil': null,
            'dueOn': null,
          }, before: row.json),
        );
        final updated = await fx.detail(fundId);
        expect(updated.name, 'نام جدید');
        expect(updated.money('bookValue'), row.money('bookValue'));
        expect(updated.json['warrantyUntil'], isNull);
        expect(updated.json['dueOn'], isNull);
        expect((await fx.transferBranches()).map((b) => b.branchId), [bankId]);
        expect(fx.context.selectedBranch!.branchId, branch);
      },
    );
    test(
      '$app both branch grants, unsettled guard and exact transfer replay',
      () async {
        final server = EditAssetServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        final row = await fx.detail(fundId);
        server.destinationAllowed = false;
        await expectLater(fx.send(transfer(row)), throwsA(isA<AuthError>()));
        expect(server.editWrites, isEmpty);
        server.destinationAllowed = true;
        server.sourceAllowed = false;
        await expectLater(fx.send(transfer(row)), throwsA(isA<AuthError>()));
        expect(server.editWrites, isEmpty);
        server.sourceAllowed = true;
        final unsettled = RemoteFixedAsset({
          ...row.json,
          'liabilityAmount': 10,
        });
        await expectLater(
          fx.send(transfer(unsettled)),
          throwsA(isA<AuthError>()),
        );
        expect(server.editWrites, isEmpty);
        server.loseEditReply = true;
        await expectLater(
          fx.send(transfer(row)),
          throwsA(isA<TimeoutException>()),
        );
        final resumed = FixedAssetsFX(fx.context), pending = await fx.restore();
        await resumed.send(pending!);
        expect(server.editReceipts.length, 1);
        expect(server.editWrites[0].body, server.editWrites[1].body);
        expect(
          server.editWrites[0].headers['idempotency-key'],
          server.editWrites[1].headers['idempotency-key'],
        );
        expect(server.currentAsset['branchId'], bankId);
        expect(server.currentAsset['location'], isNull);
        expect(fx.context.selectedBranch!.branchId, branch);
        expect(await resumed.restore(), isNull);
      },
    );
    testWidgets('$app native editing and transfer form submit backend fields', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = EditAssetServer(app);
      final fx = FixedAssetsFX(await server.prepare());
      final moving = app == 'mikyar';
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            home: AssetEditForm(fx: fx, assetId: fundId, transfer: moving),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (moving) {
        tester
            .widget<Dropdown>(
              find.byWidgetPredicate(
                (w) => w is Dropdown && w.name == 'شعبه مقصد',
              ),
            )
            .onChange(const ItemValue(text: 'مقصد', data: bankId));
        tester
                .widget<Input>(
                  find.byWidgetPredicate(
                    (w) => w is Input && w.name == 'تاریخ مؤثر انتقال',
                  ),
                )
                .controller
                .text =
            '1405/7/28';
      } else {
        tester
                .widget<Input>(
                  find.byWidgetPredicate(
                    (w) => w is Input && w.name == 'نام دارایی',
                  ),
                )
                .controller
                .text =
            'نام جدید';
      }
      await tester.scrollUntilVisible(
        find.byWidgetPredicate((w) => w is Input && w.name == 'دلیل عملیات'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      tester
              .widget<Input>(
                find.byWidgetPredicate(
                  (w) => w is Input && w.name == 'دلیل عملیات',
                ),
              )
              .controller
              .text =
          'ثبت واقعی تغییر';
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('asset-edit-save')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('asset-edit-save')));
      await tester.pumpAndSettle();
      expect(server.editWrites.length, 1);
      final body = jsonDecode(server.editWrites.single.body) as Map;
      expect(body['fixedAssetId'], fundId);
      expect(body.containsKey('amount'), isFalse);
      expect(fx.context.selectedBranch!.branchId, branch);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
