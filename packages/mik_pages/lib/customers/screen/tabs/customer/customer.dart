part of '../../screen.dart';

class CustomerTabDashboard extends StatefulWidget {
  const CustomerTabDashboard({super.key});

  @override
  State<CustomerTabDashboard> createState() => _CustomerTabDashboardState();
}

class _CustomerTabDashboardState extends State<CustomerTabDashboard> {
  @override
  void initState() {
    // TODO: implement initState
    customerTabDashboardController.init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      floatingActionButton: PermissionAccess.hasPermission(PermissionsName.customersCreate)
          ? MyFAB(
              icon: IconsaxPlusLinear.add,
              text: 'مشتری جدید',
              onTap: () async {
                await Get.toNamed(
                  RoutesName.PERSONEADD,
                  arguments: {'title': 'مشتری جدید'},
                );
                customerTabDashboardController.init();
              },
            )
          : Container(),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.only(right: 10),
                child: const Text(
                  'لیست مشتریان',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Stack(
                children: [
                  IconButton(
                    onPressed: () =>
                        customerTabDashboardController.filter(context),
                    icon: const RotatedBox(
                      quarterTurns: 1,
                      child: Icon(IconsaxPlusLinear.setting_5),
                    ),
                  ),
                  Obx(
                    () => customerTabDashboardController.filtered.isTrue
                        ? Container(
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(top: 9, right: 7),
                            child: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              maxRadius: 5,
                            ),
                          )
                        : Container(),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: customerTabDashboardController.customer.isNotEmpty
                ? Obx(
                    () => customerTabDashboardController.prs.isEmpty
                        ? EmptyList(
                            text: 'مشتری با این مشخصات موجود نیست!',
                            icon: IconsaxPlusLinear.user_search,
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            // controller: customerTabDashboardController.scl,
                            itemCount:
                                customerTabDashboardController.prs.length,
                            itemBuilder: (context, index) {
                              return PermissionAccess.hasPermission(PermissionsName.customersViewAll) ||
                                      (PermissionAccess.hasPermission(PermissionsName.customersView) &&
                                          customerTabDashboardController
                                                  .prs[index]
                                                  .inserter ==
                                              mikyarProfileID)
                                  ? PersonItem(
                                      customerTabDashboardController.prs[index],
                                      index + 1 ==
                                          customerTabDashboardController
                                              .prs
                                              .length,
                                      'customer',
                                    )
                                  : Container();
                            },
                          ),
                  )
                : EmptyList(
                    text: 'هیچ مشتری وجود ندارد!',
                    icon: IconsaxPlusLinear.user_search,
                  ),
          ),
        ],
      ),
    );
  }
}
