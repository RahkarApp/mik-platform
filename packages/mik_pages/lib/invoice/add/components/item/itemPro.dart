// ignore_for_file: prefer_typing_uninitialized_variables, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/invoice/add/components/item/components/amount.dart';
import 'package:mik_pages/invoice/add/components/item/components/price.dart';
import 'package:mik_pages/invoice/add/components/item/components/warehouse.dart';
import 'package:mik_utils/public/number.dart';
import 'package:text_scroll/text_scroll.dart';

// import 'package:mik/core/common/components/elements/input/warehuoseInput.dart';
// import 'package:mik_components/elements/popNumberPad.dart';
// import 'package:mik_utils/public/number.dart';
// import 'package:mik_data/utils/variable.dart';
// import 'package:mik_data/utils/fx/product.dart';

// import '../../../../../../../core/common/consts/colors.dart';
// import '../../../../../../../core/common/variables/variable.dart';
// import '../../../../../../../core/router/routing.dart';
import '../model.dart';

class ProductItemProInvoice extends GetView {
  InvoiceItemModel item;
  int index;
  String type;
  String? warehouseUID;
  String branchUID;
  var changeAmount;
  var changePrice;
  var changeWarehouse;
  bool isEdit;
  ProductItemProInvoice({
    required this.index,
    required this.item,
    required this.type,
    required this.isEdit,
    required this.changeAmount,
    required this.changePrice,
    required this.changeWarehouse,
    required this.branchUID,
    this.warehouseUID,
    super.key,
  });
  final warehouseCtl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    // if (item.warehouseUID != null) {
    //   warehouseUID = item.warehouseUID;
    // }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(right: 10),
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: Get.width,
          child: Column(
            children: [
              Row(
                spacing: 5,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (type != 'w2w')
                    Icon(
                      (item.type == 'product')
                          ? IconsaxPlusBold.box
                          : IconsaxPlusBold.tag_2,
                      size: 20,
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                  Flexible(
                    child: TextScroll(
                      item.name,
                      pauseBetween: Duration(seconds: 1),
                      velocity: const Velocity(pixelsPerSecond: Offset(40, 0)),
                      numberOfReps: 2,
                      mode: TextScrollMode.endless,
                      intervalSpaces: 10,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 5),
              //pro

              ...item.pro.map(
                (e) => Container(
                  padding: EdgeInsets.only(right: 20),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: EdgeInsets.all(5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    spacing: 5,
                                    children: [
                                      SizedBox(
                                        width: Get.width,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child:
                                                  ProductFX.productProNameWidget(
                                                    productPro.values
                                                        .where(
                                                          (t) =>
                                                              t.productUID ==
                                                                  item.uid &&
                                                              t.uid == e.uid,
                                                        )
                                                        .toList()[0]
                                                        .property,
                                                  ),
                                            ),
                                            if (type == 'w2w')
                                              Text(
                                                'موجودی مبدا: ${Number.addCommas(ProductFX.productInWarehouse(item.uid, e.uid, e.warehouseUID))}',
                                              ),
                                          ],
                                        ),
                                      ),
                                      AmountChangeInvoice(
                                        item: item,
                                        pro: e,
                                        isEdit: isEdit,
                                        type: type,
                                        branchUID: branchUID,
                                        callback: (prouid, v) {
                                          changeAmount(prouid, v);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (type != 'w2w')
                                  Flexible(
                                    child: SizedBox(
                                      width: Responsive.isMobile(context)
                                          ? null
                                          : 300,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        spacing: 5,
                                        children: [
                                          if (item.type != 'service')
                                            WarehouseChangeInvoice(
                                              item: item,
                                              type: type,
                                              pro: e,
                                              branchUID: branchUID,
                                              callback: (prouid, v) {
                                                changeWarehouse(prouid, v);
                                              },
                                            ),
                                          PriceChangeInvoice(
                                            item: item,
                                            type: type,
                                            pro: e,
                                            price: e.price,
                                            callback: (prouid, v) {
                                              changePrice(prouid, v);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (e.uid != null &&
                              (ProductFX.productInWarehouse(
                                    item.uid,
                                    e.uid,
                                    e.warehouseUID,
                                  ) <
                                  0) &&
                              type != 'buy' &&
                              type != 'pf')
                            Container(height: 75, color: Colors.black26),
                        ],
                      ),
                      EndLine(
                        rightPadding: 8,
                        opacity: 0.5,
                        show: item.pro.indexOf(e) != item.pro.length - 1
                            ? true
                            : false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        EndLine(rightPadding: 0),
      ],
    );
  }
}
