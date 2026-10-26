import 'package:get/get.dart';
import 'package:mik_variables/variable.dart';
import 'package:flutter/material.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:mik_utils/public/date.dart';

Future<void> editInvoiceMetadata(
  BuildContext context, {
  required DateTime? dueAt,
  required String note,
  required void Function(DateTime? dueAt, String note) onSave,
}) async {
  await MyBottomSheet.view(
    context,
    title: 'سررسید و یادداشت',
    child: (scroll) => InvoiceMetadataEditor(
      dueAt: dueAt,
      note: note,
      onSave: onSave,
      scroll: scroll,
    ),
  );
}

class InvoiceMetadataEditor extends StatefulWidget {
  final DateTime? dueAt;
  final String note;
  final void Function(DateTime?, String) onSave;
  final ScrollController scroll;
  final bool embedded;
  final ValueChanged<bool>? onValidity;
  const InvoiceMetadataEditor({
    super.key,
    this.embedded = false,
    this.onValidity,
    required this.dueAt,
    required this.note,
    required this.onSave,
    required this.scroll,
  });
  @override
  State<InvoiceMetadataEditor> createState() => _MetadataEditorState();
}

class _MetadataEditorState extends State<InvoiceMetadataEditor> {
  late final note = TextEditingController(text: widget.note);
  late final date = TextEditingController(
    text: widget.dueAt == null
        ? ''
        : '${DateConvertor.grigoriToJalali(widget.dueAt!.toLocal())} ${DateConvertor.showTime(widget.dueAt!.toLocal())}',
  );
  DateTime? readDate() {
    if (date.text.isEmpty) return null;
    final match = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2}) (\d{1,2}):(\d{1,2})$')
        .firstMatch(date.text.toEnglishDigit());
    if (match == null) throw const FormatException('Invalid due date');
    final parts = [for (var i = 1; i <= 5; i++) int.parse(match.group(i)!)];
    // Use the chosen local minute, never the current clock's seconds.
    return Jalali(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
    ).toDateTime().toUtc();
  }

  void changed() {
    if (!widget.embedded) return;
    try {
      if (note.text.trim().length > 1000) {
        throw const FormatException('Long note');
      }
      final due = readDate();
      widget.onValidity?.call(true);
      widget.onSave(due, note.text.trim());
    } catch (_) {
      widget.onValidity?.call(false);
    }
  }

  @override
  void dispose() {
    note.dispose();
    date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        DateInput(
          key: const ValueKey('invoice-due-at'),
          controller: date,
          name: 'سررسید پرداخت (اختیاری)',
          require: false,
          timePicker: true,
          fillColor: widget.embedded && !darkMode.value
              ? Colors.grey.shade300
              : null,
          onChanged: (_) => changed(),
        ),
        MiniBTN(
          name: 'بدون سررسید',
          icon: IconsaxPlusLinear.close_circle,
          noFlex: true,
          onTap: () {
            date.clear();
            changed();
          },
        ),
        if (!widget.embedded) MyDivider(text: 'یادداشت اختیاری'),
        Input(
          key: const ValueKey('invoice-note'),
          controller: note,
          name: widget.embedded ? 'توضیحات' : 'یادداشت فاکتور',
          fillColor: widget.embedded && !darkMode.value
              ? Colors.grey.shade300
              : null,
          onChanged: (_) => changed(),
          maxLength: 1000,
          minLines: widget.embedded ? 2 : 3,
          maxLines: widget.embedded ? 2 : 5,
        ),
        if (!widget.embedded)
          BTN(
            name: 'اعمال اطلاعات',
            type: BTNType.ok,
            onTap: () {
              if (note.text.trim().length > 1000) {
                Alert.error('یادداشت نباید بیشتر از ۱۰۰۰ نویسه باشد.');
                return;
              }
              DateTime? selected;
              try {
                selected = readDate();
              } catch (_) {
                Alert.error('تاریخ و ساعت سررسید معتبر نیست.');
                return;
              }
              widget.onSave(selected, note.text.trim());
              Get.back();
              Alert.success(
                'سررسید و یادداشت اعمال شد؛ ثبت نهایی هنوز انجام نشده است.',
              );
            },
          ),
      ],
    );
    return widget.embedded
        ? content
        : SingleChildScrollView(controller: widget.scroll, child: content);
  }
}
