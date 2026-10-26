import 'financial_report.dart';
import 'remote_json.dart';

class Partnership {
  final Map<String, dynamic> json;
  Partnership(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    FinancialReportPage.uuid(row.text('partnershipId'));
    row.number('businessId');
    if (row.number('revision') < 1 ||
        !['FIXED', 'CONTRIBUTIONS'].contains(row.text('mode')) ||
        row.text('reason').length > 500) {
      throw const FormatException('Invalid partnership');
    }
    final parts = shares(json['allocations'], nullable: false);
    if (mode == 'FIXED'
        ? parts.isEmpty ||
              parts.fold<int>(0, (sum, r) => sum + r.number('basisPoints')) !=
                  10000
        : parts.isNotEmpty) {
      throw const FormatException('Invalid fixed ownership');
    }
  }
  int get revision => json['revision'] as int;
  String get mode => json['mode'] as String;
  static List<RemoteJson> shares(Object? value, {bool nullable = true}) {
    final rows = RemoteJson({'items': value}).items('items', RemoteJson.new);
    final ids = <String>{};
    for (final row in rows) {
      FinancialReportPage.uuid(row.text('partnerId'));
      final points = row.optionalNumber('basisPoints');
      if (!ids.add(row.text('partnerId')) ||
          (points == null ? !nullable : points < 0 || points > 10000)) {
        throw const FormatException('Invalid ownership share');
      }
    }
    if (rows.length > 100) {
      throw const FormatException('Too many ownership shares');
    }
    return rows;
  }
}

class PartnerOwnership {
  final Partnership? partnership;
  final List<RemoteJson> shares;
  PartnerOwnership(Object? value, int businessId)
    : partnership = RemoteJson(value).value['partnership'] == null
          ? null
          : Partnership(RemoteJson(value).value['partnership']),
      shares = Partnership.shares(RemoteJson(value).value['shares']) {
    final row = RemoteJson(value);
    if (row.number('businessId') != businessId ||
        row.flag('configured') != (partnership != null) ||
        partnership != null && partnership!.json['businessId'] != businessId) {
      throw const FormatException('Unexpected ownership settings');
    }
    if (partnership?.mode == 'FIXED') {
      final fixed = Partnership.shares(
        partnership!.json['allocations'],
        nullable: false,
      );
      if (fixed.length != shares.length ||
          fixed.any(
            (r) => !shares.any(
              (s) =>
                  s.text('partnerId') == r.text('partnerId') &&
                  s.value['basisPoints'] == r.number('basisPoints'),
            ),
          )) {
        throw const FormatException('Unexpected fixed ownership shares');
      }
    } else if (shares.isNotEmpty &&
        !(shares.every((r) => r.value['basisPoints'] == null) ||
            shares.every((r) => r.value['basisPoints'] != null) &&
                shares.fold<int>(
                      0,
                      (sum, r) => sum + r.number('basisPoints'),
                    ) ==
                    10000)) {
      throw const FormatException('Invalid contribution shares');
    }
  }
}
