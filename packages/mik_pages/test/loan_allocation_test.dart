import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/loans.dart';
import 'package:mik_pages/loans/forms.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'loans_test.dart' as base;

Future<LoanCommand> allocation(
  LoansFX fx, {
  int principal = 100,
  int charge = 20,
  bool early = false,
}) async {
  final original = await base.operation(fx, 'payment');
  final rows = (original.before!['installments'] as List).cast<Map>();
  return LoanCommand('payment', {
    ...original.body,
    'payment': {
      ...original.body['payment'] as Map,
      'amount': principal + charge,
    },
    'allocations': [
      {
        'loanInstallmentId': rows.last['loanInstallmentId'],
        'principalAmount': principal,
        'chargeAmount': charge,
      },
    ],
    'recognizeFutureCharges': early,
  }, before: original.before);
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
      '$app explicit future allocations require consent, exact totals and available balances',
      () async {
        final server = base.LoanServer(app);
        final fx = LoansFX(await server.prepare());
        await fx.send(base.draft());
        await fx.send(await base.operation(fx, 'fund'));
        final denied = await allocation(fx);
        final count = server.loanRequests.length;
        await expectLater(fx.send(denied), throwsA(isA<FormatException>()));
        final mismatch = await allocation(fx, early: true);
        await expectLater(
          fx.send(
            LoanCommand('payment', {
              ...mismatch.body,
              'payment': {...mismatch.body['payment'] as Map, 'amount': 121},
            }, before: mismatch.before),
          ),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          fx.send(await allocation(fx, principal: 501, early: true)),
          throwsA(isA<FormatException>()),
        );
        final duplicate = (mismatch.body['allocations'] as List).first;
        await expectLater(
          fx.send(
            LoanCommand('payment', {
              ...mismatch.body,
              'allocations': [duplicate, duplicate],
            }, before: mismatch.before),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(server.loanRequests.length, count);
        final result = await fx.send(await allocation(fx, early: true));
        expect(result.money('paidPrincipalAmount'), 100);
        expect(result.money('paidChargeAmount'), 20);
        expect(server.installments.first['paidPrincipalAmount'], 0);
        expect(server.installments.last['paidPrincipalAmount'], 100);
        expect(server.installments.last['accruedChargeAmount'], 20);
        expect(fx.pending, isNull);
      },
    );

    test(
      '$app pending cheque reservation, mismatched response and exact retry',
      () async {
        final server = base.LoanServer(app);
        final fx = LoansFX(await server.prepare());
        await fx.send(base.draft());
        await fx.send(await base.operation(fx, 'fund'));
        server.installments.last['pendingPrincipalAmount'] = 450;
        server.currentLoan!['pendingPrincipalAmount'] = 450;
        await expectLater(
          fx.send(await allocation(fx, charge: 0)),
          throwsA(isA<FormatException>()),
        );
        server.installments.last['pendingPrincipalAmount'] = 0;
        server.currentLoan!['pendingPrincipalAmount'] = 0;
        server.wrongLoan = true;
        await expectLater(
          fx.send(await allocation(fx, early: true)),
          throwsA(isA<FormatException>()),
        );
        expect(fx.pending, isNotNull);
        final retry = fx.pending!;
        server.wrongLoan = false;
        server.lostLoan = true;
        await expectLater(fx.send(retry), throwsA(isA<TimeoutException>()));
        await fx.send(retry);
        final posts = server.loanRequests
            .where((r) => r.url.path.endsWith('/payments'))
            .toList();
        expect(posts.length, 3);
        expect(posts.map((r) => r.body).toSet().length, 1);
        expect(
          posts.map((r) => r.headers['idempotency-key']).toSet().length,
          1,
        );
        expect(server.loanPayments.length, 1);
      },
    );

    testWidgets(
      '$app native allocation fields show summary and send selected installment',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = base.LoanServer(app);
        final fx = LoansFX(await server.prepare());
        await fx.send(base.draft());
        await fx.send(await base.operation(fx, 'fund'));
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              home: LoanForm(fx: fx, action: 'payment', loanId: base.loanId),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scroll = find.byType(Scrollable).first;
        Future<void> fill(String name, String value) async {
          final finder = find.byWidgetPredicate(
            (w) => w is Input && w.name == name,
          );
          await tester.scrollUntilVisible(finder, 200, scrollable: scroll);
          final input = tester.widget<Input>(finder);
          input.controller.text = value;
          if (input.onChanged != null) input.onChanged(value);
          await tester.pump();
        }

        tester
            .widget<MyTab>(find.byKey(const ValueKey('loan-allocation-mode')))
            .callback('انتخاب اقساط');
        await tester.pumpAndSettle();
        await fill('مبلغ بازپرداخت', '۱۲۰ تومان');
        await fill('اصل قسط 2', '۱۰۰ تومان');
        await fill('هزینه قسط 2', '۲۰ تومان');
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('loan-future-charges')),
          200,
          scrollable: scroll,
        );
        expect(find.textContaining('جمع انتخابی:'), findsOneWidget);
        tester
            .widget<MyTab>(find.byKey(const ValueKey('loan-future-charges')))
            .callback('بله');
        await tester.pump();
        await fill('تاریخ جابه‌جایی وجه', '1405/7/30');
        final target = find.byWidgetPredicate(
          (w) => w is Dropdown && w.name == 'صندوق یا حساب',
        );
        await tester.scrollUntilVisible(target, 200, scrollable: scroll);
        final dropdown = tester.widget<Dropdown>(target);
        dropdown.onChange(dropdown.items_Value!.single);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('loan-save')),
          200,
          scrollable: scroll,
        );
        await tester.tap(find.byKey(const ValueKey('loan-save')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(server.loanPayments.length, 1);
        expect(server.installments.last['paidPrincipalAmount'], 100);
        expect(server.installments.last['paidChargeAmount'], 20);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
