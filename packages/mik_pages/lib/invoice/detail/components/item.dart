// ignore_for_file: deprecated_member_use

part of '../screen.dart';

class InvoiceItems extends GetView {
  int? prID;
  InvoiceDB item;
  InvoiceItems(this.item, {super.key});
  RxBool showItems = true.obs;
  List pID = [];
  @override
  Widget build(BuildContext context) {
    pID = item.items!.keys.toList();
    // if (pID.isEmpty) pID = item.productID!;

    return Column(
      children: [
        InkWell(
          onTap: () => showItems.toggle(),
          child: Container(
            margin: const EdgeInsets.only(
              right: 20,
              left: 10,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Text('اقلام سفارش:', style: TextStyle(fontSize: 18)),
                    Text(
                      ' (${pID.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Obx(
                  () => AnimatedRotation(
                    turns: showItems.isTrue ? 0 : 0.5,
                    curve: Curves.easeIn,
                    duration: const Duration(milliseconds: 500),
                    child: const Icon(IconsaxPlusLinear.arrow_up_1),
                  ),
                ),
              ],
            ),
          ),
        ),
        Obx(
          () => AnimatedContainer(
            width: Get.width,
            height: showItems.isTrue
                ? pID.length > 4
                      ? Get.height * 0.47
                      : ((Get.height * 0.47) / 3.5) * pID.length
                : 0,
            duration: const Duration(milliseconds: 500),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (int i = 0; i < pID.length; i++)
                    pr(context, item, pID[i]),
                ],
              ),
            ),
          ),
        ),
        MyDivider(),
      ],
    );
  }

  pr(context, item, puid) {
    var pr = AccountingFX.findProduct(puid);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(right: 20, left: 10, top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImage.img(
                context,
                pr,
                Responsive.isMobile(context) ? Get.width / 6 : 100,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: TextScroll(
                            pr.name ?? '',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkMode.isTrue
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                            pauseBetween: Duration(seconds: 1),
                            velocity: const Velocity(
                              pixelsPerSecond: Offset(40, 0),
                            ),
                            numberOfReps: 2,
                            mode: TextScrollMode.endless,
                            intervalSpaces: 10,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        SizedBox(width: 10),
                        if (!ProductFX.isPro(puid))
                          Row(
                            children: [
                              Text(
                                'x${Number.addCommas(item.items[puid][0]['amount'])}',
                                style: TextStyle(
                                  color: darkMode.isTrue
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700,
                                ),
                              ),
                              if (pr.type != 'service')
                                Text(
                                  ' ${WarehouseFX.findFromName(puid, item.items[puid][0]['prouid'], item.uid, item.type)}',
                                ),
                            ],
                          ),
                      ],
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      spacing: 5,
                      children: [
                        Icon(
                          IconsaxPlusLinear.category,
                          size: 15,
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                        Flexible(
                          child: MyTextScroll(
                            ProductFX.catListName(pr.catIDList!),
                          ),
                        ),
                      ],
                    ),
                    if (!ProductFX.isPro(puid))
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            Price.showWithCurrency(
                              item.items[puid][0]['price'],
                            ),
                          ),
                          Text(
                            Price.showWithCurrency(
                              item.items[puid][0]['price'] *
                                  item.items[puid][0]['amount'],
                            ),
                          ),
                        ],
                      ),

                    // if (false)
                    //   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    //     Text(Price.show(item.type == 'buy' ? item.buyPrice![i] : item.sellPrice![i]), style: TextStyle(color: darkMode.isTrue ? Colors.grey.shade400 : Colors.grey.shade700)),
                    //     Text('قیمت کل: ${Price.show(item.amount![i] * (item.isBuy! ? item.buyPrice![i] : item.sellPrice![i]))}',
                    //         style: TextStyle(color: darkMode.isTrue ? Colors.grey.shade400 : Colors.grey.shade700))
                    //   ])
                    if (ProductFX.isPro(puid))
                      Column(
                        children: [
                          for (int i = 0; i < item.items[puid].length; i++)
                            // for (var it in item.items[puid])
                            Column(
                              children: [
                                SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: ProductFX.proWidget(
                                        pr.uid,
                                        item.items[puid][i]['prouid'],
                                      ),
                                    ),
                                    Text(
                                      'x ${item.items[puid][i]['amount']} ${WarehouseFX.findFromName(puid, item.items[puid][0]['prouid'], item.uid, item.type)}',
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5, width: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      Price.showWithCurrency(
                                        item.items[puid][i]['price'],
                                      ),
                                    ),
                                    Text(
                                      Price.showWithCurrency(
                                        item.items[puid][i]['price'] *
                                            item.items[puid][i]['amount'],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                EndLine(
                                  rightPadding: 10,
                                  show: i + 1 < item.items[puid].length,
                                ),
                              ],
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          width: Get.width,
          margin: EdgeInsets.only(right: Get.width / 4.4),
          color: darkMode.isTrue ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ],
    );
  }
}
