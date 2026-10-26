import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_data/source/remote/models/invoice_read.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/invoice/read_controller.dart';
import 'package:mik_pages/invoice/read_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const invoiceOne = '11111111-1111-4111-8111-111111111119';
const invoiceTwo = '22222222-2222-4222-8222-222222222229';
const partyId = '33333333-3333-4333-8333-333333333339';
const lineId = '44444444-4444-4444-8444-444444444449';

class InvoiceReadServer {
  final String app;
  InvoiceReadServer(this.app);
  final requests = <http.Request>[];
  bool allowed = true, repeated = false, wrongBranch = false, empty = false;
  String currentType = 'SALE', returnStatus = 'NONE';
  List<Map<String, Object?>> relatedDocuments = [];
  final relatedDetails = <String, Map<String, Object?>>{};
  Completer<http.Response>? delayed;
  Map<String, Object?> summary(
    String type, {
    String id = invoiceOne,
    String status = 'ISSUED',
  }) => {
    'invoiceId': id,
    'rootInvoiceId': id,
    'number': id == invoiceOne ? '000001' : '000002',
    'type': type,
    'status': status,
    'deliveryStatus': 'DELIVERED',
    'party': {
      'partyType': type == 'PURCHASE' ? 'SUPPLIER' : 'CUSTOMER',
      'partyId': partyId,
      'name': 'طرف نمونه',
      'phone': '09121234567',
    },
    'total': 100,
    'openAmount': 20,
    'paymentApplicable': type != 'PROFORMA',
    'paymentStatus': 'PARTIALLY_PAID',
    'operationId': null,
    'createdAt': '2026-10-23T10:00:00.000Z',
    'dueAt': '2026-11-20T12:30:00.000Z',
    'revision': 3,
  };
  Map<String, Object?> detail(String type) {
    final row = summary(type);
    final totals = {
      'currency': 'TOMAN',
      'subtotal': 100,
      'lineDiscount': 0,
      'discountAmount': 0,
      'shippingAmount': 0,
      'surchargeAmount': 0,
      'taxAmount': 0,
      'total': 100,
    };
    return {
      ...row,
      'businessId': 12345678,
      'branchId': wrongBranch ? invoiceTwo : branch,
      'partySnapshot': row['party'],
      'totals': {...totals, 'total': 9999},
      'settledAmount': 0,
      'note': 'یادداشت نمونه',
      'view': {
        'returnStatus': returnStatus,
        'totals': totals,
        'openAmount': 20,
        'settledAmount': 80,
        'paymentApplicable': type != 'PROFORMA',
        'paymentStatus': 'PARTIALLY_PAID',
        'lines': [
          {
            'lineId': lineId,
            'variantId': variantId,
            'name': 'قلم ثبت‌شده',
            'sku': null,
            'quantity': '0.5',
            'unitPrice': 200,
            'amount': 100,
          },
        ],
      },
    };
  }

  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    expect(request.method, 'GET');
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      return jsonResponse({
        ...fixtureAuthorization(
          allowed
              ? [
                  'accounting.sale.read',
                  'accounting.sale-return.read',
                  'accounting.purchase.read',
                  'accounting.proforma.read',
                ]
              : [],
        ),
        'scopeType': request.url.queryParameters['scopeType'],
        'scopeId': request.url.queryParameters['scopeId'],
      });
    }
    if (path.endsWith('/branches')) {
      return jsonResponse({
        'items': [fixtureResult()['branch']],
        'nextCursor': null,
      });
    }
    expect(request.headers['x-app-id'], app);
    expect(request.headers['x-branch-id'], branch);
    expect(path, startsWith('/v1/businesses/12345678/accounting/v2/invoices'));
    if (path.endsWith('/invoices')) {
      expect(
        request.url.queryParameters.keys.toSet().difference({
          'types',
          'limit',
          'after',
          'status',
        }),
        isEmpty,
      );
      expect(request.url.queryParameters['limit'], '30');
      currentType = request.url.queryParameters['types']!;
      if (delayed != null) {
        final reply = delayed!;
        delayed = null;
        return reply.future;
      }
      final more = request.url.queryParameters['after'] != null;
      return jsonResponse({
        'businessId': 12345678,
        'items': empty
            ? []
            : [
                summary(
                  currentType,
                  id: more && !repeated ? invoiceTwo : invoiceOne,
                  status: request.url.queryParameters['status'] ?? 'ISSUED',
                ),
              ],
        'nextCursor': empty || more && !repeated ? null : invoiceOne,
      });
    }
    return jsonResponse({
      'businessId': 12345678,
      'invoice': relatedDetails[path.split('/').last] ?? detail(currentType),
      'relatedDocuments': relatedDocuments,
    });
  }

  Future<void> prepare() async {
    final context = pimFixture(MockClient(respond), appId: app).context;
    await context.selectBranch((await context.branches()).single);
    requests.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var root = Directory.current;
    while (!File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
            .existsSync() &&
        root.parent.path != root.path) {
      root = root.parent;
    }
    await (FontLoader('ravi')..addFont(
          File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
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
      '$app scoped pages, status filter and current invoice view use server values',
      () async {
        final server = InvoiceReadServer(app);
        await server.prepare();
        final notices = <bool>[];
        final c = InvoiceReadController(
          appId: app,
          onNotice: (_, s) => notices.add(s),
        );
        addTearDown(c.onClose);
        await c.load();
        expect(c.rows.length, 1);
        await c.load(more: true);
        expect(notices, isEmpty);
        expect(c.rows.length, 2);
        expect(c.rows.map((row) => row.number), ['000002', '000001']);
        await c.refreshFromServer();
        expect(c.rows.map((row) => row.number), ['000002', '000001']);
        expect(c.next.value, isNull);
        final result = await c.detail(invoiceOne, 'SALE');
        expect(result!.summary.total, 100);
        expect(result.settledAmount, 80);
        expect(result.summary.openAmount, 20);
        expect(result.lines.single.quantity.toString(), '0.5');
        expect(result.lines.single.unitPrice, 200);
        server.returnStatus = 'FULL';
        final returned = await c.detail(invoiceOne, 'SALE');
        expect(returned!.returnStatus, 'FULL');
        server.returnStatus = 'NONE';
        expect(notices, isEmpty);
        c.type.value = 'PURCHASE';
        c.status.value = 'CANCELLED';
        await c.load();
        expect(c.rows.single.type, 'PURCHASE');
        expect(c.rows.single.status, 'CANCELLED');
        expect(server.requests.last.url.queryParameters['status'], 'CANCELLED');
        server.empty = true;
        await c.load();
        expect(c.rows, isEmpty);
        expect(c.error.value, isNull);
      },
    );
    test(
      '$app rejects denied access, repeated pages, cross-branch detail and late results',
      () async {
        final server = InvoiceReadServer(app);
        await server.prepare();
        final notices = <bool>[];
        final c = InvoiceReadController(
          appId: app,
          onNotice: (_, s) => notices.add(s),
        );
        addTearDown(c.onClose);
        await c.load();
        server.repeated = true;
        await c.load(more: true);
        expect(c.rows.length, 1);
        expect(notices.last, isFalse);
        server.wrongBranch = true;
        expect(await c.detail(invoiceOne, 'SALE'), isNull);
        expect(notices.last, isFalse);
        server.allowed = false;
        await c.load();
        expect(c.rows, isEmpty);
        expect(notices.last, isFalse);
        server.allowed = true;
        server.repeated = false;
        final reply = Completer<http.Response>();
        server.delayed = reply;
        final loading = c.load();
        while (server.delayed != null) {
          await Future<void>.delayed(Duration.zero);
        }
        BusinessContext.forApp(app)!.clearAccess();
        reply.complete(
          jsonResponse({
            'businessId': 12345678,
            'items': [server.summary('SALE')],
            'nextCursor': null,
          }),
        );
        await loading;
        expect(c.rows, isEmpty);
        expect(notices.last, isFalse);
        expect(
          () => RemoteInvoiceDetail.fromJson({
            ...server.detail('SALE'),
            'view': {},
          }),
          throwsFormatException,
        );
      },
    );
    testWidgets(
      '$app native tabs open read-only detail and filter with Alert feedback',
      (tester) async {
        final server = InvoiceReadServer(app);
        server.returnStatus = 'PARTIAL';
        server.relatedDocuments = [
          for (final entry in {invoiceTwo: '000003', lineId: '000004'}.entries)
            {
              'invoiceId': entry.key,
              'type': 'SALE_RETURN',
              'number': entry.value,
              'amount': 25,
              'status': 'ISSUED',
              'createdAt': '2026-10-24T10:00:00.000Z',
              'financialOnly': false,
            },
        ];
        for (final document in server.relatedDocuments) {
          server.relatedDetails[document['invoiceId'] as String] = {
            ...server.detail('SALE_RETURN'),
            'invoiceId': document['invoiceId'],
            'number': document['number'],
          };
        }
        await server.prepare();
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: RemoteInvoicesScreen(appId: app, includeProforma: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MyTabBar), findsOneWidget);
        expect(find.text('پیش‌فاکتور'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byKey(const ValueKey('invoice-$invoiceOne')));
        await tester.pumpAndSettle();
        expect(find.text('قلم ثبت‌شده'), findsOneWidget);
        expect(find.text('بخشی از کالاها مرجوع شده‌اند'), findsOneWidget);
        expect(find.text('اقلام باقی‌مانده: (1)'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('invoice-detail-items')));
        await tester.pumpAndSettle();
        expect(find.text('قلم ثبت‌شده'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('invoice-detail-items')));
        await tester.pumpAndSettle();
        expect(find.text('قلم ثبت‌شده'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('شماره 000004'),
          150,
          scrollable: find
              .descendant(
                of: find.byType(RefreshIndicator).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('مرجوعی فروش'), findsWidgets);
        expect(find.text('شماره 000003'), findsOneWidget);
        expect(find.text('مشاهده اقلام این مرجوعی'), findsWidgets);
        await tester.tap(find.text('مشاهده اقلام این مرجوعی').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('اقلام این سند'), findsOneWidget);
        expect(server.requests.last.url.path, endsWith('/$lineId'));
        Get.back();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('مهلت پرداخت'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(RefreshIndicator).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('مهلت پرداخت'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('یادداشت نمونه'),
          250,
          scrollable: find
              .descendant(
                of: find.byType(RefreshIndicator).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('یادداشت نمونه'), findsOneWidget);
        expect(find.byType(MyDivider), findsWidgets);
        expect(find.text('جزئیات فاکتور فروش 000001'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        Get.back();
        await tester.pumpAndSettle();
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('خرید'));
        await tester.pumpAndSettle();
        expect(server.currentType, 'PURCHASE');
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byType(IconButton).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('لغوشده'));
        await tester.pumpAndSettle();
        expect(server.requests.last.url.queryParameters['status'], 'CANCELLED');
        expect(find.text('فهرست فاکتورها دریافت شد.'), findsNothing);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        server.empty = true;
        await tester.tap(find.text('فروش'));
        await tester.pumpAndSettle();
        expect(find.text('فاکتوری یافت نشد!'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        server.empty = false;
        await tester.tap(find.text('به‌روزرسانی'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('invoice-$invoiceOne')),
          findsOneWidget,
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
