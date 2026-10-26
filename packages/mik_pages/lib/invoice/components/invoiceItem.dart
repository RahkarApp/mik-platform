import 'package:mik_variables/permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_consts/const.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_utils/private/invoiceStatus.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_variables/variable.dart';

import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';
import 'package:widget_loading/widget_loading.dart';

import 'package:mik_consts/colors.dart';

class InvoiceItem extends GetView {
  InvoiceDB item;
  ValueSetter callback;
  bool end;
  bool endList;
  bool? showDate;
  String? type;
  var paid = 0.0;
  InvoiceItem({
    super.key,
    required this.item,
    required this.callback,
    required this.end,
    required this.endList,
    this.showDate = false,
    this.type,
  });

  @override
  Widget build(BuildContext context) {
    bool isPaid = false;
    if (!type.toString().startsWith('product')) {
      isPaid = InvoiceFX.isPaid(item.billUID ?? []);
    }
    RxBool changeStatus = false.obs;
    int ex = 0;
    int dis = 0;
    for (var element in item.parameters!) {
      if (element['name'] == 'discount') {
        dis += int.tryParse(element['amount'].toString()) ?? 0;
      } else if (element['name'] == 'excess') {
        ex += int.tryParse(element['amount'].toString()) ?? 0;
      }
    }
    return Obx(
      () =>
          (changeStatus.isFalse || changeStatus.isTrue) &&
              (darkMode.isFalse || darkMode.isTrue)
          ? Column(
              children: [
                SwipeActionCell(
                  backgroundColor: Colors.transparent,
                  index: item.id,
                  key: ValueKey(item.id),
                  firstActionWillCoverAllSpaceOnDeleting: false,
                  closeWhenScrolling: false,
                  trailingActions: !type.toString().startsWith('product')
                      ? item.type != 'buy'
                            ? type == 'marketer'
                                  ? [
                                      if (item.commission!['status'] == 0)
                                        for (var i = 1; i < 3; i++)
                                          SwipeAction(
                                            title: i == 1
                                                ? 'برداشت نقدی'
                                                : 'سرمایه‌گذاری',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: darkMode.value
                                                  ? AppColors.primaryLite
                                                  : AppColors.primaryDark,
                                            ),
                                            icon: Icon(
                                              InvoiceStatus.cIcon(i),
                                              color: darkMode.value
                                                  ? AppColors.primaryLite
                                                  : AppColors.primaryDark,
                                            ),
                                            backgroundRadius: 10,
                                            color: AppColors.boxBackground,
                                            widthSpace: 60,
                                            forceAlignmentToBoundary: true,
                                            performsFirstActionWithFullSwipe:
                                                false,
                                            onTap: (handler) async {
                                              await handler(false);
                                              InvoiceFX.onClickCommissionStatus(
                                                i,
                                                item,
                                                callback,
                                              );
                                            },
                                          ),
                                    ]
                                  : [
                                      for (
                                        var i = 0;
                                        i < invoiceStatus.length;
                                        i++
                                      )
                                        if ((invoiceStatus[i] == 1 &&
                                                PermissionAccess.hasPermission(PermissionsName.invoicesSellCreate)) ||
                                            (invoiceStatus[i] == 2 &&
                                                PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusReady)) ||
                                            (invoiceStatus[i] == 3 &&
                                                    PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusSent) ||
                                                invoiceStatus[i] == 8 &&
                                                    PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusCancelled)) ||
                                            (invoiceStatus[i] == 9 &&
                                                PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusReturned)) ||
                                            (invoiceStatus[i] == 100 &&
                                                PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusDelivered)))
                                          if (item.status!.every(
                                                (t) =>
                                                    t['status'] <
                                                    invoiceStatus[i],
                                              ) &&
                                              i < 6 &&
                                              item.status!.every(
                                                (e) => e['status'] < 4,
                                              ))
                                            if ((invoiceStatus[i] < 4 ||
                                                    invoiceStatus[i] > 10) ||
                                                ((invoiceStatus[i] == 8 ||
                                                        invoiceStatus[i] ==
                                                            9) &&
                                                    DateTime.parse(item.date!)
                                                            .add(
                                                              Duration(
                                                                days: settings!
                                                                    .dayForCancel!,
                                                              ),
                                                            )
                                                            .difference(
                                                              DateTime.now(),
                                                            )
                                                            .inMinutes >
                                                        0))
                                              if ((invoiceStatus[i] == 1 &&
                                                      PermissionAccess.hasPermission(PermissionsName.invoicesSellCreate)) ||
                                                  (invoiceStatus[i] == 2 &&
                                                      PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusReady)) ||
                                                  (invoiceStatus[i] == 3 &&
                                                      PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusSent)) ||
                                                  (invoiceStatus[i] == 8 &&
                                                      PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusCancelled)) ||
                                                  (invoiceStatus[i] == 9 &&
                                                      PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusReturned)) ||
                                                  (invoiceStatus[i] == 100 &&
                                                      PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusDelivered)))
                                                SwipeAction(
                                                  title: InvoiceStatus.name(
                                                    invoiceStatus[i],
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: darkMode.value
                                                        ? Colors.white
                                                        : AppColors.primaryDark,
                                                    //  InvoiceStatus.color(
                                                    //     factorStatus[i])
                                                  ),
                                                  icon: Icon(
                                                    InvoiceStatus.icon(
                                                      invoiceStatus[i],
                                                    ),
                                                    color: darkMode.value
                                                        ? Colors.white
                                                        : AppColors.primaryDark,
                                                    //  InvoiceStatus.color(
                                                    //     factorStatus[i]),
                                                  ),
                                                  backgroundRadius: 10,
                                                  color:
                                                      AppColors.boxBackground,
                                                  widthSpace: 60,
                                                  forceAlignmentToBoundary:
                                                      true,
                                                  performsFirstActionWithFullSwipe:
                                                      false,
                                                  onTap: (handler) async {
                                                    await handler(false);
                                                    await InvoiceFX.onClickStatus(
                                                      invoiceStatus[i],
                                                      item,
                                                      paid,
                                                      false,
                                                      (v) {
                                                        if (v.runtimeType
                                                                .toString() ==
                                                            'bool') {
                                                          changeStatus.value =
                                                              v;
                                                        }
                                                      },
                                                    );
                                                  },
                                                ),
                                    ]
                            : [
                                if (item.personUID != '-' &&
                                    item.status!.every(
                                      (t) => t['status'] != 444,
                                    ) &&
                                    !(item.description ?? '').startsWith(
                                      'موجودی اولیه',
                                    ))
                                  if (PermissionAccess.hasPermission(PermissionsName.invoicesBuyDeleteAll) ||
                                      (PermissionAccess.hasPermission(PermissionsName.invoicesBuyDelete) &&
                                          item.inserter == mikyarProfileID))
                                    SwipeAction(
                                      title: 'حذف فاکتور',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                      icon: const Icon(
                                        IconsaxPlusLinear.trash_square,
                                        color: Colors.white,
                                      ),
                                      backgroundRadius: 10,
                                      color: AppColors.error,
                                      widthSpace: 60,
                                      forceAlignmentToBoundary: true,
                                      performsFirstActionWithFullSwipe: false,
                                      // nestedAction: SwipeNestedAction(
                                      //     title: "از حذف اطمیان دارم، حذف کن!",
                                      //     nestedWidth: Get.width * 0.6),
                                      onTap: (handler) async {
                                        handler(false);

                                        await InvoiceFX.deleteBuyInvoice(
                                          context,
                                          item,
                                          paid,
                                          false,
                                          (v) {
                                            if (v.runtimeType.toString() ==
                                                'bool') {
                                              Get.back();
                                            }
                                          },
                                        );
                                        //InvoiceFX.delete(item));
                                      },
                                    ),
                              ]
                      : [],
                  leadingActions:
                      !type.toString().startsWith('product') &&
                          item.type != 'buy' &&
                          type != 'marketer'
                      ? [
                          SwipeAction(
                            title: (!Platform.isAndroid && !Platform.isIOS)
                                ? 'کپی لینک'
                                : 'اشتراک‌گذاری',
                            style: TextStyle(
                              fontSize: 10,
                              color: darkMode.value
                                  ? Colors.white
                                  : AppColors.primaryDark,
                            ),
                            icon: Icon(
                              (!Platform.isAndroid && !Platform.isIOS)
                                  ? IconsaxPlusLinear.copy
                                  : IconsaxPlusLinear.share,
                              color: darkMode.value
                                  ? Colors.white
                                  : AppColors.primaryDark,
                            ),
                            backgroundRadius: 10,
                            color: AppColors.boxBackground,
                            widthSpace: 60,
                            forceAlignmentToBoundary: true,
                            performsFirstActionWithFullSwipe: false,
                            onTap: (handler) async {
                              handler(false);
                              if (!Platform.isAndroid && !Platform.isIOS) {
                                await Clipboard.setData(
                                  ClipboardData(text: 'onmik.ir/?${item.uid}'),
                                );
                                Alert.success(
                                  'لینک فاکتور با موفقیت در کلیپ‌بورد کپی شد.',
                                );
                                return;
                              }

                              await SharePlus.instance.share(
                                ShareParams(
                                  text:
                                      'سلام ${PersonFX.findByUID(item.personUID).name} عزیز\nفاکتور شماره ${item.id} برای شما صادر شد.\nمشاهده فاکتور:\nonmik.ir/?${item.uid}\n${profile.getAt(0)?.name}',
                                ),
                              );
                            },
                          ),
                          // SwipeAction(
                          //     title: 'PDF',
                          //     style: TextStyle(
                          //         fontSize: 10, color: AppColors.primaryDark),
                          //     icon: Icon(
                          //       IconsaxPlusLinear.document,
                          //       color: AppColors.primaryDark,
                          //     ),
                          //     backgroundRadius: 10,
                          //     color: AppColors.boxBackground,
                          //     widthSpace: 60,
                          //     forceAlignmentToBoundary: true,
                          //     performsFirstActionWithFullSwipe: false,
                          //     onTap: (handler) async {
                          //       handler(false);
                          //       InvoicePDF.setting(item);
                          //     })
                        ]
                      : [],
                  child: InkWell(
                    onTap: () async {
                      // await Get.to(FactorDetails(item));
                      await Get.toNamed(
                        RoutesName.INVOICEDETAIL,
                        arguments: {'item': item, 'type': null},
                      );
                      changeStatus.value = true;
                      changeStatus.value = false;

                      callback('change');
                    },
                    child: Container(
                      padding: const EdgeInsets.only(right: 20),
                      child: Row(
                        children: [
                          type == 'marketer'
                              ? Obx(
                                  () => CircularWidgetLoading(
                                    loading: changeStatus.value,
                                    dotRadius: 1,
                                    maxLoadingCircleSize: 20,
                                    dotColor: AppColors.primaryLite,
                                    loadingDuration: const Duration(
                                      milliseconds: 50,
                                    ),
                                    child: CircleAvatar(
                                      maxRadius: 25,
                                      backgroundColor: AppColors.boxBackground,
                                      //  InvoiceStatus.color(item.cStatus),
                                      child: Icon(
                                        InvoiceStatus.cIcon(
                                          item.commission!['status'],
                                        ),
                                        color: InvoiceStatus.color(
                                          item.commission!['status'],
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : item.type == 'buy'
                              ? Container(
                                  width: 54.0,
                                  height: 54.0,
                                  decoration: BoxDecoration(
                                    color: AppColors.boxBackground,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(50.0),
                                    ),
                                    // border: Border.all(
                                    //   color: item.status == 444
                                    //       ? AppColors.error
                                    //       : AppColors.primaryDark,
                                    //   width: 3.0,
                                    // ),
                                  ),
                                  child: Icon(
                                    item.status!.any((e) => e['status'] == 444)
                                        ? IconsaxPlusLinear.close_circle
                                        : IconsaxPlusLinear.import,
                                    color:
                                        item.status!.any(
                                          (e) => e['status'] == 444,
                                        )
                                        ? AppColors.error
                                        : darkMode.value
                                        ? AppColors.primaryLite
                                        : AppColors.primaryDark,
                                  ),
                                )
                              : Obx(
                                  () => Container(
                                    width: 54.0,
                                    height: 54.0,
                                    decoration: BoxDecoration(
                                      color: AppColors.boxBackground,
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(50.0),
                                      ),
                                      // border: Border.all(
                                      //   color: InvoiceStatus.color(item.status),
                                      //   width: 3.0,
                                      // ),
                                    ),
                                    alignment: Alignment.center,
                                    child: CircularWidgetLoading(
                                      loading: changeStatus.value,
                                      dotRadius: 0.7,
                                      maxLoadingCircleSize: 15,
                                      dotColor: AppColors.primaryLite,
                                      loadingDuration: const Duration(
                                        milliseconds: 50,
                                      ),
                                      child: Icon(
                                        InvoiceStatus.icon(
                                          InvoiceStatus.findLastStatusCode(
                                            item.status!,
                                          ),
                                        ),
                                        color: InvoiceStatus.color(
                                          InvoiceStatus.findLastStatusCode(
                                            item.status!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: SizedBox(
                              height: 60,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text.rich(
                                              TextSpan(
                                                text: item.id.toString(),
                                                style: TextStyle(
                                                  color: darkMode.isTrue
                                                      ? Colors.white
                                                      : Colors.black,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        " - ${PersonFX.findByUID(item.personUID).name}",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              maxLines: 1,
                                            ),
                                            Text(
                                              (showDate ?? false)
                                                  ? item.date
                                                        .toString()
                                                        .toPersianDate()
                                                  : DateConvertor.showTime(
                                                      DateTime.parse(
                                                        item.date!,
                                                      ),
                                                    ),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${Number.addCommas(item.type == 'buy' ? AccountingFX.total(item.items!, type: 'buy') : AccountingFX.total(item.items!) + ex - dis).split('.')[0]} تومان',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                color: darkMode.isTrue
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            if (type == 'marketer')
                                              Text(
                                                '${Number.addCommas(item.commission!)} تومان',
                                                style: const TextStyle(),
                                              ),
                                            if (type.toString().startsWith(
                                              'product',
                                            ))
                                              Directionality(
                                                textDirection:
                                                    TextDirection.ltr,
                                                child: Text(
                                                  'need',
                                                  // item.type=='buy'
                                                  //     ? '${Number.addCommas(item.amount![item.productID!.indexOf(int.parse(type.toString().split('-')[1]))])} x ${Number.addCommas(item.buyPrice![item.productID!.indexOf(int.parse(type.toString().split('-')[1]))]).split('.')[0]}'
                                                  //     : '${Number.addCommas(item.amount![item.productID!.indexOf(int.parse(type.toString().split('-')[1]))])} x ${Number.addCommas(item.sellPrice![item.productID!.indexOf(int.parse(type.toString().split('-')[1]))]).split('.')[0]}',
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            InvoiceStatus.check(
                                              isPaid,
                                              InvoiceStatus.findLastStatusCode(
                                                item.status!,
                                              ),
                                            ),
                                            // Text
                                            //   InvoiceStatus.name(item.status),
                                            //   textAlign: TextAlign.center,
                                            //   style: const TextStyle(
                                            //       height: 1,
                                            //       color: Colors.grey),
                                            // ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // if (!type.toString().startsWith('product'))
                                  //   const SizedBox(
                                  //     width: 20,4
                                  //   ),
                                  // if (!type.toString().startsWith('product'))
                                  //   Icon(
                                  //     isPaid || item.status! > 899
                                  //         ? IconsaxPlusLinear.tick_circle
                                  //         : IconsaxPlusLinear.more_circle,
                                  //     color: item.status != null &&
                                  //             item.status! > 899
                                  //         ? Colors.indigo.withValues(alpha:0.5)
                                  //         : isPaid
                                  //             ? green
                                  //             : Colors.red,
                                  //     size: 18,
                                  //   ),
                                  const SizedBox(width: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(height: endList ? 50 : 0),
                EndLine(show: !end),
              ],
            )
          : Container(),
    );
  }
}
