import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_pages/invoice/read_screen.dart';
import 'package:mik_utils/public/analytics.dart';

import 'controller.dart';

// Legacy socket consumers still reference this controller; remote rows never enter Hive.
final InvoiceScreenController invoiceScreenController = Get.put(
  InvoiceScreenController(),
);

class InvoiceScreen extends StatelessWidget {
  final String appId;
  final String? analyticsName;
  const InvoiceScreen({super.key, this.appId = 'mik', this.analyticsName});
  @override
  Widget build(BuildContext context) {
    Analytics.pageView(analyticsName);
    return RemoteInvoicesScreen(appId: appId, includeProforma: true);
  }
}
