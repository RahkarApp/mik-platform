import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/reports/financial_screen.dart';
import 'package:mik_variables/permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_pages/reports/components/reportBTN.dart';

export 'screen/profit.dart' show ReportProfit;
export 'screen/productCount/screen.dart' show ReportProductsCount;
export 'screen/productCount/details.dart' show ReportProductsCountDetails;

class ReportsTabDashboard extends GetView {
  final String appId, quantityRoute, profitRoute;
  final bool embedded;
  const ReportsTabDashboard({
    super.key,
    this.appId = 'mik',
    this.quantityRoute = RoutesName.REPORTSPRODUCTCOUNT,
    this.profitRoute = RoutesName.REPORTSPROFIT,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (BusinessContext.forApp(appId) != null)
                  FinancialReportEntries(appId: appId),
                if (PermissionAccess.hasPermission(
                  PermissionsName.reportsQuantityView,
                ))
                  ReportBTNDashboard(
                    name: 'گردش تعدادی کالا',
                    desc: 'تعداد فروش هر کالا را در بازه‌های زمانی مختلف مشاهده کنید',
                    icon: IconsaxPlusLinear.chart,
                    onTap: () async {
                      await Get.toNamed(quantityRoute);
                    },
                  ),
                if (BusinessContext.forApp(appId)?.hasPermission(
                      'accounting.report.profit',
                      inBranch: true,
                    ) ??
                    PermissionAccess.hasPermission(
                      PermissionsName.reportsProfitView,
                    ))
                  ReportBTNDashboard(
                    name: 'سود و زیان',
                    desc: 'سود هر دوره را با دوره‌های قبل مقایسه کنید',
                    icon: IconsaxPlusLinear.activity,
                    onTap: () async {
                      await Get.toNamed(profitRoute);
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                      ]);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    if (embedded) return content;
    return Main(
      initState: () async => Container(),
      header: Header.page(context, isBack: false, text: 'گزارشات'),
      child: (_) => content,
    );
  }
}
