// ignore_for_file: file_names

import 'dart:convert';

import 'package:mik_components/base/alert.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:mik_data/utils/saveHelper.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class SMSSystem {
  static bool checkautoSMS(orderType) {
    switch (orderType) {
      case 1:
        return settings!.sendSms!.orderSubmit ?? false;
      case 2:
        return settings!.sendSms!.orderReadySend ?? false;
      case 3:
        return settings!.sendSms!.orderSended ?? false;
      case 4:
        return settings!.sendSms!.orderDelayTanks ?? false;
      case 8:
        return settings!.sendSms!.orderCancelled ?? false;
      case 9:
        return settings!.sendSms!.orderReturned ?? false;
      case 100:
        return settings!.sendSms!.orderOnlinePay ?? false;
      case 900:
        return settings!.sendSms!.preFactor ?? false;
      default:
        return false;
    }
  }

  static changeAutoSMS(orderType, newValue) async {
    switch (orderType) {
      case 1:
        settings!.sendSms!.orderSubmit = newValue;
        break;
      case 2:
        settings!.sendSms!.orderReadySend = newValue;
        break;
      case 3:
        settings!.sendSms!.orderSended = newValue;
        break;
      case 4:
        settings!.sendSms!.orderDelayTanks = newValue;
        break;
      case 8:
        settings!.sendSms!.orderCancelled = newValue;
        break;
      case 9:
        settings!.sendSms!.orderReturned = newValue;
        break;
      case 100:
        settings!.sendSms!.orderOnlinePay = newValue;
        break;
      case 900:
        settings!.sendSms!.preFactor = newValue;
        break;
      default:
        break;
    }
    await SaveHelper.save(settings);
  }

  static send({orderType, smsValue}) async {
    late bool active = false;
    active = checkautoSMS(orderType);
    if (active) {
      PatternDB? pt;
      for (var i = 0; i < pattern.length; i++) {
        var it = pattern.getAt(i)!;
        if (it.orderType == orderType && it.active != null && it.active!) {
          pt = it;
          break;
        }
      }
      if (pt == null) {
        Alert.error('پترن شما برای ارسال پیامک تایید نشده است.');
      } else {
        SmsPatternValue patternVal = SmsPatternValue(
          name: smsValue['name'],
          factorID: smsValue['factorID'].toString(),
          price: smsValue['price'] + ' تومان',
          date: smsValue['date'].toString().toPersianDate(),
          link: 'onmik.ir/?${smsValue['link']}',
        );
        SMS smsItem = SMS(
          personID: smsValue['personID'],
          mobile: smsValue['mobile'],
          patternCode: pt.code,
          smsPatternValue: patternVal,
          status: 'send',
          bulk: '',
          inserter: 0,
          date: DateTime.now().toIso8601String(),
        );
        var res = await API.sendSMS(smsItem.toJson());
        if (jsonDecode(res.body) != '400') {
          if (jsonDecode(res.body)['bulk'] != 'error') {
            smsItem.bulk = jsonDecode(res.body)['bulk'].toString();
            if (jsonDecode(res.body)['bulk'] == '0') {
              smsItem.status = 'error';
              Alert.error(
                'در ارسال پیامک خطایی رخ داده که علت آن نامشخص است.\nچند دقیقه دیگر امتحان کنید.',
              );
            } else {
              Alert.success('پیامک برای مشتری ارسال شد.');
            }
            await sms.add(smsItem);
          } else {
            if (jsonDecode(res.body)['status'] == 'noCredit') {
              Alert.info(
                'اعتبار پیامک شما منفی شده و امکان ارسال پیامک میسر نیست.\nلطفا حساب پیامکی خود را شارژ نمایید.',
              );
            } else if (jsonDecode(res.body)['status'] == 'service is Off') {
              Alert.info(
                'موقتا سرویس اطلاع رسانی هوشمند در دسترس نمیباشد، بزودی مشکل مرتفع شده و سرویس در دسترس قرار خواهد گرفت.',
              );
            } else {
              Alert.error(
                'در ارسال پیامک خطایی رخ داده که علت آن نامشخص است.\nچند دقیقه دیگر امتحان کنید.',
              );
            }
            smsItem.status = 'noCredit';
            await sms.add(smsItem);
          }
        } else {
          Alert.error(
            'در ارسال پیامک خطایی رخ داده که علت آن نامشخص است.\nچند دقیقه دیگر امتحان کنید.',
          );
          smsItem.status = 'error';
          await sms.add(smsItem);
        }
      }
    }
  }
}
