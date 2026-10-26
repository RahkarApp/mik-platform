import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/myTextScroll.dart';
// ignore_for_file: prefer_typing_uninitialized_variables, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_pages/invoice/add/components/item/itemNormal.dart';
import 'package:mik_pages/invoice/add/components/item/itemPro.dart';

import '../model.dart';

class ProductItemInvoice extends GetView {
  late final InvoiceItemModel item;
  late final int index;
  late final String type;
  late final String? warehouseUID;
  late final String branchUID;
  late final dynamic changeAmount;
  late final dynamic changePrice;
  late final dynamic changeWarehouse;
  late final bool isEdit;
  // Separate constructors keep remote rows independent of Hive fields.
  // ignore: prefer_const_constructors_in_immutables
  ProductItemInvoice({
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
  }) : remote = null;

  late final ({
    String name,
    String? variant,
    Widget quantity,
    Widget price,
    Widget? warehouse,
    String? total,
    bool header,
    bool divider,
  })?
  remote;

  // Keep server UUIDs and exact quantities out of the legacy Hive model.
  ProductItemInvoice.remote({
    super.key,
    required String name,
    String? variant,
    required Widget quantity,
    required Widget price,
    Widget? warehouse,
    String? total,
    bool showHeader = true,
    bool showDivider = true,
  }) {
    remote = (
      name: name,
      variant: variant,
      quantity: quantity,
      price: price,
      warehouse: warehouse,
      total: total,
      header: showHeader,
      divider: showDivider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = remote;
    if (row != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
            child: Column(
              children: [
                if (row.header)
                  Row(
                    children: [
                      Icon(
                        IconsaxPlusBold.box,
                        size: 20,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: MyTextScroll(
                          row.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (row.variant != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(
                                  row.variant!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            row.quantity,
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (row.warehouse != null) ...[
                              row.warehouse!,
                              const SizedBox(height: 5),
                            ],
                            row.price,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (row.total != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, left: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        row.total!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (row.divider) EndLine(rightPadding: 0),
        ],
      );
    }
    return item.pro.isEmpty || item.pro[0].uid == '-'
        ? ProductItemNormalInvoice(
            index: index,
            type: type,
            branchUID: branchUID,
            item: item,
            warehouseUID: warehouseUID,
            isEdit: isEdit,
            changeAmount: (prouid, v) => changeAmount('-', v),
            changePrice: (prouid, p) => changePrice('-', p),
            changeWarehouse: (prouid, w) => changeWarehouse('-', w),
          )
        : ProductItemProInvoice(
            index: index,
            type: type,
            branchUID: branchUID,
            warehouseUID: warehouseUID,
            item: item,
            isEdit: isEdit,
            changeAmount: (prouid, v) => changeAmount(prouid, v),
            changePrice: (prouid, p) => changePrice(prouid, p),
            changeWarehouse: (prouid, w) => changeWarehouse(prouid, w),
          );
  }
}
