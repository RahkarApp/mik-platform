import 'package:mik_router/mik_router.dart' as nav_routes;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/multiFab.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_components/elements/productImage.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_data/utils/fx/product_facts.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/fx/warehouse.dart';
import 'package:mik_data/utils/saveHelper.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/product/screen/tabs/controllers/cat.dart';
import 'package:mik_pages/product/screen/tabs/controllers/product.dart';
import 'package:mik_pages/product/screen/tabs/controllers/property.dart';
import 'package:mik_pages/product/screen/tabs/controllers/store.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_variables/variable.dart';

import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:text_scroll/text_scroll.dart';

import 'controller.dart';
import 'tabs/cat/cat_tree_helper.dart';
import 'components/propertyItem.dart';
import '../brand/screen.dart';
import '../brand/controller.dart';
import '../warehouse/controller.dart';
import '../warehouse/screen.dart';

part './components/productItem.dart';
part './components/pim_product_item.dart';
part './components/warehouseItem.dart';
part 'tabs/cat/cat.dart';
part 'tabs/cat/cat_manage_screen.dart';
part 'tabs/cat/add_cat_form.dart';
part 'tabs/cat/cat_tree_view.dart';
part 'tabs/product.dart';
part 'tabs/store.dart';
part 'tabs/property.dart';

ProductDashboardController productDashboardController = Get.put(
  ProductDashboardController(),
);

ProductTabDashboardController productTabDashboardController = Get.put(
  ProductTabDashboardController(),
);

ProductPropertyTabDashboardController productPropertyTabDashboardController =
    Get.put(ProductPropertyTabDashboardController());

CatTabDashboardController catTabDashboardController = Get.put(
  CatTabDashboardController(),
);

WarehouseTabDashboardController warehouseTabDashboardController = Get.put(
  WarehouseTabDashboardController(),
);

ProductBrandController productBrandController = Get.put(
  ProductBrandController(),
);

final warehouseManagementController = Get.put(WarehouseManagementController());

class ProductDashboardScreen extends GetView {
  final String appId;
  ProductDashboardScreen({super.key, this.appId = 'mik'});
  final List<String> tabs = const [
    'محصولات',
    'ویژگی‌ها',
    'انبارها',
    'دسته‌بندی‌ها',
    'برندها',
  ];
  final textCTL = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        children: [
          MyTabBar(
            tabs: tabs,
            currentIndex: productDashboardController.index.value,
            index: (value) {
              if (warehouseManagementController.saving.value ||
                  catTabDashboardController.saving.value ||
                  productPropertyTabDashboardController.saving.value ||
                  productBrandController.saving.value) {
                return;
              }
              productDashboardController.index.value = value;
              MySearchBarController.unfoces();
              textCTL.clear();
              productDashboardController.search.value = '';
            },
          ),
          const SizedBox(height: 5),
          MySearchBar(
            controller: textCTL,
            enableScanner:
                productDashboardController.index.value != 0 &&
                productDashboardController.index.value != 4,
            hintText: productDashboardController.index.value == 0
                ? 'برای جستجو نام یا شناسه محصول را وارد کنید...'
                : productDashboardController.index.value == 4
                ? 'برای جستجو نام یا شناسه برند را وارد کنید...'
                : null,
            type: productDashboardController.index.value == 0
                ? SearchBarType.product
                : productDashboardController.index.value == 1
                ? SearchBarType.productProperty
                : productDashboardController.index.value == 2
                ? SearchBarType.warehouse
                : productDashboardController.index.value == 3
                ? SearchBarType.category
                : SearchBarType.text,
            callback: (v) {
              productDashboardController.search.value = v;
              if (productDashboardController.index.value == 0) {
                productTabDashboardController.search(v);
              } else if (productDashboardController.index.value == 1) {
                productPropertyTabDashboardController.search(v);
              } else if (productDashboardController.index.value == 2) {
                warehouseManagementController.search(v);
              } else if (productDashboardController.index.value == 3) {
                catTabDashboardController.search(v);
              } else if (productDashboardController.index.value == 4) {
                productBrandController.search(v);
              }
            },
          ),
          Expanded(
            child: Obx(
              () => productDashboardController.search.value.isEmpty
                  ? child()
                  : child(),
            ),
          ),
        ],
      ),
    );
  }

  Widget child() {
    switch (productDashboardController.index.value) {
      case 0:
        return ProductTabDashboard(appId: appId);
      case 1:
        return ProductPropertyTabDashboard(appId: appId);
      case 2:
        return WarehouseManagementScreen(
          appId: appId,
          controller: warehouseManagementController,
        );
      case 3:
        return CatTabDashboard(appId: appId);
      case 4:
        return ProductBrandsScreen(
          appId: appId,
          controller: productBrandController,
        );
      default:
        return ProductTabDashboard(appId: appId);
    }
  }
}

Widget buildCatManageRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return CatManageScreen(
    controller: args.required<CatTabDashboardController>('controller'),
    item: args.optional<PimCategory>('item'),
  );
}
