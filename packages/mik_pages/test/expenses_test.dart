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
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/expenses.dart';
import 'package:mik_pages/cost/remote_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_payment_test.dart' as previous;

const expenseId = '11111111-1111-4111-8111-111111111116';
const categoryId = '22222222-2222-4222-8222-222222222226';
const payeeId = '33333333-3333-4333-8333-333333333336';

class ExpenseServer extends previous.PaymentServer {
  ExpenseServer(super.app);
  bool exists = true,
      writeExpense = true,
      lostExpense = false,
      wrongExpense = false,
      revisionConflict = false;
  int expenseWrites = 0;
  final expenseRequests = <http.Request>[];
  final expenseReceipts = <String, Map<String, dynamic>>{};
  final disbursements = <Map<String, dynamic>>[];
  final category = <String, dynamic>{
    'businessId': 12345678,
    'categoryId': categoryId,
    'name': 'تعمیرات',
    'status': 'ACTIVE',
    'revision': 1,
  };
  late final expense = <String, dynamic>{
    'businessId': 12345678,
    'expenseId': expenseId,
    'branchId': branch,
    'categoryId': categoryId,
    'payeeId': payeeId,
    'title': 'هزینه تعمیر',
    'amount': 100,
    'paidAmount': 0,
    'pendingAmount': 0,
    'revision': 1,
    'status': 'ISSUED',
    'paymentStatus': 'UNPAID',
    'occurredAt': '2026-10-24T10:00:00.000Z',
    'dueAt': null,
    'categorySnapshot': {'name': 'تعمیرات'},
    'payeeSnapshot': {'name': 'تعمیرکار نمونه'},
    'createdBy': {'identityId': identity},
  };
  void refresh() {
    expense['paidAmount'] = disbursements
        .where((r) => r['status'] == 'CONFIRMED')
        .fold<int>(0, (s, r) => s + (r['amount'] as int));
    expense['pendingAmount'] = disbursements
        .where((r) => r['status'] == 'PENDING')
        .fold<int>(0, (s, r) => s + (r['amount'] as int));
    expense['paymentStatus'] = expense['paidAmount'] == expense['amount']
        ? 'PAID'
        : expense['paidAmount'] == 0
        ? 'UNPAID'
        : 'PARTIALLY_PAID';
    expense['revision'] = (expense['revision'] as int) + 1;
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request),
          row = jsonDecode(response.body) as Map<String, dynamic>;
      final business = request.url.queryParameters['scopeType'] == 'BUSINESS';
      (row['permissionCodes'] as List).addAll(
        business
            ? [
                'accounting.expense.category.read',
                'accounting.service-provider.read',
                if (writeExpense) ...[
                  'accounting.expense.category.create',
                  'accounting.expense.category.update',
                ],
              ]
            : [
                'accounting.expense.read',
                if (writeExpense) ...[
                  'accounting.expense.create',
                  'accounting.expense.update',
                  'accounting.expense.delete',
                  'accounting.expense.payment.pay',
                  'accounting.expense.payment.reverse',
                  'accounting.expense.cheque.pay',
                  'accounting.cheque.clear',
                ],
              ],
      );
      return jsonResponse(row);
    }
    if (path.endsWith('/expenses/payees')) {
      return jsonResponse({
        'businessId': 12345678,
        'items': [
          {
            'businessId': 12345678,
            'payeeId': payeeId,
            'name': 'تعمیرکار نمونه',
            'kind': 'PERSON',
            'phone': '09121234567',
            'status': 'ACTIVE',
            'revision': 1,
            'createdBy': {'identityId': identity},
          },
        ],
        'nextCursor': null,
      });
    }
    if (request.method == 'GET' && path.contains('/expenses')) {
      requests.add(request);
      if (path.endsWith('/expenses/categories')) {
        return jsonResponse({
          'businessId': 12345678,
          'items': [category],
          'nextCursor': null,
        });
      }
      if (path.endsWith('/expenses/payments')) {
        expect(request.url.queryParameters['expenseId'], expenseId);
        return jsonResponse({
          'businessId': 12345678,
          'items': disbursements,
          'nextCursor': null,
        });
      }
      final record = {...expense, if (wrongExpense) 'branchId': payeeId};
      if (path.endsWith('/expenses')) {
        return jsonResponse({
          'businessId': 12345678,
          'items': exists ? [record] : [],
          'nextCursor': null,
        });
      }
      return jsonResponse({'businessId': 12345678, 'item': record});
    }
    if (request.method == 'POST' && path.contains('/expenses')) {
      requests.add(request);
      expenseRequests.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!;
      if (expenseReceipts.containsKey(key)) {
        return jsonResponse(expenseReceipts[key]!);
      }
      if (revisionConflict) {
        return jsonResponse({
          'error': {'code': 'REVISION_CONFLICT'},
        }, 409);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final result = <String, dynamic>{'businessId': 12345678};
      if (path.contains('/categories')) {
        category.addAll({
          'name': body['name'],
          'revision': (category['revision'] as int) + 1,
          if (body['status'] != null) 'status': body['status'],
        });
        result['item'] = category;
      } else {
        if (path.endsWith('/expenses')) {
          expect(body.containsKey('payments'), isFalse);
          exists = true;
          expense.addAll(body);
        } else if (path.endsWith('/amend')) {
          expect(body['expectedRevision'], expense['revision']);
          for (final field in [
            'title',
            'amount',
            'categoryId',
            'payeeId',
            'dueAt',
            'note',
          ]) {
            if (body.containsKey(field)) expense[field] = body[field];
          }
          expense['revision'] = (expense['revision'] as int) + 1;
        } else if (path.endsWith('/cancel')) {
          expect(body['expectedRevision'], expense['revision']);
          expense['status'] = 'VOIDED';
          expense['revision'] = (expense['revision'] as int) + 1;
        } else {
          Map<String, dynamic> paid;
          if (path.endsWith('/payments')) {
            expect(body['expectedRevision'], expense['revision']);
            final input = body['payment'] as Map;
            expect(input['direction'], 'OUT');
            expect(input['confirmed'], true);
            final remaining =
                (expense['amount'] as int) -
                (expense['paidAmount'] as int) -
                (expense['pendingAmount'] as int);
            if ((input['amount'] as int) > remaining) {
              return jsonResponse({
                'error': {'code': 'SETTLEMENT_EXCEEDED'},
              }, 409);
            }
            final fund = (input['routing'] as Map)['fundId'];
            paid = {
              'businessId': 12345678,
              'branchId': branch,
              'expenseId': expenseId,
              'payeeId': payeeId,
              'disbursementId':
                  '44444444-4444-4444-8444-${(disbursements.length + 1).toString().padLeft(12, '0')}',
              'revision': 1,
              'method': input['method'],
              'amount': input['amount'],
              'routing': {
                'fundId': fund,
                'fundName': fund == previous.fundId
                    ? 'صندوق شعبه'
                    : 'حساب بانکی',
              },
              'status': input['method'] == 'CHEQUE' ? 'PENDING' : 'CONFIRMED',
              if (input['cheque'] != null) 'cheque': input['cheque'],
            };
            disbursements.add(paid);
          } else {
            paid = disbursements.singleWhere(
              (r) => r['disbursementId'] == body['disbursementId'],
            );
            expect(body['expectedRevision'], paid['revision']);
            if (path.endsWith('/reverse')) {
              expect(body['fundsConfirmed'], true);
              paid['status'] = 'REVERSED';
            } else {
              expect(body['confirmed'], true);
              paid['status'] = body['status'];
            }
            paid['revision'] = (paid['revision'] as int) + 1;
          }
          refresh();
          result['disbursement'] = paid;
        }
        result['expense'] = expense;
      }
      expenseWrites++;
      final reply = jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
      expenseReceipts[key] = reply;
      if (lostExpense) {
        lostExpense = false;
        throw TimeoutException('lost expense reply');
      }
      return jsonResponse(reply);
    }
    return super.respond(request);
  }

  Future<ExpensesFX> client() async => ExpensesFX(await prepare());
  Map<String, dynamic> get createBody => {
    'title': 'هزینه تعمیر',
    'amount': 100,
    'categoryId': categoryId,
    'payeeId': payeeId,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var dir = Directory.current;
    while (!File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
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
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test('$app durable expense payment routes and cheque outcomes', () async {
      final server = ExpenseServer(app);
      var fx = await server.client();
      await fx.authorize();
      server.lostExpense = true;
      await expectLater(
        fx.send(ExpenseCommand('create', server.createBody)),
        throwsA(anything),
      );
      fx = ExpensesFX(fx.context);
      await fx.restore();
      await fx.send(fx.pending!);
      expect(server.expenseWrites, 1);
      expect(
        server.expenseRequests.first.body,
        server.expenseRequests.last.body,
      );
      expect(
        server.expenseRequests.first.headers['idempotency-key'],
        server.expenseRequests.last.headers['idempotency-key'],
      );
      for (final method in ['CASH', 'CARD', 'BANK_TRANSFER', 'CHEQUE']) {
        var before = await fx.get(expenseId);
        final fund = (await fx.targets(method)).first;
        expect(fund.kind, method == 'CASH' ? 'CASH' : 'BANK');
        final payment = <String, dynamic>{
          'amount': 20,
          'method': method,
          'direction': 'OUT',
          'confirmed': true,
          'routing': {'fundId': fund.id},
          if (method == 'CHEQUE')
            'cheque': {
              'bankName': 'بانک نمونه',
              'number': '1234',
              'dueAt': '2099-01-01T00:00:00.000Z',
            },
        };
        await fx.send(
          ExpenseCommand(
            'payment',
            {
              'expenseId': expenseId,
              'expectedRevision': before.revision,
              'payment': payment,
            },
            before: {'expense': before.json},
          ),
        );
        before = await fx.get(expenseId);
        var paid = (await fx.payments(before)).last;
        if (method == 'CHEQUE') {
          expect(before.money('pendingAmount'), 20);
          await fx.send(
            ExpenseCommand(
              'cheque',
              {
                'disbursementId': paid.id,
                'expectedRevision': paid.json['revision'],
                'status': 'CONFIRMED',
                'confirmed': true,
                'reason': 'وصول واقعی',
              },
              before: {'expense': before.json, 'payment': paid.json},
            ),
          );
          before = await fx.get(expenseId);
          paid = (await fx.payments(before)).last;
        }
        server.lostExpense = true;
        await expectLater(
          fx.send(
            ExpenseCommand(
              'reverse',
              {
                'disbursementId': paid.id,
                'expectedRevision': paid.json['revision'],
                'fundsConfirmed': true,
                'reason': 'برگشت واقعی کامل',
              },
              before: {'expense': before.json, 'payment': paid.json},
            ),
          ),
          throwsA(anything),
        );
        fx = ExpensesFX(fx.context);
        await fx.restore();
        await fx.send(fx.pending!);
        expect((await fx.get(expenseId)).remaining, 100);
      }
      for (final outcome in ['BOUNCED', 'RETURNED']) {
        var before = await fx.get(expenseId);
        await fx.send(
          ExpenseCommand(
            'payment',
            {
              'expenseId': expenseId,
              'expectedRevision': before.revision,
              'payment': {
                'method': 'CHEQUE',
                'direction': 'OUT',
                'amount': 30,
                'confirmed': true,
                'routing': {'fundId': previous.bankId},
                'cheque': {
                  'bankName': 'بانک نمونه',
                  'number': outcome,
                  'dueAt': '2099-01-01T00:00:00.000Z',
                },
              },
            },
            before: {'expense': before.json},
          ),
        );
        before = await fx.get(expenseId);
        expect(before.remaining, 70);
        final paid = (await fx.payments(before)).last;
        await fx.send(
          ExpenseCommand(
            'cheque',
            {
              'disbursementId': paid.id,
              'expectedRevision': paid.json['revision'],
              'status': outcome,
              'confirmed': true,
              'reason': 'نتیجه واقعی چک',
            },
            before: {'expense': before.json, 'payment': paid.json},
          ),
        );
        expect((await fx.get(expenseId)).remaining, 100);
      }
    });
    test(
      '$app expense references, edit/void, permissions, revision and scope',
      () async {
        final server = ExpenseServer(app);
        final fx = await server.client();
        await fx.authorize();
        var row = await fx.get(expenseId);
        final category = (await fx.categories()).single;
        await fx.send(
          ExpenseCommand('category-update', {
            'categoryId': category.id,
            'expectedRevision': category.json['revision'],
            'name': 'هزینه‌های تعمیر',
            'status': 'ACTIVE',
          }),
        );
        server.writeExpense = false;
        await expectLater(
          fx.send(
            ExpenseCommand(
              'amend',
              {
                'expenseId': row.id,
                'expectedRevision': row.revision,
                'title': 'عنوان تازه',
                'reason': 'اصلاح عنوان',
              },
              before: {'expense': row.json},
            ),
          ),
          throwsA(isA<AuthError>().having((e) => e.code, 'code', 'FORBIDDEN')),
        );
        server.writeExpense = true;
        server.revisionConflict = true;
        await expectLater(
          fx.send(
            ExpenseCommand(
              'amend',
              {
                'expenseId': row.id,
                'expectedRevision': row.revision,
                'title': 'عنوان تازه',
                'reason': 'اصلاح عنوان',
              },
              before: {'expense': row.json},
            ),
          ),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
          ),
        );
        expect(fx.pending, isNull);
        server.revisionConflict = false;
        await fx.send(
          ExpenseCommand(
            'amend',
            {
              'expenseId': row.id,
              'expectedRevision': row.revision,
              'title': 'عنوان تازه',
              'reason': 'اصلاح عنوان',
            },
            before: {'expense': row.json},
          ),
        );
        row = await fx.get(expenseId);
        expect(row.json['title'], 'عنوان تازه');
        await fx.send(
          ExpenseCommand(
            'cancel',
            {
              'expenseId': row.id,
              'expectedRevision': row.revision,
              'reason': 'لغو واقعی',
            },
            before: {'expense': row.json},
          ),
        );
        expect((await fx.get(expenseId)).status, 'VOIDED');
        server.wrongExpense = true;
        await expectLater(fx.all(), throwsFormatException);
        expect(fx.context.selectedBranch!.branchId, branch);
      },
    );
    testWidgets('$app native expense create and actual payment confirmation', (
      tester,
    ) async {
      tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = ExpenseServer(app)..exists = false;
      await server.prepare();
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: RemoteExpensesScreen(appId: app),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('هزینه جدید'));
      await tester.pumpAndSettle();
      for (final entry in {
        'expense-title': 'هزینه تعمیر',
        'expense-amount': '100',
      }.entries) {
        final field = find.descendant(
          of: find.byKey(ValueKey(entry.key)),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      await tester.tap(find.text('تعمیرات'));
      await tester.tap(find.text('تعمیرکار نمونه'));
      await tester.ensureVisible(find.text('ثبت هزینه'));
      await tester.tap(find.text('ثبت هزینه'));
      await tester.pumpAndSettle();
      expect(server.expenseWrites, 1);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('expense-$expenseId')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('پرداخت‌ها و چک‌های هزینه'));
      await tester.tap(find.text('پرداخت‌ها و چک‌های هزینه'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byKey(const ValueKey('expense-payment-amount')),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, '40');
      await tester.ensureVisible(find.text('صندوق شعبه'));
      await tester.tap(find.text('صندوق شعبه'));
      await tester.ensureVisible(find.text('ثبت پرداخت هزینه'));
      await tester.tap(find.text('ثبت پرداخت هزینه'));
      await tester.pumpAndSettle();
      expect(server.expense['paidAmount'], 40);
      expect(server.disbursements.single['routing']['fundId'], previous.fundId);
      expect(find.text('پرداخت هزینه با موفقیت ثبت شد.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
