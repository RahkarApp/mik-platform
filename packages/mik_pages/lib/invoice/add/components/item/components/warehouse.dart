import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/input/warehuose.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/invoice/add/components/model.dart';
import 'package:mik_variables/variable.dart';

class WarehouseChangeInvoice extends GetView {
  late final InvoiceItemModel item;
  late final InvoiceProItemModel pro;
  late final String type;
  late final String? branchUID;
  late final dynamic callback;
  final RxBool change = false.obs;
  WarehouseChangeInvoice({
    required this.item,
    required this.pro,
    required this.type,
    this.branchUID,
    required this.callback,
    super.key,
  }) : remote = null;
  late final ({String value, VoidCallback? onTap})? remote;
  WarehouseChangeInvoice.remote({
    super.key,
    required String value,
    VoidCallback? onTap,
  }) {
    remote = (value: value, onTap: onTap);
  }

  final warehouseCtl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final row = remote;
    if (row != null) {
      return Obx(
        () => InkWell(
          onTap: row.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 30,
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: darkMode.isFalse ? Colors.white : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: darkMode.isFalse
                    ? Colors.grey.shade300
                    : Colors.grey.shade700,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: darkMode.isFalse
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'انبار',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, height: 1),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Icon(
                    IconsaxPlusLinear.arrow_down,
                    size: 16,
                    color: row.onTap == null ? Colors.grey : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (type == 'pf') return Container(height: 30);
    return Container(
      height: 30,
      //  width: 100,
      margin: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: darkMode.isFalse ? Colors.white : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: darkMode.isFalse ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              color: darkMode.isFalse
                  ? Colors.grey.shade300
                  : Colors.grey.shade700,
            ),
            child: const Text(
              'انبار',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1, fontSize: 10),
            ),
          ),
          Obx(
            () => change.isTrue || change.isFalse
                ? Container(
                    width: 100,
                    alignment: Alignment.center,
                    child: // type != 'buy'
                        //?
                        WarehouseInput(
                          controller: warehouseCtl,
                          selectedUID: pro.warehouseUID,
                          branchUID: branchUID,
                          puid: item.uid,
                          prouid: pro.uid,
                          type: type,
                          onChanged: (v) {
                            callback(pro.uid, v);
                            change.toggle();
                          },
                          isBox: true,
                          name: 'انبار',
                        ),
                    // : Text(
                    //     wName(),
                    //     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    //   ),
                  )
                : Container(),
          ),
          Container(
            padding: const EdgeInsets.only(left: 5),
            child: InkWell(
              onTap: null,
              child: (type != 'buy')
                  ? const Icon(
                      IconsaxPlusBold.arrow_swap_horizontal,
                      color: Colors.grey,
                    )
                  : const SizedBox(width: 20),
            ),
          ),
        ],
      ),
    );
  }

  String? wName() {
    var w = warehouseName.getAt(0)!;
    callback(pro.uid, w.uid);
    return w.name;
  }
}
