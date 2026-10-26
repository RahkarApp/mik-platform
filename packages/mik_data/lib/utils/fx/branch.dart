import 'package:flutter/cupertino.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_utils/public/date.dart';

import '../../models/models.dart';

class BranchFX {
  static String name(uid) {
    try {
      var br = branch.values.firstWhere((e) => e.uid == uid);
      return br.name;
    } catch (e) {
      return '';
    }
  }

  static Widget showListItem(List<String> uids) {
    var br = branch.values.where((b) => uids.contains(b.uid)).toList();
    return Wrap(
      children: [
        for (int i = 0; i < br.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(br[i].name),
          ),
      ],
    );
  }

  static showID(int id) {
    String sid = id.toString();
    String s = sid;
    for (var i = 0; i < 4 - sid.length; i++) {
      s = '0$s';
    }
    return s;
  }

  static monthSell(String uid, {month}) {
    List<DateTime> d = DateConvertor.dateTimeMonthRang(month: month);
    DateTime startDate = d[0];
    DateTime endDate = d[1];
    List<InvoiceDB> fct = invoice.values.where((f) => f.type!.contains(uid) && DateTime.parse(f.date!).isAfter(startDate) && DateTime.parse(f.date!).isBefore(endDate) && f.type != 'buy').toList();
    return AccountingFX.findTotalInvoice(fct, false);
  }

  static mikyarCount(String uid) {
    return mikyarPermissionExt.values.where((w) => w.branch!.contains(uid)).toList().length;
  }

  static List<WarehouseNameDB> warehouse(String uid) {
    List wb = branchAccess.values.where((t) => t.branchUID == uid).map((p) => p.warehouseUID).toList();
    List wbranch = [];
    for (var i = 0; i < wb.length; i++) {
      wbranch.addAll(wb[i]);
    }

    return warehouseName.values.where((e) => wbranch.contains(e.uid)).toList();
  }

  static List<String> warehouseUIDs(String uid) {
    List<WarehouseNameDB> w = warehouse(uid);
    return List<String>.from(w.map((v) => v.uid).toList());
  }

  static showMikyarListName(String uid) {
    List<int> mList = mikyarPermissionExt.values.where((g) => g.branch!.contains(uid)).toList().map((m) => m.yarID).toList();
    List<MiKYarDB> mikyarList = mikyar.values.where((m) => mList.contains(m.id)).toList();
    return Wrap(
      children: [
        for (int i = 0; i < mikyarList.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(mikyarList[i].name!),
          ),
      ],
    );
  }

  //MiKyar
  // static bool checkNeed() {
  //   return mikyarPermissionExt.values
  //       .where((t) => t.branch!.contains(yarID))
  //       .toList()
  //       .isNotEmpty;
  // }
}
