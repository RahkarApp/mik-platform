// ignore_for_file: dead_code

part of '../screen.dart';

class ProductItem extends GetView {
  ProductDB item;
  int index;
  String? wuid;
  ValueSetter callback;

  ProductItem(this.item, this.index, this.callback, {this.wuid, super.key});
  RxBool change = false.obs;
  @override
  Widget build(BuildContext context) {
    double inventory = wuid != null ? ProductFX.productInWarehouse(item.uid!, '-', wuid!) : ProductFX.productInAllWarehouse(item.uid!);

    return Obx(
      () => change.isFalse || change.isTrue
          ? InkWell(
              // The detail page and its supporting components were removed.
              onTap: null,
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      ProductImage.img(context, item, 70, showAll: true),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    children: [
                                      Icon(
                                        (item.type == null || (item.type != null && item.type == 'product')) ? IconsaxPlusLinear.box : IconsaxPlusLinear.tag_2,
                                        size: 20,
                                        color: Colors.grey.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: TextScroll(
                                          item.name.toString(),
                                          pauseBetween: Duration(seconds: 1),
                                          velocity: const Velocity(pixelsPerSecond: Offset(40, 0)),
                                          numberOfReps: 2,
                                          mode: TextScrollMode.endless,
                                          intervalSpaces: 10,
                                          textDirection: TextDirection.rtl,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(padding: const EdgeInsets.only(left: 10), child: Text('کد: ${ProductFX.showID(item.id ?? 0)}')),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              spacing: 5,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                if (ProductFX.isPro(item.uid)) Icon(IconsaxPlusLinear.star, size: 15, color: Colors.grey.withValues(alpha: 0.5)),
                                Icon(IconsaxPlusLinear.category, size: 15, color: Colors.grey.withValues(alpha: 0.5)),
                                Flexible(
                                  child: TextScroll(
                                    ProductFX.catListName(item.catIDList!),
                                    pauseBetween: Duration(seconds: 1),
                                    velocity: const Velocity(pixelsPerSecond: Offset(40, 0)),
                                    numberOfReps: 2,
                                    mode: TextScrollMode.endless,
                                    textDirection: TextDirection.rtl,
                                    intervalSpaces: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: inventory == 0 && item.type != 'service'
                                      ? Container(
                                          decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          child: Text(
                                            'بدون موجودی',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                                          ),
                                        )
                                      : Text(
                                          item.type == 'service'
                                              ? ''
                                              : wuid != null
                                              ? 'موجودی این انبار: ${Number.addCommas(inventory)} ${ProductFX.unitName(item.unitCode)}'
                                              : 'موجودی: ${Number.addCommas(inventory)} ${ProductFX.unitName(item.unitCode)}',
                                        ),
                                ),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('قیمت: '),
                                        Flexible(
                                          child: TextScroll(
                                            ProductFX.minMaxPrice(puid: item.uid),
                                            pauseBetween: Duration(seconds: 1),
                                            velocity: const Velocity(pixelsPerSecond: Offset(40, 0)),
                                            numberOfReps: 2,
                                            mode: TextScrollMode.endless,
                                            intervalSpaces: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  EndLine(),
                  if (index != product.length - 1) const SizedBox(height: 5),
                  if (index == product.length - 1) const SizedBox(height: 60),
                ],
              ),
            )
          : Container(),
    );
  }

}
