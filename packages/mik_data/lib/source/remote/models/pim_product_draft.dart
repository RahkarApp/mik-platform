import 'pim_command.dart';

class PimDraftPrice {
  final String name;
  final int? amount;
  final String? input;
  final bool isDefault;
  const PimDraftPrice({
    required this.name,
    required this.amount,
    this.input,
    this.isDefault = false,
  });
  factory PimDraftPrice.fromJson(Map<String, dynamic> json) => PimDraftPrice(
    name: json['name'] as String,
    amount: json['amount'] as int?,
    input: json['input'] as String?,
    isDefault: json['isDefault'] == true,
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'input': input,
    'isDefault': isDefault,
  };
}

class PimProductDraft {
  final String id, name;
  final Map<String, dynamic> fields;
  final List<PimDraftPrice> prices;
  final String? barcode;
  const PimProductDraft({
    required this.id,
    required this.name,
    this.fields = const {},
    this.prices = const [],
    this.barcode,
  });
  factory PimProductDraft.fromJson(Map<String, dynamic> json) =>
      PimProductDraft(
        id: json['id'] as String,
        name: json['name'] as String,
        fields: Map<String, dynamic>.from(json['fields'] as Map? ?? {}),
        prices: (json['prices'] as List? ?? [])
            .map(
              (value) => PimDraftPrice.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(),
        barcode: json['barcode'] as String?,
      );
  PimProductDraft rename(String value) => PimProductDraft(
    id: id,
    name: value,
    fields: {...fields, 'name': value},
    prices: prices,
    barcode: barcode,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fields': fields,
    'prices': prices.map((price) => price.toJson()).toList(),
    'barcode': barcode,
  };
}

class PimGroupStep {
  final String draftId;
  final PimCommand command;
  const PimGroupStep({required this.draftId, required this.command});
  factory PimGroupStep.fromJson(Map<String, dynamic> json) => PimGroupStep(
    draftId: json['draftId'] as String,
    command: PimCommand.fromJson(json['command']),
  );
  Map<String, dynamic> toJson() => {
    'draftId': draftId,
    'command': command.toJson(),
  };
}

class PimGroupState {
  final List<PimProductDraft> drafts;
  final List<PimGroupStep> steps;
  final int next;
  const PimGroupState({
    this.drafts = const [],
    this.steps = const [],
    this.next = 0,
  });
  factory PimGroupState.fromJson(Map<String, dynamic> json) => PimGroupState(
    drafts: (json['drafts'] as List)
        .map(
          (value) =>
              PimProductDraft.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
    steps: (json['steps'] as List)
        .map(
          (value) =>
              PimGroupStep.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
    next: json['next'] as int,
  );
  bool get pending => steps.isNotEmpty;
  Map<String, dynamic> toJson() => {
    'drafts': drafts.map((draft) => draft.toJson()).toList(),
    'steps': steps.map((step) => step.toJson()).toList(),
    'next': next,
  };
}
