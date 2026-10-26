import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:mik_variables/permissions.dart';

void main() {
  tearDown(PermissionAccess.clear);
  test('staff owner id zero does not implicitly grant owner privileges', () {
    PermissionAccess.load('', personnelId: 0);
    expect(
      PermissionAccess.hasPermission(PermissionsName.productsEdit),
      isFalse,
    );
    PermissionAccess.useOwner();
    expect(
      PermissionAccess.hasPermission(PermissionsName.productsEdit),
      isTrue,
    );
    expect(PermissionAccess.hasPermission('unknown'), isFalse);
  });
  test('switching accounts and revoking all rights clears prior grants', () {
    PermissionAccess.useOwner();
    PermissionAccess.load('["products.menu"]', personnelId: 2);
    expect(
      PermissionAccess.hasPermission(PermissionsName.productsEdit),
      isFalse,
    );
    PermissionAccess.load('["products.edit"]', personnelId: 3);
    expect(
      PermissionAccess.hasPermission(PermissionsName.productsEdit),
      isTrue,
    );
    PermissionAccess.load('', personnelId: 3);
    expect(PermissionAccess.permissionList, isEmpty);
  });
  test(
    'own rights only apply to records created by the current staff account',
    () {
      bool can(int? id) => PermissionAccess.canAccessRecord(
        own: PermissionsName.chequesView,
        all: PermissionsName.chequesViewAll,
        inserter: id,
      );
      PermissionAccess.load('["cheques.view"]', personnelId: 7);
      expect(can(7), isTrue);
      expect(can(8), isFalse);
      expect(can(null), isFalse);
      PermissionAccess.load('["cheques.view.all"]', personnelId: 7);
      expect(can(8), isTrue);
      PermissionAccess.clear();
      expect(can(7), isFalse);
    },
  );
  testWidgets('permission changes rebuild observers immediately', (
    tester,
  ) async {
    PermissionAccess.load('["products.edit"]', personnelId: 7);
    await tester.pumpWidget(
      MaterialApp(
        home: Obx(
          () => Text(
            PermissionAccess.hasPermission(PermissionsName.productsEdit)
                ? 'allowed'
                : 'denied',
          ),
        ),
      ),
    );
    expect(find.text('allowed'), findsOneWidget);
    PermissionAccess.load('', personnelId: 7);
    await tester.pump();
    expect(find.text('denied'), findsOneWidget);
  });
}
