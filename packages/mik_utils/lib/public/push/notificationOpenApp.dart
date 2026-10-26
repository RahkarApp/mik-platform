// ignore_for_file: unused_local_variable, file_names, prefer_typing_uninitialized_variables, empty_catches

// import 'dart:convert';
// import 'package:push/push.dart';

notificationOpenApp(event) async {
  if (event.data['act'] == 'msg') {
    //
  }
  if (event.data['data'] != 'smart') {
    //
  }
}

// yandexNotificationOpenAppAndroid(event) async {
//   var data;
//   try {
//     data = event.data;
//   } catch (e) {}
//   Notification? notif;
//   notif = Notification(
//       title: event.notification!.title, body: event.notification!.body);
//   // if (data != null) {
//   //   if (data['act'] == 'msg') {
//   //     //
//   //   }
//   //   if (data['data'] != 'smart') {
//   //     //
//   //   }
//   // }
// }

// yandexNotificationOpenAppIOS(event) async {
//   var data = jsonDecode(event.data['yamp']['d']);
//   Notification? notif;
//   notif = Notification(
//       title: jsonDecode(event.data['aps']["alert"])['title'],
//       body: jsonDecode(event.data['aps']["alert"])['body']);
//   if (data['act'] == 'msg') {
//     //
//   }
//   if (data['data'] != 'smart') {
//     //
//   }
// }
