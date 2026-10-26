import 'package:mik_consts/city.dart';


class City {
  static List<String>? city(String provice) {
    return provinces.contains(provice) ? citis[provice] : null;
  }

  static int stateID(String provice) {
    return provinces.indexOf(provice);
  }

  static int cityID(String provice, String city) {
    return provinces.contains(provice) ? citis[provice]!.indexOf(city) : 0;
  }
}
