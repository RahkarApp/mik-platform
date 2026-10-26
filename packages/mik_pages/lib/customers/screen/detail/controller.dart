import 'package:mik_variables/permissions.dart';
import 'package:mik_utils/public/date.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/titledList.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/permissionfx.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/variable.dart';

import 'package:mik_pages/customers/crm/screen/connections/components/item.dart';
import 'package:mik_pages/persons/components/details.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CustomerDetailsController extends GetxController {
  late PersonDB item;

  RxString tabV = 'فاکتورها'.obs;

  RxList<InvoiceDB> inv = <InvoiceDB>[].obs;

  RxList<ChequeDB> ch = <ChequeDB>[].obs;

  RxList bl = [].obs;

  RxList cannections = [].obs;

  RxInt currentIndex = 0.obs;

  head(context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 2,
                child: Text(
                  'عضویت: ${DateConvertor.grigoriToJalali(item.date)}',
                ),
              ),
              Flexible(
                child: Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      IconsaxPlusLinear.star_1,
                      color: darkMode.isTrue
                          ? Colors.grey.shade300
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Obx(
                  () => BTN(
                    name: 'مشخصات',
                    navigate: true,
                    color: darkMode.isFalse
                        ? AppColors.backgroundDarkMode
                        : (darkMode.value
                              ? AppColors.background
                              : AppColors.backgroundDarkMode),
                    borderOnly: true,
                    //itemColor: (darkMode.value ? AppColors.background : AppColors.backgroundDarkMode),
                    icon: IconsaxPlusLinear.user_search,
                    onTap: () => PersonDetails.detail(context, item),
                  ),
                ),
              ),
              Flexible(
                child: Obx(
                  () => BTN(
                    name: 'تماس',
                    navigate: true,
                    color: darkMode.isFalse
                        ? AppColors.backgroundDarkMode
                        : (darkMode.value
                              ? AppColors.background
                              : AppColors.backgroundDarkMode),
                    borderOnly: true,
                    //  itemColor: (darkMode.value ? AppColors.background : AppColors.backgroundDarkMode),
                    icon: IconsaxPlusLinear.call,
                    onTap: () {
                      launchUrlString('tel://${item.mobile}');
                    },
                  ),
                ),
              ),
              if (PermissionAccess.hasPermission(PermissionsName.customersEditAll) ||
                  (PermissionAccess.hasPermission(PermissionsName.customersEdit) && item.inserter == mikyarProfileID))
                Flexible(
                  child: Obx(
                    () => BTN(
                      name: 'ویرایش',
                      color: darkMode.isFalse
                          ? AppColors.backgroundDarkMode
                          : (darkMode.value
                                ? AppColors.background
                                : AppColors.backgroundDarkMode),
                      borderOnly: true,
                      //itemColor: (darkMode.value ? AppColors.background : AppColors.backgroundDarkMode),
                      icon: IconsaxPlusLinear.edit_2,
                      navigate: true,
                      onTap: () async {
                        await Get.toNamed(
                          RoutesName.PERSONEADD,
                          arguments: {
                            'title': 'ویرایش ${item.name}',
                            'item': item,
                            'mobile': item.mobile,
                          },
                        );

                        ///
                      },
                    ),
                  ),
                ),
              // MiniBTN(
              //     name: 'فروش',
              //     color: AppColors.primaryDark,
              //     itemColor: Colors.white,
              //     icon: IconsaxPlusLinear.bag,
              //     onTap: () async {
              //       await Get.toNamed(RoutesName.INVOICEADD, arguments: {
              //         'type': 'sell',
              //         'item': null,
              //         'personID': item.id
              //       });
              //     }),
              // MiniBTN(
              //     name: 'ارتباط',
              //     itemColor: Colors.white,
              //     color: AppColors.primaryDark,
              //     icon: IconsaxPlusLinear.call_add,
              //     onTap: () async {
              //       await Get.toNamed(RoutesName.CRMCONNETCIONADD,
              //           arguments: {'pid': item.id, 'pname': item.name});

              //       ///
              //     }),
            ],
          ),
          Row(
            children: [
              if (PermissionFx.isAddSell())
                Flexible(
                  child: BTN(
                    onTap: () async {
                      await Get.toNamed(
                        RoutesName.INVOICEADD,
                        arguments: {
                          'type': 'sell',
                          'item': null,
                          'puid': item.uid,
                          'isBack': true,
                        },
                      );
                    },
                    icon: IconsaxPlusLinear.bag,
                    navigate: true,
                    color: AppColors.secondary,
                    name: 'فروش جدید',
                  ),
                ),
              if (PermissionFx.isAddCRM())
                Flexible(
                  child: BTN(
                    onTap: () async {
                      await Get.toNamed(
                        RoutesName.CRMCONNETCIONADD,
                        arguments: {'puid': item.uid, 'pname': item.name},
                      );
                    },
                    navigate: true,
                    color: AppColors.secondary,
                    icon: IconsaxPlusLinear.call_add,
                    name: 'ارتباط جدید',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  factors() {
    init(currentIndex.value);
    return inv.isEmpty
        ? EmptyList(
            text: 'هیچ فاکتوری وجود ندارد!',
            icon: IconsaxPlusLinear.receipt_1,
          )
        : TitledList(
            data: inv,
            type: TitledListType.factor,
            callback: (v) {
              init(currentIndex.value);
            },
          );
  }

  connectionW() {
    init(currentIndex.value);
    return Obx(
      () => cannections.isEmpty
          ? EmptyList(
              text: 'هیچ تماسی وجود ندارد!',
              icon: IconsaxPlusLinear.call_slash,
            )
          : ListView.builder(
              itemCount: cannections.length,
              itemBuilder: (context, index) {
                if (PermissionFx.isShowConnection(cannections[index])) {
                  return CRMConnectionItem(cannections[index], cmScreen: true);
                }
                return Container();
              },
            ),
    );
  }

  financial() {
    init(currentIndex.value);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('وضعیت: '),
              Text(
                Number.financial(AccountingFX.findPersonFinancial(item.uid!)),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AccountingFX.findPersonFinancial(item.uid!) > 0
                      ? AppColors.blue
                      : AccountingFX.findPersonFinancial(item.uid!) == 0
                      ? AppColors.success
                      : Colors.red,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(
            () => bl.value.isEmpty
                ? EmptyList(
                    text: 'هیچ صورتحسابی وجود ندارد!',
                    icon: IconsaxPlusLinear.receipt,
                  )
                : TitledList(
                    data: bl,
                    type: TitledListType.bill,
                    callback: (v) {
                      init(currentIndex.value);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  chequew() {
    init(currentIndex.value);
    return Obx(
      () => ch.isEmpty
          ? EmptyList(
              text: 'هیچ چکی وجود ندارد!',
              icon: IconsaxPlusLinear.money_4,
            )
          : TitledList(
              data: ch,
              type: TitledListType.cheque,
              callback: (v) {
                init(currentIndex.value);
              },
            ),
    );
  }

  report() {
    return EmptyList(text: 'بزودی...', icon: IconsaxPlusLinear.chart_3);
  }

  init(type) {
    // WidgetsBinding.instance.addPostFrameCallback((_) {

    if (type == 0) {
      inv.value = invoice.values
          .where(
            (f) =>
                f.personUID == item.uid &&
                f.status!.every((a) => a['status'] != 444),
          )
          .toList()
          .reversed
          .toList();
      inv.value = inv.where((f) => PermissionFx.isShowFactorItem(f)).toList();
    }
    if (type == 2) {
      bl.value = [];
      var bb = bill.values
          .where((f) => (f.creditorUID == item.uid || f.debtorUID == item.uid))
          .toList();
      bb = bb.where((f) => PermissionFx.isShowBillItem(f.toJson())).toList();

      List toL = bb.map((v) => v.toUID == '' ? v.to : v.toUID).toSet().toList();

      for (var i = 0; i < toL.length; i++) {
        List thisB = bb
            .where((b) => b.toUID == '' ? b.to == toL[i] : b.toUID == toL[i])
            .toList();
        // per = 0,
        var mod = 'پرداخت', checkout = false, perUID = '';
        num paid = 0, unPaid = 0;
        for (var i = 0; i < thisB.length; i++) {
          paid = paid + thisB[i].paid!;
          unPaid = thisB[i].total - paid;
        }

        if (thisB.isNotEmpty) {
          if (thisB[0].debtor == 0 && thisB[0].creditor != 0) {
            mod = 'پرداخت';
          } else {
            //  per = thisB[0].debtor;
            perUID = thisB[0].debtorUID;
          }

          if (thisB[0].creditor == 0 && thisB[0].debtor != 0) {
            mod = 'دریافت';
          } else {
            // per = thisB[0].creditor;
            perUID = thisB[0].creditorUID;
          }

          if (thisB[0].total <= paid) checkout = true;
          bl.add({
            'id': thisB[0].id,
            'uid': thisB[0].uid,
            'to': thisB[0].to,
            'toUID': thisB[0].toUID,
            // 'person': per,
            'personUID': perUID,
            'date': thisB[0].date,
            'total': thisB[0].total,
            'paid': paid,
            'debt': unPaid,
            'deadLine': thisB[0].deadLine ?? "-",
            'mode': mod,
            'checkout': checkout,
            'type': thisB[0].type,
            'billItem': thisB,
          });
        }
      }
    }
    if (type == 3) {
      ch.value = cheque.values
          .where(
            (element) =>
                element.holderUID == item.uid || element.payeeUID == item.uid,
          )
          .toList();
      ch.value = ch.where((f) => PermissionFx.isShowChequeItem(f)).toList();
    }
    if (type == 1) {
      cannections.value = connection.values
          .where((t) => t.personUID == item.uid)
          .toList();
      cannections.value = cannections
          .where((f) => PermissionFx.isShowConnection(f))
          .toList();
    }

    return 'ok';
  }
}
