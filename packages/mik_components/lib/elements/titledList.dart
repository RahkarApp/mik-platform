import 'package:mik_variables/permissions.dart';
// ignore_for_file: must_be_immutable, prefer_final_fields, prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/permissionfx.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_pages/bill/components/item.dart';
import 'package:mik_pages/cheque/components/item.dart';
import 'package:mik_pages/cost/components/item.dart';
import 'package:mik_pages/cost/controllers/cost.dart';
import 'package:mik_pages/invoice/components/invoiceItem.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'package:mik_consts/colors.dart';

enum TitledListType { factor, bill, cost, shippingCost, cheque }

class TitledList extends GetView {
  TitledList({
    super.key,
    required this.data,
    required TitledListType type,
    required this.callback,
    this.billMode,
  }) : _type = type;
  TitledListType get type => _type;
  late TitledListType _type;
  var data;
  String? billMode;
  ValueSetter callback;
  var sortList = {};
  num totalDebt = 0, totalCredit = 0;
  RxBool ready = false.obs;
  @override
  Widget build(BuildContext context) {
    initPage();
    return Obx(
      () => ready.isTrue
          ? CustomScrollView(
              slivers: [
                for (var i = 0; i < sortList.length; i++)
                  MultiSliver(
                    pushPinnedChildren: true,
                    children: [
                      SliverPinnedHeader(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10),
                          height: 30,
                          color: darkMode.isTrue
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          // decoration: BoxDecoration(
                          //     border:
                          //         Border(bottom: BorderSide(color: Colors.grey))),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                flex: 2,
                                fit: FlexFit.tight,
                                child: Text(
                                  sortList.keys
                                      .toList()[i]
                                      .toString()
                                      .toPersianDate(),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              Flexible(
                                flex: 2,
                                fit: FlexFit.tight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'تعداد: ',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    SizedBox(
                                      width: 25,
                                      child: Text(
                                        sortList[sortList.keys.toList()[i]]!
                                            .length
                                            .toString(),
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (TitledListType.factor == type)
                                Flexible(
                                  flex: 3,
                                  fit: FlexFit.tight,
                                  child:
                                      reducePriceFactor(
                                            sortList[sortList.keys
                                                .toList()[i]]!,
                                          ) !=
                                          "0 تومان"
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Icon(
                                              sortList[sortList.keys
                                                              .toList()[i]][0]
                                                          .type !=
                                                      'buy'
                                                  ? IconsaxPlusLinear.arrow_up_1
                                                  : IconsaxPlusLinear
                                                        .arrow_down,
                                              size: 20,
                                              color:
                                                  sortList[sortList.keys
                                                              .toList()[i]][0]
                                                          .type !=
                                                      'buy'
                                                  ? AppColors.success
                                                  : AppColors.error,
                                            ),
                                            Text(
                                              reducePriceFactor(
                                                sortList[sortList.keys
                                                    .toList()[i]]!,
                                              ),
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(),
                                ),
                              if (TitledListType.bill == type)
                                Flexible(
                                  fit: FlexFit.tight,
                                  flex: 3,
                                  child:
                                      reducePriceBill(
                                            sortList[sortList.keys
                                                .toList()[i]]!,
                                          ) !=
                                          "0 تومان"
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Icon(
                                              sortList[sortList.keys
                                                          .toList()[0]][0]['type'] !=
                                                      'credit'
                                                  ? IconsaxPlusLinear.arrow_up_1
                                                  : IconsaxPlusLinear
                                                        .arrow_down,
                                              size: 20,
                                              color:
                                                  sortList[sortList.keys
                                                          .toList()[0]][0]['type'] !=
                                                      'credit'
                                                  ? AppColors.secondary
                                                  : AppColors.error,
                                            ),
                                            Text(
                                              reducePriceBill(
                                                sortList[sortList.keys
                                                    .toList()[i]]!,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(),
                                ),
                              if (TitledListType.cost == type)
                                if (PermissionAccess.hasPermission(PermissionsName.costsViewAll) ||
                                    (sortList[sortList.keys.toList()[i]]
                                                .inserter ==
                                            mikyarProfileID &&
                                        PermissionAccess.hasPermission(PermissionsName.costsView)))
                                  Flexible(
                                    flex: 3,
                                    fit: FlexFit.tight,
                                    child:
                                        reducePriceCost(
                                              sortList[sortList.keys
                                                  .toList()[i]]!,
                                            ) !=
                                            "0 تومان"
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Icon(
                                                IconsaxPlusLinear.arrow_down,
                                                size: 20,
                                                color: AppColors.error,
                                              ),
                                              Text(
                                                reducePriceCost(
                                                  sortList[sortList.keys
                                                      .toList()[i]]!,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Container(),
                                  ),
                              if (TitledListType.shippingCost == type)
                                Flexible(
                                  flex: 3,
                                  fit: FlexFit.tight,
                                  child:
                                      reducePriceShippingCost(
                                            sortList[sortList.keys
                                                .toList()[i]]!,
                                          ) !=
                                          "0 تومان"
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Icon(
                                              IconsaxPlusLinear.arrow_down,
                                              size: 20,
                                              color: AppColors.error,
                                            ),
                                            Text(
                                              reducePriceShippingCost(
                                                sortList[sortList.keys
                                                    .toList()[i]]!,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(),
                                ),
                              if (TitledListType.cheque == type)
                                if (PermissionAccess.hasPermission(PermissionsName.chequesViewAll) ||
                                    (sortList[sortList.keys.toList()[i]]
                                                .inserter ==
                                            mikyarProfileID &&
                                        PermissionAccess.hasPermission(PermissionsName.chequesView)))
                                  Flexible(
                                    flex: 3,
                                    fit: FlexFit.tight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(
                                          reducePriceCheque(
                                                    sortList[sortList.keys
                                                        .toList()[i]]!,
                                                  ) >
                                                  0
                                              ? IconsaxPlusLinear.arrow_up_1
                                              : IconsaxPlusLinear.arrow_down,
                                          size: 20,
                                          color:
                                              reducePriceCheque(
                                                    sortList[sortList.keys
                                                        .toList()[i]]!,
                                                  ) >
                                                  0
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                        Text(
                                          reducePriceCheque(
                                                    sortList[sortList.keys
                                                        .toList()[i]]!,
                                                  ) >
                                                  0
                                              ? Price.show(
                                                  reducePriceCheque(
                                                    sortList[sortList.keys
                                                        .toList()[i]]!,
                                                  ),
                                                )
                                              : Price.show(
                                                  (-1 *
                                                      reducePriceCheque(
                                                        sortList[sortList.keys
                                                            .toList()[i]]!,
                                                      )),
                                                ),
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            switch (type) {
                              case TitledListType.factor:
                                if (PermissionFx.isShowFactorItem(
                                  sortList[sortList.keys.toList()[i]]![index],
                                )) {
                                  return InvoiceItem(
                                    item:
                                        sortList[sortList.keys
                                            .toList()[i]]![index],
                                    callback: (_) => callback(''),
                                    end:
                                        sortList[sortList.keys.toList()[i]]!
                                            .length ==
                                        index + 1,
                                    endList:
                                        sortList.keys.toList().last == i + 1 &&
                                        sortList[sortList.keys.toList().last]!
                                                .length ==
                                            index + 1,
                                  );
                                }
                              case TitledListType.cost:
                                if (PermissionFx.isShowCostItem(
                                  sortList[sortList.keys.toList()[i]]![index],
                                )) {
                                  return CostItem(
                                    item:
                                        sortList[sortList.keys
                                            .toList()[i]]![index],
                                    callback: (v) {
                                      callback('');
                                    },
                                    end:
                                        sortList[sortList.keys.toList()[i]]!
                                            .length ==
                                        index + 1,
                                  );
                                }
                              case TitledListType.shippingCost:
                                if (PermissionFx.isShowShippingCostItem(
                                  sortList[sortList.keys.toList()[i]]![index],
                                )) {
                                  return CostItem(
                                    item:
                                        sortList[sortList.keys
                                            .toList()[i]]![index],
                                    callback: (v) {
                                      callback('');
                                    },
                                    end:
                                        sortList[sortList.keys.toList()[i]]!
                                            .length ==
                                        index + 1,
                                  );
                                }
                              case TitledListType.bill:
                                if (PermissionFx.isShowBillItem(
                                  sortList[sortList.keys.toList()[i]]![index],
                                )) {
                                  return BillItem(
                                    item:
                                        sortList[sortList.keys
                                            .toList()[i]]![index],
                                    callback: (v) {
                                      callback('s');
                                    },
                                    end:
                                        sortList[sortList.keys.toList()[i]]!
                                            .length ==
                                        index + 1,
                                  );
                                }
                              case TitledListType.cheque:
                                if (PermissionFx.isShowChequeItem(
                                  sortList[sortList.keys.toList()[i]]![index],
                                )) {
                                  return ChequeItem(
                                    item:
                                        sortList[sortList.keys
                                            .toList()[i]]![index],
                                    callback: (v) {
                                      callback('');
                                    },
                                    end:
                                        sortList[sortList.keys.toList()[i]]!
                                            .length ==
                                        index + 1,
                                  );
                                }
                            }
                          },
                          childCount:
                              sortList[sortList.keys.toList()[i]]!.length,
                        ),
                      ),
                    ],
                  ),
                MultiSliver(children: const [SizedBox(height: 80)]),
              ],
            )
          : Container(),
    );
  }

  reducePriceFactor(data) {
    num tp = 0;
    for (var i = 0; i < data.length; i++) {
      if (PermissionFx.isShowFactorItem(data[i])) {
        tp += AccountingFX.invoicePrice(data[i]);
      }
    }
    return Price.show(tp);
  }

  reducePriceCheque(data) {
    num tp = 0;
    for (var i = 0; i < data.length; i++) {
      if (data[i].payeeUID == '-') tp += data[i].price;
      if (data[i].holderUID == '-') tp -= data[i].price;
    }
    return tp;
  }

  reducePriceBill(data) {
    num tp = 0;

    for (var i = 0; i < data.length; i++) {
      if (data[i]['type'] != 'returned' &&
          data[i]['type'] != 'cancelled' &&
          data[i]['type'] != 'deleted') {
        tp += data[i]['paid'];
      }
    }
    return Price.show(tp);
  }

  reducePriceCost(data) {
    num tp = 0;
    for (var i = 0; i < data.length; i++) {
      tp += data[i].price;
    }
    return Price.show(tp);
  }

  reducePriceShippingCost(data) {
    num tp = 0;
    for (var i = 0; i < data.length; i++) {
      tp += data[i].shipping['cost'];
    }
    return Price.show(tp);
  }

  initPage() {
    ready.value = false;
    ready.value = false;
    if (type == TitledListType.shippingCost) {
      for (var i = 0; i < data.length; i++) {
        if (CostScreenController.getStatus3Date(data[i]) != null &&
            sortList.containsKey(
              CostScreenController.getStatus3Date(data[i])
                  .toString()
                  .split(' ')[0],
            )) {
          sortList.update(
            (CostScreenController.getStatus3Date(data[i]) ?? '')
                .toString()
                .split(' ')[0],
            (value) => [...value, data[i]],
          );
        } else {
          sortList.putIfAbsent(
            (CostScreenController.getStatus3Date(data[i]) ?? '')
                .toString()
                .split(' ')[0],
            () => [data[i]],
          );
        }
      }
    } else if (type != TitledListType.bill) {
      for (var i = 0; i < data.length; i++) {
        if (data[i].date != null &&
            sortList.containsKey(
              type == TitledListType.cheque
                  ? data[i].dueDate.split('T')[0]
                  : data[i].date.split('T')[0],
            )) {
          sortList.update(
            type == TitledListType.cheque
                ? data[i].dueDate.split('T')[0]
                : data[i].date.split('T')[0],
            (value) => [...value, data[i]],
          );
        } else {
          sortList.putIfAbsent(
            data[i].date != null && type == TitledListType.cheque
                ? data[i].dueDate.split('T')[0]
                : (data[i].date ?? DateTime.now().toIso8601String()).split(
                    'T',
                  )[0],
            () => [data[i]],
          );
        }
      }
    }
    if (type == TitledListType.bill) {
      for (var i = 0; i < data.length; i++) {
        if (sortList.containsKey(data[i]['date'].toString().split('T')[0])) {
          sortList.update(
            data[i]['date'].toString().split('T')[0],
            (value) => [...value, data[i]],
          );
        } else {
          sortList.putIfAbsent(
            data[i]['date'].toString().split('T')[0],
            () => [data[i]],
          );
        }
      }
    }
    ready.value = true;
  }

  // toFind(to) {
  //   return to
  //       .toString()
  //       .replaceAll('f0', 'اول دوره')
  //       .replaceAll('ff', 'دریافتی بدون فاکتور')
  //       .replaceAll('c0', 'اول دوره')
  //       .replaceAll('f', 'فاکتور ')
  //       .replaceAll('c', 'هزینه ');
  // }
}
