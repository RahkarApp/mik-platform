// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_consts/banks.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class Banks {
  static logoByPersianName(name) {
    List<BankInformation> b = banksInfo
        .where((element) => element.persianName == name)
        .toList();
    return b.isNotEmpty ? b[0].logo : '';
  }

  static logoByCode(int code) {
    List<BankInformation> b = banksInfo
        .where((element) => element.code == code)
        .toList();
    return b.isNotEmpty ? b[0].logo : '';
  }

  static nameByCard(String cardNumber) {
    String bankname = 'نامشخص';
    if (cardNumber.length > 6) {
      for (var i = 0; i < banksInfo.length; i++) {
        if (banksInfo[i].startCard.contains(
          cardNumber.replaceAll('-', '').substring(0, 6),
        )) {
          bankname = banksInfo[i].persianName;
        }
      }
    } else {
      return '';
    }
    return bankname;
  }

  static nameByIban(iban) {
    String bankname = 'نامشخص';
    if (iban.length > 4) {
      for (var i = 0; i < banksInfo.length; i++) {
        if (banksInfo[i].code.toString() == iban.substring(3, 5)) {
          bankname = banksInfo[i].persianName;
        }
      }
    } else {
      return '';
    }
    return bankname;
  }

  static nameByCode(code) {
    List<BankInformation> b = banksInfo
        .where((element) => element.code == code)
        .toList();
    if (b.isNotEmpty) {
      return b[0].persianName;
    } else {
      return '';
    }
  }

  static codeByName(name) {
    List<BankInformation> b = banksInfo
        .where((element) => element.persianName == name)
        .toList();
    if (b.isNotEmpty) {
      return b[0].code;
    } else {
      return '';
    }
  }

  static BankInformation detailByIban(iban) {
    if (iban.length > 4) {
      for (var i = 0; i < banksInfo.length; i++) {
        if (banksInfo[i].code.toString() ==
            (iban.replaceAll("IR", "").substring(2, 5))) {
          return banksInfo[i];
        }
      }
    } else {
      return BankInformation(
        nickname: '',
        name: '',
        persianName: '',
        startCard: [''],
        pol: true,
        code: 0,
        logo: '',
      );
    }
    return BankInformation(
      nickname: '',
      name: '',
      persianName: '',
      startCard: [''],
      pol: true,
      code: 0,
      logo: '',
    );
  }

  static listWithLogo(context, {bool? polSupport, callback}) {
    RxList<BankInformation> bl = (polSupport ?? false)
        ? banksInfo.where((e) => e.pol).toList().obs
        : banksInfo.toList().obs;
    MyBottomSheet.view(
      context,
      child: (scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Column(
          children: [
            Obx(
              () => darkMode.isTrue || darkMode.isFalse
                  ? MySearchBar(
                      type: SearchBarType.bank,
                      callback: (v) {
                        List<BankInformation> filtter = [];
                        int itemSize = bl.length;
                        if (v.length > 0) {
                          for (var i = 0; i < itemSize; i++) {
                            if (bl[i].persianName.contains(v)) {
                              filtter.add(bl[i]);
                            }
                          }
                          bl.value = filtter;
                        } else {
                          bl.value = banksInfo;
                        }
                      },
                    )
                  : Container(),
            ),
            Obx(
              () => Wrap(
                children: bl
                    .map(
                      (e) => InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          if (callback != null) callback(e);
                        },
                        child: Container(
                          height: Get.width / 5,
                          width: Get.width / 5,
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withValues(alpha: 0.3),
                            border: Border.all(
                              color: darkMode.isTrue
                                  ? Colors.grey
                                  : Colors.grey.shade600,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              e.logo != null && e.logo != ''
                                  ? Image.asset(
                                      e.logo,
                                      height: (Get.width / 5) - 30,
                                      width: (Get.width / 5) - 30,
                                    )
                                  : const Icon(IconsaxPlusLinear.bank),
                              Text(
                                e.persianName,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: darkMode.isTrue
                                      ? AppColors.background
                                      : AppColors.backgroundDarkMode,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      //   h: Get.height * 0.79,
      title: (polSupport ?? false)
          ? 'بانک‌های پشتیبانی کننده از سامانه پل'
          : '',
    );
  }
}
