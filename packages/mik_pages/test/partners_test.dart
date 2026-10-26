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
import 'package:mik_pages/persons/supplier/server_controller.dart';
import 'package:mik_pages/persons/supplier/server_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'suppliers_test.dart' show SupplierServer, SupplierAssets, createdId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String root;
  setUpAll(() async {
    var dir = Directory.current;
    while (!File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      if (dir.parent.path == dir.path) throw StateError('Workspace not found');
      dir = dir.parent;
    }
    root = dir.path;
    await (FontLoader('ravi')..addFont(
          File('$root/mik-app/assets/fonts/RaviLight.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });
  setUp(resetOnboardingStorage);
  tearDown(() {
    toastification.dismissAll(delayForAnimation: false);
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app partner manage, exact retry, revision and archive constraints',
      () async {
        final server = SupplierServer(app, type: AccountingPersonType.partner);
        await server.prepare();
        final notices = <(String, bool)>[];
        final c = SuppliersController(
          appId: app,
          type: AccountingPersonType.partner,
          onNotice: (m, success) => notices.add((m, success)),
        );
        addTearDown(c.onClose);
        await c.load();
        expect(notices, isEmpty); // Successful GETs stay silent.
        expect(c.items.length, 2);
        expect(c.canCreate, isTrue); // No invented partner.create permission.
        expect(await c.create('شریک', '', kind: 'PERSON'), isNull);
        expect(server.writes, isEmpty);
        for (final details in [
          <String, dynamic>{'legalName': 'bad\u0001name'},
          <String, dynamic>{'reference': 123},
          <String, dynamic>{
            'note': ['invalid'],
          },
        ]) {
          expect(
            await c.create(
              'شریک',
              '09121234567',
              kind: 'PERSON',
              details: details,
            ),
            isNull,
          );
        }
        expect(server.writes, isEmpty);
        server.lost = true;
        expect(
          await c.create(
            'شریک تازه',
            '۰۹۱۲۱۲۳۴۵۶۷',
            kind: 'PERSON',
            details: {'reference': 'REF-1', 'note': 'یادداشت'},
          ),
          isNull,
        );
        final restored = SuppliersController(
          appId: app,
          type: AccountingPersonType.partner,
        );
        addTearDown(restored.onClose);
        await restored.load();
        final created = (await restored.create('', ''))!;
        expect(created.id, createdId);
        expect(created.capitalBalance, 0);
        expect(
          server.writes[0].url.path,
          endsWith('/accounting/v2/capital/partners'),
        );
        expect(server.writes[0].body, server.writes[1].body);
        expect(
          server.writes[0].headers['idempotency-key'],
          server.writes[1].headers['idempotency-key'],
        );
        expect(jsonDecode(server.writes.first.body).keys.toSet(), {
          'name',
          'phone',
          'kind',
          'reference',
          'note',
        });
        server.wrongPartnerProfile = true;
        expect(
          await restored.create(
            'شریک ویرایش شده',
            created.phone!,
            kind: 'PERSON',
            item: created,
            details: created.profile,
          ),
          isNull,
        );
        expect(restored.pending.value, isNotNull);
        final mismatched = server.writes.last;
        final edited = (await restored.create(
          'شریک ویرایش شده',
          created.phone!,
          kind: 'PERSON',
          item: created,
          details: created.profile,
        ))!;
        expect(edited.revision, 2);
        expect(server.writes.last.body, mismatched.body);
        expect(
          server.writes.last.headers['idempotency-key'],
          mismatched.headers['idempotency-key'],
        );
        expect(
          server.writes.last.url.path,
          endsWith('/capital/partners/update'),
        );
        expect(
          await restored.create(
            created.name,
            created.phone!,
            kind: 'PERSON',
            item: created,
            details: created.profile,
          ),
          isNull,
        );
        expect(restored.commandError.value, contains('نسخه جدید'));
        expect(restored.pending.value, isNull);
        server.rows.singleWhere(
          (r) => r['partnerId'] == createdId,
        )['capitalBalance'] = 100;
        expect(
          await restored.create(
            edited.name,
            edited.phone!,
            kind: 'PERSON',
            item: edited,
            details: edited.profile,
            status: 'ARCHIVED',
          ),
          isNull,
        );
        expect(restored.commandError.value, contains('قابل آرشیو نیست'));
        expect(restored.pending.value, isNull);
        server.rows.singleWhere(
          (r) => r['partnerId'] == createdId,
        )['capitalBalance'] = 0;
        expect(
          (await restored.create(
            edited.name,
            edited.phone!,
            kind: 'PERSON',
            item: edited,
            details: edited.profile,
            status: 'ARCHIVED',
          ))!.status,
          'ARCHIVED',
        );
        server.create = false;
        server.update = false;
        await restored.load();
        expect(restored.canCreate, isFalse);
        final writes = server.writes.length;
        expect(
          await restored.create('بدون مجوز', '09121234567', kind: 'PERSON'),
          isNull,
        );
        expect(server.writes.length, writes);
        server.read = false;
        await restored.load();
        expect(restored.items, isEmpty);
        expect(restored.error.value, isNotNull);
      },
    );

    testWidgets('$app partner uses native form with only supported fields', (
      tester,
    ) async {
      final server = SupplierServer(app, type: AccountingPersonType.partner);
      await server.prepare();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: SupplierAssets(root),
          child: ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: SuppliersScreen(
                appId: app,
                type: AccountingPersonType.partner,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('شریک جدید'));
      await tester.pumpAndSettle();
      expect(find.text('آدرس‌ها'), findsNothing);
      expect(find.text('افزودن آدرس'), findsNothing);
      for (final field in {
        'name': 'شریک تازه',
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
      expect(find.text('شریک با موفقیت ثبت شد.'), findsOneWidget);
      expect(jsonDecode(server.writes.single.body).keys.toSet(), {
        'name',
        'phone',
        'kind',
      });
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(createdId)));
      await tester.pumpAndSettle();
      expect(find.text('مانده سرمایه: ۰'), findsWidgets);
      expect(find.text('مانده جاری: ۰'), findsOneWidget);
      expect(find.text('ویرایش'), findsOneWidget);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
