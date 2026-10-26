import 'package:get/get.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/saveHelper.dart';

class ConnectionsFX {
  static add(ConnectionDB data, {bool isBack = false}) async {
    var res = await SaveHelper.save(data);

    if (res == '200') {
      if (isBack) Get.back();
      return 'ok';
    }
    return 'e';
  }
}
