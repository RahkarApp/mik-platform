import 'package:mik_variables/permissions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mik_pages/persons/supplier/server_screen.dart';
import 'package:mik_pages/personnel/screen.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_pages/persons/controller.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_variables/variable.dart';

import 'components/item.dart';

PersonScreenController personScreenController = Get.put(
  PersonScreenController(),
);

class PersonScreen extends GetView {
  const PersonScreen(this.type, {super.key});
  final String type;

  @override
  Widget build(BuildContext context) {
    if (type == 'marketer') return const PersonnelScreen(appId: 'mik');
    if (type == 'partner') {
      return const SuppliersScreen(
        appId: 'mik',
        type: AccountingPersonType.partner,
      );
    }
    if (type == 'supplier') return const SuppliersScreen(appId: 'mik');
    if (type == 'servicer') {
      return const SuppliersScreen(
        appId: 'mik',
        type: AccountingPersonType.serviceProvider,
      );
    }
    return Main(
      initState: () async => {
        await Future.delayed(Duration(seconds: 1)),
        await personScreenController.init(type),
      },
      floatingActionButton: Obx(
        () =>
            (type == 'supplier' &&
                    PermissionAccess.hasPermission(
                      PermissionsName.suppliersCreate,
                    )) ||
                (type == 'servicer' &&
                    PermissionAccess.hasPermission(
                      PermissionsName.servicersCreate,
                    ))
            ? MyFAB(
                icon: IconsaxPlusLinear.add,
                text: personScreenController.addName.value,
                onTap: () async {
                  await Get.toNamed(
                    RoutesName.PERSONEADD,
                    arguments: {
                      'title': personScreenController.addName.value,
                      'item': null,
                      'mobile': null,
                    },
                  );
                  // init();
                },
              )
            : Container(),
      ),
      header: Obx(
        () => Header.page(
          context,
          isBack: false,
          text: personScreenController.name.value,
        ),
      ),
      child: (d) => Column(
        children: [
          const SizedBox(height: 10),
          MySearchBar(
            type: SearchBarType.user,
            callback: (c) {
              personScreenController.search = c;
              personScreenController.init(type);
            },
          ),
          Obx(
            () => Expanded(
              child: personScreenController.prs.isNotEmpty
                  ? ListView.builder(
                      itemCount: personScreenController.prs.length,
                      itemBuilder: (context, i) {
                        return PersonItem(
                          personScreenController.prs[i],
                          i + 1 == personScreenController.prs.length,
                          type,
                          callback: (v) => personScreenController.init(type),
                        );
                      },
                    )
                  : EmptyList(
                      text: 'هیچ فردی تعریف نشده است.',
                      icon: IconsaxPlusLinear.user_search,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
