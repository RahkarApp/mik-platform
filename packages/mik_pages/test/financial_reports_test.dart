import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/financial_report.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/reports/financial_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_payment_test.dart' as previous;

const recordId = '11111111-1111-4111-8111-111111111111';
const secondId = '22222222-2222-4222-8222-222222222222';

class ReportServer extends previous.PaymentServer {
  ReportServer(super.app);
  final reportRequests = <http.Request>[];
  bool allowReports = true, changed = false, wrongScope = false, empty = false;
  bool duplicate = false, error = false;
  Map<String, dynamic> report(String kind, Map<String, String> query) {
    final second = query['cursor'] != null;
    final id = second && !duplicate ? secondId : recordId;
    final row = <String, dynamic>{
      'key': 'EXPENSE:$id',
      'recordId': id,
      'source': 'EXPENSE',
      'branchId': branch,
      'payeeId': secondId,
      'name': 'طرف حساب نمونه',
      'title': 'هزینه نمونه',
      'direction': 'OUT',
      'amount': 100,
      'pendingAmount': 40,
      'overdueAmount': 100,
      'dueAt': '2026-10-01T00:00:00.000Z',
    };
    final output = <String, dynamic>{
      'businessId': 12345678,
      'scope': wrongScope ? 'BUSINESS' : query['scope'],
      'branchIds': query['scope'] == 'BUSINESS' ? null : [branch],
      'snapshot': {'sequence': 5, 'asOf': '2026-10-24T10:00:00.000Z'},
      'currency': 'TOMAN',
      'nextCursor': second || empty ? null : 'page_two',
      if (kind != 'balances') ...{
        'startAt': query['startAt'],
        'endAt': query['endAt'],
      },
      'items': empty ? [] : [row],
    };
    if (['balances', 'dues'].contains(kind)) {
      output['totals'] = <String, dynamic>{
        'count': empty ? 0 : 2,
        'receivableAmount': 0,
        'payableAmount': empty ? 0 : 200,
        'overdueReceivableAmount': 0,
        'overduePayableAmount': empty ? 0 : 200,
      };
      if (kind == 'balances') {
        output['basis'] = 'CURRENT_OPEN_OBLIGATIONS';
        output['creditBalances'] = query['scope'] == 'BUSINESS'
            ? {
                'partyAccounts': [
                  {'partyType': 'SUPPLIER', 'debt': 2, 'credit': 3},
                ],
                'unallocatedCredit': [
                  {'partyType': 'SUPPLIER', 'amount': 7},
                ],
                'classifiedAdvances': [],
                'clearing': [],
                'additiveToOpenItems': false,
              }
            : null;
      } else {
        output['section'] = query['section'];
        output['additiveToOtherSections'] = false;
        if (query['section'] == 'CHEQUES') {
          row['source'] = 'EXPENSE_CHEQUE';
          row.remove('pendingAmount');
        }
      }
    }
    if (kind == 'expenses') {
      final totals = <String, dynamic>{
        for (final key in FinancialReportPage.expenseFields) key: 200,
      };
      output['items'] = empty
          ? []
          : [
              {'key': 'CATEGORY:$id', 'name': 'تعمیرات', ...totals},
            ];
      output['totals'] = totals;
      output['groupBy'] = query['groupBy'];
      output['settlementIsCashflowInRange'] = false;
    }
    if (['cash-flow', 'treasury'].contains(kind)) {
      output.addAll({'openingBalance': 1000, 'closingBalance': 900});
      if (kind == 'cash-flow') {
        output.addAll({
          'totals': {'inflow': 0, 'outflow': 100, 'net': -100},
          'externalCashflow': {'inflow': 0, 'outflow': 100, 'net': -100},
          'sharedBankExcluded': query['scope'] == 'BRANCH',
          'unclassified': false,
          'items': empty
              ? []
              : [
                  {
                    'key': 'OPERATING',
                    'category': 'OPERATING',
                    'inflow': 0,
                    'outflow': 100,
                    'net': -100,
                  },
                ],
          'nextCursor': null,
        });
      } else {
        output.addAll({
          'fund': {
            'fundId': query['fundId'],
            'name': 'صندوق شعبه',
            'kind': query['fundId'] == previous.bankId ? 'BANK' : 'CASH',
            'branchId': query['fundId'] == previous.bankId ? null : branch,
          },
          'current': {
            'balance': 900,
            'heldAmount': 100,
            'availableAmount': 800,
            'unreconciledAmount': 0,
          },
          'inflow': 0,
          'outflow': 100,
          'items': empty
              ? []
              : [
                  {
                    'journalId': id,
                    'sequence': second ? 2 : 1,
                    'sourceId': recordId,
                    'sourceType': 'EXPENSE_PAYMENT',
                    'branchId': secondId,
                    'description': 'پرداخت هزینه',
                    'occurredAt': '2026-10-20T10:00:00.000Z',
                    'inflow': 0,
                    'outflow': 100,
                  },
                ],
        });
      }
    }
    return output;
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/authorization')) {
      final original = await super.respond(request);
      final row = jsonDecode(original.body) as Map<String, dynamic>;
      if (allowReports) {
        (row['permissionCodes'] as List).addAll(
          financialReportNames.keys.map((kind) => 'accounting.report.$kind'),
        );
      }
      (row['permissionCodes'] as List).add(
        request.url.queryParameters['scopeType'] == 'BUSINESS'
            ? 'accounting.bank.read'
            : 'accounting.treasury.read',
      );
      return jsonResponse(row);
    }
    if (request.url.path.endsWith('/treasury/funds')) {
      final kind = request.url.queryParameters['kind'];
      return jsonResponse({
        'businessId': 12345678,
        'items': kind == 'PETTY_CASH'
            ? []
            : [
                {
                  'businessId': 12345678,
                  'fundId': kind == 'BANK' ? previous.bankId : previous.fundId,
                  'branchId': kind == 'BANK' ? null : branch,
                  'kind': kind,
                  'name': kind == 'BANK' ? 'بانک مشترک' : 'صندوق شعبه',
                  'status': 'ACTIVE',
                  'revision': 1,
                  'balance': 900,
                  'heldAmount': 100,
                },
              ],
        'nextCursor': null,
      });
    }
    if (request.url.path.contains('/reports/')) {
      reportRequests.add(request);
      expect(request.method, 'GET');
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      if (error || changed && request.url.queryParameters['cursor'] != null) {
        return jsonResponse({
          'error': {'code': changed ? 'REPORT_SNAPSHOT_CHANGED' : 'FORBIDDEN'},
        }, changed ? 409 : 403);
      }
      return jsonResponse(
        report(request.url.path.split('/').last, request.url.queryParameters),
      );
    }
    return super.respond(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    final bytes = File('../../mik-app/assets/fonts/RaviLight.ttf')
        .readAsBytesSync();
    await (FontLoader(
      'ravi',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    HttpOverrides.global = null;
  });
  tearDown(() {
    toastification.dismissAll(delayForAnimation: false);
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  test('report server errors retain their code and request ID instead of a connection error', () {
    final message = FinancialReportsFX.message(
      const AuthError(500, 'INTERNAL_ERROR', requestId: 'report-request-123'),
    );
    expect(message, contains('خطای داخلی'));
    expect(message, contains('INTERNAL_ERROR'));
    expect(message, contains('HTTP 500'));
    expect(message, contains('report-request-123'));
    expect(message, isNot(contains('ارتباط با سرور انجام نشد')));
    expect(
      FinancialReportsFX.message(const AuthError(504, 'RPC_TIMEOUT')),
      contains('مهلت پاسخ'),
    );
    expect(
      FinancialReportsFX.message(const AuthError(502, 'INVALID_RESPONSE')),
      contains('پاسخ معتبر'),
    );
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app report contracts, scopes, dates, snapshots and signed cashflow',
      () async {
        final server = ReportServer(app);
        final fx = FinancialReportsFX(await server.prepare());
        await fx.authorize();
        final start = DateTime.utc(2026, 10, 1, 0, 0, 0, 0, 123),
            end = DateTime.utc(2026, 11, 1, 0, 0, 0, 0, 456);
        for (final kind in financialReportNames.keys) {
          final page = await fx.page(
            kind,
            business: false,
            startAt: start,
            endAt: end,
            fundId: previous.fundId,
          );
          if (kind != 'balances') {
            expect(
              server.reportRequests.last.url.queryParameters['startAt'],
              '2026-10-01T00:00:00.000Z',
            );
            expect(
              server.reportRequests.last.url.queryParameters['endAt'],
              '2026-11-01T00:00:00.000Z',
            );
          }
          expect(page.sequence, 5);
          expect(page.branchIds, [branch]);
          if (page.next != null) {
            final next = await fx.page(
              kind,
              business: false,
              startAt: start,
              endAt: end,
              fundId: previous.fundId,
              cursor: page.next,
            );
            expect(next.asOf, page.asOf);
            expect(
              next.items.map(next.itemKey),
              isNot(contains(page.itemKey(page.items.single))),
            );
          }
        }
        final cash = await fx.page(
          'cash-flow',
          business: false,
          startAt: start,
          endAt: end,
        );
        expect((cash.json['totals'] as Map)['net'], -100);
        final credits = await fx.page('balances', business: true);
        expect(credits.branchIds, isNull);
        expect(credits.json['creditBalances'], isNotNull);
        await fx.page(
          'treasury',
          business: true,
          startAt: start,
          endAt: end,
          fundId: previous.bankId,
        );
        await expectLater(
          fx.page(
            'treasury',
            business: false,
            startAt: start,
            endAt: end,
            fundId: previous.bankId,
          ),
          throwsFormatException,
        );
        await fx.page(
          'dues',
          business: false,
          startAt: start,
          endAt: end,
          section: 'CHEQUES',
        );
        expect(
          server.reportRequests.last.url.queryParameters['section'],
          'CHEQUES',
        );
        final before = server.reportRequests.length;
        await expectLater(
          fx.page('dues', business: false, startAt: end, endAt: start),
          throwsA(isA<AuthError>()),
        );
        expect(server.reportRequests.length, before);
        server.wrongScope = true;
        await expectLater(
          fx.page('balances', business: false),
          throwsFormatException,
        );
        server.wrongScope = false;
        server.allowReports = false;
        await fx.authorize();
        await expectLater(
          fx.page('balances', business: false),
          throwsA(isA<AuthError>()),
        );
        server.allowReports = true;
        await fx.authorize();
        final malformed = server.report('balances', {'scope': 'BRANCH'});
        (malformed['totals'] as Map)['payableAmount'] = 1.5;
        expect(
          () => FinancialReportPage('balances', malformed),
          throwsFormatException,
        );
        fx.context.clearAccess();
        await expectLater(
          fx.page('balances', business: false),
          throwsA(isA<AuthError>()),
        );
      },
    );
    testWidgets(
      '$app native reports show full totals and clear invalid snapshots with Alert',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = ReportServer(app);
        final fx = FinancialReportsFX(await server.prepare());
        await fx.authorize();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              home: FinancialReportScreen(fx: fx, kind: 'balances'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('هزینه نمونه'), findsOneWidget);
        expect(find.text('200 تومان'), findsNWidgets(2));
        expect(find.text('100 تومان'), findsNWidgets(2));
        expect(find.textContaining('داده‌های مالی تغییر کرده'), findsNothing);
        server.changed = true;
        await tester.ensureVisible(find.text('نمایش بیشتر'));
        await tester.tap(find.text('نمایش بیشتر'));
        await tester.pumpAndSettle();
        expect(find.text('هزینه نمونه'), findsNothing);
        expect(find.textContaining('داده‌های مالی تغییر کرده'), findsWidgets);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        server.changed = false;
        server.empty = true;
        await tester.ensureVisible(find.text('دریافت گزارش'));
        await tester.tap(find.text('دریافت گزارش'));
        await tester.pumpAndSettle();
        expect(
          find.text('اطلاعاتی برای این گزارش وجود ندارد.'),
          findsOneWidget,
        );
        server.empty = false;
        await tester.tap(find.text('کل کسب‌وکار'));
        await tester.pumpAndSettle();
        expect(find.text('اعتبار و حساب طرف‌حساب‌ها'), findsOneWidget);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
    testWidgets('$app date reports and fund selection use native controls', (
      tester,
    ) async {
      tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = ReportServer(app);
      final fx = FinancialReportsFX(await server.prepare());
      await fx.authorize();
      for (final kind in ['dues', 'expenses', 'cash-flow', 'treasury']) {
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              home: FinancialReportScreen(
                key: ValueKey(kind),
                fx: fx,
                kind: kind,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (kind == 'treasury') {
          expect(find.text('خلاصه گزارش'), findsNothing);
          await tester.tap(find.text('انتخاب صندوق یا بانک'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('صندوق شعبه'));
          await tester.pumpAndSettle();
          expect(find.text('800 تومان'), findsOneWidget);
          expect(find.text('پرداخت هزینه'), findsOneWidget);
        } else {
          expect(find.text('خلاصه گزارش'), findsOneWidget);
        }
        final query = server.reportRequests.last.url.queryParameters;
        expect(
          DateTime.parse(query['endAt']!)
              .difference(DateTime.parse(query['startAt']!)),
          const Duration(days: 30),
        );
        if (kind == 'dues') {
          await tester.tap(find.text('چک‌های در انتظار'));
          await tester.pumpAndSettle();
          expect(
            server.reportRequests.last.url.queryParameters['section'],
            'CHEQUES',
          );
          expect(find.text('چک هزینه'), findsOneWidget);
        }
        if (kind == 'expenses') {
          await tester.tap(find.text('شعبه'));
          await tester.pumpAndSettle();
          expect(
            server.reportRequests.last.url.queryParameters['groupBy'],
            'BRANCH',
          );
        }
        if (kind == 'cash-flow') {
          expect(find.text('-100 تومان'), findsWidgets);
          expect(find.textContaining('بانک مشترک خارج'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });
  }
}
