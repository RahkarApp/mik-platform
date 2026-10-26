// ignore_for_file: prefer_typing_uninitialized_variables, unnecessary_null_comparison, invalid_use_of_protected_member
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTextScroll.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/bill.dart';
import 'package:mik_data/utils/fx/cost.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/mikyar.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/cost/detail/components/billItem.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_utils/public/price.dart';



import 'package:persian_number_utility/persian_number_utility.dart';


import 'package:mik_consts/colors.dart';

import '../../cheque/components/form.dart';
import '../../cheque/components/item.dart';

part 'components/cheque.dart';

class CostDetailScreen extends GetView {
  var item;
  String type;
  CostDetailScreen({required this.item, required this.type, super.key});
  var paid;
  RxList<BillDB> bills = <BillDB>[].obs;
  RxList<ChequeDB> chequeList = <ChequeDB>[].obs;
  RxList<BillDB> enabaledBills = <BillDB>[].obs;
  var scrollCtl = ScrollController();
  @override
  Widget build(BuildContext context) {
    var person = PersonFX.findByUID(item.personUID);
    return Main(
      initState: () async => await init(),
      header: Header.page(context, text: 'هزینه ${item.name}'),
      child: (d) => SingleChildScrollView(
        controller: scrollCtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        maxRadius: 20,
                        backgroundColor: AppColors.boxBackground,
                        child: Icon(IconsaxPlusLinear.user, color: AppColors.primaryDark, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text.rich(
                        TextSpan(
                          text: person.org ? person.orgName : person.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          children: [
                            if (person.org)
                              TextSpan(
                                text: '(${person.name})',
                                style: const TextStyle(fontWeight: FontWeight.normal),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(item.date.toString().toPersianDate()),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.only(left: 20, right: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('عنوان هزینه:', style: TextStyle()),
                      Flexible(
                        child: MyTextScroll(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('دسته‌بندی:', style: TextStyle()),
                      Text(CostFX.cat(item.categoryUID), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (item.description != '') Text('توضیحات: ${item.description}'),
                  if (item.factorUID != '' && item.factorUID != '-')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('مربوط به فاکتور شماره:'),
                        Text(InvoiceFX.find(item.factorUID.toString().substring(2)).id.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  MyDivider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('مبلغ:', style: TextStyle()),
                      Text(Price.showWithCurrency(item.price), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  MyDivider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('پرداخت شده: ', style: TextStyle(fontSize: 16)),
                      Text(Price.showWithCurrency(paid), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('مانده: ', style: TextStyle(fontSize: 16)),
                      Text(Price.showWithCurrency((item.price - paid)), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  MyDivider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('نحوه پرداخت: ', style: TextStyle(fontSize: 16)),
                      if (bills.isNotEmpty)
                        Text(
                          bills[0].type == 'credit'
                              ? 'اقساطی'
                              : bills[0].type == 'online' || bills[0].type == 'online-mik'
                              ? 'آنلاین'
                              : 'نقد',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),

                  if (bills.isNotEmpty && bills[0].date != bills[0].deadLine!)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('مهلت پرداخت: ', style: TextStyle(fontSize: 16)),
                        Text(bills[0].deadLine!.toString().toPersianDate(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  if (item.inserter != 0) MyDivider(),
                  if (item.inserter != 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ثبت‌کننده: ', style: TextStyle(fontSize: 16)),
                        Text(MiKyarFX.find(item.inserter).name ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (((item.price - paid) > 0))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    MiniBTN(
                      icon: IconsaxPlusLinear.card,
                      name: 'پرداخت وجه',
                      onTap: () {
                        BillFX.addNewBillForItem(
                          context,
                          item.billUID,
                          (v) {
                            init();
                          },
                          paid,
                          'debt',
                        );
                      },
                    ),
                    MiniBTN(
                      icon: IconsaxPlusLinear.money_4,
                      name: 'پرداخت چک',
                      onTap: () async {
                        MyBottomSheet.view(
                          context,
                          child: (scrollController) => ChequeAddForm(
                            controller: scrollController,
                            type: 'cost',
                            pname: PersonFX.findByUID(item.personUID).name,
                            pid: item.personID,
                            puid: item.personUID,
                            to: 'c${item.id}',
                            toUID: 'C-${item.uid}',
                            callback: (v) => init(),
                          ),
                          title: 'پرداخت چک',
                        );
                      },
                    ),
                  ],
                ),
              ),
            if (!(item.description.contains('کد رهگیری:') && item.description.contains('شماره مرجع:') && item.description.contains('شماره سفارش:')))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    MiniBTN(
                      icon: IconsaxPlusLinear.edit,
                      name: 'ویرایش هزینه',
                      onTap: () async {
                        var d = await Get.toNamed(RoutesName.COSTADD, arguments: {'item': item});
                        if (d != null) item = d;
                        init();
                      },
                    ),
                    MiniBTN(
                      itemColor: AppColors.error,
                      name: 'حذف هزینه',
                      onTap: () {
                        CostFX.del(context, item, (v) {
                          Get.back();
                        });
                      },
                      icon: IconsaxPlusLinear.trash,
                    ),
                  ],
                ),
              ),
            MyDivider(),
            Container(
              padding: const EdgeInsets.all(10),
              child: const Text('صورتحساب هزینه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (paid == 0)
              const Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.paid_outlined, size: 30, color: Colors.grey),
                    Text('پرداختی برای این فاکتور انجام نشده است.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            if (paid > 0)
              for (int i = 0; i < enabaledBills.length; i++) CostBillItem(bill: enabaledBills[i], index: i, callback: (v) => init()),
            Obx(() => CostCheque(item: item, chequeList: chequeList.value, callback: (v) => init())),
          ],
        ),
      ),
    );
  }

  init() {
    bills.value = bill.values.where((element) => item.billUID.contains(element.uid) && (element.to.toString().startsWith('c') || element.toUID.toString().startsWith('C-'))).toList();
    enabaledBills.value = bills.where((b) => b.paid! > 0).toList();
    chequeList.value = cheque.values.where((element) => element.toUID == '' ? element.to == 'c${item.id}' : element.toUID == 'C-${item.uid}').toList();
    chequeList.sort((a, b) => DateTime.parse(a.dueDate!).compareTo(DateTime.parse(b.dueDate!)));

    paid = 0.0;
    for (var i = 0; i < bills.length; i++) {
      paid = paid + bills[i].paid!;
    }
    if (type != null && type == 'bill') {
      Future.delayed(const Duration(milliseconds: 200), () {
        scrollCtl.animateTo(scrollCtl.position.maxScrollExtent, duration: const Duration(milliseconds: 500), curve: Curves.ease);
      });
    }
    return '';
  }
}
