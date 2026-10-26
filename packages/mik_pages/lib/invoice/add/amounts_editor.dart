import 'package:get/get.dart';
import 'package:mik_variables/variable.dart';
import 'package:flutter/material.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/source/remote/models/invoice_amounts.dart';
import 'package:mik_utils/public/price.dart';

Future<void> editInvoiceAmounts(
  BuildContext context, {
  required InvoiceAmounts initial,
  required int subtotal,
  required bool canDiscount,
  required bool canSurcharge,
  required ValueChanged<InvoiceAmounts> onSave,
  bool purchase = false,
}) async {
  await MyBottomSheet.view(
    context,
    title: 'تخفیف و هزینه‌های فاکتور',
    child: (scroll) => InvoiceAmountsEditor(
      initial: initial,
      subtotal: subtotal,
      canDiscount: canDiscount,
      canSurcharge: canSurcharge,
      purchase: purchase,
      scroll: scroll,
      onSave: onSave,
    ),
  );
}

class InvoiceAmountsEditor extends StatefulWidget {
  final InvoiceAmounts initial;
  final int subtotal;
  final bool canDiscount, canSurcharge, purchase;
  final bool embedded;
  final ValueChanged<bool>? onValidity;
  final ScrollController scroll;
  final ValueChanged<InvoiceAmounts> onSave;
  const InvoiceAmountsEditor({
    super.key,
    this.embedded = false,
    this.onValidity,
    required this.initial,
    required this.subtotal,
    required this.canDiscount,
    required this.canSurcharge,
    required this.purchase,
    required this.scroll,
    required this.onSave,
  });
  @override
  State<InvoiceAmountsEditor> createState() => _AmountsEditorState();
}

class _AmountsEditorController extends GetxController {
  _AmountsEditorController(this.widget);
  InvoiceAmountsEditor widget;
  late final fields =
      [
            widget.initial.discount,
            widget.initial.shipping,
            widget.initial.surcharge,
            widget.initial.tax,
          ]
          .map((v) => TextEditingController(text: v == 0 ? '' : v.toString()))
          .toList();
  late String? treatment = widget.initial.purchaseTaxTreatment;
}

class _AmountsEditorState extends State<InvoiceAmountsEditor> {
  late final _page = _AmountsEditorController(widget);

  static const names = ['تخفیف فاکتور', 'هزینه ارسال', 'هزینه اضافی', 'مالیات'];
  static const treatments = {
    'RECOVERABLE': 'مالیات قابل بازیافت',
    'NON_RECOVERABLE': 'مالیات جزو بهای تمام‌شده کالا',
  };
  InvoiceAmounts read() => InvoiceAmounts(
    discount: InvoiceAmounts.parse(_page.fields[0].text),
    shipping: InvoiceAmounts.parse(_page.fields[1].text),
    surcharge: InvoiceAmounts.parse(_page.fields[2].text),
    tax: InvoiceAmounts.parse(_page.fields[3].text),
    purchaseTaxTreatment: widget.purchase ? _page.treatment : null,
  );
  void changed() {
    {
      _page.update();
    }
    if (!widget.embedded) return;
    try {
      final value = read();
      value.total(widget.subtotal);
      if (widget.purchase && value.tax > 0 && _page.treatment == null) {
        throw const FormatException('Missing tax treatment');
      }
      widget.onValidity?.call(true);
      widget.onSave(value);
    } on FormatException {
      widget.onValidity?.call(false);
    }
  }

  @override
  void dispose() {
    for (final field in _page.fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_AmountsEditorController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        int? total;
        try {
          total = read().total(widget.subtotal);
        } on FormatException {
          total = null;
        }
        final options = [
          for (final entry in treatments.entries)
            ItemValue(text: entry.value, data: entry.key),
        ];
        final content = Column(
          children: [
            if (!widget.embedded) ...[
              Text('جمع اقلام: ${Price.showWithCurrency(widget.subtotal)}'),
              MyDivider(),
            ],
            for (var i = 0; i < _page.fields.length; i++)
              PriceInput(
                key: ValueKey('invoice-amount-$i'),
                currency: 'تومان',
                controller: _page.fields[i],
                name: names[i],
                enabled: i == 0 ? widget.canDiscount : widget.canSurcharge,
                fillColor: widget.embedded && !darkMode.value
                    ? Colors.grey.shade300
                    : null,
                onChanged: (_) => changed(),
              ),
            if (widget.purchase)
              Dropdown(
                name: 'نوع مالیات خرید',
                itemValue: true,
                search: false,
                disable: !widget.canSurcharge,
                items_Value: options,
                defaultValue: _page.treatment == null
                    ? null
                    : options.firstWhere((o) => o.data == _page.treatment),
                onChange: (v) {
                  _page.treatment = (v as ItemValue).data as String;
                  changed();
                },
              ),
            if (!widget.canDiscount) const Text('مجوز اعمال تخفیف ندارید.'),
            if (!widget.canSurcharge)
              const Text('مجوز اعمال هزینه و مالیات ندارید.'),
            if (!widget.embedded) ...[
              MyDivider(text: 'مبلغ نهایی'),
              Text(
                total == null
                    ? 'مبلغ‌ها معتبر نیستند یا تخفیف بیشتر از جمع اقلام است.'
                    : Price.showWithCurrency(total),
              ),
              BTN(
                name: 'اعمال مبالغ',
                type: BTNType.ok,
                onTap: () {
                  try {
                    final value = read();
                    value.total(widget.subtotal);
                    if (widget.purchase &&
                        value.tax > 0 &&
                        _page.treatment == null) {
                      Alert.error('نوع مالیات خرید را مشخص کنید.');
                      return;
                    }
                    widget.onSave(value);
                    Get.back();
                    Alert.success(
                      'مبالغ فاکتور اعمال شد؛ ثبت نهایی هنوز انجام نشده است.',
                    );
                  } on FormatException {
                    Alert.error(
                      'مبالغ را به تومان و بدون اعشار وارد کنید؛ تخفیف نباید بیشتر از جمع اقلام باشد.',
                    );
                  }
                },
              ),
            ],
          ],
        );
        return widget.embedded
            ? content
            : SingleChildScrollView(controller: widget.scroll, child: content);
      },
    );
  }

  @override
  void didUpdateWidget(covariant InvoiceAmountsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}
