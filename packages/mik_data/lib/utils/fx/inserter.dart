import 'package:mik_data/utils/variable.dart';

class InserterFX {
  static find(int inserter) {
    var y = mikyar.values.where((e) => e.id == inserter).toList();
    if (y.isNotEmpty) {
      return {'name': y[0].name, 'id': y[0].id};
    } else {
      return {'name': '', 'id': '0'};
    }
  }
}
