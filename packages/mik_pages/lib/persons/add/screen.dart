// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/citiesInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/numInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/city.dart';

import 'package:mik_consts/colors.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_utils/public/analytics.dart';
import 'package:mik_utils/public/banks.dart';
import 'package:mik_utils/public/city.dart';
import 'package:mik_variables/variable.dart';

class PersonAddScreen extends GetView {
  String title;
  PersonDB? item;
  String? mobile;
  RxString org = 'حقیقی'.obs;
  PersonAddScreen({
    super.key,
    this.title = 'مشتری جدید',
    this.item,
    this.mobile,
  });
  final nameCtl = TextEditingController();
  final orgNameCtl = TextEditingController();
  final economicIDCtl = TextEditingController();
  final nationalIDCtl = TextEditingController();
  final mobileCtl = TextEditingController();
  final telCtl = TextEditingController();
  final mailCtl = TextEditingController();
  final instaCtl = TextEditingController();
  final cityCtl = TextEditingController();
  final provinceCtl = TextEditingController();
  final addressCtl = TextEditingController();
  final cardCtl = TextEditingController();
  final shebaCtl = TextEditingController();
  final postalCodeCtl = TextEditingController();
  final descriptionCtl = TextEditingController();
  RxString province = ''.obs;
  RxString bankNameCard = ''.obs;
  RxString bankNameIban = ''.obs;
  RxBool isAdminDef = false.obs,
      isPartnerDef = false.obs,
      isSupplierDef = false.obs,
      isCustomerDef = false.obs,
      isMarketerDef = false.obs,
      isServiceDef = false.obs,
      all = false.obs;
  @override
  Widget build(BuildContext context) {
    return Main(
      forceNet: true,
      initState: () async => init(),
      header: Header.page(context, text: title),
      child: (d) => Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  MyTab(
                    tab: const ['حقیقی', 'حقوقی'],
                    value: org,
                    callback: (v) {
                      org.value = v;
                    },
                  ),
                  const SizedBox(height: 10),
                  Obx(
                    () => org.value == 'حقوقی'
                        ? Column(
                            children: [
                              Input(
                                controller: orgNameCtl,
                                require: true,
                                name: 'نام شرکت',
                              ),
                              Input(
                                controller: nameCtl,
                                require: true,
                                rightPadding: 120,
                                name: 'نام‌ونام‌خانوادگی رابط',
                              ),
                              Input(controller: telCtl, name: 'تلفن شرکت'),
                              NumberInput(
                                controller: nationalIDCtl,
                                name: 'شناسه‌ملی',
                              ),
                              NumberInput(
                                controller: nationalIDCtl,
                                name: 'کداقتصادی',
                              ),
                            ],
                          )
                        : Input(
                            controller: nameCtl,
                            require: true,
                            rightPadding: 100,
                            name: 'نام‌ونام‌خانوادگی',
                          ),
                  ),
                  item == null ||
                          (item != null && item!.isAdmin!) ||
                          (item != null && item!.mobile == null)
                      ? Input(
                          controller: mobileCtl,
                          name: 'تلفن همراه',
                          maxLength: 11,
                          require: true,
                          keyboardType: TextInputType.phone,
                        )
                      : Container(),
                  Input(
                    controller: instaCtl,
                    name: org.value == 'حقوقی' ? 'سایت' : 'ID اینستاگرام',
                    keyboardType: TextInputType.url,
                  ),
                  ExpansionTile(
                    collapsedTextColor: darkMode.value
                        ? Colors.grey[50]
                        : Colors.black,
                    textColor: darkMode.value ? Colors.grey[50] : Colors.black,
                    maintainState: false,
                    title: const Text(
                      'برای وارد کردن سایر اطلاعات اینجا را لمس کنید',
                    ),
                    children: [
                      Column(
                        children: [
                          Obx(
                            () => org.value == 'حقوقی'
                                ? const Column(children: [])
                                : Column(
                                    children: [
                                      NumberInput(
                                        controller: nationalIDCtl,
                                        name: 'کدملی',
                                      ),
                                    ],
                                  ),
                          ),
                          Input(
                            controller: mailCtl,
                            name: 'ایمیل',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: SelectListInput(
                                  controller: provinceCtl,
                                  list: provinces,
                                  onChanged: (v) {
                                    provinceCtl.text = v;
                                    province.value = v;
                                    cityCtl.text = '';
                                  },
                                  name: 'استان',
                                ),
                              ),
                              Obx(
                                () => province.value != ''
                                    ? Flexible(
                                        child: SelectListInput(
                                          name: 'شهر',
                                          list: City.city(province.value) ?? [],
                                          onChanged: (v) {
                                            cityCtl.text = v;
                                          },
                                          controller: cityCtl,
                                        ),
                                      )
                                    : Container(),
                              ),
                            ],
                          ),
                          Input(
                            controller: addressCtl,
                            name: 'ادامه آدرس',
                            minLines: 2,
                            maxLines: 2,
                          ),
                          NumberInput(
                            controller: postalCodeCtl,
                            name: 'کدپستی',
                          ),
                          Stack(
                            children: [
                              NumberInput(
                                controller: cardCtl,
                                name: 'شماره کارت',
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(16),
                                ],
                                onChanged: (v) {
                                  bankNameCard.value = Banks.nameByCard(v);
                                },
                              ),
                              Obx(
                                () => bankNameCard.value != ''
                                    ? Container(
                                        alignment: Alignment.centerLeft,
                                        margin: const EdgeInsets.only(
                                          left: 10,
                                          top: 46,
                                        ),
                                        child: Text(
                                          bankNameCard.value,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : Container(),
                              ),
                            ],
                          ),
                          Stack(
                            children: [
                              NumberInput(
                                controller: shebaCtl,
                                maxLength: 24,
                                name: 'شماره شبا',
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (v) {
                                  bankNameIban.value = Banks.nameByIban(v);
                                },
                              ),
                              Obx(
                                () => bankNameIban.value != ''
                                    ? Container(
                                        alignment: Alignment.centerLeft,
                                        margin: const EdgeInsets.only(
                                          left: 10,
                                          top: 46,
                                        ),
                                        child: Text(
                                          bankNameIban.value,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : Container(),
                              ),
                            ],
                          ),
                          Input(
                            controller: descriptionCtl,
                            name: 'توضیحات',
                            minLines: 2,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (all.isTrue || item != null)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.only(right: 20),
                          alignment: Alignment.centerRight,
                          child: const Text(
                            'نقش فرد را انتخاب کنید:',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Obx(
                            () => Column(
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: BTN(
                                        margin: const EdgeInsets.all(5),
                                        name: 'مشتری',
                                        color: AppColors.primaryLite,
                                        textColor: !isCustomerDef.value
                                            ? AppColors.primaryLite
                                            : Colors.white,
                                        borderOnly: !isCustomerDef.value,
                                        onTap: () {
                                          if (!item!.isCustomer!) {
                                            if (item != null &&
                                                !item!.isCustomer!) {
                                              isCustomerDef.toggle();
                                            } else {
                                              isCustomerDef.toggle();
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    Flexible(
                                      child: BTN(
                                        margin: const EdgeInsets.all(5),
                                        name: 'شریک',
                                        color: AppColors.primaryLite,
                                        textColor:
                                            !(isAdminDef.value ||
                                                isPartnerDef.value)
                                            ? AppColors.primaryLite
                                            : Colors.white,
                                        borderOnly:
                                            !(isAdminDef.value ||
                                                isPartnerDef.value),
                                        onTap: () {
                                          if (item != null &&
                                              isAdminDef.isFalse &&
                                              !item!.isPartner!) {
                                            isPartnerDef.toggle();
                                          } else {
                                            isPartnerDef.toggle();
                                          }
                                        },
                                      ),
                                    ),
                                    // Flexible(
                                    //     child: BTN(
                                    //         margin: const EdgeInsets.all(5),
                                    //         name: 'بازاریاب/پرسنل',
                                    //         color: AppColors.primaryLite,
                                    //         textColor: !isMarketerDef.value
                                    //             ? AppColors.primaryLite
                                    //             : Colors.white,
                                    //         borderOnly: !isMarketerDef.value,
                                    //         onTap: () {
                                    //           if (!item!.isMarketer!) {
                                    //             if (item != null && !item!.isMarketer!) {
                                    //               isMarketerDef.toggle();
                                    //             } else {
                                    //               isMarketerDef.toggle();
                                    //             }
                                    //           }
                                    //         })),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: BTN(
                                        margin: const EdgeInsets.all(5),
                                        name: 'تامین کننده',
                                        color: AppColors.primaryLite,
                                        textColor: !isSupplierDef.value
                                            ? AppColors.primaryLite
                                            : Colors.white,
                                        borderOnly: !isSupplierDef.value,
                                        onTap: () {
                                          if (item != null &&
                                              !item!.isSupplier!) {
                                            isSupplierDef.toggle();
                                          } else {
                                            isSupplierDef.toggle();
                                          }
                                        },
                                      ),
                                    ),
                                    Flexible(
                                      child: BTN(
                                        margin: const EdgeInsets.all(5),
                                        name: 'سرویس دهنده',
                                        color: AppColors.primaryLite,
                                        textColor: !isServiceDef.value
                                            ? AppColors.primaryLite
                                            : Colors.white,
                                        borderOnly: !isServiceDef.value,
                                        onTap: () {
                                          if (item != null &&
                                              !item!.isService!) {
                                            isServiceDef.toggle();
                                          } else {
                                            isServiceDef.toggle();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (item == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: BTN(
                onTap: () async {
                  await PersonFX.add(
                    uid: null,
                    id: null,
                    name: nameCtl.text,
                    nationalID: nationalIDCtl.text,
                    mobile: mobileCtl.text,
                    instagram: instaCtl.text,
                    email: mailCtl.text,
                    cardNumber: cardCtl.text,
                    shebaNumber: shebaCtl.text,
                    address:
                        '${provinceCtl.text}-${cityCtl.text}-${addressCtl.text}',
                    isAdmin: isAdminDef.value,
                    isSupplier: isSupplierDef.value,
                    isPartner: isPartnerDef.value,
                    isCustomer: isCustomerDef.value,
                    isMarketer: isMarketerDef.value,
                    isService: isServiceDef.value,
                    description: descriptionCtl.text,
                    stateID: null,
                    townID: null,
                    orgName: orgNameCtl.text,
                    org: org.value == 'حقوقی',
                    tel: telCtl.text,
                    economicID: economicIDCtl.text,
                    postalCode: postalCodeCtl.text,
                  );
                  // if (v.runtimeType == PersonDB) {
                  //   // Get.back(result: v);
                  //   // Alert.success(' با موفقیت افزوده شد.');
                  // }
                },
                // wait: waitServer.value,
                name: 'افزودن',
                type: BTNType.ok,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Flexible(
                  child: BTN(
                    onTap: () async {
                      var v = await PersonFX.add(
                        uid: item?.uid,
                        id: item?.id,
                        name: nameCtl.text,
                        nationalID: nationalIDCtl.text,
                        mobile: mobileCtl.text,
                        instagram: instaCtl.text,
                        email: mailCtl.text,
                        cardNumber: cardCtl.text,
                        shebaNumber: shebaCtl.text,
                        address:
                            '${provinceCtl.text}-${cityCtl.text}-${addressCtl.text}',
                        isAdmin: isAdminDef.value,
                        isSupplier: isSupplierDef.value,
                        isPartner: isPartnerDef.value,
                        isCustomer: isCustomerDef.value,
                        isMarketer: isMarketerDef.value,
                        isService: isServiceDef.value,
                        description: descriptionCtl.text,
                        stateID: null,
                        townID: null,
                        orgName: orgNameCtl.text,
                        org: org.value == 'حقوقی',
                        tel: telCtl.text,
                        economicID: economicIDCtl.text,
                        postalCode: postalCodeCtl.text,
                      );
                      if (v.runtimeType.toString() == 'PersonDB') {
                        if (item != null) {
                          // Get.back(result: v);
                          // Alert.success('$title با موفقیت ویرایش شد.');
                        } else {
                          nameCtl.clear();
                          orgNameCtl.clear();
                          postalCodeCtl.clear();
                          economicIDCtl.clear();
                          nationalIDCtl.clear();
                          mobileCtl.clear();
                          mailCtl.clear();
                          instaCtl.clear();
                          cityCtl.clear();
                          provinceCtl.clear();
                          addressCtl.clear();
                          cardCtl.clear();
                          shebaCtl.clear();
                          descriptionCtl.clear();
                          // Alert.success('$title با موفقیت افزوده شد.');
                        }
                      }
                    },
                    name: item != null ? 'ویرایش' : 'افزودن و ادامه',
                    type: item != null ? BTNType.edit : BTNType.okContinue,
                  ),
                ),
                Flexible(
                  child: BTN(
                    onTap: () {
                      nameCtl.clear();
                      orgNameCtl.clear();
                      postalCodeCtl.clear();
                      economicIDCtl.clear();
                      nationalIDCtl.clear();
                      mobileCtl.clear();
                      mailCtl.clear();
                      instaCtl.clear();
                      cityCtl.clear();
                      provinceCtl.clear();
                      addressCtl.clear();
                      cardCtl.clear();
                      shebaCtl.clear();
                      descriptionCtl.clear();
                      Get.back();
                    },
                    name: 'انصراف',
                    type: BTNType.cancel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  init() {
    switch (title) {
      case 'مدیر کسب و کار':
        isAdminDef = true.obs;
        isMarketerDef = true.obs;
        break;
      case 'شریک جدید':
        isPartnerDef = true.obs;
        break;
      case 'تامین‌کننده جدید':
        isSupplierDef = true.obs;
        break;
      case 'سرویس‌دهنده جدید':
        isServiceDef = true.obs;
        break;
      case 'پرسنل جدید':
        isMarketerDef = true.obs;
        break;
      case 'مشتری جدید':
        isCustomerDef = true.obs;
        break;
      default:
        all = true.obs;
        break;
    }
    Analytics.pageView();

    if (item != null) {
      org.value = item!.org ?? false ? 'حقوقی' : 'حقیقی';
      orgNameCtl.text = item!.orgName!;
      postalCodeCtl.text = item!.postalCode!;
      economicIDCtl.text = item!.economicID!;
      telCtl.text = item!.tel!;
      title = 'ویرایش ${item!.name!}';
      isAdminDef.value = item!.isAdmin!;
      isCustomerDef.value = item!.isCustomer!;
      isPartnerDef.value = item!.isPartner!;
      isSupplierDef.value = item!.isSupplier!;
      isMarketerDef.value = item!.isMarketer!;
      isServiceDef.value = item!.isService!;
      nameCtl.text = item!.name != null ? item!.name! : '';
      nationalIDCtl.text = item!.nationalID != null ? item!.nationalID! : '';
      mobileCtl.text = item!.mobile != null ? item!.mobile! : '';
      mailCtl.text = item!.email != null ? item!.email! : '';
      instaCtl.text = item!.instagram != null ? item!.instagram! : '';
      var address = item!.address != null ? item!.address!.split('-') : [];
      if (address.length > 1) {
        cityCtl.text = address[1];
        provinceCtl.text = address[0];
        addressCtl.text = address[2];
        province.value = address[0];
      }
      cardCtl.text = item!.cardNumber ?? '';
      shebaCtl.text = item!.shebaNumber ?? '';
      descriptionCtl.text = item!.description ?? '';
    }
    return '';
  }
}
