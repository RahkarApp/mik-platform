import 'package:shamsi_date/shamsi_date.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/dashboard.dart';
import '../../source/remote/models/financial_report.dart';
import 'dashboard_read.dart';

class ProfitReportData {
  final DashboardProfit summary;
  final List<DashboardProfitPoint> points;
  final bool incomplete;
  const ProfitReportData(this.summary, this.points, this.incomplete);
  int money(String key) => FinancialReportPage.money(summary.json[key]);
  int? get grossProfit =>
      summary.json['grossProfit'] == null ? null : money('grossProfit');
}

class ProfitReportFX {
  final DashboardReadFX dashboard;
  ProfitReportFX(this.dashboard);

  Future<ProfitReportData> load(
    String period, {
    DateTime? now,
    bool Function()? isActive,
  }) async {
    if (!['هفته', 'ماه', 'فصل', 'سال'].contains(period)) {
      throw const FormatException('Invalid profit period');
    }
    await dashboard.authorize();
    final clock = now ?? DateTime.now();
    final date = Jalali.fromDateTime(clock);
    final today = Jalali(date.year, date.month, date.day);
    final first = switch (period) {
      'هفته' => today.addDays(1 - today.weekDay),
      'ماه' => Jalali(today.year, today.month, 1),
      'فصل' => Jalali(today.year, ((today.month - 1) ~/ 3) * 3 + 1, 1),
      _ => Jalali(today.year, 1, 1),
    };
    final previous = switch (period) {
      'هفته' => first.addDays(-7),
      'ماه' => first.addMonths(-1),
      'فصل' => first.addMonths(-3),
      _ => first.addYears(-1),
    };
    final end = switch (period) {
      'هفته' => first.addDays(7),
      'ماه' => first.addMonths(1),
      'فصل' => first.addMonths(3),
      _ => first.addYears(1),
    };
    final requests = <({DateTime start, DateTime end, int index, bool old})>[];
    int count(Jalali start) => switch (period) {
      'سال' => 12,
      'هفته' => 7,
      'ماه' => start.monthLength,
      _ =>
        ((start.monthLength +
                    start.addMonths(1).monthLength +
                    start.addMonths(2).monthLength) /
                7)
            .ceil(),
    };
    final currentLength = count(first), oldLength = count(previous);
    for (final old in [false, true]) {
      final start = old ? previous : first, finish = old ? first : end;
      for (var i = 0; i < (old ? oldLength : currentLength); i++) {
        final a = period == 'سال'
            ? start.addMonths(i)
            : start.addDays(i * (period == 'فصل' ? 7 : 1));
        final b = period == 'سال'
            ? start.addMonths(i + 1)
            : start.addDays((i + 1) * (period == 'فصل' ? 7 : 1));
        if (!a.toDateTime().isBefore(clock)) continue;
        var until = b.toDateTime().isAfter(finish.toDateTime())
            ? finish.toDateTime()
            : b.toDateTime();
        if (until.isAfter(clock)) until = clock;
        requests.add((start: a.toDateTime(), end: until, index: i, old: old));
      }
    }
    final summary = await dashboard.profit(first.toDateTime(), clock);
    for (final key in [
      'netSales',
      'costOfGoodsSold',
      'otherIncome',
      'expenses',
    ]) {
      FinancialReportPage.money(summary.json[key]);
    }
    if (summary.complete != (summary.json['grossProfit'] != null)) {
      throw const FormatException('Invalid gross profit coverage');
    }
    if (summary.json['grossProfit'] != null) {
      FinancialReportPage.money(summary.json['grossProfit']);
    }
    final current = <int, int?>{}, last = <int, int?>{};
    var incomplete = !summary.complete;
    for (var offset = 0; offset < requests.length; offset += 4) {
      if (isActive != null && !isActive()) {
        throw const AuthError(409, 'SELECTION_CHANGED');
      }
      final batch = requests.skip(offset).take(4).toList();
      final results = await Future.wait(
        batch.map((r) => dashboard.profit(r.start, r.end)),
      );
      for (var i = 0; i < results.length; i++) {
        final row = results[i], request = batch[i];
        if (row.sequence != summary.sequence ||
            row.inventorySequence != summary.inventorySequence) {
          throw const AuthError(409, 'REPORT_SNAPSHOT_CHANGED');
        }
        incomplete |= !row.complete;
        (request.old ? last : current)[request.index] = row.profit;
      }
    }
    dashboard.check();
    const days = [
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه',
    ];
    const months = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];
    return ProfitReportData(
      summary,
      List.generate(
        currentLength > oldLength ? currentLength : oldLength,
        (i) => DashboardProfitPoint(
          switch (period) {
            'هفته' => days[i],
            'فصل' => 'هفته ${i + 1}',
            'سال' => months[i],
            _ => '${i + 1}',
          },
          current[i],
          last[i],
        ),
      ),
      incomplete,
    );
  }
}
