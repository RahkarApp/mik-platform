// ignore_for_file: prefer_typing_uninitialized_variables, annotate_overrides, empty_catches
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_components/elements/myTextScroll.dart';
import 'package:mik_consts/svgIcon.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import 'package:mik_consts/colors.dart';

import '../bottomSheet.dart';
import '../buttons/button.dart';
import 'dropdown.dart';

class PersonInput extends GetView {
  TextEditingController controller;
  FocusNode? focusNode;
  String name;
  bool? readOnly;
  TextDirection? textDirection;
  TextAlign? textAlign;
  bool? enabled;
  bool? require;
  var onChanged;
  String? hintText;
  String? desc;
  double? rightPadding;
  Color? fillColor;

  String type;
  PersonInput({
    super.key,
    required this.controller,
    this.readOnly,

    ///'partner','supplier','servicer','customer','marketer','all'
    required this.type,
    this.rightPadding,
    this.fillColor,
    this.focusNode,
    this.require,
    this.textDirection,
    this.textAlign,
    required this.onChanged,
    this.enabled,
    this.hintText,
    this.desc,
    required this.name,
  });
  @override
  Widget build(BuildContext context) {
    return Input(
      controller: controller,
      name: name,
      fillColor: fillColor,
      rightPadding: rightPadding,
      require: require,
      focusNode: focusNode,
      textDirection: textDirection,
      textAlign: textAlign,
      readOnly: true,
      maxLines: 1,
      minLines: 1,
      onTap: () => type == 'unselected'
          ? Alert.error('اول نوع فاکتور را مشخص کنید.')
          : !(readOnly ?? false)
          ? select(context, type, controller, (id, uid) => onChanged(id, uid))
          : null,
      enabled: enabled,
      hintText: hintText,
    );
  }

  List personList = [];
  RxList filtteredPerson = [].obs;

  select(context, type, controller, callback) {
    // ignore: unused_local_variable
    bool all = false;
    String personText = '', addTitle = '';
    filtteredPerson.value = personList;
    final searchCtl = TextEditingController();

    List<ItemValue> itemVal = const [
      ItemValue(text: 'همه', data: 'all'),
      ItemValue(text: 'مشتریان', data: 'customer'),
      ItemValue(text: 'شرکا', data: 'partner'),
      // ItemValue(text: 'بازاریاب/پرسنل', data: 'marketer'),
      ItemValue(text: 'تامین‌کنندگان', data: 'supplier'),
      ItemValue(text: 'سرویس‌دهندگان', data: 'servicer'),
    ];
    ItemValue filterValue = itemVal[0];
    switch (type) {
      case 'partner':
        personList = person.values
            .where((element) => element.isPartner! || element.isAdmin!)
            .toList();
        personText = 'شرکا';
        addTitle = 'شریک جدید';
        filterValue = itemVal[2];
        break;
      case 'supplier':
        personList = person.values
            .where((element) => element.isSupplier!)
            .toList();
        personText = 'تامین‌کنندگان';
        addTitle = 'تامین‌کننده جدید';
        filterValue = itemVal[3];
        break;
      case 'customer':
        personList = person.values
            .where((element) => element.isCustomer!)
            .toList();
        personText = 'مشتریان';
        addTitle = 'مشتری جدید';
        filterValue = itemVal[1];
        break;
      // case 'marketer':
      //   personList = mikyar.values.toList();
      //   personText = 'بازاریاب/پرسنل';
      //   addTitle = 'بازاریاب/پرسنل جدید';
      //   break;
      case 'servicer':
        personList = person.values
            .where((element) => element.isService!)
            .toList();
        personText = 'سرویس‌دهنده';
        addTitle = 'سرویس‌دهنده جدید';
        filterValue = itemVal[4];
        break;
      case 'all':
        personList = person.values.where((element) => true).toList();
        personText = 'تمام افراد';
        addTitle = 'افزودن طرف‌حساب جدید';
        all = true;
        filterValue = itemVal[0];
        break;

      default:
        break;
    }
    filtteredPerson.value = personList;

    return MyBottomSheet.view(
      context,
      child: (scrollController) => SizedBox(
        height: (Get.height * 0.74),
        // width: Get.width * 0.9,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Text(,
            //     style: TextStyle(
            //         fontSize: 20,
            //         color: darkMode.value ? Colors.white : Colors.black)),
            Row(
              children: [
                Flexible(
                  child: MySearchBar(
                    hintText: 'جستجو',
                    type: SearchBarType.user,
                    callback: (value) {
                      var filtter = [];
                      int itemSize = filtteredPerson.length;
                      if (value.length > 0) {
                        for (var i = 0; i < itemSize; i++) {
                          if (filtteredPerson[i].name.contains(value) ||
                              filtteredPerson[i].mobile.contains(
                                value.toString().toEnglishDigit(),
                              )) {
                            filtter.add(filtteredPerson[i]);
                          }
                        }
                        filtteredPerson.value = filtter;
                      } else {
                        catPerson(type);
                      }
                    },
                  ),
                ),
                if (personText == 'تمام افراد')
                  Flexible(
                    child: Dropdown(
                      itemValue: true,
                      defaultValue: filterValue,
                      items_Value: itemVal,
                      name: '',
                      onChange: (v) {
                        filterValue = v;
                        searchCtl.clear();
                        catPerson(v.data);
                      },
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Obx(
                () => filtteredPerson.isNotEmpty
                    ? ListView.builder(
                        controller: scrollController,
                        itemCount: filtteredPerson.length,
                        itemBuilder: (context, i) {
                          return InkWell(
                            onTap: () {
                              Get.back();
                              // _change.toggle();
                              controller.text =
                                  type != 'marketer' &&
                                      filtteredPerson[i].isAdmin
                                  ? filtteredPerson[i].name + " (مدیر)"
                                  : filtteredPerson[i].name +
                                        ' (${filtteredPerson[i].mobile})';
                              callback(
                                filtteredPerson[i].id,
                                type != 'marketer'
                                    ? filtteredPerson[i].uid
                                    : '-',
                              );
                            },
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 45,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              maxRadius: 15,
                                              backgroundColor:
                                                  AppColors.boxBackground,
                                              child:
                                                  (filterValue.data == 'all' ||
                                                          filterValue.data ==
                                                              'marketer') &&
                                                      type == 'marketer'
                                                  ? SvgPicture.asset(
                                                      SvgIcon.mikyar,
                                                      width: 25,
                                                    )
                                                  : (filterValue.data ==
                                                                'all' ||
                                                            filterValue.data ==
                                                                'customer') &&
                                                        filtteredPerson[i]
                                                            .isCustomer
                                                  ? SvgPicture.asset(
                                                      filtteredPerson[i].org ??
                                                              false
                                                          ? SvgIcon.orgCustomer
                                                          : SvgIcon.customer,
                                                      width: 20,
                                                    )
                                                  : filtteredPerson[i].isAdmin
                                                  ? SvgPicture.asset(
                                                      SvgIcon.admin,
                                                      width: 20,
                                                    )
                                                  : SvgPicture.asset(
                                                      (filterValue.data ==
                                                                      'all' ||
                                                                  filterValue
                                                                          .data ==
                                                                      'supplier') &&
                                                              filtteredPerson[i]
                                                                  .isSupplier
                                                          ? SvgIcon.supplier
                                                          : (filterValue.data ==
                                                                        'all' ||
                                                                    filterValue
                                                                            .data ==
                                                                        'servicer') &&
                                                                filtteredPerson[i]
                                                                    .isService
                                                          ? SvgIcon.servicer
                                                          : SvgIcon.partner,
                                                      width: 20,
                                                    ),
                                            ),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: MyTextScroll(
                                                type != 'marketer' &&
                                                        filtteredPerson[i].org
                                                    ? filtteredPerson[i]
                                                              .orgName +
                                                          ' (${filtteredPerson[i].name} - ${filtteredPerson[i].mobile})'
                                                    : filtteredPerson[i].name +
                                                          ' (${filtteredPerson[i].mobile})',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: darkMode.value
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        filterValuePerson(
                                          filterValue,
                                          filtteredPerson[i],
                                        ),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: darkMode.value
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 1,
                                  width: Get.width,
                                  margin: const EdgeInsets.only(right: 30),
                                  color: darkMode.isTrue
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade300,
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          'شخصی با این مشخصات وجود ندارد!',
                          style: TextStyle(
                            fontSize: 16,
                            color: darkMode.value ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Flexible(
                    flex: 2,
                    child: BTN(
                      name: addTitle == 'فرد' ? 'فرد جدید' : addTitle,
                      icon: IconsaxPlusLinear.add,
                      color: AppColors.primary,
                      navigate: true,
                      onTap: () async {
                        Get.back();
                        var res = await Get.toNamed(
                          RoutesName.PERSONEADD,
                          arguments: {'title': addTitle},
                        );
                        try {
                          controller.text = "${res['name']}(${res['mobile']})";
                          callback(res['id'], res['uid']);
                        } catch (e) {}
                      },
                    ),
                  ),
                  Flexible(
                    child: BTN(
                      name: 'انصراف',
                      type: BTNType.cancel,
                      onTap: () => Get.back(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      title: '$personText (${personList.length})',

      //h: Get.height * 0.798
    );
  }

  String filterValuePerson(ItemValue v, filteredPerson) {
    switch (v.data) {
      case 'all':
        return PersonFX.position(filteredPerson);
      case 'customer':
        return 'مشتری';
      case 'partner':
        return 'شریک';

      case 'supplier':
        return 'تامین کننده';
      case 'servicer':
        return 'سرویس دهنده';
      default:
        return PersonFX.position(v);
    }
  }

  catPerson(v) {
    switch (v) {
      case 'all':
        filtteredPerson.value = personList;
        break;
      case 'customer':
        filtteredPerson.value = personList
            .where((element) => element.isCustomer == true)
            .toList();
        break;
      case 'partner':
        filtteredPerson.value = personList
            .where((element) => element.isPartner == true)
            .toList();
        break;
      // case 'marketer':
      //   filtteredPerson.value = personList.toList();
      //   break;
      case 'supplier':
        filtteredPerson.value = personList
            .where((element) => element.isSupplier == true)
            .toList();
        break;
      case 'servicer':
        filtteredPerson.value = personList
            .where((element) => element.isService == true)
            .toList();
        break;
      default:
        filtteredPerson.value = personList;
    }
  }
}
