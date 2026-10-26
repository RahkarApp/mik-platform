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
import 'package:mik_pages/assets/edit_form.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'asset_edit_test.dart' show EditAssetServer;
import 'invoice_payment_test.dart' show fundId, bankId, sourceId;

class CustodyServer extends EditAssetServer {
  CustodyServer(super.app);
  bool allowCustody = true,
      allowPersonnel = true,
      loseReply = false,
      wrongCustodyReply = false;
  final custodyWrites = <http.Request>[];
  final custodyReceipts = <String, Map<String, dynamic>>{};
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final row = jsonDecode(response.body) as Map<String, dynamic>;
      final codes = row['permissionCodes'] as List;
      if (row['scopeType'] == 'BUSINESS') {
        // A business grant must not authorize a branch mutation.
        codes.add('accounting.asset.custody');
        if (allowPersonnel) codes.add('business.personnel.read');
      } else if (allowCustody) {
        codes.add('accounting.asset.custody');
      }
      return jsonResponse(row);
    }
    if (path.endsWith('/personnel')) {
      return jsonResponse({
        'items': [
          for (final active in [true, false])
            {
              'personnelId': active ? bankId : sourceId,
              'membershipId': active ? bankId : sourceId,
              'businessId': 12345678,
              'revision': 1,
              'displayName': active ? 'پرسنل فعال' : 'پرسنل تعلیق‌شده',
              'employmentStatus': active ? 'ACTIVE' : 'SUSPENDED',
              'startedAt': '2026-01-01T00:00:00.000Z',
            },
        ],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/assets/custody')) {
      custodyWrites.add(request);
      expect(request.method, 'POST');
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(
        body.keys.toSet().difference({
          'fixedAssetId',
          'expectedRevision',
          'custodianMembershipId',
          'location',
          'reason',
        }),
        isEmpty,
      );
      if (!custodyReceipts.containsKey(key)) {
        expect(body['fixedAssetId'], fundId);
        expect(body['expectedRevision'], currentAsset['revision']);
        currentAsset = {
          ...currentAsset,
          'custodian': body['custodianMembershipId'] == null
              ? null
              : {
                  'membershipId': body['custodianMembershipId'],
                  'personnelId': bankId,
                  'displayName': 'پرسنل فعال',
                },
          if (body.containsKey('location')) 'location': body['location'],
          'revision': (currentAsset['revision'] as int) + 1,
        };
        custodyReceipts[key] = {
          'businessId': 12345678,
          'asset': {...currentAsset},
          'movement': {
            'assetMovementId': sourceId,
            'fixedAssetId': fundId,
            'businessId': 12345678,
            'branchId': branch,
            'number': currentAsset['revision'],
            'kind': 'CUSTODY',
            'financial': false,
            'reason': body['reason'],
            'effectiveOn': '2026-10-24',
          },
        };
      }
      if (loseReply) {
        loseReply = false;
        throw TimeoutException('Lost custody reply');
      }
      final result = custodyReceipts[key]!;
      return jsonResponse(
        wrongCustodyReply
            ? {
                ...result,
                'asset': {...result['asset'] as Map, 'custodian': null},
              }
            : result,
      );
    }
    return super.respond(request);
  }
}

AssetCommand custody(
  RemoteFixedAsset row,
  String? member, {
  String? location,
}) => AssetCommand('custody', {
  'fixedAssetId': row.id,
  'expectedRevision': row.revision,
  'custodianMembershipId': member,
  'location': ?location,
  'reason': 'تحویل دارایی',
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
      '$app custody requires branch grant and preserves all financial values',
      () async {
        final server = CustodyServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        final before = await fx.detail(fundId);
        server.allowCustody = false;
        await expectLater(
          fx.send(custody(before, bankId)),
          throwsA(isA<AuthError>()),
        );
        expect(server.custodyWrites, isEmpty);
        server.allowCustody = true;
        await fx.send(custody(before, bankId, location: 'دفتر شعبه'));
        var saved = await fx.detail(fundId);
        expect((saved.json['custodian'] as Map)['membershipId'], bankId);
        expect(saved.json['location'], 'دفتر شعبه');
        for (final key in RemoteFixedAsset.amounts.keys) {
          expect(saved.json[key], before.json[key]);
        }
        expect(saved.json['financialThrough'], before.json['financialThrough']);
        await fx.send(custody(saved, null));
        saved = await fx.detail(fundId);
        expect(saved.json['custodian'], isNull);
        expect(saved.json['location'], 'دفتر شعبه');
        expect(fx.context.selectedBranch!.branchId, branch);
      },
    );
    test(
      '$app custody retains uncertain result and replays exact command',
      () async {
        final server = CustodyServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        final command = custody(await fx.detail(fundId), bankId);
        server.wrongCustodyReply = true;
        await expectLater(fx.send(command), throwsA(isA<FormatException>()));
        expect(await fx.restore(), isNotNull);
        server.wrongCustodyReply = false;
        server.loseReply = true;
        await expectLater(
          fx.send(fx.pending!),
          throwsA(isA<TimeoutException>()),
        );
        await fx.send(fx.pending!);
        expect(server.custodyReceipts.length, 1);
        expect(
          server.custodyWrites.map((r) => r.headers['idempotency-key']).toSet(),
          {command.key},
        );
        expect(server.custodyWrites.map((r) => r.body).toSet().length, 1);
        expect(await fx.restore(), isNull);
      },
    );
    testWidgets(
      '$app custody uses native dropdown with active personnel and clear option',
      (tester) async {
        final server = CustodyServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              home: AssetEditForm(fx: fx, assetId: fundId, custody: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final dropdown = tester.widget<Dropdown>(
          find.byWidgetPredicate(
            (w) => w is Dropdown && w.name == 'تحویل‌گیرنده',
          ),
        );
        expect(dropdown.items_Value!.any((i) => i.data == sourceId), isFalse);
        expect(dropdown.items_Value!.any((i) => i.data == null), isTrue);
        dropdown.onChange(
          dropdown.items_Value!.firstWhere((i) => i.data == bankId),
        );
        await tester.pump();
        tester
                .widget<Input>(
                  find.byWidgetPredicate(
                    (w) => w is Input && w.name == 'دلیل عملیات',
                  ),
                )
                .controller
                .text =
            'تحویل به پرسنل';
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('asset-edit-save')),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.byKey(const ValueKey('asset-edit-save')));
        await tester.pumpAndSettle();
        expect(server.custodyWrites.length, 1);
        final body = jsonDecode(server.custodyWrites.single.body) as Map;
        expect(body['custodianMembershipId'], bankId);
        expect(body.containsKey('location'), isFalse);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
