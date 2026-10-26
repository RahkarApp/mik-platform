part of '../screen.dart';

class WarehouseItem extends GetView {
  WarehouseNameDB item;
  int index;
  RxBool change = false.obs;
  WarehouseItem(this.item, this.index, {super.key});

  @override
  Widget build(BuildContext context) {
    String b = WarehouseFX.branchName(item.uid!);
    return Obx(
      () => change.isFalse || change.isTrue
          ? InkWell(
              onTap: () => {tap(context, b, index)},
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(color: AppColors.boxBackground.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(5)),
                        child: Icon(b != 'عمومی' ? IconsaxPlusBold.home_hashtag : IconsaxPlusLinear.home_hashtag, size: 40, color: AppColors.disable),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Column(
                          //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    children: [Text(item.name, maxLines: 1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))],
                                  ),
                                ),
                                Container(padding: const EdgeInsets.only(left: 10), child: Text(b)),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(padding: const EdgeInsets.only(right: 5), child: Text('اقلام: ${Number.addCommas(ProductFX.inWarehouse(item.uid!))}')),
                                Container(padding: const EdgeInsets.only(left: 10), child: Text('تعداد: ${Number.addCommas(ProductFX.inventoryWarehouse(item.uid!))}')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  EndLine(),
                  if (index != warehouseName.length - 1) const SizedBox(height: 5),
                  if (index == warehouseName.length - 1) const SizedBox(height: 60),
                ],
              ),
            )
          : Container(),
    );
  }

  tap(context, b, index) {
    return MyBottomSheet.view(
      context,
      child: (scrollController) => Obx(
        () => Column(
          children: [
            Row(
              children: [
                SizedBox(width: 90, height: 90, child: Icon(b != 'عمومی' ? IconsaxPlusBold.home_hashtag : IconsaxPlusLinear.home_hashtag, size: 40, color: Colors.grey.withValues(alpha: 0.5))),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(left: 10),
                      width: Get.width - 120,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('کد: ${ProductFX.showID(item.id)}', style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black)),
                          Text(b, style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black)),
                        ],
                      ),
                    ),
                    // SizedBox(
                    //     width: Get.width - 120,
                    //     child: Text(
                    //       item.name.toString(),
                    //       maxLines: 2,
                    //       style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                    //     )),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 5, top: 5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: darkMode.isTrue ? Colors.grey[700] : Colors.grey[200]),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('تعداد اقلام:', style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black)),
                      Text('${Number.addCommas(ProductFX.inWarehouse(item.uid!))} کالا', style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('تعداد کالاها:', style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black)),
                      Text(Number.addCommas(ProductFX.inventoryWarehouse(item.uid!)), style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black)),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (item.uid != warehouseName.getAt(0)!.uid)
                  MiniBTN(
                    name: 'ویرایش',
                    color: darkMode.isTrue ? Colors.grey.shade600 : Colors.grey.shade300,
                    itemColor: darkMode.isFalse ? Colors.grey.shade800 : Colors.grey.shade300,
                    icon: IconsaxPlusLinear.edit_2,
                    onTap: () async {
                      await warehouseTabDashboardController.addW(context, item, index: index);
                      change.toggle();
                    },
                  ),
                MiniBTN(
                  name: 'انتقال کالاها',
                  color: darkMode.isTrue ? Colors.grey.shade600 : Colors.grey.shade300,
                  itemColor: darkMode.isFalse ? Colors.grey.shade800 : Colors.grey.shade300,
                  icon: IconsaxPlusLinear.arrow_swap_horizontal,
                  onTap: null,
                ),
                MiniBTN(
                  name: 'انبارگردانی',
                  color: darkMode.isTrue ? Colors.grey.shade700 : Colors.grey.shade100,
                  itemColor: darkMode.isFalse ? Colors.grey.shade400 : Colors.grey.shade500,
                  icon: IconsaxPlusLinear.refresh_2,
                  onTap: () async {
                    return Alert.info('بزودی...');
                    // change.toggle();
                  },
                ),
                if (item.uid != warehouseName.getAt(0)!.uid)
                  MiniBTN(
                    name: 'حذف انبار',
                    color: darkMode.isTrue ? Colors.grey.shade600 : Colors.grey.shade300,
                    itemColor: darkMode.isFalse ? Colors.grey.shade800 : Colors.grey.shade300,
                    icon: IconsaxPlusLinear.trash,
                    onTap: () async {
                      if (ProductFX.inventoryWarehouse(item.uid!) > 0) {
                        return Alert.error('حذف انبار دارای موجودی ممکن نیست!');
                      } else {
                        Confirm.con(
                          context,
                          onTapConfirm: () async {
                            if (ProductFX.inventoryWarehouse(item.uid!) > 0) {
                              return Alert.error('حذف انبار دارای موجودی ممکن نیست!');
                            } else {
                              Get.back();
                              Get.back();
                              Alert.success('حذف انبار با موفقیت انجام شد.');
                              await SaveHelper.delete(item, index);
                              warehouseTabDashboardController.init();
                            }
                            // change.toggle();
                          },
                          confirmText: 'تایید و حذف',
                          type: ConfirmType.DELETE,
                        );

                        //Get.back();
                      }
                      // change.toggle();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      title: item.name.toString(),
    );
  }
}
