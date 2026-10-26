// ignore_for_file: file_names

import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_utils/public/analytics.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_data/source/database/db.dart';

import 'package:mik_data/source/remote/api.dart';
import 'package:mik_data/utils/variable.dart';

import '../screen/getData.dart';

class GetFirstData {
  static get() async {
    getDataFirstMaxSize.value = 0;
    getDataFirstsavedSize.value = 0;
    await API.getData().then((data) async {
      if (data == '200') {
        Analytics.login();
        // reg.value = false;
        // authCode.value = false;
        // wait.value = false;
        await DB.update();
        return Get.offAllNamed(RoutesName.MAIN);
      } else {
        Analytics.event('loginError');
        Alert.error('لطفا مجددا تلاش کنید');
        await jwt.clear();
        return Get.offAllNamed(RoutesName.LOGIN);
        // _codectl.clear();
        // authCode.value = false;
        // reg.value = false;
      }
    });
  }
}
