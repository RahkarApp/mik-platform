import 'package:auto_size_text_plus/auto_size_text_plus.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_consts/colors.dart';

import 'package:mik_consts/units.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/branch.dart';
import 'package:mik_utils/public/color.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_variables/variable.dart';

import '../saveHelper.dart';
import '../variable.dart';

class ProductFX {
  static int minPrice() {
    List<ProductPriceDB> pp = productPrice.values.toList();
    if (pp.isNotEmpty) {
      List price = [];
      for (var i = 0; i < pp.length; i++) {
        price.add(pp[i].price);
        if (pp[i].pro != null) price.addAll(pp[i].pro!.values);
      }
      int min = price.reduce((a, b) => a < b ? a : b);
      return min;
    }
    return 0;
  }

  static int maxPrice() {
    List<ProductPriceDB> pp = productPrice.values.toList();
    if (pp.isNotEmpty) {
      List price = [];
      for (var i = 0; i < pp.length; i++) {
        price.add(pp[i].price);
        if (pp[i].pro != null) price.addAll(pp[i].pro!.values);
      }
      int max = price.reduce((a, b) => a > b ? a : b);
      return max;
    }
    return 0;
  }

  static String minMaxPricePro({required puid, required prouid}) {
    List<ProductPriceDB> pp = productPrice.values
        .where((p) => p.puid == puid)
        .toList();
    if (pp.isNotEmpty) {
      List price = [];
      for (var i = 0; i < pp.length; i++) {
        if (pp[i].pro != null && pp[i].pro![prouid] != null) {
          price.add(pp[i].pro![prouid]);
        } else {
          price.add(pp[i].price);
        }
      }
      if (price.isEmpty) return 'پیش‌فرض';
      int max = price.reduce((a, b) => a > b ? a : b);
      int min = price.reduce((a, b) => a < b ? a : b);

      if (min == max) {
        return Number.addCommas(min);
      }
      return '${Number.addCommas(min)} - ${Number.addCommas(max)}';
    }
    return '';
  }

  static String minMaxPrice({required puid}) {
    List<ProductPriceDB> pp = productPrice.values
        .where((p) => p.puid == puid)
        .toList();
    if (pp.isNotEmpty) {
      List price = [];
      for (var i = 0; i < pp.length; i++) {
        price.add(pp[i].price);
        if (pp[i].pro != null) price.addAll(pp[i].pro!.values);
      }
      int max = price.reduce((a, b) => a > b ? a : b);
      int min = price.reduce((a, b) => a < b ? a : b);
      if (min == max) {
        return Number.addCommas(min);
      }
      return '${Number.addCommas(min)} - ${Number.addCommas(max)}';
    }
    return '';
  }

  static findUID(String uid) {
    var p = product.values.where((w) => w.uid == uid).toList();
    if (p.isNotEmpty) return p[0];
  }

  static findProUID({required String uid, required String prouid}) {
    var pr = productPro.values
        .where((p) => p.productUID == uid && p.uid == prouid)
        .toList();
    if (pr.isNotEmpty) return pr[0];
  }

  static int findPrice(String uid, {String prouid = '-'}) {
    var pp = productPrice.values.where((p) => p.puid == uid).toList();
    if (pp.length == 1) {
      return prouid == '-'
          ? pp[0].price
          : ((pp[0].pro != null
                    ? pp[0].pro![prouid] ?? pp[0].price
                    : pp[0].price) ??
                0);
    } else if (pp.length > 1) {
      int i = pp.indexWhere((e) => e.defaultPrice);
      if (i > -1) {
        return prouid == '-'
            ? pp[i].price
            : ((pp[0].pro != null
                      ? pp[0].pro![prouid] ?? pp[0].price
                      : pp[0].price) ??
                  0);
      } else {
        return prouid == '-'
            ? pp[0].price
            : ((pp[0].pro != null
                      ? pp[0].pro![prouid] ?? pp[0].price
                      : pp[0].price) ??
                  0);
      }
    }
    var pr = productPrice.values
        .where((p) => p.puid == uid && p.defaultPrice)
        .toList();
    if (pr.isEmpty) {
      pr = productPrice.values.where((p) => p.puid == uid).toList();
    }
    if (pr.isNotEmpty) return pr[0].price ?? 0;
    return 0;
  }

  static int findBuyPrice(String uid, {String prouid = '-'}) {
    return ((settings!.profitInInvoice ?? 'FIFO') == 'FIFO')
        ? findBuyPriceFIFO(uid, prouid: prouid)
        : findBuyPriceAverage(uid, prouid: prouid);
  }

  static int findBuyPriceFIFO(String uid, {String prouid = '-'}) {
    List buyInvoice = invoice.values
        .where(
          (element) =>
              element.type == 'buy' &&
              element.status!.every((t) => t['status'] != 444) &&
              element.items!.keys.toList().contains(uid),
        )
        .toList();
    buyInvoice.sort(
      (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)),
    );
    Map itemBuy = {};

    for (var element in buyInvoice) {
      num amount = 0.0;
      if (prouid == '-' || prouid == '') {
        amount = element.items[uid]
            .map((e) => e['amount'] as num)
            .reduce((a, b) => a + b);
      } else {
        List list = [];
        try {
          list = element.items[uid]
              .where((e) => e['prouid'] == prouid)
              .toList();
        } catch (e) {
          list = element.items[uid].where((e) => e['prouid'] == '-').toList();
        }
        if (list.isNotEmpty) {
          amount = list.map((e) => e['amount'] as num).reduce((a, b) => a + b);
        }
      }
      List data;
      if (prouid == '-' || prouid == '') {
        data = element.items[uid];
      } else {
        try {
          data = element.items[uid]
              .where((e) => e['prouid'] == prouid)
              .toList();
        } catch (e) {
          data = element.items[uid].where((e) => e['prouid'] == '-').toList();
        }
      }
      if (data.isNotEmpty)
        itemBuy[element.uid] = {'data': data, 'amount': amount};
    }
    num tAmount = productInAllWarehouse(uid, prouid: prouid);
    num amountChecked = 0;
    int index = -1;
    for (var i = 0; i < itemBuy.keys.toList().length; i++) {
      amountChecked += itemBuy[itemBuy.keys.toList()[i]]['amount'];
      if (tAmount <= amountChecked) {
        index = i;
      }
    }
    int price = 0;
    if (index > -1) {
      for (var element in itemBuy[itemBuy.keys.toList()[index]]['data']) {
        price += element['price'] as int;
      }
      if (price > 0) {
        price = (price / itemBuy[itemBuy.keys.toList()[index]]['data'].length)
            .toInt();
      }
    }

    return price;
  }

  static int findBuyPriceAverage(String uid, {String prouid = '-'}) {
    List buyInvoice = invoice.values
        .where(
          (element) =>
              element.type == 'buy' &&
              element.status!.every((t) => t['status'] != 444) &&
              element.items!.keys.toList().contains(uid),
        )
        .toList();
    buyInvoice.sort(
      (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)),
    );
    Map itemBuy = {};

    for (var element in buyInvoice) {
      num amount = 0.0;
      if (prouid == '-' || prouid == '') {
        amount = element.items[uid]
            .map((e) => e['amount'] as num)
            .reduce((a, b) => a + b);
      } else {
        List list = [];
        try {
          list = element.items[uid]
              .where((e) => e['prouid'] == prouid)
              .toList();
        } catch (e) {
          list = element.items[uid].where((e) => e['prouid'] == '-').toList();
        }
        if (list.isNotEmpty) {
          amount = list.map((e) => e['amount'] as num).reduce((a, b) => a + b);
        }
      }
      var data;
      if (prouid == '-' || prouid == '') {
        data = element.items[uid];
      } else {
        try {
          data = element.items[uid]
              .where((e) => e['prouid'] == prouid)
              .toList();
        } catch (e) {
          data = element.items[uid].where((e) => e['prouid'] == '-').toList();
        }
      }
      if (data.isNotEmpty)
        itemBuy[element.uid] = {'data': data, 'amount': amount};
    }
    num tAmount = itemBuy.isEmpty
        ? 0
        : itemBuy.values.map((r) => r['amount']).reduce((a, b) => a + b);
    num stockAmount = productInAllWarehouse(uid, prouid: prouid);
    num selledAmount = tAmount - stockAmount;
    if (selledAmount > 0) {
      for (var i = 0; i < itemBuy.keys.toList().length; i++) {
        if (selledAmount >= itemBuy[itemBuy.keys.toList()[i]]['amount']) {
          selledAmount -= itemBuy[itemBuy.keys.toList()[i]]['amount'];
          itemBuy[itemBuy.keys.toList()[i]]['amount'] = 0;
        } else {
          itemBuy[itemBuy.keys.toList()[i]]['amount'] -= selledAmount;
          selledAmount = 0;
          break;
        }
      }
    }
    itemBuy.removeWhere((k, v) => v['amount'] == 0);
    int tPrice = 0;
    for (var i = 0; i < itemBuy.keys.toList().length; i++) {
      int price = 0;
      for (var element in itemBuy[itemBuy.keys.toList()[i]]['data']) {
        price += element['price'] as int;
      }
      if (price > 0) {
        tPrice += (price / itemBuy[itemBuy.keys.toList()[i]]['data'].length)
            .toInt();
      }
    }

    return itemBuy.isEmpty
        ? 0
        : (tPrice / itemBuy.keys.toList().length).toInt();
  }

  static List<ProductDB> list({String? type, bool? inventory, String? wuid}) {
    List<ProductDB> p = product.values.toList().reversed.toList();

    if (type != null) {
      p = p.where((e) => e.type == type).toList();
    }
    if (inventory != null) {
      p = p
          .where((e) => inventory ? e.inventory! > 0 : e.inventory! <= 0)
          .toList();
    }
    if (wuid != null) {
      var li = warehouse.values
          .where((p) => p.wuid == wuid && p.inventory > 0)
          .toList();
      List<String> pid = li.map((e) => e.puid).toList();
      p = p.where((e) => pid.contains(e.uid)).toList();
    }
    return p;
  }

  static showID(int id) {
    String sid = id.toString();
    String s = sid;
    for (var i = 0; i < 4 - sid.length; i++) {
      s = '0$s';
    }
    return s;
  }

  static int lastSellPrice(String uid, String prouid) {
    List sellInvoice = invoice.values
        .where(
          (element) =>
              element.type == 'sell' &&
              element.items!.keys.toList().contains(uid),
        )
        .toList();
    sellInvoice.sort(
      (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)),
    );
    if (sellInvoice.isNotEmpty) {
      var lastInvoice = sellInvoice[0];
      var item;
      if (prouid == '-' || prouid == '') {
        item = lastInvoice.items[uid];
      } else {
        try {
          item = lastInvoice.items[uid]
              .where((e) => e['prouid'] == prouid)
              .toList();
        } catch (e) {
          item = lastInvoice.items[uid]
              .where((e) => e['prouid'] == '-')
              .toList();
        }
      }
      if (item.isNotEmpty) {
        return item[0]['price'];
      }
    }
    return 0;
  }

  static int lastBuyPrice(String uid, String prouid) {
    List buyInvoice = invoice.values
        .where(
          (element) =>
              element.type == 'buy' &&
              element.status!.every((t) => t['status'] != 444) &&
              element.items!.keys.toList().contains(uid),
        )
        .toList();
    buyInvoice.sort(
      (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)),
    );
    if (buyInvoice.isNotEmpty) {
      var lastInvoice = buyInvoice[0];
      var item;
      if (prouid == '-' || prouid == '') {
        item = lastInvoice.items[uid];
      } else {
        try {
          item = lastInvoice.items[uid]
              .where((e) => e['prouid'] == prouid)
              .toList();
        } catch (e) {
          item = lastInvoice.items[uid]
              .where((e) => e['prouid'] == '-')
              .toList();
        }
      }
      if (item.isNotEmpty) {
        return item[0]['price'];
      }
    }
    return 0;
  }

  static double inventory(String uid) {
    double i = 0.0;
    for (var element in warehouse.values.where((e) => e.puid == uid).toList()) {
      i += element.inventory;
    }
    return i;
  }

  static bool used(String uid) {
    for (var element in invoice.values) {
      for (var e in element.items!.keys.toList()) {
        if (e == uid) {
          return true;
        }
      }
    }
    return false;
  }

  static bool propertyUsed(String uid) {
    for (var i = 0; i < productPro.length; i++) {
      var ppro = productPro.getAt(i)!;
      for (var p in ppro.property!) {
        if (p['uid'] == uid) return true;
      }
    }
    return false;
  }

  static bool propertyValueUsed(String uid, int vid) {
    for (var i = 0; i < productPro.length; i++) {
      var ppro = productPro.getAt(i)!;
      for (var p in ppro.property!) {
        if (p['uid'] == uid && p['vid'] == vid) return true;
      }
    }
    return false;
  }

  static unitName(int? unitCode) {
    if (unitCode == null) return '';
    return productUnits[unitCode]['name'] ?? '';
  }

  static editCat(context, {required int index, required callback}) {
    CategoryDB cat = category.getAt(index)!;

    final formKey = GlobalKey<FormState>();
    final nameCtl = TextEditingController(text: cat.name);
    final descCtl = TextEditingController(text: cat.description);
    final nameF = FocusNode();
    nameF.requestFocus();
    MyBottomSheet.view(
      context,
      child: (scrollController) => Obx(
        () => darkMode.isFalse || darkMode.isTrue
            ? Form(
                key: formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    Input(
                      name: 'نام دسته‌بندی',
                      focusNode: nameF,
                      rightPadding: 120,
                      require: true,
                      controller: nameCtl,
                    ),
                    Input(
                      name: 'توضیحات',
                      minLines: 2,
                      maxLines: 2,
                      controller: descCtl,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: BTN(
                            name: 'ویرایش',
                            type: BTNType.ok,
                            onTap: () async {
                              // SystemChannels.textInput.invokeMethod('TextInput.hide');
                              if (nameCtl.text.isEmpty) {
                                Alert.error('نام دسته‌بندی را وارد کنید.');
                              } else {
                                var item = CategoryDB(
                                  id: cat.id,
                                  uid: cat.uid,
                                  name: nameCtl.text,
                                  description: descCtl.text,
                                  type: cat.type,
                                  parent: cat.parent,
                                  inserter: cat.inserter,
                                  backup: 'edit',
                                  isActive: true,
                                  isCustom: cat.isCustom,
                                );
                                await SaveHelper.save(item, index: index);

                                Get.back();
                                callback({'name': item.name, 'uid': item.uid});
                              }
                            },
                          ),
                        ),
                        Flexible(
                          child: BTN(
                            name: 'انصراف',
                            type: BTNType.cancel,
                            onTap: () => Get.back(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : Container(),
      ),
      title: 'ویرایش نام دسته‌بندی',
    );
  }
  // static addCat(context, {int? index, String? type, required callback}) {
  //   CategoryDB? cat;
  //   int? idItem;
  //   String? uidItem;
  //   RxString tp = type != null
  //       ? type == 'product'
  //           ? 'کالا'.obs
  //           : 'خدمت'.obs
  //       : ''.obs;
  //   //String typeString = type == 'product' ? 'کالا' : 'خدمت';
  //   if (index != null && index > -1) {
  //     cat = category.getAt(index)!;
  //     idItem = cat.id;
  //     uidItem = cat.uid;
  //   }
  //   final formKey = GlobalKey<FormState>();
  //   final nameCtl = TextEditingController(text: cat != null ? cat.name : '');
  //   final descCtl = TextEditingController(text: cat != null ? cat.description : '');
  //   final nameF = FocusNode();
  //   nameF.requestFocus();
  //   final selectedParent = ''.obs;
  //   MyBottomSheet.view(
  //     context,
  //     child: (scrollController) => Obx(() => darkMode.isFalse || darkMode.isTrue
  //         ? Form(
  //             key: formKey,
  //             child: Column(children: [
  //               if ((index == null || index == 0) && type == null)
  //                 MyTab(
  //                     tab: const ['کالا', 'خدمت'],
  //                     value: tp,
  //                     callback: (v) {
  //                       tp.value = v;
  //                       if (v == 'کالا') {
  //                         type = 'product';
  //                       } else {
  //                         type = 'service';
  //                       }
  //                     }),
  //               const SizedBox(height: 5),
  //               Input(name: 'نام دسته‌بندی', focusNode: nameF, rightPadding: 120, require: true, controller: nameCtl),
  //               Input(name: 'توضیحات', minLines: 2, maxLines: 2, controller: descCtl),
  //               Dropdown(
  //                 name: 'والد',
  //                 items_Value: category.values.map((e) => ItemValue(text: e.name!, data: e.uid)).toList(),
  //                 onChange: (v) {
  //                   selectedParent.value = v.data;
  //                 },
  //               ),
  //               Row(mainAxisAlignment: MainAxisAlignment.center, children: [
  //                 Flexible(
  //                     child: BTN(
  //                         name: cat == null ? 'افزودن' : 'ویرایش',
  //                         type: BTNType.ok,
  //                         onTap: () async {
  //                           // SystemChannels.textInput.invokeMethod('TextInput.hide');
  //                           if (nameCtl.text.isEmpty) {
  //                             Alert.error('نام دسته‌بندی را وارد کنید.');
  //                           } else if (type == null) {
  //                             Alert.error('نوع دسته‌بندی را انتخاب کنید.');
  //                           } else {
  //                             var item = CategoryDB(
  //                                 id: idItem ?? ID.newId(category),
  //                                 uid: uidItem ?? ID.uidNew(),
  //                                 name: nameCtl.text,
  //                                 description: descCtl.text,
  //                                 type: type,
  //                                 parent: selectedParent.value,
  //                                 inserter: 0,
  //                                 backup: idItem == null ? 'new' : 'edit',
  //                                 isActive: true,
  //                                 isCustom: cat?.isCustom ?? true);
  //                             idItem == null ? await SaveHelper.save(item) : await SaveHelper.save(item, index: index);

  //                             Get.back();
  //                             callback({'name': item.name, 'uid': item.uid});
  //                           }
  //                         })),
  //                 Flexible(child: BTN(name: 'انصراف', type: BTNType.cancel, onTap: () => Get.back()))
  //               ]),
  //               // Text('برای انصراف و لغو به پایین بکشید.')
  //             ]))
  //         : Container()),
  //     fitSize: index == null ? 0.55 : 0.48,
  //     title: idItem == null ? 'افزودن دسته‌بندی جدید' : 'ویرایش دسته‌بندی',
  //   );
  // }

  static String catName(String uid) {
    var cat = category.values.where((e) => e.uid == uid).toList();
    if (cat.isNotEmpty) {
      return cat[0].name!;
    }
    return '';
  }

  static String catListName(List<String> catList) {
    String cat = '';
    List catt = category.values.where((e) => catList.contains(e.uid)).toList();
    for (var e in catt) {
      if (cat == '') {
        cat = '${e.name}';
      } else {
        cat = '$cat, ${e.name}';
      }
    }
    return cat;
  }

  static int inCat(String uid) {
    return product.values
        .where(
          (e) =>
              e.catIDList != null &&
              e.catIDList!.any((id) => id == uid || id.startsWith(uid)),
        )
        .toList()
        .length;
    //return product.values.where((e) => (e.catIDList != [] && e.catIDList!.contains(uid))).toList().length;
  }

  static String warehouseNames(String uid) {
    if (warehouseName.isEmpty) return '';
    try {
      return warehouseName.values.where((w) => w.uid == uid).first.name;
    } catch (e) {
      return '';
    }
  }

  static warehouseNameItemByUID(String uid) {
    WarehouseNameDB? w;
    for (var i = 0; i < warehouseName.length; i++) {
      var v = warehouseName.getAt(i)!;
      if (v.uid == uid) {
        w = v;
        break;
      }
    }
    return w ?? false;
  }

  static int inWarehouse(String uid) {
    return warehouse.values
        .where((w) => w.wuid == uid && w.inventory > 0)
        .length;
  }

  static double inventoryWarehouse(String uid) {
    List<double> ww = List<double>.from(
      (warehouse.values.map((d) {
        if (d.wuid == uid) {
          return d.inventory;
        } else {
          return 0.0;
        }
      })).toList(),
    );
    if (ww.isNotEmpty) return ww.reduce((a, b) => a + b);
    return 0.0;
  }

  static double productInWarehouse(String puid, String prouid, String wuid) {
    List w = warehouse.values
        .where(
          (e) =>
              e.puid == puid &&
              ((prouid != '-' && prouid != '') ? e.prouid == prouid : true) &&
              e.wuid == wuid,
        )
        .toList();
    double inv = 0.0;
    for (var e in w) {
      inv = inv + e.inventory;
    }
    return inv;
  }

  static double productInWarehouseAccess(
    String puid,
    String prouid,
    String wuid,
  ) {
    List w = warehouse.values
        .where(
          (e) =>
              warehouses.contains(e.wuid) &&
              e.puid == puid &&
              ((prouid != '-' && prouid != '') ? e.prouid == prouid : true) &&
              e.wuid == wuid,
        )
        .toList();
    double inv = 0.0;
    for (var e in w) {
      inv = inv + e.inventory;
    }
    return inv;
  }

  static double productInAllWarehouseAccess(String puid, {String? prouid}) {
    List w = prouid == null
        ? warehouse.values
              .where((e) => warehouses.contains(e.wuid) && e.puid == puid)
              .toList()
        : warehouse.values
              .where(
                (e) =>
                    warehouses.contains(e.wuid) &&
                    e.puid == puid &&
                    e.prouid == prouid,
              )
              .toList();

    double inv = 0.0;
    for (var e in w) {
      inv = inv + e.inventory;
    }
    return inv;
  }

  static double productInAllWarehouse(String puid, {String? prouid}) {
    List w = prouid == null || prouid == '-' || prouid == ''
        ? warehouse.values.where((e) => e.puid == puid).toList()
        : warehouse.values
              .where((e) => e.puid == puid && e.prouid == prouid)
              .toList();

    double inv = 0.0;
    for (var e in w) {
      inv = inv + e.inventory;
    }
    return inv;
  }

  static double productInBranch(String puid, String prouid, String buid) {
    List wb = branchAccess.values
        .where((t) => t.branchUID == buid)
        .map((p) => p.warehouseUID)
        .toList();
    List wbranch = [];
    for (var i = 0; i < wb.length; i++) {
      wbranch.addAll(wb[i]);
    }
    List w = prouid == '-'
        ? warehouse.values
              .where((e) => e.puid == puid && wbranch.contains(e.wuid))
              .toList()
        : warehouse.values
              .where(
                (e) =>
                    e.puid == puid &&
                    e.prouid == prouid &&
                    wbranch.contains(e.wuid),
              )
              .toList();
    double inv = 0.0;
    for (var e in w) {
      inv = inv + e.inventory;
    }
    return inv;
  }

  static selectWarehouse(String branchUID, String puid, String prouid) {
    if (branchUID != '') {
      List<WarehouseNameDB> w = BranchFX.warehouse(branchUID);
      for (var i = 0; i < w.length; i++) {
        if (productInWarehouse(puid, prouid, w[i].uid!) > 0) {
          return w[i].uid!;
        }
      }
    } else {
      String? pw = warehouseName.getAt(0)!.uid;
      if (productInWarehouse(puid, prouid, pw!) > 0) {
        return pw;
      } else {
        return warehouse.values
            .where(
              (e) => e.puid == puid && e.prouid == prouid && e.inventory > 0,
            )
            .toList()
            .first
            .wuid;
      }
    }
  }

  static isPro(puid) {
    return productPro.values
        .where((e) => e.productUID == puid)
        .toList()
        .isNotEmpty;
  }

  static isProSell(puid) {
    List pro = productPro.values.where((e) => e.productUID == puid).toList();
    if (pro.isEmpty) {
      return false;
    } else {
      //
    }
  }

  static proWidget(puid, prouid) {
    List ppp = productPro.values
        .where((e) => e.productUID == puid && e.uid == prouid)
        .toList();
    if (ppp.isNotEmpty) {
      ProductProDB pp = ppp[0];
      return productProNameWidget(pp.property);
    }
    return Container();
  }

  static proName(puid, prouid) {
    List ppp = productPro.values
        .where((e) => e.productUID == puid && e.uid == prouid)
        .toList();
    if (ppp.isNotEmpty) {
      ProductProDB pp = ppp[0];
      return productProName(pp.property);
    }
    return Container();
  }

  static productProNameWidget(p) {
    List<Widget> wed = [];

    for (var i = 0; i < p.length; i++) {
      ProductPropertyDB prop = productProperty.values
          .where((e) => e.uid == p[i]['uid'])
          .toList()[0];
      var pvalue = prop.value.where((r) => r['id'] == p[i]['vid']).toList()[0];
      wed.add(
        Container(
          width: 40,
          height: 29,
          padding: EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: prop.type == "color" && int.tryParse(pvalue['code']) != null
                ? Color(int.parse(pvalue['code']))
                : null,
            border: prop.type == "color" && int.tryParse(pvalue['code']) != null
                ? null
                : Border.all(
                    width: 0.3,
                    color: darkMode.isTrue ? Colors.white : Colors.black,
                  ),
            borderRadius: BorderRadius.circular(7),
          ),
          margin: EdgeInsets.only(left: 5),
          child: Column(
            children: [
              Container(
                // padding: EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                height: 12,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 0.3,
                      color:
                          isColorDark(
                            prop.type == "color"
                                ? pvalue['code'] != null && pvalue['code'] != ''
                                      ? Color(
                                          int.tryParse(pvalue['code']) ??
                                              443547886,
                                        )
                                      : darkMode.value
                                      ? AppColors.backgroundDarkMode
                                      : AppColors.boxBackground
                                : darkMode.value
                                ? AppColors.backgroundDarkMode
                                : AppColors.boxBackground,
                          )
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  // border: Border.all(width: 0.3),
                  // borderRadius: BorderRadius.circula9r(10)
                ),
                child: AutoSizeText(
                  prop.name,
                  maxLines: 1,
                  maxFontSize: 9,
                  minFontSize: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // fontSize: 8,
                    color:
                        isColorDark(
                          prop.type == "color"
                              ? pvalue['code'] != null && pvalue['code'] != ''
                                    ? Color(
                                        int.tryParse(pvalue['code']) ??
                                            443547886,
                                      )
                                    : darkMode.value
                                    ? AppColors.backgroundDarkMode
                                    : AppColors.boxBackground
                              : darkMode.value
                              ? AppColors.backgroundDarkMode
                              : AppColors.boxBackground,
                        )
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
              Container(
                height: 14.4,
                alignment: Alignment.center,
                child: AutoSizeText(
                  pvalue!['name'],
                  maxLines: 1,
                  maxFontSize: 9,
                  minFontSize: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        isColorDark(
                          prop.type == "color"
                              ? pvalue['code'] != null && pvalue['code'] != ''
                                    ? Color(
                                        int.tryParse(pvalue['code']) ??
                                            443547886,
                                      )
                                    : darkMode.value
                                    ? AppColors.backgroundDarkMode
                                    : AppColors.boxBackground
                              : darkMode.value
                              ? AppColors.backgroundDarkMode
                              : AppColors.boxBackground,
                        )
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      // } else {
      //   text += ' $pvalue';
      // }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: wed.map((e) => e).toList()),
    );
  }

  static productProName(p) {
    String text = '';
    for (var i = 0; i < p.length; i++) {
      ProductPropertyDB prop = productProperty.values
          .where((e) => e.uid == p[i]['uid'])
          .toList()[0];
      String pvalue = prop.value
          .where((r) => r['id'] == p[i]['vid'])
          .toList()[0]['name'];
      if (text == '') {
        text = pvalue;
      } else {
        text += ' $pvalue';
      }
    }
    return text;
  }
}
