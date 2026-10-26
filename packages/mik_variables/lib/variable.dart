export 'package:mik_variables/permissions.dart';
import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:mik_data/models/models.dart';

RxList<int> permissions = <int>[].obs;
RxList<String> warehouses = <String>[].obs;
RxList<String> branchs = <String>[].obs;
int? mikyarProfileID;

GlobalKey<DrawerControllerState>? homeDashboardKey;

//1:تومان
//0: ریال
int currencyType = 1;
RxDouble dbUpdateLength = 0.0.obs, dbUpdateCurrent = 0.0.obs;
double topPadding = 0, bottomPadding = 0;
bool isToken = false;
RxBool darkMode = false.obs,
    vpn = false.obs,
    msgNew = false.obs,
    dbUpdate = false.obs,
    internetCheck = false.obs,
    temporaryProductExist = false.obs,
    dataQueueFlag = false.obs,
    dataToServerFlag = false.obs,
    ipgStatus = false.obs,
    smartLinkStatus = false.obs,
    smartConnectStatus = false.obs,
    smartViewStatus = false.obs,
    lockApp = false.obs,
    newVersion = false.obs,
    active = true.obs,
    systemDarkMode = false.obs,
    waitServer = false.obs,
    lock = false.obs,
    lpgStatus = false.obs;

bool marketStatus = false, serverAvailable = false;

Directory? dir, prImageDir, userImageDir;

String version = '2.2.0';

SettingsData? settings;

RxInt msgCount = 0.obs;

RxMap balanceMony = {
  'invBalance': 0,
  'buyBalance': 0,
  'sellBalance': 0,
  'paidBalance': 0,
  //'buySellBalance': 0,
  'debtBalance': 0,
  'cerditBalance': 0.0,
  'stockSellBalance': 0.0,
  'stockBuyBalance': 0.0,
  'commissinBalance': 0,
  'costBalance': 0,
  'takenBalance': 0,
  //'shippingCostBalance': 0,
  //'excessBalance': 0,
  //'discountBalance':0,
  'tBalance': 0.0,
  'chequeHold': 0,
  'chequePayee': 0,
  'profit': 0,
}.obs;

StreamSubscription? linkStream;

// RxBool socketConnected = false.obs;
RxString socketConnected = 'ok'.obs;
BaseDeviceInfo? device;

// Host layout state shared by the reusable desktop/mobile components.
BuildContext? appContext;
RxBool isDesktop = false.obs,
    isMobile = false.obs,
    isTablet = false.obs,
    isPOS = false.obs;
RxDouble statusBarHeight = 0.0.obs,
    heightScreen = 0.0.obs,
    widthScreen = 0.0.obs;
LocalSetting? localSettings;
int mikyarProfileIndex = 0;
int hijriOffset = 0;
RxString get serverConnect => socketConnected;
