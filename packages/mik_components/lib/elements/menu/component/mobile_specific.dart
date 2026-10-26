import 'package:flutter/foundation.dart';

void platformSpecificFunction(String route) {
  // کد مخصوص موبایل
  if (kDebugMode) {
    print('This is mobile platform with route: $route');
  }
}
