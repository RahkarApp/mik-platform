import 'package:mik_variables/permissions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/permissionfx.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_utils/public/copy.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_variables/variable.dart';

import 'package:url_launcher/url_launcher_string.dart';

class PersonDetails {
  static detail(context, PersonDB item) {
    return MyBottomSheet.view(
      context,
      child: (d) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('کدملی: '),
              Flexible(child: MyDivider()),
              Text(
                item.nationalID ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text('آدرس: '), Text(item.address ?? '')],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('شماره کارت: '),
              Flexible(child: MyDivider()),
              InkWell(
                onTap: () => item.cardNumber != null && item.cardNumber != ''
                    ? Copy.clipdoard(item.cardNumber)
                    : null,
                child: Row(
                  children: [
                    Text(
                      item.cardNumber ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (item.cardNumber != null && item.cardNumber != '')
                      const Icon(IconsaxPlusLinear.copy),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('شماره شبا: '),
              Flexible(child: MyDivider()),
              InkWell(
                onTap: () => item.shebaNumber != null && item.shebaNumber != ''
                    ? Copy.clipdoard(item.shebaNumber)
                    : null,
                child: Row(
                  children: [
                    Text(
                      item.shebaNumber ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (item.shebaNumber != null && item.shebaNumber != '')
                      const Icon(IconsaxPlusLinear.copy),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text('توضیحات: '), Text(item.description ?? '')],
          ),
          Row(
            children: [
              MiniBTN(
                name: 'پیامک',
                color: Colors.transparent,
                itemColor: darkMode.value
                    ? Colors.grey.shade300
                    : Colors.grey.shade800,
                icon: IconsaxPlusLinear.message,
                onTap: () => launchUrlString('sms://${item.mobile}'),
              ),
              MiniBTN(
                name: 'واتس‌آپ',
                color: Colors.transparent,
                itemColor: darkMode.value
                    ? Colors.grey.shade300
                    : Colors.grey.shade800,
                icon: Image.asset(
                  'assets/images/icon/whatsapp.png',
                  width: 26,
                  height: 26,
                  color: darkMode.value
                      ? Colors.grey.shade300
                      : Colors.grey.shade800,
                ),
                onTap: () async {
                  var uri =
                      "https://wa.me/+98${item.mobile.toString().substring(1)}";

                  if (await launchUrlString(
                    uri,
                    mode: LaunchMode.externalApplication,
                  )) {
                  } else {
                    Alert.error('واتس‌آپ نصب نیست!');
                  }
                },
              ),
              if (item.instagram != null && item.instagram != '')
                MiniBTN(
                  name: item.org! ? 'سایت' : 'اینستاگرام',
                  color: Colors.transparent,
                  itemColor: darkMode.value
                      ? Colors.grey.shade300
                      : Colors.grey.shade800,
                  icon: item.org!
                      ? IconsaxPlusLinear.link_square
                      : IconsaxPlusLinear.instagram,
                  onTap: () => item.org!
                      ? launchUrlString('${item.instagram}')
                      : launchUrlString(
                          'https://instagram.com/${item.instagram}',
                        ),
                ),
              if (item.email != null && item.email != '')
                MiniBTN(
                  name: 'ایمیل',
                  color: Colors.transparent,
                  itemColor: darkMode.value
                      ? Colors.grey.shade300
                      : Colors.grey.shade800,
                  icon: IconsaxPlusLinear.sms,
                  onTap: () => launchUrlString('mail://${item.email}'),
                ),
            ],
          ),
        ],
      ),
      title: '',
    );
  }

  static header(context, PersonDB item, {callback}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
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
                child: BTN(
                  name: 'مشخصات',
                  color: darkMode.value
                      ? Colors.white
                      : AppColors.backgroundDarkMode,
                  navigate: true,
                  borderOnly: true,
                  textColor: AppColors.backgroundDarkMode,
                  icon: IconsaxPlusLinear.user_search,
                  onTap: () => PersonDetails.detail(context, item),
                ),
              ),
              Flexible(
                child: BTN(
                  name: 'تماس',
                  color: darkMode.value
                      ? Colors.white
                      : AppColors.backgroundDarkMode,
                  navigate: true,
                  borderOnly: true,
                  textColor: AppColors.backgroundDarkMode,
                  icon: IconsaxPlusLinear.call,
                  onTap: () {
                    launchUrlString('tel://${item.mobile}');
                  },
                ),
              ),
              Obx(
                () => Flexible(
                  child:
                      (PermissionAccess.hasPermission(PermissionsName.suppliersEditAll) && item.isSupplier!) ||
                          (PermissionAccess.hasPermission(PermissionsName.servicersEditAll) && item.isService!)
                      ? BTN(
                          name: 'ویرایش',
                          color: darkMode.value
                              ? Colors.white
                              : AppColors.backgroundDarkMode,
                          navigate: true,
                          textColor: AppColors.backgroundDarkMode,
                          borderOnly: true,
                          icon: IconsaxPlusLinear.edit_2,
                          onTap: () async {
                            var d = await Get.toNamed(
                              RoutesName.PERSONEADD,
                              arguments: {
                                'title': 'ویرایش ${item.name}',
                                'item': item,
                                'mobile': item.mobile,
                              },
                            );
                            callback(d);
                          },
                        )
                      : (item.isSupplier! &&
                                PermissionAccess.hasPermission(PermissionsName.suppliersEdit) &&
                                item.inserter == mikyarProfileID) ||
                            (item.isService! &&
                                PermissionAccess.hasPermission(PermissionsName.servicersEdit) &&
                                item.inserter == mikyarProfileID)
                      ? BTN(
                          name: 'ویرایش',
                          color: darkMode.value
                              ? Colors.white
                              : AppColors.backgroundDarkMode,
                          navigate: true,
                          textColor: AppColors.backgroundDarkMode,
                          borderOnly: true,
                          icon: IconsaxPlusLinear.edit_2,
                          onTap: () async {
                            var d = await Get.toNamed(
                              RoutesName.PERSONEADD,
                              arguments: {
                                'title': 'ویرایش ${item.name}',
                                'item': item,
                                'mobile': item.mobile,
                              },
                            );
                            callback(d);
                          },
                        )
                      : Container(),
                ),
              ),
            ],
          ),
          // if (
          //   // item.isPartner == true &&
          //     item.isSupplier == true &&
          //     item.isService == true &&
          //     item.isCustomer == true)
          //   Column(
          //     children: [
          //       Row(
          //         children: [
          //           // if (item.isPartner ?? false) transactionBTN(),
          //           if (item.isSupplier ?? false) buyBTN(item, callback),
          //         ],
          //       ),
          //       Row(
          //         children: [
          //           if (item.isService ?? false) CostBTN(item, callback),
          //           if (item.isCustomer ?? false) invoiceBTN(item, callback),
          //         ],
          //       )
          //     ],
          //   )
          // else
          Row(
            children: [
              // if (item.isPartner ?? false) transactionBTN(),
              if (PermissionFx.isAddBuy() && (item.isSupplier ?? false))
                buyBTN(item, callback),
              if (PermissionFx.isAddCost() && (item.isService ?? false))
                CostBTN(item, callback),
              if (PermissionFx.isAddSell() && (item.isCustomer ?? false))
                invoiceBTN(item, callback),
            ],
          ),
        ],
      ),
    );
  }

  static Flexible invoiceBTN(PersonDB item, callback) {
    return Flexible(
      child: BTN(
        name: 'فاکتور جدید',
        color: AppColors.secondary,
        icon: IconsaxPlusLinear.bag,
        navigate: true,
        onTap: () async {
          await Get.toNamed(
            RoutesName.INVOICEADD,
            arguments: {
              'type': 'sell',
              'item': null,
              'puid': item.uid,
              'isTabBar': true,
            },
          );
          callback('v');
        },
      ),
    );
  }

  static Flexible CostBTN(PersonDB item, callback) {
    return Flexible(
      child: BTN(
        name: 'هزینه جدید',
        color: AppColors.secondary,
        navigate: true,
        icon: IconsaxPlusLinear.money_send,
        onTap: () async {
          await Get.toNamed(
            RoutesName.COSTADD,
            arguments: {'puid': item.uid, 'pid': item.id},
          );
          callback('v');
        },
      ),
    );
  }

  static Flexible buyBTN(PersonDB item, callback) {
    return Flexible(
      child: BTN(
        name: 'خرید جدید',
        color: AppColors.secondary,
        navigate: true,
        icon: IconsaxPlusLinear.shopping_cart,
        onTap: () async {
          await Get.toNamed(
            RoutesName.INVOICEADD,
            arguments: {'type': 'buy', 'item': null, 'personUID': item.uid},
          );
          callback('v');
        },
      ),
    );
  }

  static Flexible transactionBTN() {
    return Flexible(
      child: BTN(
        name: 'واریز/برداشت',
        color: AppColors.secondary,
        navigate: true,
        icon: IconsaxPlusLinear.money,
        onTap: () {
          // PartnerTransactionAddForm.add(
          //     name: item.name, id: item.id);
        },
      ),
    );
  }

  vi() {}
}
