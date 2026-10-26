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
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/invoice_read.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/invoice_change.dart';
import 'package:mik_pages/invoice/change_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'invoice_read_test.dart' show InvoiceReadServer, invoiceOne, lineId;

const opId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

class ChangeServer extends InvoiceReadServer {
  final String documentType;
  ChangeServer(super.app, {this.documentType = 'SALE'}) {
    currentType = documentType;
  }
  bool write = true,
      posted = true,
      lost = false,
      conflict = false,
      wrongOperation = false,
      finished = false,
      failed = false,
      manual = false;
  int revision = 3;
  String documentStatus = 'ISSUED', quantity = '1';
  int price = 100, total = 100;
  String? action;
  Map<String, dynamic>? command;
  final receipts = <String, Map<String, dynamic>>{};
  final mutationRequests = <http.Request>[];
  @override
  Map<String, Object?> detail(String type) {
    final base = super.detail(type);
    final oldView = base['view'] as Map;
    final oldLine = (oldView['lines'] as List).first as Map;
    final lines = documentStatus == 'CANCELLED'
        ? <Map<String, dynamic>>[]
        : [
            {
              ...Map<String, dynamic>.from(oldLine),
              'quantity': quantity,
              'unitPrice': price,
              'amount': total,
              'discountAmount': 0,
              'productPriceId': priceId,
              'warehouseIds': [warehouse],
            },
          ];
    final totals = {
      ...Map<String, dynamic>.from(oldView['totals'] as Map),
      'total': total,
      'subtotal': total,
    };
    return {
      ...base,
      'revision': revision,
      'status': documentStatus,
      'partyId': (base['partySnapshot'] as Map)['partyId'],
      'partyType': documentType == 'PURCHASE' ? 'SUPPLIER' : 'CUSTOMER',
      'postings': posted
          ? [
              {'postingId': opId},
            ]
          : [],
      'createdBy': {'identityId': identity},
      'financialVersion': 2,
      'lines': lines,
      'totals': totals,
      'view': {
        ...oldView,
        'lines': lines,
        'totals': totals,
        'openAmount': total,
        'settledAmount': 0,
        'paymentStatus': total == 0 ? 'PAID' : 'UNPAID',
      },
    };
  }

  Map<String, dynamic> operation({bool done = false}) => {
    'operationId': opId,
    'command': wrongOperation ? 'invoice.create.v2' : 'invoice.$action.v2',
    'revision': done ? 2 : 1,
    'status': done
        ? (failed ? 'FAILED' : 'SUCCEEDED')
        : manual
        ? 'ACTION_REQUIRED'
        : 'PENDING',
    if (done && !failed)
      'result': {
        'invoiceId': invoiceOne,
        'rootInvoiceId': invoiceOne,
        'revision': revision,
      },
    if (done && failed) 'errorCode': 'INSUFFICIENT_STOCK',
  };
  void complete() {
    if (finished) return;
    finished = true;
    if (failed) return;
    revision++;
    if (action == 'cancel') {
      documentStatus = 'CANCELLED';
      total = 0;
    }
    if (action == 'amend') {
      final row = (command!['lines'] as List).single as Map;
      quantity = row['quantity'] as String;
      price = row['unitPrice'] as int;
      total = 200;
    }
    if (action == 'return') {
      quantity = '0.5';
      total = 50;
    }
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final original = await super.respond(request);
      final json = jsonDecode(original.body) as Map<String, dynamic>;
      (json['permissionCodes'] as List).addAll([
        if (write) ...[
          'accounting.sale.update',
          'accounting.sale.update.all',
          'accounting.sale-return.create',
          'accounting.sale.status.cancelled',
          'accounting.purchase.update',
          'accounting.purchase.update.all',
          'accounting.purchase-return.create',
          'accounting.purchase.delete',
          'accounting.invoice.amend',
          'accounting.sale.price.override',
        ],
      ]);
      return jsonResponse(json);
    }
    if (request.method == 'GET' && path.contains('/operations/')) {
      requests.add(request);
      expect(request.headers['x-branch-id'], branch);
      if (!manual) complete();
      return jsonResponse({
        'businessId': 12345678,
        'operation': operation(done: !manual),
      });
    }
    if (request.method == 'POST') {
      requests.add(request);
      mutationRequests.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!;
      if (receipts.containsKey(key)) return jsonResponse(receipts[key]!);
      if (path.endsWith('/operations/retry')) {
        manual = false;
        return jsonResponse({'businessId': 12345678, 'operation': operation()});
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['invoiceId'], invoiceOne);
      if (conflict || body['expectedRevision'] != revision) {
        return jsonResponse({
          'error': {'code': 'REVISION_CONFLICT'},
        }, 409);
      }
      action = path.split('/').last;
      command = body;
      if (action == 'cancel' && posted && documentType == 'SALE') {
        return jsonResponse({
          'error': {'code': 'INVALID_STATE'},
        }, 409);
      }
      final result = {
        'businessId': 12345678,
        'operation': {...operation(), 'command': 'invoice.$action.v2'},
      };
      receipts[key] = result;
      if (lost) {
        lost = false;
        throw TimeoutException('lost acceptance');
      }
      if (wrongOperation) {
        return jsonResponse({...result, 'operation': operation()});
      }
      return jsonResponse(result);
    }
    return super.respond(request);
  }

  RemoteInvoiceSummary get row =>
      RemoteInvoiceSummary.fromJson(summary(documentType));
  Future<InvoiceChangeFX> client() async {
    await prepare();
    return InvoiceChangeFX(BusinessContext.forApp(app)!, row);
  }

  Map<String, dynamic> get body => {
    'invoiceId': invoiceOne,
    'expectedRevision': revision,
    'reason': 'اصلاح فاکتور',
  };
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
      '$app lost acceptance, exact replay and authoritative amended snapshot',
      () async {
        final server = ChangeServer(app);
        final fx = await server.client();
        final before = await fx.load();
        expect(before.revision, 3);
        expect(before.lines.single['warehouseIds'], [warehouse]);
        final body = {
          ...server.body,
          'lines': [
            {
              'lineId': lineId,
              'variantId': variantId,
              'quantity': '2',
              'unitPrice': 100,
              'discountAmount': 0,
              'warehouseIds': [warehouse],
              'productPriceId': priceId,
            },
          ],
        };
        server.lost = true;
        await expectLater(
          fx.send(InvoiceChangeCommand('amend', body)),
          throwsA(isA<TimeoutException>()),
        );
        final resumed = InvoiceChangeFX(fx.context, server.row);
        final saved = await resumed.restore();
        await resumed.send(saved!);
        expect(
          server.mutationRequests[0].body,
          server.mutationRequests[1].body,
        );
        expect(
          server.mutationRequests[0].headers['idempotency-key'],
          server.mutationRequests[1].headers['idempotency-key'],
        );
        expect(resumed.pending!.operation!['status'], 'PENDING');
        await resumed.refresh();
        final result = await resumed.finish();
        expect(result.detail.summary.total, 200);
        expect(result.detail.lines.single.quantity.toString(), '2');
        expect(resumed.pending, isNull);
      },
    );
    test(
      '$app permission, revision, physical cancel rule and invalid operation retain safe state',
      () async {
        final denied = ChangeServer(app)..write = false;
        final noAccess = await denied.client();
        await noAccess.load();
        await expectLater(
          noAccess.send(InvoiceChangeCommand('amend', denied.body)),
          throwsA(isA<AuthError>()),
        );
        expect(denied.mutationRequests, isEmpty);
        final conflict = ChangeServer(app)..conflict = true;
        final stale = await conflict.client();
        await stale.load();
        await expectLater(
          stale.send(InvoiceChangeCommand('cancel', conflict.body)),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
          ),
        );
        expect(stale.pending, isNull);
        final sale = ChangeServer(app);
        final posted = await sale.client();
        await posted.load();
        await expectLater(
          posted.send(InvoiceChangeCommand('cancel', sale.body)),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'INVALID_STATE'),
          ),
        );
        expect(posted.pending, isNull);
        final server = ChangeServer(app)..wrongOperation = true;
        final client = await server.client();
        await client.load();
        await expectLater(
          client.send(
            InvoiceChangeCommand('return', {
              ...server.body,
              'goodsConfirmed': true,
              'lines': [
                {'lineId': lineId, 'quantity': '0.5'},
              ],
              'conditions': [
                {'lineId': lineId, 'condition': 'SELLABLE'},
              ],
            }),
          ),
          throwsFormatException,
        );
        expect(client.pending, isNotNull);
        server.wrongOperation = false;
        await client.send(client.pending!);
        await client.refresh();
        expect((await client.finish()).detail.summary.total, 50);
      },
    );
    test(
      '$app cancellation and recoverable operation are confirmed through root result',
      () async {
        final server = ChangeServer(app, documentType: 'PURCHASE')
          ..manual = true;
        final fx = await server.client();
        await fx.load();
        await fx.send(
          InvoiceChangeCommand('cancel', {
            ...server.body,
            'goodsConfirmed': true,
            'conditions': [
              {'lineId': lineId, 'condition': 'SELLABLE'},
            ],
          }),
        );
        expect(fx.pending!.operation!['status'], 'ACTION_REQUIRED');
        await fx.retry();
        await fx.refresh();
        final result = await fx.finish();
        expect(result.detail.summary.status, 'CANCELLED');
        expect(fx.pending, isNull);
      },
    );
    testWidgets(
      '$app native amendment/return form validates conditions and waits for processing',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = ChangeServer(
          app,
          documentType: app == 'mik' ? 'SALE' : 'PURCHASE',
        );
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: InvoiceChangeScreen(appId: app, invoice: server.row),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('مرجوعی'));
        await tester.pumpAndSettle();
        final quantity = find.descendant(
          of: find.byKey(ValueKey('return-quantity-$lineId')),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(quantity);
        await tester.enterText(quantity, '۰.۵');
        final reason = find.descendant(
          of: find.byKey(const ValueKey('invoice-change-reason')),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(reason);
        await tester.enterText(reason, 'بازگشت واقعی کالا');
        await tester.ensureVisible(find.text('ثبت مرجوعی فاکتور'));
        await tester.tap(find.text('ثبت مرجوعی فاکتور'));
        await tester.pumpAndSettle();
        expect(server.mutationRequests, isEmpty);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.ensureVisible(find.text('سالم'));
        await tester.tap(find.text('سالم'));
        await tester.pumpAndSettle();
        expect(find.text('بله'), findsNothing);
        await tester.ensureVisible(find.text('ثبت مرجوعی فاکتور'));
        await tester.tap(find.text('ثبت مرجوعی فاکتور'));
        await tester.pumpAndSettle();
        expect(server.mutationRequests, hasLength(1));
        expect(
          jsonDecode(server.mutationRequests.single.body)['goodsConfirmed'],
          isTrue,
        );
        expect(find.text('عملیات فاکتور با موفقیت تکمیل شد.'), findsNothing);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('عملیات فاکتور با موفقیت تکمیل شد.'), findsOneWidget);
        expect(server.total, 50);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
