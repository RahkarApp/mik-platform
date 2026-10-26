import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_variables/variable.dart';


class UpdateFX {
  static check(context) async {
    var update = {};
    // int tc = 0;
    //  do {
    var cc = await API.checkUpdate();
    if (cc != 400 && cc != '400' && cc != '' && !cc.toString().startsWith('<!DOCTYPE html>')) {
      update = cc;
    }
    //   tc++;
    // } while (update.toString() == '{}' && tc < 5);

    if (Platform.isAndroid) {
      if (update.toString() != '{}' && int.parse(version.replaceAll('.', '')) < int.parse(update['versionAndroid'].toString().replaceAll('.', ''))) {
        newVersion.value = true;
        await checkUpdateDirect(context);
      }
    } else if (Platform.isIOS) {
      if (update.toString() != '{}' && int.parse(version.replaceAll('.', '')) < int.parse(update['versionIOS'].toString().replaceAll('.', ''))) {
        newVersion.value = true;
        MyBottomSheet.view(
          context,
          child: (scrollController) => Column(children: [
            Text('🚀', style: TextStyle(fontSize: 90)),
            const Text('همین الان از اپ‌استوری که میک را نصب کردید بروزرسانی کنید.'),
            const SizedBox(height: 20),
            BTN(
                onTap: () {
                  Get.back();
                },
                type: BTNType.cancel,
                name: 'متوجه شدم')
          ]),
          title: 'ورژن جدید میک در دسترس است!',
          isDismissible: false,
          showClose: false,

          // h: 130
        );
      }
    }
  }

  static checkUpdateDirect(context) async {
    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(children: [
        Text('🚀', style: TextStyle(fontSize: 90)),
        Row(children: [
          Flexible(
              flex: 2,
              child: BTN(
                  navigate: true,
                  onTap: () {
                    Get.back();
                    return Get.toNamed(RoutesName.DRAWER_UPGRADE);
                  },
                  name: 'بروزرسانی')),
          Flexible(
              child: BTN(
                  onTap: () {
                    Get.back();
                  },
                  navigate: true,
                  type: BTNType.cancel,
                  name: 'بعدا'))
        ])
      ]),
      title: 'ورژن جدید میک در دسترس است!',
      isDismissible: false,
      showClose: false,

      //h: 130
    );
  }
}
