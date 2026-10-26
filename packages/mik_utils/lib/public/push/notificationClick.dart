// ignore_for_file: file_names

import 'dart:convert';

notificationClick(message) async {
  if (message.data['act'] == 'patternStatusOK') {
  } else if (message.data['act'] == 'msg') {
    if (message.data['data'] != 'smart') {}
  } else if (message.data['act'] == 'tickt') {
  } else if (message.data['act'] == 'openLink') {}
}

yandexNotificationClick(payload) async {
  if (payload != null) {
    var data = jsonDecode(payload);
    if (data['act'] == 'patternStatusOK') {
    } else if (data['act'] == 'msg') {
      if (data['data'] != 'smart') {}
    } else if (data['act'] == 'tickt') {
      //
    } else if (data['act'] == 'openLink') {
      //
    }
  }
}
