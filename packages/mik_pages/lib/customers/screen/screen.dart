import 'package:mik_pages/customers/crm/remote_screen.dart';
import 'package:flutter/material.dart';
import 'package:mik_pages/customers/customer_controller.dart';
import 'package:mik_pages/customers/customer_tab.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/persons/components/item.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_variables/variable.dart';

import 'package:persian_number_utility/persian_number_utility.dart';

part 'tabs/customer/customer.dart';
part 'tabs/customer/controller.dart';
part 'tabs/crm/crm.dart';
part 'tabs/crm/controller.dart';
part './tabs/campain.dart';

RxInt indexCustomer = 0.obs;
RxString customerSearch = ''.obs;
CustomerTabDashboardController customerTabDashboardController = Get.put(
  CustomerTabDashboardController(),
);
CRMTabDashboardController crmTabDashboardController = Get.put(
  CRMTabDashboardController(),
);

class CustomersDashboardScreen extends StatefulWidget {
  final int index;
  const CustomersDashboardScreen({required this.index, super.key});

  @override
  State<CustomersDashboardScreen> createState() =>
      _CustomersDashboardScreenState();
}

class _CustomersDashboardScreenState extends State<CustomersDashboardScreen> {
  RxList<String> tabs = <String>[].obs;
  final remoteCustomers = RemoteCustomersController(appId: 'mik');

  @override
  void dispose() {
    remoteCustomers.onClose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    remoteCustomers.load();
    indexCustomer.value = widget.index;
  }

  @override
  Widget build(BuildContext context) {
    return Main(
      initState: () async => init(),
      child: (data) => Obx(
        () => Column(
          children: [
            //const SizedBox(height: 10,),
            MyTabBar(
              tabs: tabs,
              currentIndex: indexCustomer.value,
              index: (value) => {
                indexCustomer.value = value,
                MySearchBarController.unfoces(),
                customerSearch.value = '',
                remoteCustomers.search(''),
              },
            ),
            const SizedBox(height: 5),
            MySearchBar(
              type: indexCustomer.value == 0
                  ? SearchBarType.user
                  : indexCustomer.value == 1
                  ? SearchBarType.crm
                  : SearchBarType.campain,
              callback: (v) {
                customerSearch.value = v;
                if (indexCustomer.value == 0) {
                  remoteCustomers.search(v.toString());
                } else if (indexCustomer.value == 2) {
                  CampainTabDashboard().init();
                }
              },
            ),
            Expanded(child: Obx(() => child())),
          ],
        ),
      ),
    );
  }

  Future<Object> init() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tabs.value = [];
      tabs.add('مشتریان');
      // The CRM page resolves current server permissions itself.
      tabs.add('تاریخچه ارتباطات');
    });
    return '';
  }

  Widget child() {
    switch (indexCustomer.value) {
      case 0:
        return RemoteCustomersTab(controller: remoteCustomers);
      case 1:
        return CRMTabDashboard();
      case 2:
        return CampainTabDashboard();
      default:
        return RemoteCustomersTab(controller: remoteCustomers);
    }
  }
}
