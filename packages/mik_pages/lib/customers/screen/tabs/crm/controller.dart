part of '../../screen.dart';

class CRMTabDashboardController extends GetxController {
  final RxList<ConnectionDB> _conn = <ConnectionDB>[].obs;
  // final ScrollController  scl = ScrollController();

  init() {
    _conn.value = [];
    if (customerSearch.value.length >= 2) {
      _conn.value = connection.values
          .where(
            (w) =>
                PersonFX.findByUID(w.personUID).name
                    .toString()
                    .replaceAll(' ', '')
                    .toLowerCase()
                    .toEnglishDigit()
                    .contains(
                      customerSearch.value
                          .replaceAll(' ', '')
                          .toLowerCase()
                          .toEnglishDigit(),
                    ) ||
                w.desc!
                    .replaceAll(' ', '')
                    .toLowerCase()
                    .toEnglishDigit()
                    .contains(
                      customerSearch.value
                          .replaceAll(' ', '')
                          .toLowerCase()
                          .toEnglishDigit(),
                    ) ||
                w.id
                        .toString()
                        .toEnglishDigit()
                        .replaceAll(' ', '')
                        .toLowerCase() ==
                    customerSearch.value
                        .toEnglishDigit()
                        .replaceAll(' ', '')
                        .toLowerCase(),
          )
          .toList();
    } else if (customerSearch.value.length < 2) {
      _conn.value = connection.values.toList().toList();
    }

    _conn.value = _conn.reversed.toList();
  }
}
