// ignore_for_file: empty_catches, curly_braces_in_flow_control_structures, unnecessary_null_comparison


import 'package:get/get.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_variables/variable.dart';

import '../../models/models.dart';
import '../variable.dart';

class AccountingFX {
  static balance() {
    num invBalance = 0,
        buyBalance = 0,
        sellBalance = 0,
        sellPaidBalance = 0,
        buySellBalance = 0,
        stockSellBalance = 0,
        stockBuyBalance = 0,
        tBalance = 0,
        commissinBalance = 0,
        costBalance = 0,
        shippingCostBalance = 0,
        excessBalance = 0,
        discountBalance = 0,
        profit = 0,
        paidBalance = 0,
        takenBalance = 0,
        debtBalance = 0,
        cerditBalance = 0,
        whitOutFactor = 0,
        chequeHold = 0,
        chequePayee = 0;

    List<String> stockPR = [];
    List stockPrSellPrice = [], stockPrCount = [];
    for (var element in cheque.values) {
      if ((element.holderUID == '' || element.holderUID == '-') && element.status != 1) {
        chequeHold += element.price!;
      }
      if ((element.payeeUID == '' || element.payeeUID == '-') && element.status != 1) {
        chequePayee += element.price!;
      }
    }
    for (var it in partnerTransaction.values) {
      if (it.description == null || (it.description != null && !it.description!.startsWith('ناشی از تقسیم سود'))) {
        invBalance = it.status == 'invest' ? invBalance + it.amount! : invBalance - it.amount!;
      }
    }
    bool checkFirstValueDF = false, checkFirstValueCF = false, checkFirstValueDC = false, checkFirstValueCC = false;

    for (var element in bill.values) {
      if (element.type != 'returned' && element.type != 'cancelled' && element.type != 'deleted' && element.to != null) {
        if ((element.debtorUID == '' || element.debtorUID == '-') && (element.creditorUID == '' || element.creditorUID == '-')) {
        } else {
          if (element.creditorUID == '' || element.creditorUID == '-') {
            takenBalance = takenBalance + element.paid!; //
          } else if ((element.debtorUID != '' && element.debtorUID != '-')) {
            paidBalance = paidBalance + element.paid!; //
          }
        }
      }

      if (element.to == null && (element.debtorUID == '' || element.debtorUID == '-') && !checkFirstValueDF) {
        checkFirstValueDF = true;
        var billListF = bill.values.where((el) => el.to == null && (el.debtorUID == '' || el.debtorUID == '-')).toList();
        var listd = [];
        for (var element in billListF) {
          if (!listd.contains(element.creditorUID)) listd.add(element.creditorUID);
        }

        for (var element in listd) {
          var nbl = billListF.where((dl) => dl.creditorUID == element).toList();
          num paid = 0;
          for (var i = 0; i < nbl.length; i++) {
            paid += nbl[i].paid!;
          }
          paidBalance += (paid - nbl[0].paid!);
          debtBalance += (nbl[0].total! - paid);
        }
      }

      if (element.to == null && (element.creditorUID == '' || element.creditorUID == '-') && !checkFirstValueCF) {
        checkFirstValueCF = true;
        var billListF = bill.values.where((el) => el.to == null && (el.creditorUID == '' || el.creditorUID == '-')).toList();
        List listd = [];
        for (var element in billListF) {
          if (!listd.contains(element.debtorUID)) listd.add(element.debtorUID);
        }
        for (var element in listd) {
          var nbl = billListF.where((dl) => dl.debtorUID == element).toList();
          num total = nbl[0].total!;
          num paid = 0;
          for (var i = 0; i < nbl.length; i++) {
            total -= nbl[i].paid!;
            paid += nbl[i].paid!;
          }
          cerditBalance += total;
          takenBalance += (paid - nbl[0].paid!);
          whitOutFactor += (paid - nbl[0].paid!);
        }
      }

      // if (element.to == null && (element.debtorUID == '' || element.debtorUID == '-') && !checkFirstValueDC) {
      //   checkFirstValueDC = true;
      //   var billListC = bill.values.where((el) => el.to == null && (el.debtorUID == '' || el.debtorUID == '-')).toList();
      //   num total = billListC[0].total!;
      //   for (var i = 0; i < billListC.length; i++) {
      //     total -= billListC[i].paid!;
      //   }
      //   debtBalance += total;
      // }
      // if (element.to == null && (element.creditorUID == '' || element.creditorUID == '-') && !checkFirstValueCC) {
      //   checkFirstValueCC = true;
      //   var billListC = bill.values.where((el) => el.to == null && (el.debtorUID == '' || el.debtorUID == '-')).toList();
      //   num total = billListC[0].total!;
      //   for (var i = 0; i < billListC.length; i++) {
      //     total -= billListC[i].paid!;
      //   }
      //   cerditBalance += total;
      // }

      if (element.to == 'ff') {
        whitOutFactor += element.paid!;
      }
    }

    for (var it in invoice.values) {
      if (it.type == 'buy') {
        buyBalance = buyBalance + total(it.items!);
        //  excessBalance = excessBalance - it.excess!;
        for (var element in it.parameters!) {
          if (element['name'] == 'excess') {
            //   excessBalance = excessBalance - element['amount'];
          } else if (element['name'] == 'discount') {
            discountBalance = discountBalance - element['amount'];
          }
        }
      } else {
        if ((it.status!.every((w) => w['status'] < 7) || it.status!.any((s) => s['status'] == 100)) && !it.status!.every((s) => s['status'] != 900)) {
          buySellBalance = buySellBalance + total(it.items!);
          sellBalance = sellBalance + total(it.items!);
          var thisFactorBill = bill.values.where((element) => it.billUID!.contains(element.uid)).toList();
          double paidForFactor = 0;
          for (var element in thisFactorBill) {
            paidForFactor += element.paid!;
          }
          sellPaidBalance = sellPaidBalance + paidForFactor;
          for (var element in it.parameters!) {
            if (element['name'] == 'excess') {
              excessBalance = excessBalance + element['amount'];
            } else if (element['name'] == 'discount') {
              discountBalance = discountBalance - element['amount'];
            }
          }
        }
      }
      shippingCostBalance = shippingCostBalance + (it.shipping!['cost'] ?? 0);

      for (var i = 0; i < it.items!.keys.toList().length; i++) {
        var pr = findProduct(it.items!.keys.toList()[i]);
        if (pr != null && pr.uid != null && !(pr.archive ?? true) && (pr.type == null || (pr.type != null && pr.type != 'service'))) {
          if (stockPR.contains(it.items!.keys.toList()[i])) {
            int indx = stockPR.indexOf(it.items!.keys.toList()[i]);
            var itemAmount = it.items![it.items!.keys.toList()[i]].map((e) => e['amount']).toList().reduce((a, b) => a + b);
            if (it.type == 'buy') {
              stockPrCount[indx] = stockPrCount[indx] + itemAmount;
            } else if (it.status!.every((e) => e['status'] < 8) || it.status!.any((e) => e['status'] == 100)) {
              stockPrCount[indx] = stockPrCount[indx] - itemAmount;
            }
          } else {
            stockPR.add(it.items!.keys.toList()[i]);
            var itemAmount = it.items![it.items!.keys.toList()[i]].map((e) => e['amount']).toList().reduce((a, b) => a + b);
            if (it.type == 'buy') {
              stockPrCount.add(itemAmount);
            } else {
              //if (it.status! < 8 || it.status! == 100)
              stockPrCount.add(-itemAmount);
            }
            stockPrSellPrice.add(productSellPrice(it.items!.keys.toList()[i]));
          }
        }
      }
      var billitem = it.billUID;
      var billlist = bill.values.where((element) => billitem!.contains(element.uid)).toList();
      if (billlist.isNotEmpty) {
        var tl = billlist[0].total;
        var ptl = 0.0;
        for (var element in billlist) {
          ptl = ptl + element.paid!;
        }
        if (it.type == 'buy') {
          debtBalance = debtBalance + (tl! - ptl);
        } else if ((it.status!.every((s) => s['status'] < 7) || it.status!.map((s) => s['status']).toList().contains(100)) && it.status!.every((s) => s['status'] != 900)) {
          cerditBalance = cerditBalance + (tl! - ptl);
        }
      }
    }
    for (var i = 0; i < product.length; i++) {}

    var sellPriceAll = [];
    for (var element in product.values) {
      // var pr = productPrice.values.where((e) => e.puid == element.uid).toList();
      // log(pr.toString());

      //if (pr.isNotEmpty)
      sellPriceAll.add(ProductFX.productInAllWarehouse(element.uid!) * ProductFX.findPrice(element.uid!));
    }
    if (sellPriceAll.isNotEmpty) stockSellBalance = sellPriceAll.reduce((a, b) => a + b); //total(amount: stockPrCount, price: stockPrSellPrice);
    var pamount = product.values.toList().map((r) => ProductFX.productInAllWarehouse(r.uid!)).toList();
    var puid = product.values.toList().map((r) => r.uid!).toList();
    stockBuyBalance = stockBuyPrice(pr: puid, cnt: pamount);

    for (var it in commission.values) {
      if (it.type == 'commission') {
        commissinBalance = commissinBalance + it.amount!;
      }
    }

    //Total Cost Find
    for (var it in cost.values) {
      costBalance = costBalance + it.price!;
      var billitem = it.billUID;
      var billlist = bill.values.where((element) => billitem!.contains(element.uid)).toList();
      // if(billlist.isNotEmpty)
      var tl = billlist.isNotEmpty ? billlist[0].total : 0;
      var ptl = 0.0;
      for (var element in billlist) {
        ptl = ptl + element.paid!;
      }
      debtBalance = debtBalance + (tl! - ptl);
    }

    tBalance =
        invBalance +
        takenBalance +
        whitOutFactor +
        chequeHold +
        sellPaidBalance -
        paidBalance -
        // commissinBalance -
        shippingCostBalance -
        chequePayee
    // excessBalance -
    // discountBalance +
    ;
    profit = sellBalance > 0
        ? sellBalance + excessBalance - shippingCostBalance - paidBalance
        // -commissinBalance
        : 0;
    int productInStockMinor = 0;
    for (var i = 0; i < product.length; i++) {
      var p = product.getAt(i)!;
      if (
      //product.getAt(i)!.inventory! < 0 &&
      ProductFX.productInAllWarehouse(p.uid!) < 0 && !p.archive! && (p.type == null || (p.type != null && p.type != 'service'))) {
        productInStockMinor++;
      }
    }

    balanceMony = {
      'invBalance': invBalance.toInt(),
      'buyBalance': buyBalance.toInt(),
      'sellBalance': sellBalance.toInt(),
      'sellPaidBalance': sellPaidBalance,
      'paidBalance': paidBalance.toInt(),
      //  'buySellBalance': buySellBalance,
      'debtBalance': debtBalance.toInt(),
      'cerditBalance': cerditBalance.toInt(),
      'takenBalance': takenBalance.toInt(),
      'stockSellBalance': stockSellBalance,
      'stockBuyBalance': stockBuyBalance,
      'commissinBalance': commissinBalance.toInt(),
      'costBalance': costBalance.toInt(),
      //'shippingCostBalance': shippingCostBalance,
      //'excessBalance': excessBalance,
      //'discountBalance':discountBalance,
      'tBalance': tBalance.toInt(),
      'chequeHold': chequeHold,
      'chequePayee': chequePayee,
      'profit': profit.toInt(),
      'productInStockMinor': productInStockMinor,
    }.obs;
    // if (Get.currentRoute == '/Home') {
    //   homePageLoad.value = false;
    //   homePageLoad.value = true;
    // }
  }

  static findPersonFinancial(String uid) {
    List<BillDB> mb = bill.values.where((i) => (i.creditorUID == uid || i.debtorUID == uid) && (i.type != 'returned' && i.type != 'rejected' && i.type != 'cancelled' && i.type != 'deleted')).toList();
    num pt = 0;
    List<String> toUID = [];

    for (var i = 0; i < mb.length; i++) {
      if (mb[i].creditorUID == uid && !toUID.contains(mb[i].toUID)) {
        pt += mb[i].total!;
      }
      if (mb[i].debtorUID == uid && !toUID.contains(mb[i].toUID)) {
        pt -= mb[i].total!;
      }

      if (mb[i].creditorUID == uid) {
        pt -= mb[i].paid!;
      }
      if (mb[i].debtorUID == uid) {
        pt += mb[i].paid!;
      }
      toUID.add(mb[i].toUID!);
    }

    return pt;
  }

  static findInvestPartner(String uid) {
    var totalInvest = 0;
    var totalInvestPR = 0;
    var totalWithdraward = 0;
    var totalProfit = 0;
    var totalProfitWid = 0;
    List<PartnerTransactionDB> list = [];
    for (var element in partnerTransaction.values) {
      if (element.status == 'invest')
        totalInvest = totalInvest + element.amount!;
      else if (element.status == 'withdrawal')
        totalInvest = totalInvest - element.amount!;
      if (element.partnerUID == uid) {
        if (element.status == 'invest')
          totalInvestPR = totalInvestPR + element.amount!;
        else if (element.status == 'withdrawal')
          totalWithdraward = totalWithdraward + element.amount!;
        else
          totalProfitWid = totalProfitWid + element.amount!;
        if (element.description.toString().startsWith('ناشی از تقسیم سود دوره')) totalProfit = totalProfit + element.amount!;
        list.add(element);
      }
    }
    return {'invest': totalInvestPR, 'withdraward': totalWithdraward, 'profit': totalProfit, 'profitWid': totalProfitWid, 'list': list, 'totalInvest': totalInvest};
  }

  static total(Map item, {String type = 'sell'}) {
    num total = 0;
    for (var i = 0; i < item.keys.toList().length; i++) {
      var pro = item[item.keys.toList()[i]];
      for (var j = 0; j < pro.length; j++) {
        var amount = pro[j]['amount'];
        var price = pro[j]['price'];
        total += amount * price;
      }
    }
    return total;
  }

  static totalFromList(List list, {String type = 'sell'}) {
    num total = 0;
    for (var j = 0; j < list.length; j++) {
      var amount = list[j]['amount'];
      var price = list[j]['price'];
      total += amount * price;
    }
    return total;
  }

  static productSellPrice(String uid) {
    var prd = productPrice.values.where((element) => element.puid == uid).toList();
    for (var element in prd) {
      if (element.defaultPrice) return element.price ?? 0;
    }
    if (prd.isNotEmpty) {
      return prd[0].price ?? 0;
    } else {
      return 0;
    }
  }

  static stockBuyPrice({pr, cnt}) {
    num p = 0.0;
    for (var i = 0; i < pr.length; i++) {
      p += ProductFX.findBuyPriceAverage(pr[i]) * cnt[i];
    }
    return p;
  }

  static invDetails(String uid) {
    //invest = await Hive.openBox<InvesmentDB>('invest');
    var totalInvest = 0;
    var totalInvestPR = 0;
    var totalWithdraward = 0;
    var totalProfit = 0;
    var totalProfitWid = 0;
    var list = [];
    for (var element in partnerTransaction.values) {
      if (element.status == 'invest') {
        totalInvest = totalInvest + element.amount!;
      } else if (element.status == 'withdrawal') {
        totalInvest = totalInvest - element.amount!;
      }
      if (element.partnerUID == uid) {
        if (element.status == 'invest') {
          totalInvestPR = totalInvestPR + element.amount!;
        } else if (element.status == 'withdrawal') {
          totalWithdraward = totalWithdraward + element.amount!;
        } else {
          totalProfitWid = totalProfitWid + element.amount!;
        }
        if (element.description.toString().startsWith('ناشی از تقسیم سود دوره')) {
          totalProfit = totalProfit + element.amount!;
        }
        list.add(element);
      }
    }
    var data = {'inv': totalInvestPR, 'wid': totalWithdraward, 'profit': totalProfit, 'profitWid': totalProfitWid, 'list': list, 'invT': totalInvest};
    return data;
  }

  static thisPeriodDetails(endDate, startDate) {
    var thisPeriodBill = financialPeriod.length > 0
        ? bill.values
              .where(
                (element) =>
                    (element.type != 'cancelled' && element.type != 'returned' && element.type != 'deleted') &&
                    DateTime.parse(element.date!).isAfter(DateTime.parse(financialPeriod.getAt(financialPeriod.length - 1)!.endDate!)) &&
                    DateTime.parse(element.date!).isBefore(DateTime.parse(endDate).add(const Duration(days: 1))),
              )
              .toList()
        : startDate == null
        ? bill.values.where((element) => element.type != 'cancelled' && element.type != 'returned' && element.type != 'deleted').toList()
        : bill.values
              .where(
                (element) =>
                    (element.type != 'cancelled' && element.type != 'returned' && element.type != 'deleted') &&
                    DateTime.parse(element.date!).isAfter(DateTime.parse(startDate).add(const Duration(days: -1))) &&
                    DateTime.parse(element.date!).isBefore(DateTime.parse(endDate).add(const Duration(days: 1))),
              )
              .toList();

    num paidC = 0, paidF = 0, unPaid = 0, received = 0, unReceived = 0;
    var allBill = [];
    for (var fc in invoice.values) {
      List status = fc.status!.map((e) => e['status']).toList();
      if (fc.status != null && (status.every((e) => e < 7) || status.contains(100)) && status.contains(900)) {
        allBill.add(thisPeriodBill.where((element) => fc.billUID!.contains(element.uid)).toList());
      }
    }

    for (var fc in cost.values) {
      allBill.add(thisPeriodBill.where((element) => fc.billUID!.contains(element.uid)).toList());
    }

    var sellInvoice = [];
    var sellItem = [];
    for (var thisBill in allBill) {
      try {
        num thisTotal = thisBill[0].total, thisPaid = 0;
        for (var i = 0; i < thisBill.length; i++) {
          if ((thisBill[0].creditorUID == '' || thisBill[0].creditorUID == '-')) {
            if (thisBill[0].to.toString().startsWith('c') || thisBill[0].toUID.toString().startsWith('C-')) {
              paidC = paidC + thisBill[i].paid;
            }
            if (thisBill[0].to.toString().startsWith('f') || thisBill[0].toUID.toString().startsWith('F-')) {
              paidF = paidF + thisBill[i].paid;
            }

            thisPaid += thisBill[i].paid;
            if (i == thisBill.length - 1) {
              unPaid = unPaid + (thisTotal - thisPaid);
            }
            // unPaid = unPaid + (thisBill[i].unPaid ?? 0);
          } else {
            received = received + thisBill[i].paid;
            thisPaid += thisBill[i].paid;
            if (i == thisBill.length - 1) {
              unReceived = unReceived + (thisTotal - thisPaid);
            }
            // if (thisBill[i].unPaid != null)
            //   unReceived = unReceived + thisBill[i].unPaid;
          }
        }

        if (thisBill[0].toUID == '' && thisBill.length > 0 && (thisBill[0].creditorUID == '' || thisBill[0].creditorUID == '-')) {
          sellInvoice.add(int.parse(thisBill[0].to.toString().replaceAll('f', '')));
        } else if (thisBill[0].toUID != '' && thisBill.length > 0 && (thisBill[0].creditorUID == '' || thisBill[0].creditorUID == '-')) {
          sellInvoice.add(thisBill[0].toUID.toString().replaceAll('F-', ''));
        }
      } catch (e) {}
    }
    for (var fID in sellInvoice) {
      var it = invoice.values.where((element) => fID.runtimeType == int ? element.id == fID : element.uid == fID).toList();
      InvoiceDB inv;
      if (it.isNotEmpty) {
        inv = it[0];
        for (var i = 0; i < inv.items!.keys.toList().length; i++) {
          bool added = false;
          var proIndex = -1;
          var items;
          for (var element in sellItem) {
            items = inv.items![inv.items!.keys.toList()];
            proIndex = items.indexWhere((e) => e['pro'] == element['prouid']);
            if (element['productUID'] == inv.items!.keys.toList()[i] && proIndex != -1) {
              element['amount'] = element['amount'] + items[proIndex]['amount'];
              added = true;
            }
          }
          if (!added) {
            sellItem.add({'productUID': inv.items!.keys.toList()[i], 'prouid': items[proIndex]['pro'], 'amount': items[proIndex]['amount']});
          }
        }
      }
    }
    num totalBuy = 0;
    for (var item in sellItem) {
      String productUID = item['productUID'];
      String prouid = item['prouid'];
      double amount = item['amount'];
      var totalSellInvoice = invoice.values.where((element) => element.type != 'buy' && element.items!.keys.toList().contains(productUID)).toList();
      var totalBuyInvoice = invoice.values.where((element) => element.type == 'buy' && element.items!.keys.toList().contains(productUID)).toList();

      num totalSell = 0;

      for (var element in totalSellInvoice) {
        for (var i = 0; i < element.items!.keys.toList().length; i++) {
          if (element.items!.keys.toList()[i] == productUID) {
            var itemsAmount = element.items![element.items!.keys.toList()[i]].map((e) => e['amount']).toList().reduce((a, b) => a + b);
            totalSell = totalSell + itemsAmount;
          }
        }
      }
      totalSell = totalSell - amount;
      num tBuy = 0;
      num tBuyPric = 0;
      bool forPrice = true;
      tBuyPricCalculate:
      if (forPrice)
        for (var i = 0; i < totalBuyInvoice.length; i++) {
          var bfItem = totalBuyInvoice[i];
          for (var t = 0; t < bfItem.items!.keys.toList().length; t++) {
            String puid = bfItem.items!.keys.toList()[t];
            var item = bfItem.items![puid];
            for (var p = 0; p < item.length; p++) {
              if (puid == productUID && prouid == item[p]['prouid']) {
                var itemsAmount = item[p]['amount'];
                tBuy = tBuy + itemsAmount;

                if (tBuy > totalSell) {
                  num stock = tBuy - totalSell;
                  if (stock >= amount) {
                    tBuyPric = tBuyPric + (item[p]['buyPrice'] * amount);
                    forPrice = false;
                    break tBuyPricCalculate;
                  } else {
                    tBuyPric = tBuyPric + (item[p]['buyPrice'] * stock);
                    totalSell = totalSell + stock;
                  }
                }
              }
            }
          }
        }
      totalBuy = totalBuy + tBuyPric;
    }
    return {'paidC': paidC, 'paidF': paidF, 'unPaid': unPaid, 'totalBuy': totalBuy, 'received': received, 'unReceived': unReceived};
  }

  static ProductDB findProduct(String uid) {
    var pl = product.values.where((element) => element.uid == uid).toList();
    return pl.isNotEmpty ? pl[0] : ProductDB(uid: '', inserter: 0);
  }

  static invoicePrice(InvoiceDB inv) {
    num price = 0;
    for (var i = 0; i < inv.items!.keys.toList().length; i++) {
      var p = inv.items![inv.items!.keys.toList()[i]];
      for (var j = 0; j < p.length; j++) {
        price += (p[j]['amount'] * p[j]['price']);
      }
    }
    price +=
        (inv.parameters!.map((r) => r['name'] == 'excess' ? r['amount'] : 0).toList().reduce((a, b) => a + b) -
        inv.parameters!.map((r) => r['name'] == 'discount' ? r['amount'] : 0).toList().reduce((a, b) => a + b));
    return price;
  }

  static List<BillDB> allBill(List<String> uid) {
    return bill.values.where((element) => uid.contains(element.uid)).toList();
  }

  static int findTotalInvoice(List<InvoiceDB> inv, isBuy) {
    num t = 0;
    for (var i = 0; i < inv.length; i++) {
      t += total(inv[i].items!);
      for (var element in inv[i].parameters!) {
        if (element['name'] == 'excess') {
          t += element['amount'];
        } else if (element['name'] == 'discount') {
          t -= element['amount'];
        }
      }

      t -= inv[i].shipping!['cost'] ?? 0;
    }
    return t.toInt();
  }
}
