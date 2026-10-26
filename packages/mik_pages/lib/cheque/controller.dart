import 'package:get/get.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/variable.dart';

class ChequeScreenController extends GetxController {
  RxString mode = 'همه'.obs;
  RxString submode = 'سررسید'.obs;
  RxList<ChequeDB> chequeList = <ChequeDB>[].obs;
  RxInt currentIndex = 0.obs;
  RxInt submodeIndex = 1.obs;

  init() {
    if (submode.value == 'همه') {
      chequeList.value = cheque.values
          .where(
            (element) =>
                (mode.value == 'همه' && true) ||
                (mode.value == 'دریافتی' && (element.payeeUID == '' || element.payeeUID == '-')) ||
                (mode.value == 'پرداختی' && (element.holderUID == '' || element.holderUID == '-')),
          )
          .toList();
    } else if (submode.value == 'پاس‌شده') {
      chequeList.value = cheque.values
          .where(
            (element) =>
                element.status == 1 &&
                ((mode.value == 'همه' && true) ||
                    (mode.value == 'دریافتی' && (element.payeeUID == '' || element.payeeUID == '-')) ||
                    (mode.value == 'پرداختی' && (element.holderUID == '' || element.holderUID == '-'))),
          )
          .toList();
    } else if (submode.value == 'سررسید') {
      chequeList.value = cheque.values
          .where(
            (element) =>
                element.status == 0 &&
                DateTime.parse(element.dueDate!).difference(DateTime.now()).inDays <= 1 &&
                ((mode.value == 'همه' && true) ||
                    (mode.value == 'دریافتی' && (element.payeeUID == '' || element.payeeUID == '-')) ||
                    (mode.value == 'پرداختی' && (element.holderUID == '' || element.holderUID == '-'))),
          )
          .toList();
    } else if (submode.value == 'درانتظار') {
      chequeList.value = cheque.values
          .where(
            (element) =>
                element.status == 0 &&
                DateTime.parse(element.dueDate!).difference(DateTime.now()).inDays >= 1 &&
                ((mode.value == 'همه' && true) ||
                    (mode.value == 'دریافتی' && (element.payeeUID == '' || element.payeeUID == '-')) ||
                    (mode.value == 'پرداختی' && (element.holderUID == '' || element.holderUID == '-'))),
          )
          .toList();
    } else if (submode.value == 'پاس‌نشده') {
      chequeList.value = cheque.values
          .where(
            (element) =>
                element.status == 0 &&
                DateTime.parse(element.dueDate!).difference(DateTime.now()).inDays < 0 &&
                ((mode.value == 'همه' && true) ||
                    (mode.value == 'دریافتی' && (element.payeeUID == '' || element.payeeUID == '-')) ||
                    (mode.value == 'پرداختی' && (element.holderUID == '' || element.holderUID == '-'))),
          )
          .toList();
    }
    chequeList.sort((a, b) => DateTime.parse(a.dueDate!).compareTo(DateTime.parse(b.dueDate!)));

    return '';
  }
}
