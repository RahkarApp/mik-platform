import 'pim_option_pair.dart';
import 'remote_json.dart';

class PimPreview {
  final String productId;
  final List<List<PimOptionPair>> combinations;
  PimPreview.fromJson(Object? value) : this._(RemoteJson(value));
  PimPreview._(RemoteJson json)
    : productId = json.text('productId'),
      combinations = json.items('combinations', (row) {
        if (row is! List) throw const FormatException('Invalid combination');
        return List.unmodifiable(row.map(PimOptionPair.fromJson));
      });
}
