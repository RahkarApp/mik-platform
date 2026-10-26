// ignore_for_file: unrelated_type_equality_checks, prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:shamsi_date/shamsi_date.dart';

class DateConvertor {
  static String jalaliNow() {
    var pick = Jalali.now();
    return "${"${pick.year}".toEnglishDigit()}/${"${pick.month}".toEnglishDigit()}/${"${pick.day}".toEnglishDigit()}";
  }

  static String jalaliTimeNow() {
    var pick = Jalali.now();
    var tt = TimeOfDay.now();
    return "${"${pick.year}".toEnglishDigit()}/${"${pick.month}".toEnglishDigit()}/${"${pick.day}".toEnglishDigit()} ${tt.hour}:${tt.minute}";
  }

  static String jalaliToGrigori(pdate) {
    if (pdate == null || pdate == '' || pdate == '0000/00/00') {
      return '';
      // var d = DateTime.now().toJalali();
      // pdate =
      //     "${"${d.year}".toEnglishDigit()}/${"${d.month}".toEnglishDigit()}/${"${d.day}".toEnglishDigit()}";
    }
    String spliter = pdate.contains(' ') ? ' ' : 'T';
    List ft = pdate.split(spliter);
    var dt = ft[0].split('/');
    var tt;

    if (ft.length > 1) {
      tt = ft[1].split(':');
    }
    DateTime time = DateTime.now();
    var hour = tt != null ? int.parse(tt[0]) : time.hour;
    var min = tt != null ? int.parse(tt[1]) : time.minute;
    var sec = time.second;
    return Jalali(
      int.parse('${dt[0]}'.toEnglishDigit()),
      int.parse('${dt[1]}'.toEnglishDigit()),
      int.parse('${dt[2]}'.toEnglishDigit()),
      hour,
      min,
      sec,
    ).toGregorian().toDateTime().toIso8601String();
  }

  static grigoriToJalali(grigori) {
    if (grigori == null || grigori == '') {
      return '';
    }
    return grigori.toString().toPersianDate();
  }

  static grigori({DateTime? date}) {
    var d = date ?? DateTime.now();
    return "${"${d.year}".toEnglishDigit()}/${"${d.month}".toEnglishDigit()}/${"${d.day}".toEnglishDigit()}";
  }

  static jalali({DateTime? date}) {
    var d = date == null ? Jalali.now() : date.toJalali();
    return "${"${d.year}".toEnglishDigit()}/${"${d.month}".toEnglishDigit()}/${"${d.day}".toEnglishDigit()}";
  }

  static toDuration(date) {
    if (date != null) {
      DateTime sdate = DateTime.parse(date.toString());
      int min = DateTime.now().difference(sdate).inMinutes;
      int hour = 0; //60
      int day = 0; //1440
      int month = 0; //43200
      int year = 0; //525600
      while (min > 60) {
        if (min > 525600) {
          year++;
          min -= 525600;
        } else if (min > 43200) {
          month++;
          min -= 43200;
        } else if (min > 1440) {
          day++;
          min -= 1440;
        } else if (min > 60) {
          hour++;
          min -= 60;
        }
      }
      // ignore: unused_local_variable
      String mins = '', hours = '', days = '', monts = '', years = '';
      if (year > 0) years = "$year سال ";
      if (month > 0) monts = "${years != '' ? 'و ' : ''}$month ماه ";
      if (day > 0) days = "${month != '' ? 'و ' : ''}$day روز ";
      if (hour > 0) hours = "${day != '' ? 'و ' : ''}$hour ساعت ";
      if (min > 0) mins = "${hour != '' ? 'و ' : ''}$min دقیقه";
      if ("$years$monts$days" == '') {
        return 'به‌تازگی';
      } else {
        return "$years$monts$days";
      }
    } else {
      return '';
    }
  }

  static Jalali jalaliStartMonth({month}) {
    ///  DateTime s = DateTime.now().add(Duration(days: ));
    return Jalali.now().addMonths(month ?? 0).withDay(1);
  }

  static Jalali jalaliEndMonth({month}) {
    return Jalali.now()
        .addMonths(month ?? 0)
        .withDay(Jalali.now().addMonths(month ?? 0).monthLength);
  }

  static List<String> jalaliMonthDates({int? month, int? year}) {
    month = month ?? Jalali.now().month;
    year = year ?? Jalali.now().year;
    List<String> date = [];
    for (var i = 0; i < Jalali(year, month).monthLength; i++) {
      date.add(Jalali(year, month, i + 1).toDateTime().toPersianDate());
    }
    return date;
  }

  static String showTime(DateTime date, {int? offsetPerMin}) {
    if (offsetPerMin != null) date = date.add(Duration(minutes: offsetPerMin));
    return '${date.hour}:${date.minute < 10 ? '0${date.minute}' : date.minute}';
  }

  static List<DateTime> dateTimeMonthRang({month}) {
    DateTime startDate = DateTime.parse(
      jalaliStartMonth(month: month)
          .toDateTime()
          .toIso8601String()
          .split('T')[0],
    );
    DateTime endDate = DateTime.parse(
      jalaliEndMonth(month: month)
          .toDateTime()
          .add(Duration(days: 1))
          .toIso8601String()
          .split('T')[0],
    );
    return [startDate, endDate];
  }

  static String toJalaliLong(DateTime date, {bool time = true}) {
    var jdd = date.toJalali();
    return time
        ? '${jdd.day} ${jdd.formatter.mN} ${jdd.year} ${jdd.hour}:${jdd.minute}'
        : '${jdd.day} ${jdd.formatter.mN} ${jdd.year}';
  }

  static String toJalaliShort(DateTime date, {bool time = true}) {
    var jdd = date.toJalali();
    return time
        ? '${jdd.hour}:${jdd.minute}-${jdd.year}/${jdd.month}/${jdd.day}'
        : '${jdd.year}/${jdd.month}/${jdd.day}';
  }

  static HijriCalendar toHijri(DateTime date) {
    return HijriCalendar.fromDate(date.add(Duration(days: hijriOffset)));
  }
}
