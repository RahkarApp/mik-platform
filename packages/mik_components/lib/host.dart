import 'package:flutter/widgets.dart';

abstract final class ComponentHost {
  static Widget Function(BuildContext context, Widget page)? pageShell;
  static WidgetBuilder? calendar;
  static WidgetBuilder? profile;
  static WidgetBuilder? settings;
  static WidgetBuilder? accounts;
}
