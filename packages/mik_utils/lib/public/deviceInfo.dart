// ignore_for_file: file_names

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfo {
  static info() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      WebBrowserInfo browserInfo = await deviceInfo.webBrowserInfo;
      return ({
        'id': browserInfo.appCodeName,
        'brand': browserInfo.platform,
        'model': browserInfo.appName,
        'os': 'web',
        'osVersion': browserInfo.appVersion
      });
    } else {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return ({
          'id': androidInfo.id,
          'brand': androidInfo.brand,
          'model': androidInfo.model,
          'os': 'Android',
          'osVersion': androidInfo.version.release
        });
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return ({
          'id': iosInfo.identifierForVendor,
          'brand': 'Apple',
          'model': "${iosInfo.model} ${iosInfo.localizedModel}",
          'os': 'iOS',
          'osVersion': iosInfo.systemVersion
        });
      }
    }
  }
}
