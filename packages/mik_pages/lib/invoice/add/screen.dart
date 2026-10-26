import 'package:mik_router/mik_router.dart' as nav_routes;
// ignore_for_file: unnecessary_null_comparison, unused_local_variable, invalid_use_of_protected_member, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:mik_pages/invoice/add/sale_products.dart';
import 'package:mik_pages/invoice/add/purchase_products.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/branchInput.dart';
import 'package:mik_components/elements/input/personInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/invoice/add/components/item/components/amount.dart';
import 'package:mik_pages/invoice/add/components/selectproduct.dart';
import 'package:mik_pages/invoice/add/controller.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

import 'components/item/item.dart';
import 'components/model.dart';

InvoiceAddScreenController invoiceAddScreenController = Get.put(
  InvoiceAddScreenController(),
);

class InvoiceAddScreen extends StatefulWidget {
  String? type;
  InvoiceDB? item;
  String? puid;
  bool? isBack;

  bool? isTabBar = true;
  InvoiceAddScreen({
    //required
    this.isBack = false,
    this.type,
    this.item,
    this.puid,
    this.isTabBar = true,
    super.key,
  });

  @override
  State<InvoiceAddScreen> createState() => _InvoiceAddScreenState();
}

class _InvoiceAddScreenState extends State<InvoiceAddScreen> {
  @override
  void initState() {
    // TODO: implement initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.item != null
          ? invoiceAddScreenController.isEdit = true
          : invoiceAddScreenController.isEdit = false;
      AmountChangeInvoice.firstAmounts = {};
      invoiceAddScreenController.type = widget.type;
      invoiceAddScreenController.item = widget.item;
      invoiceAddScreenController.puid = widget.puid;
      invoiceAddScreenController.isTabBar = widget.isTabBar;
      invoiceAddScreenController.rxtype.value = widget.type ?? '';
      invoiceAddScreenController.typeMode.value = InvoiceFX.toTypeMode(
        invoiceAddScreenController.rxtype.value,
      );
      // if (settings!.usePreFactor! &&
      //     !invoiceAddScreenController.tabs.contains('پیش‌فاکتور')) {
      //   invoiceAddScreenController.tabs = [
      //     'پیش‌فاکتور',
      //     ...invoiceAddScreenController.tabs
      //   ];
      // }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Main(
      initState: () async => {
        await Future.delayed(Duration(seconds: 1)),
        await invoiceAddScreenController.init(),
      },
      forceNet: true,
      header: Obx(
        () => Header.page(
          context,
          text: InvoiceFX.pageTitle(
            invoiceAddScreenController.item,
            InvoiceFX.toType(invoiceAddScreenController.typeMode.value),
          ),
          isBack: widget.isBack ?? false,
        ),
      ),
      child: (d) => Obx(() => Column(
        children: [
          const SizedBox(height: 10),
          if (invoiceAddScreenController.item == null &&
              widget.isTabBar != false)
            MyTab(
              tab: [...invoiceAddScreenController.tabs, 'پیش‌فاکتور'],
              value: invoiceAddScreenController.typeMode,
              callback: (v) {
                invoiceAddScreenController.typeMode.value = v;
                invoiceAddScreenController.rxtype.value = InvoiceFX.toType(
                  invoiceAddScreenController.typeMode.value,
                );
                invoiceAddScreenController.productSelected.value = [];
              },
            ),
          if (invoiceAddScreenController.item == null)
            const SizedBox(height: 5),
          if (widget.item == null && invoiceAddScreenController.typeMode.value == 'فروش')
            const Expanded(child: SaleInvoiceProducts(appId: 'mik'))
          else if (widget.item == null && invoiceAddScreenController.typeMode.value == 'خرید')
            const Expanded(child: PurchaseInvoiceProducts(appId: 'mik'))
          else if (widget.item == null && invoiceAddScreenController.typeMode.value == 'پیش‌فاکتور')
            const Expanded(child: SaleInvoiceProducts(key: ValueKey('proforma'), appId: 'mik', type: 'PROFORMA'))
          else ...[
          Obx(
            () => invoiceAddScreenController.typeMode.value == 'فروش'
                ? Row(
                    children: [
                      Flexible(
                        flex: 6,
                        child: BranchInput(
                          readOnly: invoiceAddScreenController.item != null,
                          controller: invoiceAddScreenController.branchCtl,
                          name: 'شعبه',
                          onChanged: (uid) {
                            invoiceAddScreenController.branchUID.value = uid;
                            if (uid != null && uid != '') {
                              BranchDB br = branch.values.firstWhere(
                                (d) => d.uid == uid,
                              );
                              BranchAccessDB ba = branchAccess.values
                                  .firstWhere((d) => d.branchUID == uid);
                              for (
                                var i = 0;
                                i <
                                    invoiceAddScreenController
                                        .productSelected
                                        .value
                                        .length;
                                i++
                              ) {
                                for (
                                  var j = 0;
                                  j <
                                      invoiceAddScreenController
                                          .productSelected
                                          .value[i]
                                          .pro
                                          .length;
                                  j++
                                ) {
                                  invoiceAddScreenController
                                          .productSelected
                                          .value[i]
                                          .pro[j]
                                          .warehouseUID =
                                      '';
                                  if (!ba.warehouseUID!.contains(
                                    invoiceAddScreenController
                                        .productSelected
                                        .value[i]
                                        .pro[j]
                                        .warehouseUID,
                                  )) {
                                    BranchDB br = branch.values.firstWhere(
                                      (b) => b.uid == uid,
                                    );
                                    if (br.defaultWarehouse != null &&
                                        br.defaultWarehouse != '') {
                                      if (ProductFX.productInWarehouse(
                                            invoiceAddScreenController
                                                .productSelected
                                                .value[i]
                                                .uid,
                                            invoiceAddScreenController
                                                .productSelected
                                                .value[i]
                                                .pro[j]
                                                .uid,
                                            br.defaultWarehouse!,
                                          ) >
                                          0) {
                                        invoiceAddScreenController
                                                .productSelected
                                                .value[i]
                                                .pro[j]
                                                .warehouseUID =
                                            br.defaultWarehouse!;
                                      }
                                    }
                                    if (invoiceAddScreenController
                                                .productSelected
                                                .value[i]
                                                .pro[j]
                                                .warehouseUID ==
                                            null ||
                                        invoiceAddScreenController
                                                    .productSelected
                                                    .value[i]
                                                    .pro[j]
                                                    .warehouseUID !=
                                                null &&
                                            invoiceAddScreenController
                                                    .productSelected
                                                    .value[i]
                                                    .pro[j]
                                                    .warehouseUID ==
                                                '') {
                                      BranchAccessDB ba = branchAccess.values
                                          .firstWhere(
                                            (b) => b.branchUID == uid,
                                          );
                                      if (ba.warehouseUID!.length == 1) {
                                        if (ProductFX.productInWarehouse(
                                              invoiceAddScreenController
                                                  .productSelected
                                                  .value[i]
                                                  .uid,
                                              invoiceAddScreenController
                                                  .productSelected
                                                  .value[i]
                                                  .pro[j]
                                                  .uid,
                                              ba.warehouseUID![0],
                                            ) >
                                            0) {
                                          invoiceAddScreenController
                                                  .productSelected
                                                  .value[i]
                                                  .pro[j]
                                                  .warehouseUID =
                                              ba.warehouseUID![0];
                                        }
                                      } else {
                                        for (var baw in ba.warehouseUID!) {
                                          if (ProductFX.productInWarehouse(
                                                invoiceAddScreenController
                                                    .productSelected
                                                    .value[i]
                                                    .uid,
                                                invoiceAddScreenController
                                                    .productSelected
                                                    .value[i]
                                                    .pro[j]
                                                    .uid,
                                                baw,
                                              ) >
                                              0) {
                                            invoiceAddScreenController
                                                    .productSelected
                                                    .value[i]
                                                    .pro[j]
                                                    .warehouseUID =
                                                baw;
                                          }
                                          if (invoiceAddScreenController
                                                      .productSelected
                                                      .value[i]
                                                      .pro[j]
                                                      .warehouseUID !=
                                                  null &&
                                              invoiceAddScreenController
                                                      .productSelected
                                                      .value[i]
                                                      .pro[j]
                                                      .warehouseUID !=
                                                  '')
                                            break;
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          },
                        ),
                      ),
                      Obx(
                        () => invoiceAddScreenController.branchUID.value != ''
                            ? Flexible(
                                child: IconButton(
                                  onPressed: () {
                                    invoiceAddScreenController.branchCtl
                                        .clear();
                                    invoiceAddScreenController.branchUID.value =
                                        '';
                                  },
                                  icon: const Icon(
                                    IconsaxPlusLinear.close_circle,
                                  ),
                                  color: AppColors.error.withValues(alpha: 0.7),
                                ),
                              )
                            : Container(),
                      ),
                    ],
                  )
                : Container(),
          ),
          Row(
            children: [
              Flexible(
                flex: 6,
                child: Obx(
                  () => PersonInput(
                    rightPadding: 70,
                    controller: invoiceAddScreenController.personCtl,
                    readOnly:
                        invoiceAddScreenController.personCtl.text == 'اول دوره',
                    type: invoiceAddScreenController.typeMode.value == 'جدید'
                        ? 'unselected'
                        : invoiceAddScreenController.typeMode.value == 'خرید'
                        ? 'supplier'
                        : 'customer',
                    name: invoiceAddScreenController.typeMode.value == 'جدید'
                        ? 'طرف حساب'
                        : invoiceAddScreenController.typeMode.value == 'خرید'
                        ? 'تامین‌کننده'
                        : 'مشتری',
                    focusNode: invoiceAddScreenController.personF,
                    require: true,
                    onChanged: (int id, uid) {
                      invoiceAddScreenController.personId.value = id;
                      invoiceAddScreenController.personUID.value = uid;
                    },
                  ),
                ),
              ),
              Obx(
                () => invoiceAddScreenController.personId.value != 0
                    ? Flexible(
                        child: IconButton(
                          onPressed: () => PersonFX.csHistory(
                            context,
                            invoiceAddScreenController.personUID.value,
                            'customer',
                          ),
                          icon: const Icon(IconsaxPlusLinear.info_circle),
                          color: AppColors.primary.withValues(alpha: 0.7),
                        ),
                      )
                    : Container(),
              ),
            ],
          ),
          if (invoiceAddScreenController.productSelected.isNotEmpty)
            Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: 15),
              child: Text(
                'اقلام فاکتور:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: Obx(
              () => invoiceAddScreenController.productSelected.isEmpty
                  ? EmptyList(
                      text: 'محصولی انتخاب نشده است.',
                      icon: IconsaxPlusLinear.box_remove,
                    )
                  : Obx(
                      () =>
                          invoiceAddScreenController
                                  .productSelectedCahnge
                                  .isFalse ||
                              invoiceAddScreenController
                                  .productSelectedCahnge
                                  .isTrue
                          ? ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: invoiceAddScreenController
                                  .productSelected
                                  .length,
                              itemBuilder: (context, i) {
                                return Obx(
                                  () =>
                                      invoiceAddScreenController
                                              .change
                                              .isTrue ||
                                          invoiceAddScreenController
                                              .change
                                              .isFalse
                                      ? ProductItemInvoice(
                                          item: invoiceAddScreenController
                                              .productSelected
                                              .value[i],
                                          type: invoiceAddScreenController
                                              .rxtype
                                              .value,
                                          isEdit:
                                              invoiceAddScreenController.isEdit,
                                          changeAmount: (prouid, a) {
                                            if (prouid == '-') {
                                              invoiceAddScreenController
                                                      .productSelected[i]
                                                      .pro[0]
                                                      .amount =
                                                  a;
                                            } else {
                                              int index =
                                                  invoiceAddScreenController
                                                      .productSelected[i]
                                                      .pro
                                                      .indexWhere(
                                                        (t) => t.uid == prouid,
                                                      );
                                              invoiceAddScreenController
                                                      .productSelected[i]
                                                      .pro[index]
                                                      .amount =
                                                  a;
                                            }
                                            if (a == 0) {
                                              int index =
                                                  invoiceAddScreenController
                                                      .productSelected[i]
                                                      .pro
                                                      .indexWhere(
                                                        (t) => t.uid == prouid,
                                                      );
                                              invoiceAddScreenController
                                                  .productSelected[i]
                                                  .pro
                                                  .removeAt(index);
                                              if (invoiceAddScreenController
                                                  .productSelected[i]
                                                  .pro
                                                  .isEmpty) {
                                                invoiceAddScreenController
                                                    .productSelected
                                                    .removeAt(i);
                                              }
                                            }
                                            invoiceAddScreenController
                                                .priceFind();
                                            invoiceAddScreenController.change
                                                .toggle();
                                          },
                                          changePrice: (prouid, p) {
                                            if (prouid == '-') {
                                              invoiceAddScreenController
                                                      .productSelected[i]
                                                      .pro[0]
                                                      .price =
                                                  p;
                                            } else {
                                              int index =
                                                  invoiceAddScreenController
                                                      .productSelected[i]
                                                      .pro
                                                      .indexWhere(
                                                        (t) => t.uid == prouid,
                                                      );
                                              invoiceAddScreenController
                                                      .productSelected[i]
                                                      .pro[index]
                                                      .price =
                                                  p;
                                            }
                                            invoiceAddScreenController
                                                .priceFind();
                                            invoiceAddScreenController.change
                                                .toggle();
                                          },
                                          changeWarehouse: (prouid, w) {
                                            if (prouid == '-') {
                                              invoiceAddScreenController
                                                      .productSelected[i]
                                                      .pro[0]
                                                      .warehouseUID =
                                                  w;
                                            } else {
                                              int index =
                                                  invoiceAddScreenController
                                                      .productSelected[i]
                                                      .pro
                                                      .indexWhere(
                                                        (t) => t.uid == prouid,
                                                      );
                                              invoiceAddScreenController
                                                      .productSelected[i]
                                                      .pro[index]
                                                      .warehouseUID =
                                                  w;
                                            }
                                            int inx = invoiceAddScreenController
                                                .productSelected[i]
                                                .pro
                                                .indexWhere(
                                                  (t) => t.uid == prouid,
                                                );
                                            var prp = invoiceAddScreenController
                                                .productSelected[i]
                                                .pro[inx];
                                            if (invoiceAddScreenController
                                                    .rxtype
                                                    .value ==
                                                'sell') {
                                              var ww = warehouse.values
                                                  .where(
                                                    (f) =>
                                                        f.wuid == w &&
                                                        f.puid ==
                                                            invoiceAddScreenController
                                                                .productSelected[i]
                                                                .uid &&
                                                        f.prouid == prp.uid,
                                                  )
                                                  .toList()[0];
                                              if (ww.inventory < prp.amount) {
                                                invoiceAddScreenController
                                                        .productSelected[i]
                                                        .pro[inx]
                                                        .amount =
                                                    ww.inventory;
                                                Alert.warning(
                                                  'تعداد به اندازه موجودی انبار تغییر کرد.',
                                                );
                                              }
                                            }
                                            invoiceAddScreenController
                                                .priceFind();
                                            invoiceAddScreenController.change
                                                .toggle();
                                          },
                                          branchUID: invoiceAddScreenController
                                              .branchUID
                                              .value,
                                          index: i,
                                        )
                                      // InvoiceProductItem(
                                      //     item: productSelected[i],
                                      //     type: rxtype.value,
                                      //     changeAmount: (a) {},
                                      //     changePrice: (p) {},
                                      //     changeWarehouse: (w) {},
                                      //     branchUID: branchUID.value,
                                      //   )
                                      // ProductItemInvoice(
                                      //     index: i + 1,
                                      //     type: rxtype.value,
                                      //     branchUID: branchUID.value,
                                      // item: productSelected[i],
                                      //   changeAmount: (v) {
                                      //     if (v > 0) {
                                      //       productSelected[i].amount = v;
                                      //     } else if (v == 0) {
                                      //       productSelected.removeAt(i);
                                      //     }
                                      //     addNew();
                                      //     _change.toggle();
                                      //   },
                                      //   changePrice: (p) {
                                      //     //  rxtype.value == 'buy' ? productSelected[i].buyPrice = p : productSelected[i].price = p;
                                      //     addNew();
                                      //     _change.toggle();
                                      //   },
                                      //   changeWarehouse: (w) {
                                      //     addNew();
                                      //     _change.toggle();
                                      //   },
                                      // )
                                      : Container(),
                                );
                              },
                            )
                          : Container(),
                    ),
            ),
          ),
          Obx(
            () =>
                (invoiceAddScreenController.typeMode.value == 'جدید' ||
                    invoiceAddScreenController.typeMode.value == '')
                ? Container()
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Flexible(
                              flex: 3,
                              child: BTN(
                                name: 'افزودن کالا',
                                color: darkMode.isFalse
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade700,
                                navigate: true,
                                icon: IconsaxPlusLinear.box,
                                onTap: () {
                                  if (!Responsive.isMobile(context)) {
                                    MyBottomSheet.view(
                                      context,
                                      child: (d) => SelectProductForInvoice(
                                        productType: 'product',
                                        type: invoiceAddScreenController
                                            .rxtype
                                            .value,
                                        selected: invoiceAddScreenController
                                            .productSelected,
                                        branchUID: invoiceAddScreenController
                                            .branchUID
                                            .value,
                                        callback: (List<InvoiceItemModel> v) {
                                          invoiceAddScreenController
                                                  .productSelected
                                                  .value =
                                              [];
                                          invoiceAddScreenController
                                                  .productSelected
                                                  .value =
                                              v;

                                          invoiceAddScreenController.addNew();
                                          if (warehouses.length == 1) {
                                            for (
                                              int i = 0;
                                              i <
                                                  invoiceAddScreenController
                                                      .productSelected
                                                      .length;
                                              i++
                                            ) {
                                              invoiceAddScreenController
                                                  .productSelected[i]
                                                  .pro
                                                  .forEach((p) {
                                                    p.warehouseUID =
                                                        warehouses[0];
                                                  });
                                            }
                                          }
                                        },
                                      ),
                                      title: 'افزودن به فاکتور',
                                      initialChildSize: 400,
                                      height: 700,
                                      width: 600,
                                    );
                                    return;
                                  }

                                  Get.toNamed(
                                        nav_routes
                                            .RoutesName
                                            .SELECT_PRODUCT_FOR_INVOICE,
                                        arguments: {
                                          'productType': 'product',
                                          'type': invoiceAddScreenController
                                          .rxtype
                                          .value,
                                          'selected': invoiceAddScreenController
                                          .productSelected,
                                          'branchUID': invoiceAddScreenController
                                          .branchUID
                                          .value,
                                          'callback': (List<InvoiceItemModel> v) {
                                        invoiceAddScreenController
                                                .productSelected
                                                .value =
                                            [];
                                        invoiceAddScreenController
                                                .productSelected
                                                .value =
                                            v;
                                        invoiceAddScreenController.addNew();
                                        if (warehouses.length == 1) {
                                          for (
                                            int i = 0;
                                            i <
                                                invoiceAddScreenController
                                                    .productSelected
                                                    .length;
                                            i++
                                          ) {
                                            invoiceAddScreenController
                                                .productSelected[i]
                                                .pro
                                                .forEach((p) {
                                                  p.warehouseUID =
                                                      warehouses[0];
                                                });
                                          }
                                        }
                                      },
                                        },
                                        preventDuplicates: false,
                                  );
                                },
                              ),
                            ),
                            if (invoiceAddScreenController.typeMode.value !=
                                    'جدید' &&
                                invoiceAddScreenController.rxtype.value !=
                                    'buy')
                              Flexible(
                                flex: 3,
                                child: BTN(
                                  name: 'افزودن خدمت',
                                  navigate: true,
                                  color: darkMode.isFalse
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade700,
                                  icon: IconsaxPlusLinear.tag_2,
                                  onTap: () {
                                    if (!Responsive.isMobile(context)) {
                                      MyBottomSheet.view(
                                        context,
                                        child: (d) => SelectProductForInvoice(
                                          productType: 'service',
                                          type: invoiceAddScreenController
                                              .rxtype
                                              .value,
                                          selected: invoiceAddScreenController
                                              .productSelected,
                                          callback: (List<InvoiceItemModel> v) {
                                            invoiceAddScreenController
                                                    .productSelected
                                                    .value =
                                                v;
                                            invoiceAddScreenController.addNew();
                                          },
                                        ),
                                        title: 'افزودن به فاکتور',
                                        initialChildSize: 400,
                                        height: 700,
                                        width: 600,
                                      );
                                      return;
                                    }

                                    Get.toNamed(
                                          nav_routes
                                              .RoutesName
                                              .SELECT_PRODUCT_FOR_INVOICE,
                                          arguments: {
                                            'productType': 'service',
                                            'type': invoiceAddScreenController
                                            .rxtype
                                            .value,
                                            'selected': invoiceAddScreenController
                                            .productSelected,
                                            'callback': (List<InvoiceItemModel> v) {
                                          invoiceAddScreenController
                                                  .productSelected
                                                  .value =
                                              v;
                                          invoiceAddScreenController.addNew();
                                        },
                                          },
                                          preventDuplicates: false,
                                    );
                                  },
                                ),
                              ),
                            Flexible(
                              // flex: (rxtype.value != 'buy') ? 2 : 3,
                              child: BTN(
                                name: '',
                                navigate: true,
                                color: darkMode.isFalse
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade700,
                                icon: IconsaxPlusLinear.scan,
                                onTap: () => invoiceAddScreenController
                                    .barcodeScan(context),
                              ),
                            ),
                            Flexible(
                              child: BTN(
                                name: '',
                                navigate: true,
                                color: darkMode.isFalse
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade700,
                                icon: IconsaxPlusLinear.arrow_swap_horizontal,
                                disabled: true,
                                onTap: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.only(
                          right: 20,
                          left: 20,
                          top: 5,
                          bottom: 5,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'مبلغ سفارش: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Obx(
                              () => Text(
                                Price.showWithCurrency(
                                  invoiceAddScreenController.totalPrice.value,
                                ),
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: BTN(
                          name: 'ادامه',
                          color: AppColors.primary,
                          icon: IconsaxPlusLinear.tick_square,
                          onTap: () async {
                            if (invoiceAddScreenController.rxtype.value !=
                                'buy') {
                              for (
                                var i = 0;
                                i <
                                    invoiceAddScreenController
                                        .productSelected
                                        .length;
                                i++
                              ) {
                                var e = invoiceAddScreenController
                                    .productSelected[i];
                                for (var j = 0; j < e.pro.length; j++) {
                                  if (ProductFX.findBuyPrice(
                                        e.uid,
                                        prouid: e.pro[j].uid,
                                      ) >
                                      e.pro[j].price) {
                                    return invoiceAddScreenController
                                        .confirmForLowPrice(context);
                                  }
                                }
                              }
                              invoiceAddScreenController.step2(context);
                            } else {
                              invoiceAddScreenController.step2(context);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          ],
        ],
      )),
    );
  }
}
