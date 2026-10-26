import 'package:mik_data/utils/fx/permissionfx.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:mik_consts/const.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/variable.dart';

import 'model.dart';

class ReportFX {
  static profitInDate(date) {
    num profit = 0;
    var it = invoice.values
        .where(
          (element) =>
              element.date != null &&
              DateTime.parse(element.date!.split('T')[0])
                      .compareTo(DateTime.parse(date.split('T')[0])) ==
                  0,
        )
        .toList();
    it = it.where((f) => PermissionFx.isShowFactorItem(f)).toList();

    if (it.isNotEmpty) {
      for (var element in it) {
        if (element.type != 'buy' &&
            (element.status!.every(
                  (t) => t['status'] != null && t['status'] < 8,
                ) ||
                element.status!.any(
                  (e) => e['status'] != null && e['status'] == 100,
                ))) {
          var dis = 0;
          var ex = 0;
          if (element.parameters != null) {
            for (var p in element.parameters!) {
              if (p['mode'] == 'ded') {
                dis += int.parse(p['amount'].toString());
              } else if (p['mode'] == 'add') {
                ex += int.parse(p['amount'].toString());
              }
            }
            profit =
                profit +
                AccountingFX.total(element.items!) -
                element.commission!['amount'] -
                dis +
                ex -
                (element.shipping!['cost'] ?? 0);
          } else if (element.type == 'buy') {}
        }
      }
      return profit;
    }
    return 0;
  }

  static profitInYear({year, month}) {
    num profit = 0;
    var it = invoice.values
        .where(
          (element) =>
              element.date != null &&
              Jalali.fromDateTime(DateTime.parse(element.date!)).year == year &&
              Jalali.fromDateTime(DateTime.parse(element.date!)).month == month,
        )
        .toList();
    it = it.where((f) => PermissionFx.isShowFactorItem(f)).toList();
    if (it.isNotEmpty) {
      for (var element in it) {
        if (element.type != 'buy' &&
            (element.status!.every((r) => r['status'] < 8) ||
                element.status!.any((e) => e['status'] == 100))) {
          profit =
              profit +
              AccountingFX.total(element.items!, type: 'buy') -
              (element.commission!['amount'] ?? 0) -
              (element.shipping!['cost'] ?? 0);
          element.parameters?.forEach((element) {
            if (element['mode'] == 'ded') {
              profit -= int.parse(element['amount'].toString());
            } else if (element['mode'] == 'add') {
              profit += int.parse(element['amount'].toString());
            }
          });
        } else if (element.type == 'buy') {}
      }
    }

    return profit;
  }

  static findDateFromDayNum({year, dayNum}) {
    int month = 1;
    int temp = 1;
    int day = dayNum;
    var i;
    if (dayNum < 32) return '$year/$month/$dayNum';
    for (i = 0; i < dayNum; i++) {
      temp++;
      day--;
      if (month < 6 && temp > 31) {
        month++;
        temp = 1;
        if (day <= 31) {
          break;
        }
      } else if (month >= 6 && month < 13 && temp > 30) {
        month++;
        temp = 1;
        if (day <= 30) break;
      }
    }
    return '$year/$month/$day';
  }

  static productDetail(String uid, {start, end}) {
    num sellCount = 0;
    num inv = 0;
    String lastSellDate = '-';
    num buyPrice = 0;
    num profit = 0;
    var it = invoice.values
        .where(
          (element) =>
              element.items!.keys.toList().contains(uid) &&
              ((end == null && start == null) ||
                  (end != null &&
                      start != null &&
                      element.date != null &&
                      DateTime.parse(
                        element.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isBefore(end) &&
                      DateTime.parse(
                        element.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isAfter(start))),
        )
        .toList();
    if (it.isNotEmpty) {
      for (var element in it) {
        var prr = element.items![uid];
        if (element.type != 'buy' &&
            element.status!.every(
              (a) =>
                  a['status'] != 8 &&
                  a['status'] != 9 &&
                  a['status'] != 444 &&
                  a['status'] != 900 &&
                  a['status'] != 901,
            )) {
          var itemAmount = prr
              .map((e) => e['amount'])
              .toList()
              .reduce((a, b) => a + b);
          sellCount += itemAmount;
          var prPrice = prr
              .map((e) => e['price'] * e['amount'])
              .toList()
              .reduce((a, b) => a + b);
          var bPrice = prr
              .map((e) => e['buyPrice'] * e['amount'])
              .toList()
              .reduce((a, b) => a + b);
          int shippingCost = 0;
          if (element.shipping != null) {
            shippingCost = element.shipping!['cost'] ?? 0;
          }
          profit +=
              prPrice -
              commissionFindForOneProductOnFactor(element, uid) -
              parametersFindForOneProductOnFactor(element, uid) -
              shippingCost -
              bPrice;
        } else if (element.type == 'buy') {
          //   inv += element.amount![element.productUID!.indexOf(uid)];
        }
      }
      //inv -= sellCount;
      for (var i = it.length - 1; i > -1; i--) {
        if (it[i].type != 'buy' &&
            it[i].status!.every((t) => t['status'] < 900)) {
          lastSellDate = it[i].date!;
          break;
        }
      }
      buyPrice = ProductFX.findBuyPriceAverage(uid, prouid: '-');
    }
    inv = ProductFX.productInAllWarehouse(uid);

    return {
      'sellCount': sellCount,
      'inv': inv,
      "lastSellDate": lastSellDate != '-'
          ? lastSellDate.toPersianDate()
          : lastSellDate,
      "lastSellDateG": lastSellDate,
      'buyPrice': buyPrice,
      'profit': profit,
    };
  }

  static num factorCommissionFind(ft) {
    num cmsn = 0;
    for (var p = 0; p < product.length; p++) {
      var it = product.getAt(p);
      if (ft.items.keys.toList().contains(it!.uid)) {
        // double sp = 0;
        for (var element in ft.items[it.uid]) {
          if (it.isCommissionFixed!) {
            cmsn += (element['amount'] * it.commission!);
          } else {
            cmsn +=
                ((element['amount'] * element['price']) *
                (it.commission! / 100));
          }
        }
      }
    }
    return cmsn;
  }

  static double commissionFindForOneProductOnFactor(
    InvoiceDB inv,
    String pUID,
  ) {
    var it = product.values.where((element) => element.uid == pUID).toList()[0];
    double cmsn = 0;
    if (inv.commission != null &&
        inv.commission!['mikyar'] != 0 &&
        it.commission != null &&
        it.commission! > 0) {
      var item = inv.items![pUID];
      if (item != null) {
        for (var element in item) {
          if (it.isCommissionFixed!) {
            cmsn += (element['amount'] * it.commission!);
          } else {
            cmsn +=
                ((element['amount'] * element['price']) *
                (it.commission! / 100));
          }
        }
        return cmsn;
      } else {
        return cmsn;
      }
    }
    return cmsn;
  }

  static double parametersFindForOneProductOnFactor(InvoiceDB inv, pUID) {
    int dis = 0;
    inv.parameters?.forEach((element) {
      if (element['mode'] == 'add') {
        dis -= int.parse(element['amount'].toString());
      }
      if (element['mode'] == 'ded') {
        dis += int.parse(element['amount'].toString());
      }
    });
    if (dis != 0) {
      var pr = inv.items![pUID];
      var prPrice = pr
          .map((e) => e['price'] * e['amount'])
          .toList()
          .reduce((a, b) => a + b);
      var ftTotal = AccountingFX.totalFromList(pr);
      return (dis * prPrice) / ftTotal;
    }
    return 0.0;
  }

  static day(d) {
    switch (d) {
      case 1:
        return 'شنبه';
      case 2:
        return 'یکشنبه';
      case 3:
        return 'دوشنبه';
      case 4:
        return 'سه‌شنبه';
      case 5:
        return 'چهارشنبه';
      case 6:
        return 'پنجشنبه';
      case 7:
        return 'جمعه';
    }
  }

  static List<List<SalesData>> profitSalesDataInWeek() {
    List<SalesData> thisWeek = [];
    List<SalesData> lastWeek = [];
    List dateDayWeek = [];
    List dateDayLastWeek = [];

    for (var i = Jalali.now().weekDay - 1; i > 0; i--) {
      dateDayWeek.add(
        DateTime.now().add(Duration(days: -i)).toPersianDate().toEnglishDigit(),
      );
      dateDayLastWeek.add(
        DateTime.now()
            .add(Duration(days: -i - 7))
            .toPersianDate()
            .toEnglishDigit(),
      );
    }
    dateDayWeek.add(DateTime.now().toPersianDate().toEnglishDigit());
    dateDayLastWeek.add(
      DateTime.now()
          .add(const Duration(days: -7))
          .toPersianDate()
          .toEnglishDigit(),
    );
    for (var i = 1; i <= (7 - Jalali.now().weekDay); i++) {
      dateDayWeek.add(
        DateTime.now().add(Duration(days: i)).toPersianDate().toEnglishDigit(),
      );
      dateDayLastWeek.add(
        DateTime.now()
            .add(Duration(days: i - 7))
            .toPersianDate()
            .toEnglishDigit(),
      );
    }
    for (var d = 0; d < 7; d++) {
      var dd = dateDayWeek[d].split('/');
      var dateLast = DateConvertor.jalaliToGrigori(dateDayWeek[d]);
      thisWeek.add(
        SalesData(
          day(
            Jalali(
              int.parse(dd[0]),
              int.parse(dd[1]),
              int.parse(dd[2]),
            ).weekDay,
          ),
          ReportFX.profitInDate(dateLast),
        ),
      );
    }

    for (var d = 0; d < 7; d++) {
      var dd = dateDayLastWeek[d].split('/');
      var dateLast = DateConvertor.jalaliToGrigori(dateDayLastWeek[d]);
      lastWeek.add(
        SalesData(
          day(
            Jalali(
              int.parse(dd[0]),
              int.parse(dd[1]),
              int.parse(dd[2]),
            ).weekDay,
          ),
          ReportFX.profitInDate(dateLast),
        ),
      );
    }

    return [thisWeek, lastWeek];
  }

  static List<List<SalesData>> profitSalesDataInMonth() {
    List<SalesData> thisMonth = [];
    List<SalesData> lastMonth = [];

    List dateDayMonth = [];
    List dateDayLastMonth = [];
    int m = Jalali.now().month;
    int y = Jalali.now().year;
    int lm = m > 1 ? m - 1 : 12;
    int ly = m > 1 ? y : y - 1;

    dateDayMonth = DateConvertor.jalaliMonthDates();
    Jalali lastm = Jalali.now().addMonths(-1);
    dateDayLastMonth = DateConvertor.jalaliMonthDates(
      month: lastm.month,
      year: lastm.year,
    );

    for (var d = 1; d < Jalali.now().monthLength + 1; d++) {
      var dateLast = DateConvertor.jalaliToGrigori(dateDayMonth[d - 1]);
      thisMonth.add(SalesData(d.toString(), ReportFX.profitInDate(dateLast)));
    }
    for (var d = 1; d < Jalali(ly, lm).monthLength + 1; d++) {
      var dateLast = DateConvertor.jalaliToGrigori(dateDayLastMonth[d - 1]);
      lastMonth.add(SalesData(d.toString(), ReportFX.profitInDate(dateLast)));
    }
    return [thisMonth, lastMonth];
  }

  static List<List<SalesData>> profitSalesDataInSeason() {
    List<SalesData> thisSeason = [];
    List<SalesData> lastSeason = [];
    const offsets = [0, 31, 62, 93, 124, 155, 185, 215, 245, 275, 305, 335];
    int week = (offsets[Jalali.now().month - 1] + Jalali.now().day) ~/ 7;
    int thisSeasonNum = week < 13
        ? 1
        : week > 12 && week < 25
        ? 2
        : week > 24 && week <= 36
        ? 3
        : 4;
    int s4 = Jalali(Jalali.now().year, 12).monthLength;
    List seasonLength = [93, 93, 90, 60 + s4 - 1];
    num startSeasonDay = 0;
    num startLastSeasonDay = 0;
    for (var i = 0; i < thisSeasonNum - 1; i++) {
      startSeasonDay = startSeasonDay + seasonLength[i];
    }
    startLastSeasonDay = thisSeasonNum == 1
        ? 276
        : thisSeasonNum == 2
        ? 1
        : thisSeasonNum == 3
        ? 93
        : 186;
    var d = 0;
    var dw = 1;
    num thisProfit = 0;
    num lastProfit = 0;
    for (num i = 0; i < seasonLength[thisSeasonNum - 1]; i++) {
      thisProfit =
          thisProfit +
          ReportFX.profitInDate(
            DateConvertor.jalaliToGrigori(
              ReportFX.findDateFromDayNum(
                year: Jalali.now().year,
                dayNum: startSeasonDay + 1 + i,
              ),
            ),
          );
      d++;
      if (d == 7) {
        thisSeason.add(SalesData('هفته $dw', thisProfit));
        //  lastSeason.add(SalesData('هفته ' + dw.toString(), lastProfit));
        dw++;
        thisProfit = 0;
        // lastProfit = 0;
        d = 0;
      }
    }
    int lastSeasonNum = thisSeasonNum == 1 ? 4 : thisSeasonNum - 1;
    d = 0;
    dw = 1;
    for (num i = 0; i < seasonLength[lastSeasonNum - 1]; i++) {
      lastProfit =
          lastProfit +
          ReportFX.profitInDate(
            DateConvertor.jalaliToGrigori(
              ReportFX.findDateFromDayNum(
                year: thisSeasonNum == 1
                    ? Jalali.now().year - 1
                    : Jalali.now().year,
                dayNum: startLastSeasonDay + 1 + i,
              ),
            ),
          );
      d++;
      if (d == 7) {
        // thisSeason.add(SalesData('هفته ' + dw.toString(), thisProfit));
        lastSeason.add(SalesData('هفته $dw', lastProfit));
        dw++;
        // thisProfit = 0;
        lastProfit = 0;
        d = 0;
      }
    }
    return [thisSeason, lastSeason];
  }

  static List<List<SalesData>> profitSalesDataInYear() {
    List<SalesData> thisYear = [];
    List<SalesData> lastYear = [];
    for (var i = 1; i < 13; i++) {
      thisYear.add(
        SalesData(
          months[i - 1],
          ReportFX.profitInYear(year: Jalali.now().year, month: i),
        ),
      );
      lastYear.add(
        SalesData(
          months[i - 1],
          ReportFX.profitInYear(year: Jalali.now().year - 1, month: i),
        ),
      );
    }
    return [thisYear, lastYear];
  }

  static List<InvoiceDB> findAllInvoice(
    String uid, {
    DateTime? startDate,
    DateTime? endDate,
    bool? con = true,
  }) {
    List<InvoiceDB> fct = [];
    fct = invoice.values
        .where(
          (w) =>
              w.items!.keys.toList().contains(uid) &&
              ((endDate != null &&
                      DateTime.parse(
                        w.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isBefore(endDate)) ||
                  endDate == null) &&
              ((startDate != null &&
                      DateTime.parse(
                        w.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isAfter(startDate) ||
                  startDate == null)) &&
              con!,
        )
        .toList();
    return fct;
  }

  static List<InvoiceDB> findBuyInvoice(
    String uid, {
    DateTime? startDate,
    DateTime? endDate,
    bool? con = true,
  }) {
    List<InvoiceDB> fct = [];
    fct = invoice.values
        .where(
          (w) =>
              w.type == 'buy' &&
              w.items!.keys.toList().contains(uid) &&
              ((endDate != null &&
                      DateTime.parse(
                        w.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isBefore(endDate)) ||
                  endDate == null) &&
              ((startDate != null &&
                      DateTime.parse(
                        w.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isAfter(startDate) ||
                  startDate == null)) &&
              con!,
        )
        .toList();
    return fct;
  }

  static num findAmountInInvoice(
    List<InvoiceDB> list,
    String uid, {
    String? prouid,
  }) {
    num a = 0;
    for (var i = 0; i < list.length; i++) {
      var p = list[i].items![uid];
      if (prouid != null) {
        var pro = p.indexWhere((e) => e['pro'] == prouid).toList();
        a += pro['amount'];
      } else {
        a += p.map((e) => e['amount']).toList().reduce((a, b) => a + b);
      }
    }
    return a;
  }

  static num findPriceInInvoice(
    List<InvoiceDB> list,
    bool buyPrice,
    String uid, {
    String? prouid,
  }) {
    num a = 0;

    for (var i = 0; i < list.length; i++) {
      var p = list[i].items![uid];
      if (prouid != null) {
        if (buyPrice) {
          a += p
              .map((e) => e['pro'] == prouid ? e['buyPrice'] : 0)
              .toList()
              .reduce((a, b) => a + b);
        } else {
          a += p
              .map((e) => e['pro'] == prouid ? e['price'] : 0)
              .toList()
              .reduce((a, b) => a + b);
        }
      } else {
        if (buyPrice) {
          a += p.map((e) => e['buyPrice']).toList().reduce((a, b) => a + b);
        } else {
          a += p.map((e) => e['price']).toList().reduce((a, b) => a + b);
        }
      }
    }

    return a;
  }

  static List<InvoiceDB> findSellInvoice(
    String uid, {
    DateTime? startDate,
    DateTime? endDate,
    bool? con = true,
  }) {
    List<InvoiceDB> inv = [];
    inv = invoice.values
        .where(
          (w) =>
              w.type != 'buy' &&
              w.status!.every(
                (e) =>
                    e['status'] != 8 &&
                    e['status'] != 9 &&
                    e['status'] != 900 &&
                    e['status'] != 901,
              ) &&
              w.items!.keys.toList().contains(uid) &&
              ((endDate != null &&
                      DateTime.parse(
                        w.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isBefore(endDate)) ||
                  endDate == null) &&
              ((startDate != null &&
                      DateTime.parse(
                        w.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isAfter(startDate) ||
                  startDate == null)) &&
              con!,
        )
        .toList();
    return inv;
  }

  static List<InvoiceDB> findCancellInvoice(
    String uid, {
    DateTime? startDate,
    DateTime? endDate,
    bool? con = true,
  }) {
    List<InvoiceDB> inv = [];
    inv = invoice.values
        .where(
          (w) =>
              w.type != 'buy' &&
              w.status!.any((e) => e['status'] == 8) &&
              w.items!.keys.toList().contains(uid) &&
              ((endDate != null &&
                      DateTime.parse(
                        w.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isBefore(endDate)) ||
                  endDate == null) &&
              ((startDate != null &&
                      DateTime.parse(
                        w.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isAfter(startDate) ||
                  startDate == null)) &&
              con!,
        )
        .toList();
    return inv;
  }

  static List<InvoiceDB> findRejectInvoice(
    String uid, {
    DateTime? startDate,
    DateTime? endDate,
    bool? con = true,
  }) {
    List<InvoiceDB> inv = [];
    inv = invoice.values
        .where(
          (w) =>
              w.type != 'buy' &&
              w.status!.any((e) => e['status'] == 9) &&
              w.items!.keys.toList().contains(uid) &&
              ((endDate != null &&
                      DateTime.parse(
                        w.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isBefore(endDate)) ||
                  endDate == null) &&
              ((startDate != null &&
                      DateTime.parse(
                        w.date!.replaceAll("T", ' ').replaceAll("Z", ''),
                      ).isAfter(startDate) ||
                  startDate == null)) &&
              con!,
        )
        .toList();
    return inv;
  }
}
