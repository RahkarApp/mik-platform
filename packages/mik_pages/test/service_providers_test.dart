import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/suppliers.dart';
import 'package:mik_pages/persons/supplier/server_controller.dart';
import 'package:mik_pages/persons/supplier/server_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'suppliers_test.dart'
    show SupplierServer, SupplierAssets, firstId, secondId, createdId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const type = AccountingPersonType.serviceProvider;
  late String root;
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var directory = Directory.current;
    while (!File('${directory.path}/mik-app/assets/fonts/RaviLight.ttf')
            .existsSync() &&
        directory.parent.path != directory.path) {
      directory = directory.parent;
    }
    root = directory.path;
    await (FontLoader('ravi')..addFont(
          File('$root/mik-app/assets/fonts/RaviLight.ttf')
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
      '$app service providers use payee routes, permissions and isolated durable retries',
      () async {
        final server = SupplierServer(app, type: type);
        await server.prepare();
        final notices = <(String, bool)>[];
        final c = SuppliersController(
          appId: app,
          type: type,
          onNotice: (m, ok) => notices.add((m, ok)),
        );
        addTearDown(c.onClose);
        await c.load();
        expect(notices, isEmpty);
        expect(c.items.length, 2);
        expect(c.items.first.type, type);
        final other = c.items.singleWhere((row) => row.id == secondId);
        server.updateAll = false;
        server.readAll = false;
        await c.load();
        expect(c.items.length, app == 'mik' ? 2 : 1);
        expect(c.canEdit(other), app == 'mik');
        if (app == 'mikyar') {
          expect(
            await c.create(
              other.name,
              '09121234567',
              kind: 'PERSON',
              item: other,
            ),
            isNull,
          );
          expect(server.writes, isEmpty);
        }
        server.create = false;
        await c.load();
        expect(c.canCreate, isFalse);
        expect(
          await c.create('غیرمجاز', '09121234567', kind: 'PERSON'),
          isNull,
        );
        expect(server.writes, isEmpty);
        server.create = true;
        await c.load();
        expect(
          await c.create('شرکت خدمات', '09121234567', kind: 'ORGANIZATION'),
          isNull,
        );
        expect(server.writes, isEmpty);
        server.lost = true;
        expect(
          await c.create(
            'شرکت خدمات',
            '۰۹۱۲۱۲۳۴۵۶۷',
            kind: 'ORGANIZATION',
            details: {
              'legalName': 'شرکت خدمات نمونه',
              'email': 'info@example.com',
              'addresses': [
                {
                  'addressId': firstId,
                  'title': 'دفتر',
                  'fullAddress': 'آدرس دفتر',
                  'isDefault': true,
                },
              ],
            },
          ),
          isNull,
        );
        final saved = c.pending.value!;
        expect(saved.type, type);
        // A supplier's purchase flow must never restore or send a service-provider command.
        final supplier = SuppliersFX.forContext(BusinessContext.forApp(app)!);
        expect(await supplier.restore(), isNull);
        await expectLater(supplier.send(saved), throwsFormatException);
        final resumed = SuppliersController(
          appId: app,
          type: type,
          onNotice: (m, ok) => notices.add((m, ok)),
        );
        addTearDown(resumed.onClose);
        await resumed.load();
        final created = (await resumed.create('', ''))!;
        expect(created.id, createdId);
        expect(created.phone, '+989121234567');
        expect(created.profile['legalName'], 'شرکت خدمات نمونه');
        expect(notices.last, ('سرویس‌دهنده با موفقیت ثبت شد.', true));
        expect(server.writes[0].body, server.writes[1].body);
        expect(
          server.writes[0].headers['idempotency-key'],
          server.writes[1].headers['idempotency-key'],
        );
        final edited = (await resumed.create(
          'خدمات جدید',
          created.phone!,
          kind: created.kind,
          item: created,
          details: created.profile,
          status: 'ARCHIVED',
        ))!;
        expect(edited.revision, 2);
        final body = jsonDecode(server.writes.last.body) as Map;
        expect(body['payeeId'], createdId);
        expect(body.containsKey('supplierId'), isFalse);
        expect(
          server.writes.last.url.path,
          endsWith('/v2/expenses/payees/update'),
        );
        expect(resumed.items.any((row) => row.id == createdId), isFalse);
        resumed.status.value = 'آرشیو';
        await resumed.load();
        expect(resumed.items.single.id, edited.id);
        server.read = false;
        notices.clear();
        await resumed.load();
        expect(resumed.items, isEmpty);
        expect(notices.single.$2, isFalse);
      },
    );

    testWidgets(
      '$app service-provider form defaults to person and saves through native components',
      (tester) async {
        final server = SupplierServer(app, type: type);
        await server.prepare();
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ToastificationWrapper(
            child: DefaultAssetBundle(
              bundle: SupplierAssets(root),
              child: GetMaterialApp(
                onGenerateRoute: navigation.MikRouter(
                  sharedRoutes: SharedRoutes.namedPages,
                ).generateRoute,
                theme: ThemeData(fontFamily: 'ravi'),
                home: SuppliersScreen(appId: app, type: type),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('سرویس‌دهندگان'), findsOneWidget);
        await tester.tap(find.text('سرویس‌دهنده جدید'));
        await tester.pumpAndSettle();
        expect(find.text('نوع سرویس‌دهنده را انتخاب کنید.'), findsNothing);
        for (final field in {
          'name': 'خدمات نمونه',
          'phone': '09121234567',
        }.entries) {
          await tester.enterText(
            find.descendant(
              of: find.byKey(ValueKey('supplier-${field.key}')),
              matching: find.byType(TextField),
            ),
            field.value,
          );
        }
        await tester.tap(find.text('افزودن'));
        await tester.pumpAndSettle();
        expect(jsonDecode(server.writes.single.body)['kind'], 'PERSON');
        expect(find.text('سرویس‌دهنده با موفقیت ثبت شد.'), findsOneWidget);
        expect(find.text('خدمات نمونه'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byKey(const ValueKey(createdId)));
        await tester.pumpAndSettle();
        expect(find.text('مجموع هزینه: نامشخص'), findsOneWidget);
        expect(find.text('مجموع خرید: نامشخص'), findsNothing);
        await tester.tap(find.text('ویرایش'));
        await tester.pumpAndSettle();
        expect(find.text('ویرایش سرویس‌دهنده'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
