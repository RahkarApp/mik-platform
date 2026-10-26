// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class DateInput extends GetView {
  @override
  TextEditingController controller;
  FocusNode? focusNode;
  String name;
  TextDirection? textDirection;
  TextAlign? textAlign;
  bool? readOnly;
  bool? enabled;
  bool? require;
  var onChanged;
  String? hintText;
  Jalali? firstDate;
  Jalali? lastDate;
  Color? fillColor;
  bool? timePicker;
  DateInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.fillColor,
    this.textDirection,
    this.textAlign,
    this.readOnly,
    required this.onChanged,
    this.enabled,
    this.timePicker,
    this.hintText,
    this.lastDate,
    this.require,
    this.firstDate,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    // if (controller.text.isEmpty && !(require ?? true)) {
    //   controller.text = DateConvertor.jalaliNow();
    // }
    return Input(
      controller: controller,
      name: name,
      fillColor: fillColor,
      require: require,
      focusNode: focusNode,
      textDirection: textDirection,
      textAlign: textAlign,
      readOnly: true,
      maxLines: 1,
      minLines: 1,
      onTap: () => picker(
        context,
        controller,
        timePicker ?? false,
        firstDate,
        lastDate,
        (v) => onChanged(v),
      ),
      enabled: enabled,
      hintText: hintText,
    );
  }

  picker(
    context,
    controller,
    bool timePicker,
    firstDate,
    lastDate,
    callback,
  ) async {
    Jalali initDate = Jalali.now();
    if (controller.text != '') {
      try {
        var d = controller.text.split(' ').first.split('/');
        initDate = Jalali(
          int.parse(d[0].toString().toEnglishDigit()),
          int.parse(d[1].toString().toEnglishDigit()),
          int.parse(d[2].toString().toEnglishDigit()),
        );
      } catch (e) {}
    }
    Jalali? pick = await showPersianDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: firstDate ?? Jalali(1320, 1),
      lastDate:
          lastDate ??
          Jalali.fromDateTime(
            DateTime.now().add(const Duration(days: 365 * 5)),
          ),
      //title: 'انتخاب تاریخ',
    );
    TimeOfDay? time;
    var initialTime = TimeOfDay.now();
    final clock = controller.text
        .toString()
        .toEnglishDigit()
        .split(' ')
        .last
        .split(':');
    if (clock.length == 2) {
      final hour = int.tryParse(clock[0]), minute = int.tryParse(clock[1]);
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour < 24 &&
          minute >= 0 &&
          minute < 60) {
        initialTime = TimeOfDay(hour: hour, minute: minute);
      }
    }
    if (pick != null) {
      if (timePicker) {
        time = await showTimePicker(context: context, initialTime: initialTime);
      }
      // Cancelling the time picker must preserve the previous complete value.
      if (timePicker && time == null) return pick;
      controller.text =
          "${"${pick.year}".toEnglishDigit()}/${"${pick.month}".toEnglishDigit()}/${"${pick.day}".toEnglishDigit()}";
      if (time != null) {
        controller.text += ' ${time.hour}:${time.minute}';
      }
      callback(controller.text);
    } else {
      // controller.text = '';
    }
    return pick;
  }
}
