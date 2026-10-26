// ignore_for_file: prefer_typing_uninitialized_variables, unused_element, library_private_types_in_public_api, empty_catches

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_data/utils/fx/cost.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/variable.dart';

import 'package:mik_consts/colors.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import '../bottomSheet.dart';
import '../myTab.dart';

class FactorCostInput extends GetView {
  @override
  TextEditingController controller;
  FocusNode? focusNode;
  String name;
  TextDirection? textDirection;
  TextAlign? textAlign;
  bool? readOnly;
  bool? enabled;
  bool? require;
  var onChanged;

  ///['sell','buy','cost']
  String? type;
  String? hintText;
  double? rightPadding;
  Color? fillColor;
  FactorCostInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.textDirection,
    this.rightPadding,
    this.textAlign,
    this.fillColor,
    this.readOnly,
    required this.onChanged,
    this.enabled,
    this.hintText,
    this.require,
    required this.type,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Input(
      controller: controller,
      rightPadding: rightPadding,
      name: name,
      fillColor: fillColor,
      require: require,
      focusNode: focusNode,
      textDirection: textDirection,
      textAlign: textAlign,
      readOnly: true,
      maxLines: 1,
      minLines: 1,
      onTap: () =>
          select(context, controller, type, (id, uid) => onChanged(id, uid)),
      enabled: enabled,
      hintText: hintText,
    );
  }

  List<_ItemForSelectFactor> factorList = [];
  RxList factorFilter = [].obs;
  select(context, ctl, type, callback) {
    factorList = [];

    if (type.contains('sell') || type.contains('buy')) {
      var fl = invoice.values.toList();
      try {
        fl.sort(
          (a, b) => DateTime.parse(a.date!).compareTo(DateTime.parse(b.date!)),
        );
      } catch (e) {}

      for (var element in fl) {
        element.status = element.status ?? [];
        if ((type.contains('sell') &&
            (element.status != null &&
                (element.status!.every(
                      (s) => s['status'] != null && s['status'] < 8,
                    ) ||
                    element.status!.any(
                      (s) => s['status'] != null && s['status'] == 100,
                    ))))) {
          factorList.add(
            _ItemForSelectFactor(
              item: element,
              personName: PersonFX.findByUID(element.personUID).name ?? '',
              total: InvoiceFX.totalPrice(element),
              unpaid: InvoiceFX.unPaid(element),
            ),
          );
        }
        if ((type.contains('buy') && element.type == 'buy')) {
          factorList.add(
            _ItemForSelectFactor(
              item: element,
              personName: PersonFX.findByUID(element.personUID).name ?? '',
              total: InvoiceFX.totalPrice(element),
              unpaid: InvoiceFX.unPaid(element),
            ),
          );
        }
      }
    }
    if (type.contains('cost')) {
      for (var element in cost.values) {
        factorList.add(
          _ItemForSelectFactor(
            item: element,
            personName: PersonFX.findByUID(element.personUID).name ?? '',
            total: element.price!,
            unpaid: CostFX.unPaid(element),
          ),
        );
      }
    }
    // for (var i = 0; i < 20; i++) {
    //   factorList.addAll([...factorList]);
    // }
    factorFilter.value = factorList;
    final searchCtl = TextEditingController();
    RxString show = 'همه'.obs;
    return MyBottomSheet.view(
      context,
      child: (scrollController) => SizedBox(
        height: Get.height - 200,
        // width: Get.width * 0.9,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            MySearchBar(
              hintText: 'جستجو...',
              type: SearchBarType.category,
              callback: (value) {
                var filtter = [];
                int itemSize = factorFilter.length;
                if (value.length > 0) {
                  for (var i = 0; i < itemSize; i++) {
                    if (factorFilter[i].personName.contains(value) ||
                        factorFilter[i].item.id.toString().contains(value) ||
                        factorFilter[i].total.toString().contains(value)) {
                      filtter.add(factorFilter[i]);
                    }
                  }
                  factorFilter.value = filtter;
                } else {
                  factorFilter.value = factorList;
                }
              },
            ),
            if (type.toString().split(',').length > 1)
              MyTab(
                tab: const ['همه', 'فاکتور‌ها', 'هزینه‌ها'],
                value: show,
                width: Responsive.isMobile(context),
                widthSize: 100,
                callback: (v) {
                  show.value = v;
                  factorFilter.value = factorList;
                  searchCtl.clear();
                },
              ),
            Expanded(
              child: Obx(
                () => factorFilter.isNotEmpty
                    ? SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < factorFilter.length; i++)
                              if (show.value == 'همه' ||
                                  (show.value == 'فاکتور‌ها' &&
                                      factorFilter[i].item.runtimeType
                                              .toString() ==
                                          'InvoiceDB') ||
                                  (show.value == 'هزینه‌ها' &&
                                      factorFilter[i].item.runtimeType
                                              .toString() ==
                                          'CostDB'))
                                InkWell(
                                  onTap: () {
                                    Get.back();
                                    ctl.text =
                                        factorFilter[i].personName +
                                        ' - ${factorFilter[i].item.runtimeType.toString() == 'InvoiceDB' ? 'فاکتور' : 'هزینه'} شماره ${factorFilter[i].item.id} (${factorFilter[i].item.date.toString().toPersianDate()})';
                                    callback(
                                      factorFilter[i].item.runtimeType
                                                  .toString() ==
                                              'InvoiceDB'
                                          ? 'f${factorFilter[i].item.id}'
                                          : 'c${factorFilter[i].item.uid}',
                                      factorFilter[i].item.runtimeType
                                                  .toString() ==
                                              'InvoiceDB'
                                          ? 'F-${factorFilter[i].item.uid}'
                                          : 'C-${factorFilter[i].item.uid}',
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        // height: 60,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 55,
                                              padding: const EdgeInsets.only(
                                                right: 2,
                                              ),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color:
                                                    factorFilter[i]
                                                            .item
                                                            .runtimeType
                                                            .toString() ==
                                                        'InvoiceDB'
                                                    ? factorFilter[i]
                                                                  .item
                                                                  .type ==
                                                              'buy'
                                                          ? AppColors.blue
                                                          : AppColors.primary
                                                    : AppColors.success,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        10,
                                                      ),
                                                      bottomLeft:
                                                          Radius.circular(10),
                                                    ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Container(
                                                    width: 38,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '#${factorFilter[i].item.id}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  RotatedBox(
                                                    quarterTurns: 1,
                                                    child: Text(
                                                      factorFilter[i]
                                                                  .item
                                                                  .runtimeType
                                                                  .toString() ==
                                                              'InvoiceDB'
                                                          ? factorFilter[i]
                                                                        .item
                                                                        .type ==
                                                                    'buy'
                                                                ? 'خرید'
                                                                : 'فروش'
                                                          : 'هزینه',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Column(
                                                spacing: 2,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        factorFilter[i]
                                                            .personName,
                                                      ),
                                                      Text(
                                                        factorFilter[i]
                                                            .item
                                                            .date
                                                            .toString()
                                                            .toPersianDate(),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    'مبلغ کل: ${Price.showWithCurrency(factorFilter[i].total)}',
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),

                                                  Text(
                                                    'مانده: ${Price.showWithCurrency(factorFilter[i].unpaid)}',
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        height: 1,
                                        width: Get.width,
                                        margin: const EdgeInsets.only(
                                          right: 30,
                                        ),
                                        color: darkMode.isTrue
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade300,
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      )
                    : Center(
                        child: Text(
                          'فاکتوری با این مشخصات وجود ندارد!',
                          style: TextStyle(
                            fontSize: 16,
                            color: darkMode.value ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      title: 'ارتباط با',
      //h: Get.height - 190,
      //padding: const EdgeInsets.only(top: 10, left: 10, bottom: 10)
    );
  }
}

class _ItemForSelectFactor {
  var item;
  String personName;
  int total;
  int unpaid;
  _ItemForSelectFactor({
    required this.item,
    required this.personName,
    required this.total,
    required this.unpaid,
  });
}
