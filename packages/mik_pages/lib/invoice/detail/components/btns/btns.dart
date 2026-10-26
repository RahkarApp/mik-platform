// ignore_for_file: curly_braces_in_flow_control_structures

part of '../../screen.dart';

InvoiceBTNController invoiceBTNController = Get.put(InvoiceBTNController());

class InvoiceBTN extends GetView {
  InvoiceDB item;
  double paid;
  InvoiceBTN({required this.item, required this.paid, super.key});
  @override
  Widget build(BuildContext context) {
    invoiceBTNController.item = item;
    invoiceBTNController.paid = paid;
    return (!item.type!.startsWith('pf') && item.type != 'buy')
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'وضعیت سفارش',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  Column(
                    children: [
                      Obx(
                        () =>
                            invoiceDetailsScreenController.change.isFalse ||
                                invoiceDetailsScreenController.change.isTrue
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    for (var i = 0; i < 3; i++)
                                      MiniBTN(
                                        name: invoiceStatusName[i],
                                        color:
                                            invoiceStatus[i] ==
                                                InvoiceStatus.findLastStatusCode(
                                                  item.status!,
                                                )
                                            ? InvoiceStatus.color(
                                                invoiceStatus[i],
                                              )
                                            : !(invoiceStatus[i] <
                                                          InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ||
                                                      InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          9 ||
                                                      InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          8) ||
                                                  (InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          100 &&
                                                      invoiceStatus[i] == 9)
                                            ? AppColors.boxBackground
                                            : AppColors.disable,
                                        itemColor:
                                            invoiceStatus[i] ==
                                                InvoiceStatus.findLastStatusCode(
                                                  item.status!,
                                                )
                                            ? InvoiceStatus.color(
                                                        invoiceStatus[i],
                                                      ) ==
                                                      AppColors.yellow
                                                  ? AppColors.primaryDark
                                                  : Colors.white
                                            : !(invoiceStatus[i] <
                                                          InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ||
                                                      InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          9 ||
                                                      InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          8) ||
                                                  (InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          100 &&
                                                      invoiceStatus[i] == 9)
                                            ? darkMode.value
                                                  ? AppColors.grey
                                                  : AppColors.primaryDark
                                            : darkMode.isTrue
                                            ? Colors.grey
                                            : AppColors.grey,
                                        icon: InvoiceStatus.icon(
                                          invoiceStatus[i],
                                        ),
                                        onTap:
                                            !(invoiceStatus[i] <
                                                        InvoiceStatus.findLastStatusCode(
                                                          item.status!,
                                                        ) ||
                                                    item.status!.any(
                                                      (t) =>
                                                          t['status'] ==
                                                          invoiceStatus[i],
                                                    ) ||
                                                    InvoiceStatus.findLastStatusCode(
                                                          item.status!,
                                                        ) ==
                                                        9 ||
                                                    InvoiceStatus.findLastStatusCode(
                                                          item.status!,
                                                        ) ==
                                                        8) ||
                                                (InvoiceStatus.findLastStatusCode(
                                                          item.status!,
                                                        ) ==
                                                        100 &&
                                                    invoiceStatus[i] == 9)
                                            ? () {
                                                if ((invoiceStatus[i] == 1 &&
                                                        PermissionAccess.hasPermission(PermissionsName.invoicesSellCreate)) ||
                                                    (invoiceStatus[i] == 2 &&
                                                        PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusReady)) ||
                                                    (invoiceStatus[i] == 3 &&
                                                        PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusSent))) {
                                                  Confirm.con(
                                                    context,
                                                    subtex:
                                                        '${invoiceStatusName[invoiceStatus.indexOf(InvoiceStatus.findLastStatusCode(item.status!))]} >>> ${invoiceStatusName[i]}',
                                                    onTapConfirm: () =>
                                                        invoiceBTNController
                                                            .changeStatus(
                                                              invoiceStatus[i],
                                                            ),
                                                    confirmText:
                                                        'تغییر به ${invoiceStatusName[i]}',
                                                    type: ConfirmType.CHANGE,
                                                  );
                                                } else {
                                                  Alert.error(
                                                    'عدم دسترسی به تغییر وضعیت سفارش',
                                                  );
                                                }
                                              }
                                            : null,
                                      ),
                                  ],
                                ),
                              )
                            : Container(),
                      ),
                      Obx(
                        () =>
                            invoiceDetailsScreenController.change.isFalse ||
                                invoiceDetailsScreenController.change.isTrue
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    for (var i = 3; i < 6; i++)
                                      MiniBTN(
                                        name: invoiceStatusName[i],
                                        color:
                                            invoiceStatus[i] ==
                                                InvoiceStatus.findLastStatusCode(
                                                  item.status!,
                                                )
                                            ? InvoiceStatus.color(
                                                invoiceStatus[i],
                                              )
                                            : !(invoiceStatus[i] <
                                                          InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ||
                                                      InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          9 ||
                                                      InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          8) ||
                                                  (InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          100 &&
                                                      invoiceStatus[i] == 9)
                                            ? AppColors.boxBackground
                                            : AppColors.disable,
                                        itemColor:
                                            invoiceStatus[i] ==
                                                InvoiceStatus.findLastStatusCode(
                                                  item.status!,
                                                )
                                            ? InvoiceStatus.color(
                                                        invoiceStatus[i],
                                                      ) ==
                                                      AppColors.yellow
                                                  ? darkMode.value
                                                        ? AppColors.primaryLite
                                                        : AppColors.primaryDark
                                                  : Colors.white
                                            : !(invoiceStatus[i] <
                                                          InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ||
                                                      InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          9 ||
                                                      InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          8) ||
                                                  (InvoiceStatus.findLastStatusCode(
                                                            item.status!,
                                                          ) ==
                                                          100 &&
                                                      invoiceStatus[i] == 9)
                                            ? darkMode.value
                                                  ? AppColors.grey
                                                  : AppColors.primaryDark
                                            : darkMode.isTrue
                                            ? Colors.grey
                                            : AppColors.grey,
                                        icon: InvoiceStatus.icon(
                                          invoiceStatus[i],
                                        ),
                                        onTap:
                                            !(invoiceStatus[i] <
                                                        InvoiceStatus.findLastStatusCode(
                                                          item.status!,
                                                        ) ||
                                                    item.status!.any(
                                                      (t) =>
                                                          t['status'] ==
                                                          invoiceStatus[i],
                                                    ) ||
                                                    InvoiceStatus.findLastStatusCode(
                                                          item.status!,
                                                        ) ==
                                                        9 ||
                                                    InvoiceStatus.findLastStatusCode(
                                                          item.status!,
                                                        ) ==
                                                        8) ||
                                                (InvoiceStatus.findLastStatusCode(
                                                          item.status!,
                                                        ) ==
                                                        100 &&
                                                    invoiceStatus[i] == 9)
                                            ? () {
                                                if ((invoiceStatus[i] == 8 &&
                                                        PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusCancelled)) ||
                                                    (invoiceStatus[i] == 9 &&
                                                        PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusReturned)) ||
                                                    (invoiceStatus[i] == 100 &&
                                                        PermissionAccess.hasPermission(PermissionsName.invoicesSellStatusDelivered))) {
                                                  Confirm.con(
                                                    context,
                                                    subtex:
                                                        '${invoiceStatusName[invoiceStatus.indexOf(InvoiceStatus.findLastStatusCode(item.status!))]} >>> ${invoiceStatusName[i]}',
                                                    onTapConfirm: () =>
                                                        invoiceBTNController
                                                            .changeStatus(
                                                              invoiceStatus[i],
                                                            ),
                                                    confirmText:
                                                        'تغییر به ${invoiceStatusName[i]}',
                                                    type: ConfirmType.CHANGE,
                                                  );
                                                } else {
                                                  Alert.error(
                                                    'عدم دسترسی به تغییر وضعیت سفارش',
                                                  );
                                                }
                                              }
                                            : null,
                                      ),
                                  ],
                                ),
                              )
                            : Container(),
                      ),
                    ],
                  ),
                  Obx(
                    () =>
                        (socketConnected.value == 'error' ||
                            socketConnected.value == 'disconnect')
                        ? DisconnectSocket(tiny: true, height: 150)
                        : Container(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (item.status!.every(
                (t) => t['status'] == 3 || t['status'] == 100,
              ))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //  Divider(),
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: const Text(
                        'جزئیات ارسال سفارش',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        right: Get.width / 4,
                        top: 10,
                        left: 10,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('ارسال کننده:'),
                              Text(item.shipping!['company'] ?? 'ثبت نشده'),
                            ],
                          ),
                          if (PermissionAccess.hasPermission(PermissionsName.costsShippingViewAll) ||
                              (PermissionAccess.hasPermission(PermissionsName.costsShippingView) &&
                                  invoiceBTNController.item!.inserter ==
                                      mikyarProfileID))
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('هزینه ارسال:'),
                                Text(Price.show(item.shipping!['cost']!)),
                              ],
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('کدرهگیری:'),
                              Text(
                                item.shipping!['trakingCode'].toString() ==
                                            '' ||
                                        item.shipping!['trakingCode']
                                                .toString() ==
                                            'null'
                                    ? 'ثبت نشده'
                                    : item.shipping!['trakingCode']!,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              MyDivider(),
            ],
          )
        : Container();
  }
}
