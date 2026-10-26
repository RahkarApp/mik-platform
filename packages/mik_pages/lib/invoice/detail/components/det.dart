// ignore_for_file: deprecated_member_use

part of '../screen.dart';

class InvoiceDetails extends GetView {
  InvoiceDB item;
  List<BillDB> bills;
  double paid;
  InvoiceDetails({
    required this.item,
    required this.bills,
    required this.paid,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: EdgeInsets.only(
                right: Responsive.isMobile(context) ? Get.width / 4 : 20,
                top: 10,
                left: 10,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'مبلغ کل فاکتور: ',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        Price.show(InvoiceFX.price(item)),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  //if (item.discount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('- تخفیف: ', style: TextStyle(fontSize: 16)),
                      Text(
                        Price.show(
                          item.parameters!
                              .map(
                                (r) =>
                                    r['name'] == 'discount' ? r['amount'] : 0,
                              )
                              .toList()
                              .reduce((a, b) => a + b),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // if (item.excess > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '+ هزینه اضافی: ',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        Price.show(
                          item.parameters!
                              .map(
                                (r) => r['name'] == 'excess' ? r['amount'] : 0,
                              )
                              .toList()
                              .reduce((a, b) => a + b),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'قابل پرداخت: ',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        Price.show(
                          InvoiceFX.price(item) +
                              item.parameters!
                                  .map(
                                    (r) =>
                                        r['name'] == 'excess' ? r['amount'] : 0,
                                  )
                                  .toList()
                                  .reduce((a, b) => a + b) -
                              item.parameters!
                                  .map(
                                    (r) => r['name'] == 'discount'
                                        ? r['amount']
                                        : 0,
                                  )
                                  .toList()
                                  .reduce((a, b) => a + b),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  MyDivider(),
                  if (!item.type!.startsWith('pf'))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'پرداخت شده: ',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          Price.show(paid),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  if (!item.type!.startsWith('pf') &&
                      ((InvoiceFX.price(item) +
                                  item.parameters!
                                      .map(
                                        (r) => r['name'] == 'excess'
                                            ? r['amount']
                                            : 0,
                                      )
                                      .toList()
                                      .reduce((a, b) => a + b) -
                                  item.parameters!
                                      .map(
                                        (r) => r['name'] == 'discount'
                                            ? r['amount']
                                            : 0,
                                      )
                                      .toList()
                                      .reduce((a, b) => a + b)) -
                              (paid)) >
                          0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('مانده: ', style: TextStyle(fontSize: 16)),
                        Text(
                          Price.show(
                            (InvoiceFX.price(item) +
                                    item.parameters!
                                        .map(
                                          (r) => r['name'] == 'excess'
                                              ? r['amount']
                                              : 0,
                                        )
                                        .toList()
                                        .reduce((a, b) => a + b) -
                                    item.parameters!
                                        .map(
                                          (r) => r['name'] == 'discount'
                                              ? r['amount']
                                              : 0,
                                        )
                                        .toList()
                                        .reduce((a, b) => a + b)) -
                                (paid),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  if (!item.type!.startsWith('pf')) MyDivider(),
                  if (item.type != 'buy')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ثبت سفارش: ',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          InvoiceFX.findInvoiceType(item.type!, item.inserter!),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  if (item.branchUID != null && item.branchUID != '')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('شعبه: ', style: TextStyle(fontSize: 16)),
                        Text(
                          BranchFX.name(item.branchUID),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  if (!item.type!.startsWith('pf') &&
                      item.type != 'smart' &&
                      item.type != 'buy')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'نوع سفارش: ',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          item.commission!['mikyar'] == 0
                              ? 'مستقیم'
                              : 'میک‌یار ${MiKyarFX.find(item.commission!['mikyar']).name ?? ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  if (item.inserter != 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ثبت‌کننده: ',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          InserterFX.find(item.inserter!)['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  if (!item.type!.startsWith('pf'))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'نحوه پرداخت: ',
                          style: TextStyle(fontSize: 16),
                        ),
                        if (!item.type!.startsWith('pf'))
                          Text(
                            bills.isNotEmpty
                                ? bills[0].type == 'credit'
                                      ? 'اقساطی'
                                      : bills[0].type == 'online'
                                      ? 'آنلاین'
                                      : bills[0].type == 'cheque'
                                      ? 'چک'
                                      : 'نقد'
                                : 'تسویه نشده',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  if (!item.type!.startsWith('pf') &&
                      bills.isNotEmpty &&
                      bills[0].deadLine != null &&
                      bills[0].date != bills[0].deadLine!)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'مهلت پرداخت: ',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          bills[0].deadLine == ''
                              ? '-'
                              : bills[0].deadLine!.toString().toPersianDate(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if ((InvoiceFX.price(item) +
                        item.parameters!
                            .map((r) => r['name'] == 'excess' ? r['amount'] : 0)
                            .toList()
                            .reduce((a, b) => a + b) -
                        item.parameters!
                            .map(
                              (r) => r['name'] == 'discount' ? r['amount'] : 0,
                            )
                            .toList()
                            .reduce((a, b) => a + b)) <=
                    paid &&
                !(item.status != null &&
                    (item.status!.any(
                      (t) => t['status'] == 8 || t['status'] == 9,
                    ))))
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(left: Get.width / 6, top: 70),
                child: Transform(
                  alignment: FractionalOffset.topCenter,
                  transform: Matrix4.identity()..rotateZ(-20 * 3.1415927 / 180),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.5),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.only(
                      top: 3,
                      bottom: 3,
                      left: 10,
                      right: 10,
                    ),
                    child: Text(
                      item.type == 'buy' &&
                              item.status!.any((t) => t['status'] == 444)
                          ? 'حذف شده'
                          : 'پرداخت شده',
                      style: TextStyle(
                        color: AppColors.error.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w800,
                        fontSize: 35,
                      ),
                    ),
                  ),
                ),
              ),
            if (item.type != 'buy' &&
                (item.status!.any((t) => t['status'] == 8 || t['status'] == 9)))
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(left: Get.width / 6, top: 70),
                child: Transform(
                  alignment: FractionalOffset.topCenter,
                  transform: Matrix4.identity()..rotateZ(-20 * 3.1415927 / 180),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.8),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.only(
                      top: 3,
                      bottom: 3,
                      left: 10,
                      right: 10,
                    ),
                    child: Text(
                      item.status!.any((t) => t['status'] == 8)
                          ? 'لغو شده'
                          : "مرجوع شده",
                      style: TextStyle(
                        color: AppColors.error.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w800,
                        fontSize: 35,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        MyDivider(),
      ],
    );
  }
}
