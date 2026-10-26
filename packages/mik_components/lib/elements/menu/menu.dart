import 'package:mik_variables/permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/menu/controller.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_consts/svgIcon.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_router/routing.dart';

import 'component/components.dart';

RxDouble offset = 0.0.obs;
SideMenuController sideMenucontroller = Get.put(SideMenuController());

class Menu extends GetView {
  ScrollController scrollController = ScrollController(keepScrollOffset: true);
  Menu({super.key});

  final List<MenuItem> menuItems = [
    MenuItem(
      1,
      IconsaxPlusLinear.category,
      'داشبورد',
      RoutesName.DASHBOARD,
      isPermission: true,
    ),
    MenuItem(
      2,
      IconsaxPlusLinear.receipt_search,
      'پیش فاکتور',
      RoutesName.INVOICEADD,
      arguments: {'type': 'pf', 'item': null, 'puid': null, 'isTabBar': false},
      isPermission: ((settings!.usePreFactor ?? false) && PermissionAccess.hasPermission(PermissionsName.invoicesPreCreate)),
    ),
    MenuItem(
      3,
      IconsaxPlusLinear.bag,
      'فروش',
      RoutesName.INVOICEADD,
      arguments: {
        'type': 'sell',
        'item': null,
        'puid': null,
        'isTabBar': false,
      },
      isPermission: PermissionAccess.hasPermission(PermissionsName.invoicesSellCreate),
    ),
    MenuItem(
      4,
      IconsaxPlusLinear.shopping_cart,
      'خرید',
      RoutesName.INVOICEADD,
      arguments: {'type': 'buy', 'item': null, 'puid': null, 'isTabBar': false},
      isPermission: PermissionAccess.hasPermission(PermissionsName.invoicesBuyCreate),
    ),
    MenuItem(
      9,
      IconsaxPlusLinear.box,
      'محصولات',
      RoutesName.PRODUCTS,
      isPermission: PermissionAccess.hasPermission(PermissionsName.productsMenu),
    ),
    MenuItem(
      10,
      IconsaxPlusLinear.people,
      'مشتریان',
      RoutesName.CUSTOMER,
      arguments: {'index': 0},
      isPermission: PermissionAccess.hasPermission(PermissionsName.customersMenu),
    ),
    MenuItem(
      8,
      IconsaxPlusLinear.receipt_text,
      'فاکتور ها',
      RoutesName.INVOICES,
      isPermission: false,
    ),
    MenuItem(
      5,
      IconsaxPlusLinear.money_4,
      'چک ها',
      RoutesName.CHEQUE,
      isPermission: PermissionAccess.hasPermission(PermissionsName.chequesMenu),
    ),
    MenuItem(
      6,
      IconsaxPlusLinear.money_send,
      'هزینه ها',
      RoutesName.COST,
      isPermission: (PermissionAccess.hasPermission(PermissionsName.costsView) || PermissionAccess.hasPermission(PermissionsName.costsViewAll)),
    ),
    MenuItem(
      7,
      IconsaxPlusLinear.document_text,
      'صورت حساب ها',
      RoutesName.BILL,
      isPermission: PermissionAccess.hasPermission(PermissionsName.accountsMenu),
    ),
    // MenuItem(7, IconsaxPlusLinear.routing, 'مسیریابی', RoutesName.FACTORDAY),

    MenuItem(
      11,
      SvgPicture.asset(
        SvgIcon.supplier,
        height: 20,
        width: 20,
        color: !darkMode.isTrue ? Colors.black : Colors.white,
      ),
      'تامین کنندگان',
      RoutesName.SUPPLIER,
      arguments: {'type': 'supplier'},
      isPermission: PermissionAccess.hasPermission(PermissionsName.suppliersMenu),
    ),
    MenuItem(
      12,
      SvgPicture.asset(
        SvgIcon.servicer,
        height: 25,
        width: 25,
        color: (darkMode.value
            ? AppColors.background
            : AppColors.backgroundDarkMode),
      ),
      'سرویس دهندگان',
      RoutesName.SERVICER,
      arguments: {'type': 'servicer'},
      isPermission: PermissionAccess.hasPermission(PermissionsName.servicersMenu),
    ),
    // MenuItem(13, IconsaxPlusLinear.people, 'بازاریاب', null),
    MenuItem(
      13,
      IconsaxPlusLinear.activity,
      'گزارشات',
      RoutesName.REPORTS,
      isPermission: PermissionAccess.hasAny([PermissionsName.reportsProfitView, PermissionsName.reportsQuantityView]),
    ),
    MenuItem(
      14,
      IconsaxPlusLinear.teacher,
      'مرکز آموزش',
      RoutesName.DRAWER_HELP,
      isPermission: true,
    ),
    // MenuItem(15, IconsaxPlusLinear.hashtag_up, 'میک اپ', null),
  ];

  // final scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // scrollController.jumpTo(sideMenucontroller.scrollOffset.value);

    return ListView.builder(
      padding: EdgeInsets.only(top: 10),
      controller: scrollController,
      itemCount: menuItems.length,
      itemBuilder: (_, index) {
        final item = menuItems[index];

        if (!item.isPermission && item.route != RoutesName.INVOICES) {
          return const SizedBox.shrink();
        }

        return Obx(
          () => Column(
            children: [
              ItemList(
                icon: item.icon,
                text: item.text,
                selected: sideMenucontroller.selectedId.value == item.id,
                onTap: () async {
                  sideMenucontroller.select(item.id);
                  if (item.route != null) {
                    await Get.offAllNamed(
                      item.route!,
                      arguments: item.arguments,
                    );
                  }
                },
              ),
              //  EndLine(),
            ],
          ),
        );
      },
    );
  }
}
