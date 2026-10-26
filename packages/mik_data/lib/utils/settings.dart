// ignore_for_file: deprecated_member_use, empty_catches

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mik_data/source/database/db.dart';
import 'package:mik_data/utils/saveHelper.dart';
import 'package:mik_variables/variable.dart';

import '../models/models.dart';
import 'variable.dart';

class Settings {
  static SettingsData defaults() {
    final smsset = SendSmsSetting(
      orderSubmit: false,
      orderSended: false,
      orderCancelled: false,
      orderDelayTanks: false,
      orderReadySend: false,
      orderReturned: false,
      orderOnlinePay: false,
      preFactor: false,
    );
    return SettingsData(
      darkMode: 'light',
      dayForCancel: 3,
      dayForPreFactor: 7,
      animation: true,
      factorType: 1,
      factorText: 'متن نمونه',
      factorColor1: 'f77f00',
      factorColor2: '73D2DE',
      sendSms: smsset,
      skipInit: false,
      usePreFactor: false,
      factorLink: true,
      factorVat: false,
      factorIsRial: false,
      connectionStatus: [],
      profitInInvoice: 'FIFO',
      factorSize: 'a4',
    );
  }

  static Future<void> read() async {
    if (!Hive.isBoxOpen(DB.boxName('settings')) ||
        !Hive.isBoxOpen(DB.boxName('localSetting'))) {
      await DB.read(namespace: DB.namespace);
    }

    if (settingsData.isEmpty && profile.isNotEmpty) {
      final item = defaults();
      await settingsData.add(item);
      await SaveHelper.save(item);
      settingsData = await Hive.openBox<SettingsData>(DB.boxName('settings'));
    }

    if (settingsData.isNotEmpty) settings = settingsData.getAt(0)!;
    try {
      if (settings!.darkMode == 'light') {
        darkMode.value = false;
      } else if (settings!.darkMode == 'dark') {
        darkMode.value = true;
      }
      if (settings!.darkMode == 'system') {
        var brightness = WidgetsBinding.instance.window.platformBrightness;
        darkMode.value = brightness == Brightness.dark;
      }
    } catch (e) {}
    Get.changeThemeMode(darkMode.value ? ThemeMode.dark : ThemeMode.light);
    {
      if (localSetting.isEmpty && profile.isNotEmpty) {
        bool debt = bill.values
            .where((d) => d.debtorUID! != '' || d.debtorUID! != '-')
            .toList()
            .isNotEmpty;
        bool creadit = bill.values
            .where((d) => d.creditorUID! != '' || d.creditorUID! != '-')
            .toList()
            .isNotEmpty;
        bool init = !(invoice.length > 0 && partnerTransaction.length > 0);
        LocalSetting item = LocalSetting(
          isLock: false,
          password: '',
          active: true,
          init: init, //goto INIT
          ipgStatus: false,
          timeLeft: 5,
          dateupdate: DateTime.now().toIso8601String(),
          smartLink: false,
          pageIntro: [],
          firstInvoice: invoice.length > 0,
          firstDebt: debt,
          firstCreadit: creadit,
          firstInvest: partnerTransaction.length > 0,
          homeChartType: 'سود هفته',
          fastReportDayRang: 7,
        );
        await localSetting.add(item);
      }
    }
  }
}
