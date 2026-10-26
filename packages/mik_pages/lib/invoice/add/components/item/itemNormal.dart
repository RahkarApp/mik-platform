// ignore_for_file: prefer_typing_uninitialized_variables, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_pages/invoice/add/components/item/components/amount.dart';
import 'package:mik_pages/invoice/add/components/item/components/price.dart';
import 'package:mik_pages/invoice/add/components/item/components/warehouse.dart';
import 'package:mik_utils/public/number.dart';
import 'package:text_scroll/text_scroll.dart';

import '../model.dart';

class ProductItemNormalInvoice extends GetView {
  InvoiceItemModel item;
  int index;
  String type;
  String? warehouseUID;
  String branchUID;
  var changeAmount;
  var changePrice;
  var changeWarehouse;
  bool isEdit;
  ProductItemNormalInvoice({
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
    if (item.pro[0].warehouseUID != null) {
      warehouseUID = item.pro[0].warehouseUID;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(right: 10),
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: Get.width,
          child: Row(
            children: [
              Flexible(
                //   child:
                //alignment: Alignment.centerRight,
                //width: type != 'w2w' ? Get.width : Get.width - 230,
                child: Column(
                  spacing: 5,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      spacing: 5,
                      mainAxisAlignment: type == 'w2w'
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.start,
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
                            velocity: const Velocity(
                              pixelsPerSecond: Offset(40, 0),
                            ),
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
                        if (type == 'w2w')
                          Container(
                            padding: EdgeInsets.only(left: 10),
                            child: Text(
                              'موجودی مبدا: ${Number.addCommas(ProductFX.productInWarehouse(item.uid, '-', warehouseUID!))}',
                            ),
                          ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.only(right: 25),
                      child: AmountChangeInvoice(
                        item: item,
                        pro: item.pro[0],
                        type: type,
                        branchUID: branchUID,
                        isEdit: isEdit,
                        callback: (prouid, v) {
                          changeAmount(prouid, v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (type != 'w2w') const SizedBox(height: 5),
              // if (false)
              if (type != 'w2w')
                Container(
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(top: 5, left: 5),
                  //width: Get.width,
                  child: Column(
                    spacing: 5,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (item.type != 'service')
                        WarehouseChangeInvoice(
                          item: item,
                          pro: item.pro[0],
                          type: type,
                          branchUID: branchUID,
                          callback: (prouid, v) {
                            changeWarehouse(prouid, v);
                          },
                        ),
                      PriceChangeInvoice(
                        item: item,
                        pro: item.pro[0],
                        type: type,
                        price: item.pro[0].price,
                        callback: (prouid, v) {
                          changePrice(prouid, v);
                        },
                      ),
                    ],
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
