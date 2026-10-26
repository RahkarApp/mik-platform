// ignore_for_file: depend_on_referenced_packages, avoid_print, prefer_typing_uninitialized_variables, empty_catches, unused_local_variable

import 'dart:async';
import 'dart:convert';

// import 'package:appmetrica_plugin/appmetrica_plugin.dart';
// import 'package:appmetrica_push_plugin/appmetrica_push_plugin.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_data/models/models.dart';
// import 'package:push/push.dart';
import 'package:timezone/data/latest_all.dart' as tz;


late NotificationAppLaunchDetails? notificationAppLaunchDetails;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;

class Notif {
  static firstNotifINIT() async {
    await Notif.configureLocalTimeZone();
    await Notif.initialNotif();

    notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    fcm = await Hive.openBox<FCM>('fcm');
    var fcmToken = fcm.isNotEmpty ? fcm.getAt(0)!.token : '';
    // await AppMetricaPush.getTokens().then((tokens) async {
    //   print("=======TOKEN==========");
    //   print(tokens);
    //   var tk = '';
    //   var device = 'firebase';
    //   if (tokens.containsKey('firebase') && tokens['firebase'] != null) {
    //     tk = tokens['firebase']!;
    //     device = 'firebase';
    //   } else if (tokens.containsKey('apns') && tokens['apns'] != null) {
    //     tk = tokens['apns']!;
    //     device = 'ios';
    //   } else if (tokens.containsKey('hms') && tokens['hms'] != null) {
    //     tk = tokens['hms']!;
    //     device = 'hms';
    //   }
    //   if (tk != '' &&
    //       fcm.isNotEmpty &&
    //       ((fcm.getAt(0)!.device == null || fcm.getAt(0)!.device == '') ||
    //           (fcm.getAt(0)!.token != tk))) {
    //     await fcm.deleteAt(0);
    //     fcmToken = '';
    //   }
    //   if (tk != '' && fcmToken == '') {
    //     FCM fcmT = FCM(token: tk, device: device);
    //   }
    // });

    try {
      //Push.instance.addOnMessage((message) {
      // if (Platform.isIOS) {
      //   yandexNotificationOpenAppIOS(message);
      // } else {
      //   yandexNotificationOpenAppAndroid(message);
      // }
      //  });
    } catch (e) {}
    // Push.instance.notificationTapWhichLaunchedAppFromTerminated.then((data) {
    // if (data == null) {
    //   print("App was not launched by tapping a notification");
    // } else {
    //   yandexNotificationClick(data['payload']);
    // }
    //});
    // AppMetrica.sendEventsBuffer();
  }

  static Future<void> configureLocalTimeZone() async {
    tz.initializeTimeZones();
  }

  static Future<void> initialNotif() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // await AppMetricaPush.requestPermission(
    //     alert: true, badge: true, sound: true);
    //await Push.instance.requestPermission();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // onDidReceiveLocalNotification: (
      //   int id,
      //   String? title,
      //   String? body,
      //   String? payload,
      // )  async {}
    );
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: null,
      linux: null,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) async {
      switch (notificationResponse.notificationResponseType) {
        case NotificationResponseType.selectedNotification:
          break;
        case NotificationResponseType.selectedNotificationAction:
          break;
      }
    });
  }

  static requestPermissions() async {
    // await AppMetricaPush.requestPermission(
    //     alert: true, badge: true, sound: true);
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}

Future<void> showYandexNotification(notifi, notifData) async {
  var data = jsonDecode(notifData['yamp'])["c"];
  var notif;
  notif = {
    "title": jsonDecode(notifData['yamp'])["d"]['e'],
    "body": jsonDecode(notifData['yamp'])["d"]['g']
  };
  AndroidNotificationDetails androidNotificationDetails =
      const AndroidNotificationDetails('mik', 'mik',
          channelDescription: 'mik app notifications',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: DefaultStyleInformation(true, true),
          playSound: true,
          ticker: 'ticker');
  DarwinNotificationDetails iosNotificationDetails =
      const DarwinNotificationDetails(
          presentBadge: true, presentSound: true, presentAlert: true);
  NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails, iOS: iosNotificationDetails);
  await flutterLocalNotificationsPlugin.show(
      0, notif['title'], notif['body'], notificationDetails,
      payload: data);
}
