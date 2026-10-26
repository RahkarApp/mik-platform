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
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/loans.dart';
import 'package:mik_pages/loans/forms.dart';
import 'package:mik_pages/loans/screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_payment_test.dart'
    show PaymentServer, fundId, bankId, paymentId;

const loanId = '99999999-9999-4999-8999-999999999999';

class LoanServer extends PaymentServer {
  LoanServer(super.app);
  bool loanRead = true,
      manage = true,
      funding = true,
      loanPay = true,
      lostLoan = false,
      wrongLoan = false;
  Map<String, dynamic>? currentLoan;
  final installments = <Map<String, dynamic>>[],
      loanPayments = <Map<String, dynamic>>[];
  final loanRequests = <http.Request>[];
  final loanReceipts = <String, Map<String, dynamic>>{};
  Map<String, dynamic> presented() {
    final row = currentLoan!;
    return {
      ...row,
      'outstandingPrincipal': row['fundedAt'] == null
          ? 0
          : (row['principalAmount'] as int) -
                (row['paidPrincipalAmount'] as int),
      'outstandingRecognizedCharges':
          (row['accruedChargeAmount'] as int) -
          (row['paidChargeAmount'] as int),
      'remainingContractCharges':
          (row['contractChargeAmount'] as int) -
          (row['paidChargeAmount'] as int) -
          (row['waivedChargeAmount'] as int),
    };
  }

  Map<String, dynamic> installmentView(Map<String, dynamic> r) => {
    ...r,
    'outstandingPrincipal':
        (r['principalAmount'] as int) - (r['paidPrincipalAmount'] as int),
    'outstandingCharge':
        (r['chargeAmount'] as int) -
        (r['paidChargeAmount'] as int) -
        (r['waivedChargeAmount'] as int),
    'status': 'SCHEDULED',
  };
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request),
          row = jsonDecode(response.body) as Map<String, dynamic>;
      final business = row['scopeType'] == 'BUSINESS';
      (row['permissionCodes'] as List).addAll([
        if (loanRead || !business) 'accounting.loan.read',
        if (manage || !business) 'accounting.loan.manage',
        if (funding || !business) 'accounting.loan.fund',
        if (loanPay || !business) 'accounting.loan.pay',
      ]);
      return jsonResponse(row);
    }
    if (path.contains('/loans')) {
      if (request.method == 'GET') {
        return jsonResponse({
          'businessId': 12345678,
          if (path.endsWith('/payments')) ...{
            'items': loanPayments,
            'nextCursor': null,
          } else if (path.endsWith(loanId)) ...{
            'item': presented(),
            'installments': installments.map(installmentView).toList(),
          } else ...{
            'items': currentLoan == null ? [] : [presented()],
            'nextCursor': null,
          },
        });
      }
      loanRequests.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!,
          body = jsonDecode(request.body) as Map<String, dynamic>;
      if (!loanReceipts.containsKey(key)) {
        if (path.endsWith('/loans')) {
          expect(body.containsKey('loanId'), isFalse);
          currentLoan = {
            'loanId': loanId,
            'businessId': 12345678,
            'revision': 1,
            for (final key in [
              'name',
              'direction',
              'counterparty',
              'principalAmount',
              'contractChargeAmount',
              'partnerId',
              'note',
            ])
              if (body.containsKey(key)) key: body[key],
            'status': 'DRAFT',
            for (final field in [
              'paidPrincipalAmount',
              'paidChargeAmount',
              'accruedChargeAmount',
              'waivedChargeAmount',
              'pendingPrincipalAmount',
              'pendingChargeAmount',
            ])
              field: 0,
          };
          for (final entry in (body['installments'] as List).asMap().entries) {
            installments.add({
              'loanInstallmentId':
                  '88888888-8888-4888-8888-${(entry.key + 1).toString().padLeft(12, '0')}',
              'loanId': loanId,
              'businessId': 12345678,
              'revision': 1,
              'number': entry.key + 1,
              ...entry.value as Map<String, dynamic>,
              for (final field in [
                'paidPrincipalAmount',
                'paidChargeAmount',
                'accruedChargeAmount',
                'waivedChargeAmount',
                'pendingPrincipalAmount',
                'pendingChargeAmount',
              ])
                field: 0,
            });
          }
          loanReceipts[key] = {
            'businessId': 12345678,
            'loan': presented(),
            'installments': installments.map((r) => {...r}).toList(),
          };
        } else {
          expect(body['expectedRevision'], currentLoan!['revision']);
          final row = currentLoan!;
          row['revision'] = (row['revision'] as int) + 1;
          if (path.endsWith('/fund')) {
            row.addAll({
              'status': 'ACTIVE',
              'fundedAt': body['occurredAt'],
              'funding': {
                'method': body['method'],
                'routing': {
                  ...body['routing'] as Map,
                  'fundName': 'صندوق نمونه',
                  'kind': body.containsKey('method')
                      ? (body['method'] == 'CASH' ? 'CASH' : 'BANK')
                      : ((body['payment'] as Map)['method'] == 'CASH'
                            ? 'CASH'
                            : 'BANK'),
                },
                'branchId': branch,
                if (body.containsKey('reference'))
                  'reference': body['reference'],
              },
            });
            loanReceipts[key] = {'businessId': 12345678, 'loan': presented()};
          } else if (path.endsWith('/cancel')) {
            row['status'] = 'CANCELLED';
            row['note'] = body['reason'];
            loanReceipts[key] = {
              'businessId': 12345678,
              'loan': {...row},
            };
          } else if (path.endsWith('/payments')) {
            final input = body['payment'] as Map;
            var left = input['amount'] as int,
                paidPrincipal = 0,
                paidCharge = 0;
            final allocations = <Map<String, dynamic>>[];
            for (final r in installments) {
              if (DateTime.parse(r['dueAt'] as String)
                  .isBefore(DateTime.utc(2026, 10, 24))) {
                r['accruedChargeAmount'] = r['chargeAmount'];
              }
              final availableCharge =
                  (r['accruedChargeAmount'] as int) -
                  (r['paidChargeAmount'] as int);
              final requested = (body['allocations'] as List?)
                  ?.cast<Map>()
                  .where(
                    (a) => a['loanInstallmentId'] == r['loanInstallmentId'],
                  )
                  .firstOrNull;
              final c = body.containsKey('allocations')
                  ? (requested?['chargeAmount'] as int? ?? 0)
                  : (left < availableCharge ? left : availableCharge);
              if (c > availableCharge) {
                expect(body['recognizeFutureCharges'], true);
                r['accruedChargeAmount'] = (r['paidChargeAmount'] as int) + c;
              }
              left -= c;
              final availablePrincipal =
                  (r['principalAmount'] as int) -
                  (r['paidPrincipalAmount'] as int);
              final p = body.containsKey('allocations')
                  ? (requested?['principalAmount'] as int? ?? 0)
                  : (left < availablePrincipal ? left : availablePrincipal);
              left -= p;
              if (p + c > 0) {
                allocations.add({
                  'loanInstallmentId': r['loanInstallmentId'],
                  'principalAmount': p,
                  'chargeAmount': c,
                });
              }
              r['paidPrincipalAmount'] = (r['paidPrincipalAmount'] as int) + p;
              r['paidChargeAmount'] = (r['paidChargeAmount'] as int) + c;
              paidPrincipal += p;
              paidCharge += c;
            }
            expect(left, 0);
            row['paidPrincipalAmount'] =
                (row['paidPrincipalAmount'] as int) + paidPrincipal;
            row['paidChargeAmount'] =
                (row['paidChargeAmount'] as int) + paidCharge;
            row['accruedChargeAmount'] = installments.fold<int>(
              0,
              (sum, r) => sum + (r['accruedChargeAmount'] as int),
            );
            if (row['paidPrincipalAmount'] == row['principalAmount'] &&
                row['paidChargeAmount'] == row['contractChargeAmount']) {
              row['status'] = 'SETTLED';
            }
            final payment = <String, dynamic>{
              'loanPaymentId': paymentId,
              'loanId': loanId,
              'businessId': 12345678,
              'branchId': branch,
              'revision': 1,
              'amount': input['amount'],
              'method': input['method'],
              'principalAmount': paidPrincipal,
              'chargeAmount': paidCharge,
              'allocations': allocations,
              'status': 'CONFIRMED',
              'occurredAt': body['occurredAt'],
              'routing': {
                ...input['routing'] as Map,
                'fundName': 'صندوق نمونه',
                'kind': body.containsKey('method')
                    ? (body['method'] == 'CASH' ? 'CASH' : 'BANK')
                    : ((body['payment'] as Map)['method'] == 'CASH'
                          ? 'CASH'
                          : 'BANK'),
              },
              if (input.containsKey('transactionReference'))
                'transactionReference': input['transactionReference'],
              if (input.containsKey('note')) 'note': input['note'],
            };
            loanPayments.add(payment);
            loanReceipts[key] = {
              'businessId': 12345678,
              'loan': presented(),
              'payment': payment,
            };
          }
        }
      }
      if (lostLoan) {
        lostLoan = false;
        throw TimeoutException('Lost loan response');
      }
      final result = loanReceipts[key]!;
      return jsonResponse(
        wrongLoan
            ? {
                ...result,
                'loan': {...result['loan'] as Map, 'loanId': fundId},
              }
            : result,
      );
    }
    return super.respond(request);
  }
}

LoanCommand draft({String direction = 'RECEIVED'}) => LoanCommand('create', {
  'name': 'وام نمونه',
  'direction': direction,
  'counterparty': {'name': 'بانک نمونه'},
  'principalAmount': 1000,
  'contractChargeAmount': 100,
  'installments': [
    {
      'dueAt': '2026-10-22T00:00:00.000Z',
      'principalAmount': 500,
      'chargeAmount': 50,
    },
    {
      'dueAt': '2026-11-22T00:00:00.000Z',
      'principalAmount': 500,
      'chargeAmount': 50,
    },
  ],
});
Future<LoanCommand> operation(
  LoansFX fx,
  String action, {
  String method = 'CASH',
}) async {
  final snapshot = await fx.detail(loanId);
  return LoanCommand(
    action,
    {
      'loanId': loanId,
      'expectedRevision': snapshot.loan.revision,
      if (action != 'payment') 'reason': 'عملیات واقعی',
      if (action == 'fund') ...{
        'method': method,
        'routing': {'fundId': method == 'CASH' ? fundId : bankId},
        'fundsConfirmed': true,
        'occurredAt': '2026-10-20T00:00:00.000Z',
      },
      if (action == 'payment') ...{
        'occurredAt': '2026-10-23T00:00:00.000Z',
        'payment': {
          'amount': 250,
          'method': method,
          'routing': {'fundId': method == 'CASH' ? fundId : bankId},
          'confirmed': true,
        },
      },
    },
    before: {
      'loan': snapshot.loan.json,
      'installments': snapshot.installments.map((s) => s.json).toList(),
    },
  );
}

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
      '$app received/granted loan, cash/bank funding, server allocation and cancellation',
      () async {
        for (final direction in ['RECEIVED', 'GRANTED']) {
          final server = LoanServer(app);
          final fx = LoansFX(await server.prepare());
          final created = await fx.send(draft(direction: direction));
          expect(created.status, 'DRAFT');
          expect((await fx.detail(loanId)).installments.length, 2);
          final method = direction == 'RECEIVED' ? 'CASH' : 'BANK_TRANSFER';
          expect(
            (await fx.targets(method)).single.id,
            method == 'CASH' ? fundId : bankId,
          );
          expect(
            (await fx.send(await operation(fx, 'fund', method: method))).status,
            'ACTIVE',
          );
          final paid = await fx.send(
            await operation(fx, 'payment', method: method),
          );
          expect(paid.money('paidPrincipalAmount'), 200);
          expect(paid.money('paidChargeAmount'), 50);
          expect(paid.money('outstandingPrincipal'), 800);
          expect((await fx.payments(loanId)).single.money('amount'), 250);
          expect(fx.context.selectedBranch!.branchId, branch);
        }
      },
    );
    test(
      '$app business scope, explicit confirmations, exact retry and cancel raw response',
      () async {
        final server = LoanServer(app);
        final fx = LoansFX(await server.prepare());
        server.loanRead = false;
        await expectLater(fx.authorize(), throwsA(isA<AuthError>()));
        server.loanRead = true;
        server.manage = false;
        await expectLater(fx.send(draft()), throwsA(isA<AuthError>()));
        server.manage = true;
        final invalid = draft();
        await expectLater(
          fx.send(
            LoanCommand('create', {...invalid.body, 'principalAmount': 900}),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(server.loanRequests, isEmpty);
        await fx.send(draft());
        final funding = await operation(fx, 'fund');
        await expectLater(
          fx.send(
            LoanCommand('fund', {
              ...funding.body,
              'fundsConfirmed': false,
            }, before: funding.before),
          ),
          throwsA(isA<FormatException>()),
        );
        server.funding = false;
        await expectLater(fx.send(funding), throwsA(isA<AuthError>()));
        server.funding = true;
        server.wrongLoan = true;
        await expectLater(fx.send(funding), throwsA(isA<FormatException>()));
        server.wrongLoan = false;
        server.lostLoan = true;
        await fx.restore();
        await expectLater(
          fx.send(fx.pending!),
          throwsA(isA<TimeoutException>()),
        );
        await fx.send(fx.pending!);
        final requests = server.loanRequests.where(
          (r) => r.url.path.endsWith('/fund'),
        );
        expect(requests.map((r) => r.body).toSet().length, 1);
        expect(requests.map((r) => r.headers['idempotency-key']).toSet(), {
          funding.key,
        });
        expect(server.loanReceipts.length, 2);
        expect(await fx.restore(), isNull);
        final cancelServer = LoanServer(app);
        final cancelFX = LoansFX(await cancelServer.prepare());
        await cancelFX.send(draft());
        final cancelled = await cancelFX.send(
          await operation(cancelFX, 'cancel'),
        );
        expect(cancelled.status, 'CANCELLED');
      },
    );
    testWidgets(
      '$app native loan forms create, fund and repay without guessed installments',
      (tester) async {
        final server = LoanServer(app);
        final fx = LoansFX(await server.prepare());
        final scroll = find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first;
        Future<void> open(String action) async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await tester.pumpWidget(
            ToastificationWrapper(
              child: GetMaterialApp(
                onGenerateRoute: navigation.MikRouter(
                  sharedRoutes: SharedRoutes.namedPages,
                ).generateRoute,
                home: LoanForm(
                  fx: fx,
                  action: action,
                  loanId: action == 'create' ? null : loanId,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> fill(String name, String value) async {
          final finder = find.byWidgetPredicate(
            (w) => w is Input && w.name == name,
          );
          await tester.scrollUntilVisible(finder, 200, scrollable: scroll);
          tester.widget<Input>(finder).controller.text = value;
        }

        Future<void> submit() async {
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('loan-save')),
            200,
            scrollable: scroll,
          );
          await tester.tap(find.byKey(const ValueKey('loan-save')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          toastification.dismissAll(delayForAnimation: false);
          await tester.pump(const Duration(seconds: 1));
        }

        await open('create');
        await fill('عنوان وام', 'وام نمونه');
        await fill('طرف قرارداد', 'بانک نمونه');
        await fill('اصل وام', '1000');
        await fill('کل هزینه/درآمد مالی قراردادی', '100');
        await fill('سررسید قسط 1', '1405/8/1');
        await fill('اصل قسط 1', '1000');
        await fill('هزینه/درآمد قسط 1', '100');
        await submit();
        expect(server.currentLoan!['status'], 'DRAFT');
        for (final action in ['fund', 'payment']) {
          await open(action);
          if (action == 'payment') await fill('مبلغ بازپرداخت', '250');
          await fill('تاریخ جابه‌جایی وجه', '1405/7/28');
          final target = find.byWidgetPredicate(
            (w) => w is Dropdown && w.name == 'صندوق یا حساب',
          );
          await tester.scrollUntilVisible(target, 200, scrollable: scroll);
          final dropdown = tester.widget<Dropdown>(target);
          dropdown.onChange(dropdown.items_Value!.single);
          await tester.pump();
          if (action == 'fund') await fill('دلیل عملیات', 'دریافت واقعی');
          await submit();
        }
        expect(server.loanPayments.length, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              home: LoansScreen(appId: app, loanId: loanId),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
