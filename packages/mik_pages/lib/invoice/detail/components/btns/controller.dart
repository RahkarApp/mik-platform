part of '../../screen.dart';

class InvoiceBTNController extends GetxController {
  late InvoiceDB item;
  double? paid;

  changeStatus(factorStatus) async {
    if (item.status!.any((t) => t['status'] == 9 || t['status'] == 8)) {
      Alert.error('امکان تغییر وضعیت وجود ندارد.');
    } else if (item.status!.every((t) => t['status'] > factorStatus) &&
        factorStatus != 9) {
      Alert.error('امکان برگشت به وضعیت قبل وجود ندارد.');
    } else if (item.status!.every(
      (t) => t['status'] != 8 && t['status'] != 9,
    )) {
      if (item.status!.every((t) => t['status'] != 100)) {
        await InvoiceFX.onClickStatus(factorStatus, item, paid, true, (v) {});
      } else if (item.status!.any((t) => t['status'] == 100) &&
          factorStatus == 9) {
        await InvoiceFX.onClickStatus(factorStatus, item, paid, true, (v) {});
      } else {
        Alert.info(
          'سفارش تحویل مشتری شده است.\nفقط امکان مرجوع کردن وجود دارد.',
        );
      }
    } else if (item.status!.any((t) => t['status'] == 8)) {
      Alert.error('سفارش لغو شده امکان تغییر وضعیت ندارد.');
    } else if (item.status!.any((t) => t['status'] == 9)) {
      Alert.error('سفارش مرجوع شده امکان تغییر وضعیت ندارد.');
    } else if (item.status == factorStatus) {
      Alert.info('وضعیت فعلی فاکتور.');
    }
  }

  changeStatusFactor(factorItem) async {
    statusChangeFactor.toggle();
    changeFactor.toggle();
    //  await Future.delayed(Duration(microseconds: 50));
    if (item.uid == factorItem.uid) {
      item.status = factorItem.status;
    }
  }
}
