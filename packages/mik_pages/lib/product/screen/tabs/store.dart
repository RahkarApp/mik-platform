part of '../screen.dart';

class WarehouseTabDashboard extends GetView {
  const WarehouseTabDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    warehouseTabDashboardController.init();
    return Stack(
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.only(right: 10),
                  child: const Text('انبارها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 45),
                // IconButton(
                //     onPressed: () {},
                //     icon: const RotatedBox(
                //         quarterTurns: 1, child: Icon(IconsaxPlusLinear.setting_5)))
              ],
            ),
            Expanded(
              child: warehouseName.isNotEmpty
                  ? Obx(
                      () => warehouseTabDashboardController.st.isEmpty
                          ? EmptyList(text: 'انباری با این مشخصات موجود نیست!', icon: IconsaxPlusLinear.home_hashtag)
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              controller: warehouseTabDashboardController.scl,
                              itemCount: warehouseTabDashboardController.st.length,
                              itemBuilder: (context, index) {
                                return WarehouseItem(warehouseTabDashboardController.st[index], index);
                                //return Container();
                              },
                            ),
                    )
                  : EmptyList(text: 'هیچ انباری وجود ندارد!', icon: IconsaxPlusLinear.box),
            ),
          ],
        ),
        Positioned(
          bottom: 1,
          right: 10,
          child: MyFAB(
            icon: IconsaxPlusLinear.add,
            text: 'انبار جدید',
            onTap: () async {
              MySearchBarController.unfoces();
              await warehouseTabDashboardController.addW(context, null);
            },
          ),
        ),
      ],
    );
  }
}
