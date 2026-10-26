

import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/variable.dart';

class MiKyarFX {
  static MiKYarDB find(int id) {
    var y = mikyar.values.where((e) => e.id == id).toList();
    if (y.isNotEmpty) {
      return y[0];
    } else {
      return MiKYarDB(id: 0, mobile: '', name: '', post: '', permission: '', permissionUID: '', inserter: 0, active: true);
    }
  }

  static Future<bool> hasAction(int id) async {
    List b = bill.values.where((e) => e.inserter == id).toList();
    List p = person.values.where((e) => e.inserter == id).toList();
    List pr = product.values.where((e) => e.inserter == id).toList();
    return b.isEmpty && p.isEmpty && pr.isEmpty;
  }
}
