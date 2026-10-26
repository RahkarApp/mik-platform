// ignore_for_file: depend_on_referenced_packages, avoid_print, prefer_typing_uninitialized_variables, empty_catches, unused_local_variable

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  static Future<void> firebaseMessagingBackgroundHandler(message) async {
    if (kDebugMode) {
      print("Handling a background message: ${message.messageId}");
      print('Message data: ${message.data}');
      print('Message notification title: ${message.notification?.title}');
      print('Message notification body: ${message.notification?.body}');
      await showYandexNotification(message);
      //  if (Platform.isIOS) {
      //         yandexNotificationOpenAppIOS(message);
      //       } else {
      //         yandexNotificationOpenAppAndroid(message);
      //       }
      //        Push.instance.notificationTapWhichLaunchedAppFromTerminated.then((data) {
      //     if (data == null) {
      //       print("App was not launched by tapping a notification");
      //     } else {
      //       yandexNotificationClick(data['payload']);
      //     }
      //   });
    }
  }

  static firstNotifINIT() async {
    // await Firebase.initializeApp();
    await Notif.configureLocalTimeZone();
    await Notif.initialNotif();

    // notificationAppLaunchDetails =
    //     await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    // fcm = await Hive.openBox<FCM>('fcm');
    // var fcmToken = fcm.isNotEmpty ? fcm.getAt(0)!.token : '';
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
    final firebaseMessaging = FirebaseMessaging.instance;
    final settings = await firebaseMessaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Success: User authorized notifications');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('Success: User authorized notifications provisionnal');
    } else {
      print('Fail: User declined notifications');
    }
    // When it fails, open the settings page.
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((message) async {
        await firebaseMessagingBackgroundHandler(message);

        print('on messagefAGDSFDDSFSADFASDFASFDSFASDFSADFADSFDFASFSDFASFD');
        // if (Platform.isIOS) {
        //   yandexNotificationOpenAppIOS(message);
        // } else {
        //   yandexNotificationOpenAppAndroid(message);
        // }
      });

      // FirebaseMessaging.onMessageOpenedApp((message){});
    } catch (e) {}
    // Push.instance.notificationTapWhichLaunchedAppFromTerminated.then((data) {
    //   if (data == null) {
    //     print("App was not launched by tapping a notification");
    //   } else {
    //     yandexNotificationClick(data['payload']);
    //   }
    // });
    // AppMetrica.sendEventsBuffer();
  }

  static Future<void> configureLocalTimeZone() async {
    tz.initializeTimeZones();
  }

  static Future<void> initialNotif() async {
    //init android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    //init ios
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // ok initial
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: null,
      linux: null,
    );

    //request permission
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
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
    }
        // onDidReceiveBackgroundNotificationResponse: ,
        );
  }

  static Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}

Future<void> showYandexNotification(message) async {
  var data = message.data;
  var notif;
  notif = {
    "title": message.notification?.title,
    "body": message.notification?.body
  };
  AndroidNotificationDetails androidNotificationDetails =
      const AndroidNotificationDetails('mik', 'mik',
          channelDescription: 'mik app notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          ticker: 'ticker');
  DarwinNotificationDetails iosNotificationDetails =
      const DarwinNotificationDetails(
          presentBadge: true, presentSound: true, presentAlert: true);
  NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails, iOS: iosNotificationDetails);
  await flutterLocalNotificationsPlugin.show(
    0,
    notif['title'],
    notif['body'],
    notificationDetails,
  );
}
