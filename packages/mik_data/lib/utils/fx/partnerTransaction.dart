import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/price.dart';


import '../saveHelper.dart';
import '../variable.dart';

class PartnerTransactionFX {
  static add(data) async {
    return await SaveHelper.save(data);
  }

  static delete(context, item, callback) {
    Confirm.con(
      context,
      onTapConfirm: () async {
        for (var i = 0; i < partnerTransaction.length; i++) {
          var d = partnerTransaction.getAt(i);
          if (d!.uid == item.uid) {
            await SaveHelper.delete(d, i);
            callback('change');
            break;
          }
        }
        Get.back();
        Alert.success('حذف تراکنش با موفقیت انجام شد.');
      },
      confirmText: 'حذف تراکنش',
      subtex: item.status == 'invest'
          ? 'حذف سرمایه گذاری به مبلغ: ${Price.showWithCurrency(item.amount)} در: ${DateConvertor.grigoriToJalali(item.date)}'
          : 'حذف برداشت به مبلغ: ${Price.showWithCurrency(item.amount)} در: ${DateConvertor.grigoriToJalali(item.date)}',
      type: ConfirmType.DELETE,
    );
  }
}
