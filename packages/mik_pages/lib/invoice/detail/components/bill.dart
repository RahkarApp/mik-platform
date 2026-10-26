part of '../screen.dart';

class InvoiceBill extends GetView {
  InvoiceDB item;
  double paid;
  List<BillDB> bills;
  InvoiceBill({
    required this.item,
    required this.paid,
    required this.bills,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return (!item.type!.startsWith('pf') && paid > 0)
        ? Column(
            children: [
              MyDivider(),
              Container(
                padding: const EdgeInsets.all(10),
                child: const Text(
                  'صورتحساب فاکتور',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (paid == 0)
                const Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.paid_outlined, size: 30, color: Colors.grey),
                      Text(
                        'پرداختی برای این فاکتور انجام نشده است.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              for (int i = 0; i < bills.length; i++)
                billsItem(context, bills[i], i),
              if (!item.type!.startsWith('pf') &&
                  (item.type != 'buy' ||
                      (item.type == 'buy' &&
                          item.status!.every((t) => t['status'] != 444))))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: const Text(
                    'برای ویرایش هرکدام از پرداخت‌ها روی آن نگه دارید.',
                  ),
                ),
              MyDivider(),
            ],
          )
        : Container();
  }

  bool firstPaid = true;
  billsItem(context, BillDB bill, index) {
    if (index == 0 && bill.paid == 0) {
      firstPaid = false;
    }
    return bill.paid! > 0
        ? Column(
            children: [
              InkWell(
                onTap: () {
                  if (bill.type == 'pos') {
                    MyBottomSheet.view(
                      context,
                      child: (d) => Column(
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: MyDivider(
                                  text: 'شماره ترمینال',
                                  entText: '${bill.meta?['terminalID'] ?? '-'}',
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Flexible(
                                child: MyDivider(
                                  text: 'زمان پاسخ',
                                  entText:
                                      '${bill.meta?['responseTime'] ?? '-'}',
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Flexible(
                                child: MyDivider(
                                  text: 'تاریخ پاسخ',
                                  entText:
                                      '${bill.meta?['responseDate'] ?? '-'}',
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Flexible(
                                child: MyDivider(
                                  text: 'شماره کارت',
                                  entText:
                                      '${bill.meta?['maskedCardNumber'] ?? '-'}',
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Flexible(
                                child: MyDivider(
                                  text: 'شماره مرجع',
                                  entText:
                                      '${bill.meta?['referenceID'] ?? '-'}',
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Flexible(
                                child: MyDivider(
                                  text: 'شماره رهگیری',
                                  entText: '${bill.meta?['trackingID'] ?? '-'}',
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Flexible(
                                child: MyDivider(
                                  text: 'مبلغ',
                                  entText: '${bill.meta?['amount'] ?? '-'}',
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Flexible(
                                child: MyDivider(
                                  text: 'شناسه تراکنش',
                                  entText: '${bill.meta?['sessionId'] ?? '-'}',
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Flexible(
                                child: MyDivider(
                                  text: 'شماره پیگیری مرکز',
                                  entText:
                                      '${bill.meta?['retrievalReferencedNumber'] ?? '-'}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      title: 'جزئیات تراکنش',
                    );
                  }
                },
                onLongPress: () async {
                  if (!PermissionAccess.hasPermission(PermissionsName.invoicesSellPaymentReceive)) {
                    Alert.error('عدم دسترسی به ویرایش صورتحساب پرداخت');
                    return;
                  }
                  if ((socketConnected.value != 'error' &&
                      socketConnected.value != 'disconnect')) {
                    if (item.type != 'buy' ||
                        (item.type == 'buy' &&
                            item.status!.every((t) => t['status'] != 444))) {
                      if ((bill.type == 'credit' || bill.type == 'paid') &&
                          item.personUID != '-') {
                        await Get.toNamed(
                          RoutesName.BILLADD,
                          arguments: {
                            'billID': bill.id,
                            'billUID': bill.uid,
                            'mode': item.type == 'buy' ? 'debt' : 'credit',
                          },
                        );
                        invoiceDetailsScreenController.init();
                      } else if (bill.type == 'cheque') {
                        Alert.info(
                          'این پرداخت قابل ویرایش نیست. از قسمت چک‌ها اقدام کنید.',
                        );
                      } else {
                        Alert.info('این پرداخت قابل ویرایش نیست.');
                      }
                    }
                  } else {
                    Alert.error(
                      'برای ویرایش صورت‌حساب‌ها باید به سرویس همزمانی‌ اطلاعات متصل باشید.',
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.only(right: 20, left: 10),
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        flex: 7,
                        fit: FlexFit.tight,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text(
                                firstPaid
                                    ? (index + 1).toString()
                                    : index.toString(),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            Text(
                              Price.show(bill.paid!),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        flex: 3,
                        fit: FlexFit.tight,
                        child: Text(bill.date.toString().toPersianDate()),
                      ),
                      Flexible(
                        flex: 2,
                        fit: FlexFit.tight,
                        child: Text(
                          index == 0 && bill.type == 'credit' && bill.paid! > 0
                              ? 'نقدی'
                              : bill.type == 'credit'
                              ? 'اقساطی'
                              : bill.type == 'online'
                              ? 'آنلاین'
                              : bill.type == 'smart'
                              ? 'لینک‌هوشمند'
                              : bill.type == 'cheque'
                              ? 'چک'
                              : bill.type == 'pos'
                              ? 'کارتخوان'
                              : 'نقد',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              EndLine(rightPadding: 40),

              // Container(
              //   height: 1,
              //   width: Get.width,
              //   margin: const EdgeInsets.only(right: 40),
              //   color:
              //       darkMode.isTrue ? Colors.grey.shade800 : Colors.grey.shade300,
              // )
            ],
          )
        : Container();
  }
}
