import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_pages/bill/party_account.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:toastification/toastification.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/party_account.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_payment_test.dart'
    show PaymentServer, fundId, paymentId, sourceId;
import 'invoice_read_test.dart' show partyId, invoiceOne;

class AccountServer extends PaymentServer {
  AccountServer(super.app, {super.type});
  bool wrong = false, forbidden = false, badCursor = false;
  final accountRequests = <http.Request>[];
  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (forbidden) {
        (data['permissionCodes'] as List).remove('accounting.account.read');
      }
      return jsonResponse(data);
    }
    if (request.url.path.contains('/accounts/')) {
      accountRequests.add(request);
      expect(request.headers['x-branch-id'], branch);
      final after = int.parse(request.url.queryParameters['afterSequence']!);
      final type = request.url.path.split('/')[6];
      return jsonResponse({
        'businessId': 12345678,
        'party': {
          'partyType': type,
          'partyId': wrong ? fundId : partyId,
          'name': 'طرف حساب',
        },
        'accountId': fundId,
        'balance': -100,
        'debt': 0,
        'credit': 100,
        'availableCredit': 80,
        'invoiceOutstanding': 50,
        'overdueAmount': 20,
        'pendingChequeAmount': 30,
        'operationPending': null,
        'items': [
          {
            'businessId': 12345678,
            'entryId': paymentId,
            'accountId': fundId,
            'partyType': type,
            'partyId': partyId,
            'sequence': after + 2,
            'delta': -100,
            'balance': -100,
            'referenceType': 'PAYMENT',
            'referenceId': paymentId,
            'reason': 'RECEIPT',
            'createdAt': '2026-10-24T10:00:00.000Z',
          },
        ],
        'nextSequence': badCursor
            ? after
            : after == 0
            ? 2
            : null,
      });
    }
    return super.respond(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app reads party-scoped unused sources, payments and linked invoice using GET only',
      () async {
        for (final type in ['CUSTOMER', 'SUPPLIER']) {
          final server = AccountServer(
            app,
            type: type == 'SUPPLIER' ? 'PURCHASE' : 'SALE',
          );
          final fx = PartyAccountFX(await server.prepare(), type, partyId);
          server.sourceRows.add({
            'businessId': 12345678,
            'sourceId': sourceId,
            'partyId': partyId,
            'partyType': type,
            'kind': 'PAYMENT',
            'referenceId': paymentId,
            'status': 'ACTIVE',
            'amount': 100,
            'usedAmount': 20,
          });
          server.paymentRows.add({
            'businessId': 12345678,
            'paymentId': paymentId,
            'branchId': branch,
            'partyId': partyId,
            'partyType': type,
            'method': 'CASH',
            'direction': type == 'CUSTOMER' ? 'IN' : 'OUT',
            'status': 'CONFIRMED',
            'amount': 100,
          });
          expect((await fx.sources()).items.single.available, 80);
          expect((await fx.payments()).items.single.partyType, type);
          expect((await fx.invoice(invoiceOne)).summary.partyId, partyId);
          server.wrongParty = true;
          await expectLater(fx.sources(), throwsFormatException);
          expect(server.writes, isEmpty);
        }
      },
    );
    testWidgets(
      '$app existing account screen switches native tabs without writing financial data',
      (tester) async {
        final server = AccountServer(app);
        await server.prepare();
        server.sourceRows.add({
          'businessId': 12345678,
          'sourceId': sourceId,
          'partyId': partyId,
          'partyType': 'CUSTOMER',
          'kind': 'PAYMENT',
          'referenceId': paymentId,
          'status': 'ACTIVE',
          'amount': 100,
          'usedAmount': 20,
        });
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              home: PartyAccountScreen(
                appId: app,
                partyType: 'CUSTOMER',
                partyId: partyId,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MyTab), findsOneWidget);
        await tester.tap(find.text('اعتبار مصرف‌نشده'));
        await tester.pumpAndSettle();
        expect(
          server.requests.any((r) => r.url.path.endsWith('/sources')),
          isTrue,
        );
        await tester.tap(find.text('دریافت و پرداخت'));
        await tester.pumpAndSettle();
        expect(
          server.requests.any((r) => r.url.path.endsWith('/v2/payments')),
          isTrue,
        );
        expect(server.writes, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        Get.reset();
      },
    );

    test(
      '$app customer and supplier account pagination preserves signed amounts',
      () async {
        final server = AccountServer(app);
        final context = await server.prepare();
        for (final type in ['CUSTOMER', 'SUPPLIER']) {
          final fx = PartyAccountFX(context, type, partyId);
          final first = await fx.page();
          expect(first.money('balance'), -100);
          expect(first.money('pendingChequeAmount'), 30);
          expect(first.next, 2);
          final second = await fx.page(after: first.next!);
          expect(second.next, isNull);
          expect(second.items.single['sequence'], 4);
        }
        expect(server.accountRequests.every((r) => r.method == 'GET'), isTrue);
      },
    );
    test(
      '$app rejects wrong party, malformed cursor and missing permission',
      () async {
        final server = AccountServer(app);
        final fx = PartyAccountFX(await server.prepare(), 'CUSTOMER', partyId);
        server.wrong = true;
        await expectLater(fx.page(), throwsFormatException);
        server.wrong = false;
        server.badCursor = true;
        await expectLater(fx.page(), throwsFormatException);
        server.badCursor = false;
        server.forbidden = true;
        final count = server.accountRequests.length;
        await expectLater(fx.page(), throwsA(isA<AuthError>()));
        expect(server.accountRequests.length, count);
      },
    );
  }
}
