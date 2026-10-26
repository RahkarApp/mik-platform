import 'package:shamsi_date/shamsi_date.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/dashboard.dart';
import '../../source/remote/models/financial_report.dart';
import '../../source/remote/models/invoice_read.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'financial_reports.dart';

class DashboardReadFX {
  final BusinessContext context;
  late final reports = FinancialReportsFX(context);
  DashboardReadFX(this.context);
  String get branchId => reports.branchId;
  int get businessId => context.session.business.businessId;
  Future<void> authorize() => reports.authorize();
  void check() => reports.check();

  Future<DashboardProfit> profit(DateTime start, DateTime end) async {
    // Accounting accepts canonical UTC dates with millisecond precision only.
    start = DateTime.fromMillisecondsSinceEpoch(
      start.millisecondsSinceEpoch,
      isUtc: true,
    );
    end = DateTime.fromMillisecondsSinceEpoch(
      end.millisecondsSinceEpoch,
      isUtc: true,
    );
    check();
    if (!reports.has('profit')) throw const AuthError(403, 'FORBIDDEN');
    final result = DashboardProfit(
      await context.auth.request(
        'GET',
        '/v1/businesses/$businessId/accounting/reports/profit',
        branchId: branchId,
        query: {
          'scope': 'BRANCH',
          'startAt': start.toUtc().toIso8601String(),
          'endAt': end.toUtc().toIso8601String(),
          'limit': '1',
        },
      ),
    );
    check();
    if (result.businessId != businessId ||
        result.branchId != branchId ||
        result.startAt != start.toUtc() ||
        result.endAt != end.toUtc()) {
      throw const FormatException('Unexpected dashboard profit scope');
    }
    return result;
  }

  Future<({List<DashboardProfitPoint> points, bool incomplete})> profitChart({
    required bool month,
    DateTime? now,
    bool Function()? isActive,
  }) async {
    await authorize();
    final clock = now ?? DateTime.now();
    final date = Jalali.fromDateTime(clock);
    final today = Jalali(date.year, date.month, date.day);
    final start = month
        ? Jalali(today.year, today.month, 1)
        : today.addDays(1 - today.weekDay);
    final previous = month ? start.addMonths(-1) : start.addDays(-7);
    final length = month ? start.monthLength : 7,
        previousLength = month ? previous.monthLength : 7;
    final requests = <({DateTime start, DateTime end, int index, bool old})>[];
    for (final old in [false, true]) {
      final first = old ? previous : start,
          count = old ? previousLength : length;
      for (var i = 0; i < count; i++) {
        final day = first.addDays(i).toDateTime(),
            next = first.addDays(i + 1).toDateTime();
        if (!day.isBefore(clock)) continue;
        requests.add((
          start: day,
          end: next.isAfter(clock) ? clock : next,
          index: i,
          old: old,
        ));
      }
    }
    final current = <int, int?>{}, last = <int, int?>{};
    int? sequence, inventorySequence;
    var incomplete = false;
    // Profit has no daily groupBy contract. Bound independent daily reads to
    // four requests and reject mixed Accounting/Inventory versions.
    for (var offset = 0; offset < requests.length; offset += 4) {
      if (isActive != null && !isActive()) {
        throw const AuthError(409, 'SELECTION_CHANGED');
      }
      final batch = requests.skip(offset).take(4).toList();
      final results = await Future.wait(
        batch.map((r) => profit(r.start, r.end)),
      );
      for (var i = 0; i < results.length; i++) {
        final result = results[i], request = batch[i];
        sequence ??= result.sequence;
        inventorySequence ??= result.inventorySequence;
        if (sequence != result.sequence ||
            inventorySequence != result.inventorySequence) {
          throw const AuthError(409, 'REPORT_SNAPSHOT_CHANGED');
        }
        incomplete |= !result.complete;
        (request.old ? last : current)[request.index] = result.profit;
      }
    }
    check();
    const days = [
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه',
    ];
    return (
      points: List.generate(
        length > previousLength ? length : previousLength,
        (i) => DashboardProfitPoint(
          month ? '${i + 1}' : days[i],
          current[i],
          last[i],
        ),
      ),
      incomplete: incomplete,
    );
  }

  Future<List<RemoteInvoiceSummary>> invoices({
    bool Function()? isActive,
  }) async {
    await authorize();
    final types = {
      'SALE': 'accounting.sale.read',
      'PURCHASE': 'accounting.purchase.read',
      'PROFORMA': 'accounting.proforma.read',
    };
    final rows = <RemoteInvoiceSummary>[], ids = <String>{};
    for (final type in types.entries) {
      if (!reports.access.has(type.value)) continue;
      String? after;
      final cursors = <String>{};
      do {
        if (isActive != null && !isActive()) {
          throw const AuthError(409, 'SELECTION_CHANGED');
        }
        check();
        final page = RemoteJson(
          await context.auth.request(
            'GET',
            '/v1/businesses/$businessId/accounting/v2/invoices',
            branchId: branchId,
            query: {'types': type.key, 'limit': '100', 'after': ?after},
          ),
        );
        check();
        if (page.number('businessId') != businessId) {
          throw const FormatException('Unexpected invoice business');
        }
        for (final item in page.items('items', RemoteInvoiceSummary.fromJson)) {
          if (item.id != item.rootId ||
              item.type != type.key ||
              !ids.add(item.id)) {
            throw const FormatException('Invalid dashboard invoice page');
          }
          rows.add(item);
        }
        after = page.optionalText('nextCursor');
        if (after != null &&
            (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
          throw const FormatException('Invalid dashboard invoice cursor');
        }
      } while (after != null);
    }
    if (!types.values.any(reports.access.has)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    rows.sort(RemoteInvoiceSummary.compareNumberDescending);
    return rows;
  }

  Future<({int? cash, int? receivable, int? payable})> financial() async {
    await authorize();
    int? cash, receivable, payable, sequence;
    if (reports.has('balances')) {
      final page = await reports.page('balances', business: false);
      sequence = page.sequence;
      final totals = page.json['totals'] as Map;
      receivable = totals['receivableAmount'] as int;
      payable = totals['payableAmount'] as int;
    }
    if (reports.has('cash-flow')) {
      final now = DateTime.now(), start = DateTime.now();
      final page = await reports.page(
        'cash-flow',
        business: false,
        startAt: DateTime(
          start.year,
          start.month,
          start.day,
        ).subtract(const Duration(days: 1)),
        endAt: now,
      );
      if (sequence != null && page.sequence != sequence) {
        throw const AuthError(409, 'REPORT_SNAPSHOT_CHANGED');
      }
      cash = FinancialReportPage.money(page.json['closingBalance']);
    }
    return (cash: cash, receivable: receivable, payable: payable);
  }
}
