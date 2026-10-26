import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';

import '../product/warehouse/controller.dart';
import '../product/warehouse/screen.dart';

const quantityReportLimitation =
    'گزارش تجمیعی فروش هر محصول و نمودار دوره‌ای آن در قرارداد فعلی سرور ارائه نشده است. کاردکس انبار، گردش یک تنوع کالا در یک انبار است و جایگزین این گزارش نیست.';

class QuantityReportUnavailable extends StatefulWidget {
  final String appId;
  const QuantityReportUnavailable({required this.appId, super.key});
  @override
  State<QuantityReportUnavailable> createState() =>
      _QuantityReportUnavailableState();
}

class _QuantityReportUnavailableState extends State<QuantityReportUnavailable> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Alert.error(quantityReportLimitation, context: context);
    });
  }

  Future<void> warehouses() async {
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      active.check();
      await Get.toNamed(
        nav_routes.RoutesName.WAREHOUSE_MANAGEMENT,
        arguments: {'appId': widget.appId},
        preventDuplicates: false,
      );
    } catch (failure) {
      if (mounted) {
        Alert.error(FinancialReportsFX.message(failure), context: context);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Main(
    initState: () async => '',
    header: Header.page(context, text: 'گزارش گردش تعدادی'),
    child: (_) => Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(IconsaxPlusLinear.box_search, size: 50),
            const SizedBox(height: 10),
            const Text(quantityReportLimitation, textAlign: TextAlign.center),
            BTN(name: 'مشاهده انبارها و کاردکس موجود', onTap: warehouses),
          ],
        ),
      ),
    ),
  );
}

Widget buildWarehouseManagementRoute(RouteSettings settings) {
  final appId = nav_routes.RouteArguments(settings).required<String>('appId');
  return Builder(
    builder: (context) => Main(
      header: Header.page(context, text: 'انبارها'),
      initState: () async => '',
      child: (_) => WarehouseManagementScreen(
        appId: appId,
        controller: WarehouseManagementController(),
      ),
    ),
  );
}
