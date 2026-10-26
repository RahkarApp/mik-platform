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
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/remote_cheque.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/remote_cheques.dart';
import 'package:mik_pages/cheque/remote_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_payment_test.dart' as previous;
import 'invoice_read_test.dart' show partyId;

const chequeId = '11111111-1111-4111-8111-111111111117';

class ChequeServer extends previous.PaymentServer {
  ChequeServer(super.app, {super.type});
  bool write = true, clear = true, duplicate = false, wrong = false;
  final cheques = <Map<String, dynamic>>[];
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final reply = await super.respond(request);
      final json = jsonDecode(reply.body) as Map<String, dynamic>;
      final business = request.url.queryParameters['scopeType'] == 'BUSINESS';
      (json['permissionCodes'] as List).addAll(
        business
            ? ['accounting.cheque.read']
            : [
                if (clear) 'accounting.cheque.clear',
                if (write) ...[
                  'accounting.sale.cheque.receive',
                  'accounting.purchase.cheque.pay',
                ],
              ],
      );
      return jsonResponse(json);
    }
    if (request.method == 'GET' && path.contains('/cheques')) {
      requests.add(request);
      expect(request.headers['x-branch-id'], branch);
      if (path.endsWith('/cheques')) {
        return jsonResponse({
          'businessId': 12345678,
          'items': cheques,
          'nextCursor': null,
        });
      }
      return jsonResponse({
        'businessId': 12345678,
        'item': {...cheques.single, if (wrong) 'businessId': 87654321},
      });
    }
    if (request.method == 'GET' && path.contains('/v2/payments/')) {
      requests.add(request);
      return jsonResponse({'businessId': 12345678, 'item': paymentRows.single});
    }
    if (request.method == 'POST') {
      requests.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!;
      if (receipts.containsKey(key)) return jsonResponse(receipts[key]!);
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      late Map<String, dynamic> result;
      if (path.endsWith('/v2/payments')) {
        final payment = data['payment'] as Map<String, dynamic>;
        expect(payment['method'], 'CHEQUE');
        expect(payment['direction'], direction);
        if (duplicate) {
          return jsonResponse({
            'error': {'code': 'DUPLICATE_RECORD'},
          }, 409);
        }
        final details = payment['cheque'] as Map<String, dynamic>;
        final cheque = <String, dynamic>{
          'businessId': 12345678,
          'branchId': branch,
          'partyId': partyId,
          'partyType': partyType,
          'chequeId': chequeId,
          'paymentId': previous.paymentId,
          'amount': payment['amount'],
          'direction': direction,
          'status': 'PENDING',
          'revision': 1,
          ...details,
        };
        cheques.add(cheque);
        final row =
            <String, dynamic>{
                ...payment,
                'businessId': 12345678,
                'branchId': branch,
                'partyId': partyId,
                'partyType': partyType,
                'paymentId': previous.paymentId,
                'chequeId': chequeId,
                'status': 'PENDING',
                'purpose': 'SETTLEMENT',
                'financialVersion': 2,
                'revision': 1,
              }
              ..remove('confirmed')
              ..remove('cheque');
        paymentRows.add(row);
        result = {'businessId': 12345678, 'payment': row};
      } else {
        expect(path.endsWith('/v2/cheques/status'), true);
        expect(data.containsKey('routing'), false);
        expect(data['confirmed'], true);
        final row = cheques.single;
        if (row['revision'] != data['expectedRevision']) {
          return jsonResponse({
            'error': {'code': 'REVISION_CONFLICT'},
          }, 409);
        }
        if (row['status'] != 'PENDING') {
          return jsonResponse({
            'error': {'code': 'INVALID_STATE'},
          }, 409);
        }
        row['status'] = data['status'];
        row['revision'] = (row['revision'] as int) + 1;
        paymentRows.single['status'] = data['status'];
        paymentRows.single['note'] = data['reason'];
        paymentRows.single['revision'] = 2;
        result = {
          'businessId': 12345678,
          'payment': paymentRows.single,
          'cheque': row,
        };
      }
      final saved = jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
      receipts[key] = saved;
      if (lose) {
        lose = false;
        throw TimeoutException('lost cheque response');
      }
      return jsonResponse(result);
    }
    return super.respond(request);
  }

  ChequeCommand create() => ChequeCommand('CREATE', {
    'partyId': partyId,
    'partyType': partyType,
    'payment': {
      'method': 'CHEQUE',
      'direction': direction,
      'amount': 100,
      'confirmed': true,
      'routing': {'fundId': previous.bankId},
      'cheque': {
        'bankName': 'بانک نمونه',
        'number': '12345',
        'sayadId': '1234567890123456',
        'dueAt': '2026-11-01T00:00:00.000Z',
      },
    },
  });
  Future<RemoteChequesFX> client() async =>
      RemoteChequesFX(await prepare(), invoice: summary);
}

Future<ChequeCommand> statusCommand(
  RemoteChequesFX fx,
  RemoteCheque row,
  String status,
) async {
  final payment = await fx.payment(row);
  return ChequeCommand(
    'STATUS',
    {
      'chequeId': row.id,
      'expectedRevision': row.revision,
      'status': status,
      'reason': 'ثبت نتیجه واقعی',
      'confirmed': true,
    },
    before: {'cheque': row.json, 'payment': payment.json},
  );
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
      '$app cheque durable creation/result replay preserves fixed bank and pending semantics',
      () async {
        final server = ChequeServer(
          app,
          type: app == 'mik' ? 'SALE' : 'PURCHASE',
        );
        final fx = await server.client();
        server.lose = true;
        await expectLater(
          fx.send(server.create()),
          throwsA(isA<TimeoutException>()),
        );
        final resumed = RemoteChequesFX(fx.context, invoice: server.summary);
        final command = await resumed.restore();
        final cheque = await resumed.send(command!);
        expect(cheque.status, 'PENDING');
        expect(server.cheques, hasLength(1));
        expect(server.writes.first.body, server.writes.last.body);
        expect(
          server.writes.first.headers['idempotency-key'],
          server.writes.last.headers['idempotency-key'],
        );
        final status = await statusCommand(resumed, cheque, 'CONFIRMED');
        server.lose = true;
        await expectLater(
          resumed.send(status),
          throwsA(isA<TimeoutException>()),
        );
        final restored = RemoteChequesFX(fx.context, invoice: server.summary);
        final row = await restored.send((await restored.restore())!);
        expect(row.status, 'CONFIRMED');
        expect(restored.pending, isNull);
        expect(server.paymentRows.single['routing'], {
          'fundId': previous.bankId,
        });
        expect(server.writes[2].body, server.writes[3].body);
        expect((await restored.all()).single.status, 'CONFIRMED');
      },
    );
    test(
      '$app cheque permissions, duplicate Sayad, revision and final states',
      () async {
        final server = ChequeServer(app);
        final fx = await server.client();
        server.write = false;
        await expectLater(fx.send(server.create()), throwsA(isA<AuthError>()));
        expect(server.writes, isEmpty);
        server.write = true;
        server.duplicate = true;
        await expectLater(
          fx.send(server.create()),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'DUPLICATE_RECORD'),
          ),
        );
        expect(fx.pending, isNull);
        server.duplicate = false;
        final row = await fx.send(server.create());
        server.wrong = true;
        await expectLater(fx.get(row.id), throwsFormatException);
        server.wrong = false;
        final stale = await statusCommand(fx, row, 'BOUNCED');
        server.cheques.single['revision'] = 2;
        await expectLater(
          fx.send(stale),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
          ),
        );
        expect(fx.pending, isNull);
        final updated = await fx.get(row.id);
        await fx.send(await statusCommand(fx, updated, 'BOUNCED'));
        expect(server.cheques.single['status'], 'BOUNCED');
        for (final result in ['RETURNED', 'CONFIRMED']) {
          final fresh = ChequeServer(app, type: 'PURCHASE');
          final client = await fresh.client();
          final cheque = await client.send(fresh.create());
          expect(
            (await client.send(await statusCommand(client, cheque, result)))
                .status,
            result,
          );
        }
      },
    );
    testWidgets(
      '$app cheque native form creates pending cheque and confirms real result',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1150);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = ChequeServer(
          app,
          type: app == 'mik' ? 'SALE' : 'PURCHASE',
        );
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: RemoteChequeScreen(appId: app, invoice: server.summary),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(server.writes, isEmpty);
        await tester.tap(find.text('چک جدید'));
        await tester.pumpAndSettle();
        for (final entry in {
          'cheque-amount': '100',
          'cheque-bank': 'بانک نمونه',
          'cheque-number': '12345',
          'cheque-sayad': '1234567890123456',
        }.entries) {
          final field = find.descendant(
            of: find.byKey(ValueKey(entry.key)),
            matching: find.byType(TextFormField),
          );
          await tester.ensureVisible(field);
          await tester.enterText(field, entry.value);
        }
        final date = tester.widget<DateInput>(
          find.byKey(const ValueKey('cheque-due')),
        );
        date.controller.text = '1405/8/10';
        date.onChanged(date.controller.text);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('حساب بانکی'));
        await tester.tap(find.text('حساب بانکی'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('بله'));
        await tester.tap(find.text('بله'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ثبت چک').last);
        await tester.tap(find.text('ثبت چک').last);
        await tester.pumpAndSettle();
        expect(server.cheques.single['status'], 'PENDING');
        expect(
          find.text('چک با موفقیت ثبت شد؛ تا تعیین نتیجه در انتظار است.'),
          findsOneWidget,
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('بانک نمونه — 12345'));
        await tester.pumpAndSettle();
        final reason = find.descendant(
          of: find.byKey(const ValueKey('cheque-reason')),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(reason);
        await tester.enterText(reason, 'وصول واقعی چک');
        await tester.ensureVisible(find.text('ثبت نتیجهٔ چک'));
        await tester.tap(find.text('ثبت نتیجهٔ چک'));
        await tester.pumpAndSettle();
        expect(server.cheques.single['status'], 'PENDING');
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.ensureVisible(find.text('بله'));
        await tester.tap(find.text('بله'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ثبت نتیجهٔ چک'));
        await tester.tap(find.text('ثبت نتیجهٔ چک'));
        await tester.pumpAndSettle();
        expect(server.cheques.single['status'], 'CONFIRMED');
        expect(find.text('نتیجهٔ چک با موفقیت ثبت شد.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
