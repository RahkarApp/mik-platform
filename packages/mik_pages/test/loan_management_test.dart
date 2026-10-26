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
import 'package:mik_data/utils/fx/loans.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/loans/forms.dart';
import 'package:mik_pages/loans/management_form.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'loans_test.dart' as base;
import 'invoice_payment_test.dart' show bankId, fundId, paymentId;

class ManagedLoanServer extends base.LoanServer {
  ManagedLoanServer(super.app);
  bool waiveAllowed = true,
      reverseAllowed = true,
      clearAllowed = true,
      loseManaged = false,
      wrongManaged = false;
  final managedRequests = <http.Request>[];
  final managedReceipts = <String, Map<String, dynamic>>{};
  void refreshLoan() {
    for (final field in [
      'paidPrincipalAmount',
      'paidChargeAmount',
      'pendingPrincipalAmount',
      'pendingChargeAmount',
      'accruedChargeAmount',
      'waivedChargeAmount',
    ]) {
      currentLoan![field] = installments.fold<int>(
        0,
        (sum, r) => sum + (r[field] as int),
      );
    }
    if (['ACTIVE', 'SETTLED'].contains(currentLoan!['status'])) {
      currentLoan!['status'] =
          currentLoan!['paidPrincipalAmount'] ==
                  currentLoan!['principalAmount'] &&
              (currentLoan!['paidChargeAmount'] as int) +
                      (currentLoan!['waivedChargeAmount'] as int) ==
                  currentLoan!['contractChargeAmount'] &&
              currentLoan!['pendingPrincipalAmount'] == 0 &&
              currentLoan!['pendingChargeAmount'] == 0
          ? 'SETTLED'
          : 'ACTIVE';
    }
    currentLoan!['revision'] = (currentLoan!['revision'] as int) + 1;
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request),
          row = jsonDecode(response.body) as Map<String, dynamic>;
      final business = row['scopeType'] == 'BUSINESS';
      (row['permissionCodes'] as List).addAll([
        if (waiveAllowed || !business) 'accounting.loan.waive',
        if (reverseAllowed || !business) 'accounting.loan.reverse',
        if (clearAllowed && !business) 'accounting.cheque.clear',
      ]);
      return jsonResponse(row);
    }
    final body = request.method == 'POST'
        ? jsonDecode(request.body) as Map<String, dynamic>
        : <String, dynamic>{};
    final chequeCreate =
        path.endsWith('/loans/payments') &&
        (body['payment'] as Map?)?['method'] == 'CHEQUE';
    final reschedule = path.endsWith('/loans/reschedule'),
        waive = path.endsWith('/loans/waive'),
        reverse = path.endsWith('/loans/payments/reverse'),
        outcome = path.endsWith('/loans/cheques/status');
    if (request.method != 'POST' ||
        !(chequeCreate || reschedule || waive || reverse || outcome)) {
      return super.respond(request);
    }
    managedRequests.add(request);
    expect(request.headers['x-app-id'], app);
    expect(request.headers['x-branch-id'], branch);
    final key = request.headers['idempotency-key']!;
    if (!managedReceipts.containsKey(key)) {
      if (reschedule || waive || chequeCreate) {
        expect(body['expectedRevision'], currentLoan!['revision']);
      }
      Map<String, dynamic>? payment, installment;
      if (chequeCreate) {
        final input = body['payment'] as Map;
        var left = input['amount'] as int, pTotal = 0, cTotal = 0;
        final allocations = <Map<String, dynamic>>[];
        for (final row in installments) {
          if (DateTime.parse(row['dueAt'] as String)
              .isBefore(DateTime.utc(2026, 10, 24))) {
            row['accruedChargeAmount'] =
                (row['chargeAmount'] as int) -
                (row['waivedChargeAmount'] as int);
          }
          final cAvailable =
              (row['accruedChargeAmount'] as int) -
              (row['paidChargeAmount'] as int) -
              (row['pendingChargeAmount'] as int);
          final c = left < cAvailable ? left : cAvailable;
          left -= c;
          final pAvailable =
              (row['principalAmount'] as int) -
              (row['paidPrincipalAmount'] as int) -
              (row['pendingPrincipalAmount'] as int);
          final p = left < pAvailable ? left : pAvailable;
          left -= p;
          row['pendingPrincipalAmount'] =
              (row['pendingPrincipalAmount'] as int) + p;
          row['pendingChargeAmount'] = (row['pendingChargeAmount'] as int) + c;
          if (p + c > 0) {
            allocations.add({
              'loanInstallmentId': row['loanInstallmentId'],
              'principalAmount': p,
              'chargeAmount': c,
            });
          }
          pTotal += p;
          cTotal += c;
        }
        expect(left, 0);
        payment = {
          'loanPaymentId': paymentId,
          'loanId': base.loanId,
          'businessId': 12345678,
          'branchId': branch,
          'revision': 1,
          'amount': input['amount'],
          'principalAmount': pTotal,
          'chargeAmount': cTotal,
          'method': 'CHEQUE',
          'status': 'PENDING',
          'routing': {
            ...input['routing'] as Map,
            'fundName': 'حساب بانکی',
            'kind': 'BANK',
          },
          'cheque': input['cheque'],
          'allocations': allocations,
          'occurredAt': body['occurredAt'],
          if (input.containsKey('transactionReference'))
            'transactionReference': input['transactionReference'],
          if (input.containsKey('note')) 'note': input['note'],
        };
        loanPayments.add(payment);
      } else if (reschedule) {
        for (final change in body['installments'] as List) {
          final row = installments.singleWhere(
            (r) => r['loanInstallmentId'] == change['loanInstallmentId'],
          );
          row['dueAt'] = change['dueAt'];
          row['revision'] = (row['revision'] as int) + 1;
        }
        currentLoan!['scheduleReason'] = body['reason'];
      } else if (waive) {
        installment = installments.singleWhere(
          (r) => r['loanInstallmentId'] == body['loanInstallmentId'],
        );
        final unrecognized =
            (installment['chargeAmount'] as int) -
            (installment['waivedChargeAmount'] as int) -
            (installment['accruedChargeAmount'] as int);
        final recognized = (body['amount'] as int) > unrecognized
            ? (body['amount'] as int) - unrecognized
            : 0;
        installment['waivedChargeAmount'] =
            (installment['waivedChargeAmount'] as int) +
            (body['amount'] as int);
        installment['accruedChargeAmount'] =
            (installment['accruedChargeAmount'] as int) - recognized;
        installment['revision'] = (installment['revision'] as int) + 1;
      } else {
        payment = loanPayments.singleWhere(
          (r) => r['loanPaymentId'] == body['loanPaymentId'],
        );
        expect(body['expectedRevision'], payment['revision']);
        for (final allocation in payment['allocations'] as List) {
          final row = installments.singleWhere(
            (r) => r['loanInstallmentId'] == allocation['loanInstallmentId'],
          );
          if (reverse) {
            row['paidPrincipalAmount'] =
                (row['paidPrincipalAmount'] as int) -
                (allocation['principalAmount'] as int);
            row['paidChargeAmount'] =
                (row['paidChargeAmount'] as int) -
                (allocation['chargeAmount'] as int);
          } else {
            row['pendingPrincipalAmount'] =
                (row['pendingPrincipalAmount'] as int) -
                (allocation['principalAmount'] as int);
            row['pendingChargeAmount'] =
                (row['pendingChargeAmount'] as int) -
                (allocation['chargeAmount'] as int);
            if (body['status'] == 'CONFIRMED') {
              row['paidPrincipalAmount'] =
                  (row['paidPrincipalAmount'] as int) +
                  (allocation['principalAmount'] as int);
              row['paidChargeAmount'] =
                  (row['paidChargeAmount'] as int) +
                  (allocation['chargeAmount'] as int);
            }
          }
          row['revision'] = (row['revision'] as int) + 1;
        }
        payment['status'] = reverse ? 'REVERSED' : body['status'];
        payment['reason'] = body['reason'];
        payment['revision'] = (payment['revision'] as int) + 1;
        if (!reverse) payment['occurredAt'] = body['occurredAt'];
      }
      refreshLoan();
      managedReceipts[key] = {
        'businessId': 12345678,
        'loan': presented(),
        if (payment != null) 'payment': {...payment},
        if (reschedule)
          'installments': installments.map((r) => {...r}).toList(),
        if (installment != null) 'installment': {...installment},
      };
    }
    if (loseManaged) {
      loseManaged = false;
      throw TimeoutException('Lost loan management response');
    }
    final result = managedReceipts[key]!;
    return jsonResponse(
      wrongManaged
          ? {
              ...result,
              'loan': {...result['loan'] as Map, 'loanId': fundId},
            }
          : result,
    );
  }
}

Future<LoansFX> prepare(ManagedLoanServer server) async {
  final fx = LoansFX(await server.prepare());
  await fx.send(base.draft());
  await fx.send(await base.operation(fx, 'fund'));
  return fx;
}

Future<LoanCommand> cheque(LoansFX fx) async {
  final payment = await base.operation(fx, 'payment', method: 'BANK_TRANSFER');
  return LoanCommand('payment', {
    ...payment.body,
    'payment': {
      ...payment.body['payment'] as Map,
      'method': 'CHEQUE',
      'cheque': {
        'bankName': 'ملت',
        'number': '123',
        'sayadId': '1234567890123456',
        'dueAt': '2026-11-22T00:00:00.000Z',
      },
    },
  }, before: payment.before);
}

Future<LoanCommand> management(
  LoansFX fx,
  String action, {
  String status = 'CONFIRMED',
  int amount = 20,
  String? dueAt,
}) async {
  final detail = await fx.detail(base.loanId),
      payments = await fx.payments(base.loanId);
  final payment = payments.isEmpty ? null : payments.single;
  final first = detail.installments.first;
  return LoanCommand(
    action,
    {
      'reason': 'عملیات واقعی',
      if (['reschedule', 'waive'].contains(action)) ...{
        'loanId': base.loanId,
        'expectedRevision': detail.loan.revision,
        if (action == 'reschedule')
          'installments': [
            {
              'loanInstallmentId': first.id,
              'dueAt': dueAt ?? '2026-11-01T00:00:00.000Z',
            },
          ]
        else ...{
          'loanInstallmentId': first.id,
          'amount': amount,
          'agreementConfirmed': true,
        },
      } else ...{
        'loanPaymentId': payment!.json['loanPaymentId'],
        'expectedRevision': payment.json['revision'],
        if (action == 'reverse')
          'fundsConfirmed': true
        else ...{
          'confirmed': true,
          'status': status,
          'occurredAt': '2026-10-24T00:00:00.000Z',
        },
      },
    },
    before: {
      'loan': detail.loan.json,
      'installments': detail.installments.map((r) => r.json).toList(),
      if (payment != null) 'payment': payment.json,
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
      '$app cheque reserves funds, outcomes release reservations and confirmed payments reverse',
      () async {
        for (final status in ['CONFIRMED', 'BOUNCED', 'RETURNED']) {
          final server = ManagedLoanServer(app);
          final fx = await prepare(server);
          expect((await fx.targets('CHEQUE')).single.id, bankId);
          await fx.send(await cheque(fx));
          var row = (await fx.detail(base.loanId)).loan;
          expect(row.money('paidPrincipalAmount'), 0);
          expect(row.money('pendingPrincipalAmount'), 200);
          expect(row.money('pendingChargeAmount'), 50);
          server.clearAllowed = false;
          await expectLater(
            fx.send(await management(fx, 'cheque', status: status)),
            throwsA(isA<AuthError>()),
          );
          server.clearAllowed = true;
          await fx.send(await management(fx, 'cheque', status: status));
          row = (await fx.detail(base.loanId)).loan;
          expect(row.money('pendingPrincipalAmount'), 0);
          expect(row.money('pendingChargeAmount'), 0);
          expect(
            row.money('paidPrincipalAmount'),
            status == 'CONFIRMED' ? 200 : 0,
          );
          if (status == 'CONFIRMED') {
            server.reverseAllowed = false;
            await expectLater(
              fx.send(await management(fx, 'reverse')),
              throwsA(isA<AuthError>()),
            );
            server.reverseAllowed = true;
            await fx.send(await management(fx, 'reverse'));
            expect(
              (await fx.detail(base.loanId)).loan.money('paidPrincipalAmount'),
              0,
            );
            expect(
              (await fx.payments(base.loanId)).single.json['status'],
              'REVERSED',
            );
          }
        }
      },
    );
    test(
      '$app reschedule/waive preserve paid amounts, enforce grants and replay exact requests',
      () async {
        final server = ManagedLoanServer(app);
        final fx = await prepare(server);
        final small = await base.operation(fx, 'payment');
        await fx.send(
          LoanCommand('payment', {
            ...small.body,
            'payment': {...small.body['payment'] as Map, 'amount': 20},
          }, before: small.before),
        );
        server.manage = false;
        await expectLater(
          fx.send(await management(fx, 'reschedule')),
          throwsA(isA<AuthError>()),
        );
        server.manage = true;
        await expectLater(
          fx.send(
            await management(
              fx,
              'reschedule',
              dueAt: '2026-12-01T00:00:00.000Z',
            ),
          ),
          throwsA(isA<FormatException>()),
        );
        await fx.send(await management(fx, 'reschedule'));
        expect(
          (await fx.detail(base.loanId)).loan.money('accruedChargeAmount'),
          50,
        );
        server.waiveAllowed = false;
        await expectLater(
          fx.send(await management(fx, 'waive')),
          throwsA(isA<AuthError>()),
        );
        server.waiveAllowed = true;
        await expectLater(
          fx.send(await management(fx, 'waive', amount: 40)),
          throwsA(isA<FormatException>()),
        );
        final command = await management(fx, 'waive');
        server.wrongManaged = true;
        await expectLater(fx.send(command), throwsA(isA<FormatException>()));
        server.wrongManaged = false;
        server.loseManaged = true;
        await fx.restore();
        await expectLater(
          fx.send(fx.pending!),
          throwsA(isA<TimeoutException>()),
        );
        await fx.send(fx.pending!);
        final result = (await fx.detail(base.loanId)).loan;
        expect(result.money('paidChargeAmount'), 20);
        expect(result.money('waivedChargeAmount'), 20);
        expect(result.money('accruedChargeAmount'), 30);
        final writes = server.managedRequests.where(
          (r) => r.url.path.endsWith('/waive'),
        );
        expect(writes.map((r) => r.body).toSet().length, 1);
        expect(writes.map((r) => r.headers['idempotency-key']).toSet(), {
          command.key,
        });
        expect(await fx.restore(), isNull);
      },
    );
    testWidgets(
      '$app native cheque and management forms submit exact operations',
      (tester) async {
        final server = ManagedLoanServer(app);
        final fx = await prepare(server);
        final scroll = find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first;
        Future<void> open(Widget widget) async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await tester.pumpWidget(
            ToastificationWrapper(child: GetMaterialApp(home: widget)),
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

        Future<void> submit(String key) async {
          await tester.scrollUntilVisible(
            find.byKey(ValueKey(key)),
            200,
            scrollable: scroll,
          );
          await tester.tap(find.byKey(ValueKey(key)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          toastification.dismissAll(delayForAnimation: false);
          await tester.pump(const Duration(seconds: 1));
        }

        Future<void> confirm() async {
          tester
              .widget<MyTab>(
                find
                    .byWidgetPredicate(
                      (w) => w is MyTab && w.tab.contains('بله'),
                    )
                    .last,
              )
              .callback('بله');
          await tester.pump();
        }

        await open(LoanForm(fx: fx, action: 'payment', loanId: base.loanId));
        await fill('مبلغ بازپرداخت', '250');
        await fill('تاریخ جابه‌جایی وجه', '1405/7/28');
        final methodFinder = find.byWidgetPredicate(
          (w) => w is MyTab && w.tab.contains('چک'),
        );
        await tester.scrollUntilVisible(methodFinder, 200, scrollable: scroll);
        await tester.widget<MyTab>(methodFinder).callback('چک');
        await tester.pumpAndSettle();
        final target = find.byWidgetPredicate(
          (w) => w is Dropdown && w.name == 'صندوق یا حساب',
        );
        final dropdown = tester.widget<Dropdown>(target);
        dropdown.onChange(dropdown.items_Value!.single);
        await fill('بانک چک', 'ملت');
        await fill('شماره چک', '123');
        await fill('سررسید چک', '1405/8/1');
        await tester.scrollUntilVisible(
          find.text('چک واقعی تحویل یا دریافت شده است.'),
          200,
          scrollable: scroll,
        );
        await confirm();
        await submit('loan-save');
        expect(server.loanPayments.single['status'], 'PENDING');
        await open(
          LoanManagementForm(
            fx: fx,
            action: 'cheque',
            loanId: base.loanId,
            paymentId: paymentId,
          ),
        );
        tester
            .widget<MyTab>(
              find.byWidgetPredicate(
                (w) => w is MyTab && w.tab.contains('برگشت'),
              ),
            )
            .callback('برگشت');
        await tester.pump();
        await fill('زمان واقعی نتیجه چک', '1405/7/29 12:00');
        await fill('دلیل عملیات', 'نتیجه واقعی');
        await confirm();
        await submit('loan-management-save');
        expect(server.loanPayments.single['status'], 'BOUNCED');
        final installmentId =
            server.installments.first['loanInstallmentId'] as String;
        await open(
          LoanManagementForm(
            fx: fx,
            action: 'reschedule',
            loanId: base.loanId,
            installmentId: installmentId,
          ),
        );
        await fill('سررسید جدید', '1405/8/10 12:00');
        await fill('دلیل عملیات', 'توافق سررسید');
        await submit('loan-management-save');
        await open(
          LoanManagementForm(
            fx: fx,
            action: 'waive',
            loanId: base.loanId,
            installmentId: installmentId,
          ),
        );
        await fill('مبلغ بخشودگی', '20');
        await fill('دلیل عملیات', 'توافق واقعی');
        await confirm();
        await submit('loan-management-save');
        expect(server.currentLoan!['waivedChargeAmount'], 20);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
