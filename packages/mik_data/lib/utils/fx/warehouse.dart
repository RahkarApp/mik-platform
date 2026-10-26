// ignore_for_file: non_constant_identifier_names

import 'package:flutter/cupertino.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_utils/public/findID.dart';

import '../../models/models.dart';
import '../saveHelper.dart';
import '../variable.dart';

class WarehouseFX {
  static divide({required String wuid, required String puid, required List<String> proUID, required List<double> amount}) async {
    String parentuid = ID.uidNew();
    int parentid = ID.newId(warehouseHistory);
    String p = puid;
    for (var i = 0; i < warehouse.length; i++) {
      WarehouseDB w = warehouse.getAt(i)!;
      if (w.wuid == wuid && w.puid == p && (w.prouid == "-" || w.prouid == '')) {
        // num c = amount.reduce((value, element) => value + element);
        w.inventory = 0;
        await SaveHelper.save(w, index: i);
        WarehouseHistoryDB f = WarehouseHistoryDB(
          id: parentid,
          uid: parentuid,
          parentuid: parentuid,
          from: w.wuid,
          to: w.wuid,
          date: DateTime.now().toIso8601String(),
          by: profile.getAt(0)!.id.toString(),
          type: 'devider',
          puid: p,
          amount: amount.reduce((value, element) => value + element),
          inserter: 0,
          prouid: '-',
          backup: 'new',
        );
        await SaveHelper.save(f);
        break;
      }
    }
    for (var j = 0; j < proUID.length; j++) {
      bool exist = false;
      for (var i = 0; i < warehouse.length; i++) {
        WarehouseDB w = warehouse.getAt(i)!;
        if (w.wuid == wuid && w.puid == p && w.prouid == proUID[j] && w.prouid != '-' && w.prouid != '') {
          w.inventory += amount[j];
          await SaveHelper.save(w, index: i);
          exist = true;
          break;
        }
      }
      if (!exist) {
        var inW = WarehouseDB(id: ID.newId(warehouse), uid: ID.uidNew(), wuid: wuid, puid: p, prouid: proUID[j], inventory: amount[j], inserter: 0, backup: 'new');
        await SaveHelper.save(inW);
      }
      WarehouseHistoryDB f = WarehouseHistoryDB(
        id: ID.newId(warehouseHistory),
        uid: ID.uidNew(),
        parentuid: parentuid,
        from: wuid,
        to: wuid,
        date: DateTime.now().toIso8601String(),
        by: profile.getAt(0)!.id.toString(),
        type: 'devider',
        puid: p,
        amount: amount[j],
        inserter: 0,
        prouid: proUID[j],
        backup: 'new',
      );
      await SaveHelper.save(f);
    }
    return 'ok';
  }

  static W2W({required String from, required String to, required List<String> puid, required List<String> proUID, required List<double> amount}) async {
    String parentuid = ID.uidNew();
    int parentid = ID.newId(warehouseHistory);
    for (var j = 0; j < puid.length; j++) {
      String p = puid[j];
      String proid = proUID[j];
      double am = amount[j];
      WarehouseDB? outW, inW;
      int? outIndex, inIndex;
      for (var i = 0; i < warehouse.length; i++) {
        WarehouseDB w = warehouse.getAt(i)!;
        if (w.wuid == from && w.puid == p) {
          // && w.propertyuid == proid
          outW = w;
          outIndex = i;
        }
        if (w.wuid == to && w.puid == p) {
          // && w.propertyuid == proid
          inW = w;
          inIndex = i;
        }
        if (inIndex != null && outIndex != null) {
          break;
        }
      }
      if (outW != null) {
        outW.inventory -= am;
        await SaveHelper.save(outW, index: outIndex);
      }
      if (inW != null) {
        inW.inventory += am;
        await SaveHelper.save(inW, index: inIndex);
      } else {
        inW = WarehouseDB(id: ID.newId(warehouse), uid: ID.uidNew(), wuid: to, puid: p, prouid: proid, inventory: am, inserter: 0, backup: 'new');
        await SaveHelper.save(inW);
      }

      WarehouseHistoryDB f = WarehouseHistoryDB(
        id: j == 0 ? parentid : ID.newId(warehouseHistory),
        uid: j == 0 ? parentuid : ID.uidNew(),
        parentuid: parentuid,
        from: from,
        to: to,
        date: DateTime.now().toIso8601String(),
        by: profile.getAt(0)!.id.toString(),
        type: 'W2W',
        puid: p,
        amount: am,
        inserter: 0,
        prouid: proid,
        backup: 'new',
      );
      await SaveHelper.save(f);
    }
    return 'ok';
  }

  static IW({
    required String invoiceUID,
    required List<String> warehouseUID,
    required List<String> puid,
    required List<String> proUID,
    required List<double> amount,

    ///I2W,W2I
    required String type,
    bool saveToServer = true,
  }) async {
    int parentid = ID.newId(warehouseHistory);
    String parentuid = ID.uidNew();
    for (var j = 0; j < puid.length; j++) {
      String p = puid[j];
      ProductDB pr = ProductFX.findUID(p);
      String proid = proUID[j];
      String wuid = warehouseUID[j];
      double am = amount[j];
      WarehouseDB? war;
      int? index;
      if (pr.type == 'product') {
        for (var i = 0; i < warehouse.length; i++) {
          WarehouseDB w = warehouse.getAt(i)!;
          if (w.wuid == wuid && w.puid == p) {
            //&& w.propertyuid == proid
            war = w;
            index = i;
            break;
          }
        }
        if (war != null) {
          if (type == 'W2I') {
            war.inventory -= am;
          } else if (type == 'I2W') {
            war.inventory += am;
          }
          await SaveHelper.save(war, index: index, saveToServer: saveToServer);
        } else {
          war = WarehouseDB(id: ID.newId(warehouse), uid: ID.uidNew(), wuid: wuid, puid: p, prouid: proid, inventory: am, inserter: 0, backup: saveToServer ? 'new' : 'ok');
          await SaveHelper.save(war, saveToServer: saveToServer);
        }

        if (saveToServer) {
          WarehouseHistoryDB f = WarehouseHistoryDB(
            id: j == 0 ? parentid : ID.newId(warehouseHistory),
            uid: j == 0 ? parentuid : ID.uidNew(),
            parentuid: parentuid,
            from: type == 'I2W' ? invoiceUID : wuid,
            to: type == 'I2W' ? wuid : invoiceUID,
            date: DateTime.now().toIso8601String(),
            by: profile.getAt(0)!.id.toString(),
            type: type,
            puid: p,
            amount: am,
            prouid: proid,
            inserter: 0,
            backup: 'new',
          );
          await SaveHelper.save(f);
        }
      }
    }
    return 'ok';
  }

  static IWD({
    required String invoiceUID,
    required List<String> puid,
    required List<String> proUID,
    required List<double> amount,

    ///buy,sell
    required String type,
  }) {
    if (type == 'buy') {
      for (var i = 0; i < warehouseHistory.length; i++) {
        var w = warehouseHistory.getAt(i)!;
        if (w.type == 'I2W' && w.from == invoiceUID && puid.contains(w.puid) && proUID[puid.indexOf(w.puid)] == w.prouid) {
        } else if (w.type == 'W2I' && w.to == invoiceUID && puid.contains(w.puid) && proUID[puid.indexOf(w.puid)] == w.prouid) {}
      }
    }
  }

  static String findFrom(puid, prouid, fuid, type) {
    if (type == 'buy') {
      var l = warehouseHistory.values.where((w) => (w.type == 'I2W' && w.from == fuid && w.puid == puid && w.prouid == prouid)).toList();
      if (l.isNotEmpty) return l[0].to;
    } else {
      var l = warehouseHistory.values.where((w) => (w.type == 'W2I' && w.to == fuid && w.puid == puid && w.prouid == prouid)).toList();
      if (l.isNotEmpty) {
        return l[0].from;
      }
    }
    return '';
  }

  static findFromName(pid, prouid, fuid, type) {
    if (type == 'buy') {
      return 'به انبار ${ProductFX.warehouseNames(findFrom(pid, prouid, fuid, type))}';
    } else {
      return 'از انبار ${ProductFX.warehouseNames(findFrom(pid, prouid, fuid, type))}';
    }
  }

  static Widget showListName(List<String> uids, {bool? all, String? defaultWarehouse}) {
    var wl = warehouseName.values.where((w) => uids.contains(w.uid)).toList();
    if (all ?? false) wl = warehouseName.values.toList();
    return Wrap(
      children: [
        for (int i = 0; i < wl.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 5,
              children: [
                if (defaultWarehouse == wl[i].uid) Icon(IconsaxPlusLinear.tick_square, color: AppColors.grey, size: 20),
                Text(wl[i].name),
              ],
            ),
          ),
      ],
    );
  }

  static branchName(String uid) {
    List<BranchAccessDB> ba = branchAccess.values.where((b) => b.warehouseUID!.contains(uid)).toList();
    List<String> bal = ba.map((b) => b.branchUID).toList();
    List<BranchDB> br = branch.values.where((b) => bal.contains(b.uid)).toList();
    List<String> bname = br.map((b) => b.name).toList();
    if (bname.isEmpty) {
      return 'عمومی';
    } else {
      return 'شعبه: ${bname[0]}';
    }
  }

  static deleteHistory(List<String> uid) async {
    for (var i = 0; i < warehouseHistory.length; i++) {
      if (uid.contains(warehouseHistory.getAt(i)!.uid)) {
        await warehouseHistory.deleteAt(i);
      }
    }
  }
}
