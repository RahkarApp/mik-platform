import 'package:get/get.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/permissionfx.dart';
import 'package:mik_data/utils/variable.dart';

class PersonSupplierScreenController extends GetxController {
  RxBool change = false.obs;
  RxInt total = 0.obs, discount = 0.obs;
  RxList<InvoiceDB> inv = <InvoiceDB>[].obs;
  init(item) {
    total.value = 0;
    inv.value = invoice.values
        .where(
          (e) =>
              (e.type == 'buy' &&
              e.personUID == item.uid &&
              e.status!.every((t) => t['status'] != 444)),
        )
        .toList();

    for (var e in inv) {
      total.value += int.parse(InvoiceFX.totalPrice(e).toStringAsFixed(0));
      discount.value += int.parse(
        e.parameters!
            .map((r) => r['name'] == 'discount' ? r['amount'] : 0)
            .toList()
            .reduce((a, b) => a + b)
            .toString(),
      );
    }

    inv.value = inv.where((f) => PermissionFx.isShowFactorItem(f)).toList();

    return '';
  }
}
