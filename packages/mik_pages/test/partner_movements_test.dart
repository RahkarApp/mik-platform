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
import 'package:mik_data/source/remote/models/partner_movement.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/partner_movements.dart';
import 'package:mik_pages/persons/partner/movements_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_payment_test.dart' show PaymentServer, fundId, bankId, sourceId;

const partnerId = '11111111-1111-4111-8111-111111111119';

class PartnerServer extends PaymentServer {
  PartnerServer(super.app);
  final partnerRow = <String, dynamic>{
    'partnerId': partnerId,
    'businessId': 12345678,
    'revision': 1,
    'name': 'شریک نمونه',
    'status': 'ACTIVE',
    'capitalBalance': 500,
    'currentBalance': 100,
  };
  bool readPartner = true,
      transactPartner = true,
      reversePartner = true,
      overdrawPartner = false,
      lostMovement = false,
      wrongMovement = false,
      splitPages = false;
  final movementRows = <Map<String, dynamic>>[];
  final movementReceipts = <String, Map<String, dynamic>>{};
  final movementRequests = <http.Request>[];
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final business = json['scopeType'] == 'BUSINESS';
      (json['permissionCodes'] as List).addAll([
        if (readPartner || !business) 'accounting.partner.read',
        if (transactPartner || !business) 'accounting.partner.transact',
        if (reversePartner || !business) 'accounting.partner.reverse',
        if (overdrawPartner) 'accounting.partner.overdraw',
      ]);
      return jsonResponse(json);
    }
    if (request.method == 'GET' && path.contains('/capital/partners')) {
      return jsonResponse({
        'businessId': 12345678,
        if (path.endsWith(partnerId))
          'item': {...partnerRow}
        else ...{
          'items': [
            {...partnerRow},
          ],
          'nextCursor': null,
        },
      });
    }
    if (request.method == 'GET' && path.endsWith('/capital/movements')) {
      final after = request.url.queryParameters['after'];
      final filtered = movementRows
          .where(
            (r) =>
                after == null ||
                (r['partnerMovementId'] as String).compareTo(after) > 0,
          )
          .toList();
      return jsonResponse({
        'businessId': 12345678,
        'items': splitPages ? filtered.take(1).toList() : filtered,
        'nextCursor': splitPages && filtered.length > 1
            ? filtered.first['partnerMovementId']
            : null,
      });
    }
    if (request.method == 'POST' && path.contains('/capital/movements')) {
      movementRequests.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final body = jsonDecode(request.body) as Map<String, dynamic>,
          key = request.headers['idempotency-key']!;
      if (!movementReceipts.containsKey(key)) {
        final reverse = path.endsWith('/reverse');
        final original = reverse
            ? movementRows.singleWhere(
                (r) => r['partnerMovementId'] == body['partnerMovementId'],
              )
            : null;
        expect(
          body[reverse ? 'expectedPartnerRevision' : 'expectedRevision'],
          partnerRow['revision'],
        );
        final kind = reverse ? 'REVERSAL' : body['kind'] as String;
        final amount = reverse
            ? original!['amount'] as int
            : body['amount'] as int;
        final incoming = [
          'CAPITAL_IN',
          'CURRENT_IN',
          'NONCASH_CAPITAL_IN',
        ].contains(kind);
        final capitalDelta = reverse
            ? -(original!['capitalDelta'] as int)
            : kind.contains('CAPITAL')
            ? incoming
                  ? amount
                  : -amount
            : 0;
        final currentDelta = reverse
            ? -(original!['currentDelta'] as int)
            : kind.startsWith('CURRENT')
            ? incoming
                  ? amount
                  : -amount
            : 0;
        partnerRow['capitalBalance'] =
            (partnerRow['capitalBalance'] as int) + capitalDelta;
        partnerRow['currentBalance'] =
            (partnerRow['currentBalance'] as int) + currentDelta;
        partnerRow['revision'] = (partnerRow['revision'] as int) + 1;
        final route = reverse ? original!['routing'] : body['routing'];
        final method = reverse ? original!['method'] : body['method'];
        final id =
            '11111111-1111-4111-8111-${(movementRows.length + 1).toString().padLeft(12, '0')}';
        final movement = <String, dynamic>{
          'partnerMovementId': id,
          'partnerId': partnerId,
          'businessId': 12345678,
          'branchId': branch,
          'revision': 1,
          'kind': kind,
          'amount': amount,
          'capitalDelta': capitalDelta,
          'currentDelta': currentDelta,
          'capitalBalance': partnerRow['capitalBalance'],
          'currentBalance': partnerRow['currentBalance'],
          'partnerSnapshot': {'name': partnerRow['name']},
          'occurredAt': reverse
              ? '2026-10-24T00:00:00.000Z'
              : body['occurredAt'],
          'reason': body['reason'],
          'journalId': sourceId,
          if (reverse) 'originalMovementId': original!['partnerMovementId'],
          if (route != null) ...{
            'method': method,
            'routing': {
              'fundId': (route as Map)['fundId'],
              'fundName': 'صندوق نمونه',
              'kind': method == 'CASH' ? 'CASH' : 'BANK',
            },
          } else
            'assetDescription': reverse
                ? original!['assetDescription']
                : body['assetDescription'],
        };
        movementRows.add(movement);
        movementReceipts[key] = {
          'businessId': 12345678,
          'partner': {...partnerRow},
          'movement': {...movement},
        };
      }
      if (lostMovement) {
        lostMovement = false;
        throw TimeoutException('Lost partner reply');
      }
      final result = movementReceipts[key]!;
      return jsonResponse(
        wrongMovement
            ? {
                ...result,
                'partner': {
                  ...result['partner'] as Map,
                  'capitalBalance': 999999,
                },
              }
            : result,
      );
    }
    return super.respond(request);
  }
}

PartnerMovementCommand createCommand(
  PartnerMovementsFX fx,
  RemoteSupplier before, {
  String kind = 'CAPITAL_IN',
  int amount = 50,
  String method = 'CASH',
  bool debit = false,
}) => PartnerMovementCommand('create', {
  'partnerId': before.id,
  'expectedRevision': before.revision,
  'kind': kind,
  'amount': amount,
  'occurredAt': '2026-10-20T00:00:00.000Z',
  'reason': 'ثبت واقعی',
  'fundsConfirmed': true,
  if (debit) 'allowDebitBalance': true,
  if (kind == 'NONCASH_CAPITAL_IN') ...{
    'assetDescription': 'تجهیزات',
    'valuationConfirmed': true,
  } else ...{
    'method': method,
    'routing': {'fundId': method == 'CASH' ? fundId : bankId},
  },
}, before: fx.snapshot(before));
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
      '$app all movement types, balances, bank/cash routes and reversal',
      () async {
        final server = PartnerServer(app);
        final fx = PartnerMovementsFX(await server.prepare());
        await fx.authorize();
        expect((await fx.targets('CASH')).single.id, fundId);
        expect((await fx.targets('BANK_TRANSFER')).single.id, bankId);
        for (final kind in partnerMovementKinds.keys.where(
          (k) => k != 'REVERSAL',
        )) {
          final before = await fx.partner(partnerId);
          await fx.send(
            createCommand(fx, before, kind: kind, method: 'BANK_TRANSFER'),
          );
        }
        server.splitPages = true;
        final rows = await fx.movements(partnerId: partnerId);
        expect(rows.length, 5);
        expect((await fx.partner(partnerId)).capitalBalance, 550);
        expect((await fx.partner(partnerId)).currentBalance, 100);
        final before = await fx.partner(partnerId), original = rows.first;
        await fx.send(
          PartnerMovementCommand(
            'reverse',
            {
              'partnerMovementId': original.id,
              'expectedPartnerRevision': before.revision,
              'reason': 'برگشت واقعی',
              'fundsConfirmed': true,
            },
            before: fx.snapshot(before),
            original: original.json,
          ),
        );
        expect((await fx.partner(partnerId)).capitalBalance, 500);
        expect((await fx.movements()).last.kind, 'REVERSAL');
      },
    );
    test(
      '$app business grants, overdraw confirmation and exact replay',
      () async {
        final server = PartnerServer(app);
        final fx = PartnerMovementsFX(await server.prepare());
        server.readPartner = false;
        await expectLater(fx.authorize(), throwsA(isA<AuthError>()));
        server.readPartner = true;
        await fx.authorize();
        var before = await fx.partner(partnerId);
        server.transactPartner = false;
        await expectLater(
          fx.send(createCommand(fx, before)),
          throwsA(isA<AuthError>()),
        );
        server.transactPartner = true;
        await expectLater(
          fx.send(createCommand(fx, before, kind: 'CAPITAL_OUT', amount: 600)),
          throwsA(isA<AuthError>()),
        );
        await expectLater(
          fx.send(createCommand(fx, before, kind: 'CURRENT_OUT', amount: 200)),
          throwsA(isA<AuthError>()),
        );
        server.overdrawPartner = true;
        await expectLater(
          fx.send(createCommand(fx, before, kind: 'CURRENT_OUT', amount: 200)),
          throwsA(isA<AuthError>()),
        );
        expect(server.movementRequests, isEmpty);
        final command = createCommand(
          fx,
          before,
          kind: 'CURRENT_OUT',
          amount: 200,
          debit: true,
        );
        server.wrongMovement = true;
        await expectLater(fx.send(command), throwsA(isA<FormatException>()));
        server.wrongMovement = false;
        server.lostMovement = true;
        await fx.restore();
        await expectLater(
          fx.send(fx.pending!),
          throwsA(isA<TimeoutException>()),
        );
        await fx.send(fx.pending!);
        expect(server.movementReceipts.length, 1);
        expect(server.movementRequests.map((r) => r.body).toSet().length, 1);
        expect(
          server.movementRequests
              .map((r) => r.headers['idempotency-key'])
              .toSet(),
          {command.key},
        );
        before = await fx.partner(partnerId);
        expect(before.currentBalance, -100);
        expect(await fx.restore(), isNull);
      },
    );
    testWidgets('$app native movement form confirms actual transfer', (
      tester,
    ) async {
      final server = PartnerServer(app);
      final fx = PartnerMovementsFX(await server.prepare());
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            home: PartnerMovementForm(fx: fx, partnerId: partnerId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Input input(String name) => tester.widget<Input>(
        find.byWidgetPredicate((w) => w is Input && w.name == name),
      );
      input('مبلغ').controller.text = '50';
      input('تاریخ تراکنش').controller.text = '1405/7/28';
      final scroll = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;
      final fundFinder = find.byWidgetPredicate(
        (w) => w is Dropdown && w.name == 'صندوق یا حساب',
      );
      await tester.scrollUntilVisible(fundFinder, 200, scrollable: scroll);
      final dropdown = tester.widget<Dropdown>(fundFinder);
      dropdown.onChange(dropdown.items_Value!.single);
      await tester.scrollUntilVisible(
        find.byWidgetPredicate((w) => w is Input && w.name == 'دلیل تراکنش'),
        200,
        scrollable: scroll,
      );
      input('دلیل تراکنش').controller.text = 'آورده واقعی';
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('partner-movement-save')),
        200,
        scrollable: scroll,
      );
      await tester.tap(find.byKey(const ValueKey('partner-movement-save')));
      await tester.pumpAndSettle();
      expect(server.movementRequests.length, 1);
      expect(
        jsonDecode(server.movementRequests.single.body)['fundsConfirmed'],
        true,
      );
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
