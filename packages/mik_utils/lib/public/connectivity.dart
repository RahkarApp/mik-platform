// ignore_for_file: empty_catches

// import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:mik_variables/variable.dart';


class ConnectCheck {
  static vpnCheck() async {
    // if (await CheckVpnConnection.isVpnActive()) {
    //   vpn.value = true;
    // } else {
    //   vpn.value = false;
    // }
  }

  static connectivity() async {
    List<ConnectivityResult> result = await (Connectivity().checkConnectivity());
    checkConnectivityStatus(result[0]);
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      // Got a new connectivity status!
      checkConnectivityStatus(result[0]);
    });
  }

  static void checkConnectivityStatus(ConnectivityResult result) {
    if (result == (ConnectivityResult.wifi)) {
      connectAct('WIFI');
    } else if (result == (ConnectivityResult.mobile)) {
      connectAct('mobile');
    } else if (result == (ConnectivityResult.ethernet)) {
      connectAct('ethernet');
    } else if (result == (ConnectivityResult.none)) {
      if (kDebugMode) {
        print('disconnect');
      }
      vpn.value = false;
      internetCheck.value = false;
      serverAvailable = false;
    } else {
      if (kDebugMode) {
        print('disconnect Def');
      }
      internetCheck.value = kIsWeb ? true : false;
      serverAvailable = kIsWeb ? true : false;
    }
    // if (result == (ConnectivityResult.none) && isToken) {
    //   socketConnected.value = 'error';
    //   SKT.disconnect();
    // } else {
    //   if (isToken) SKT.connect();
    // }
  }

  static connectAct(from) async {
    await vpnCheck();
    internetCheck.value = true;
    if (kDebugMode) {
      print('connect $from');
    }
    await API.server();
    try {
      // if (dataQueue.isOpen) await API.sendDataQueue();
      // AppMetrica.sendEventsBuffer();
    } catch (e) {}
  }
}
