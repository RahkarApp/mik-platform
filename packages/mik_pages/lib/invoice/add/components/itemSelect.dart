// ignore_for_file: prefer_typing_uninitialized_variables, deprecated_member_use

part of './selectproduct.dart';

class ProductItemSelect extends GetView {
  late ProductDB item;
  InvoiceItemModel? itemSelect;
  late String type;
  var callback;
  String? warehouseUID;
  String? branchUID;
  ProductItemSelect({
    required this.item,
    this.itemSelect,
    required this.callback,
    required this.type,
    this.branchUID,
    this.warehouseUID,
    super.key,
  });
  ({Widget content, Widget? variants, bool selected})? remote;
  ProductItemSelect.remote({
    super.key,
    required Widget content,
    Widget? variants,
    bool isSelected = false,
  }) {
    remote = (content: content, variants: variants, selected: isSelected);
  }
  ({
    PimVariant variant,
    List<PimAttribute> attributes,
    bool selected,
    VoidCallback? onTap,
    Widget? details,
  })?
  variantRow;

  ProductItemSelect.variant({
    super.key,
    required PimVariant variant,
    required List<PimAttribute> attributes,
    bool isSelected = false,
    VoidCallback? onTap,
    Widget? details,
  }) {
    variantRow = (
      variant: variant,
      attributes: attributes,
      selected: isSelected,
      onTap: onTap,
      details: details,
    );
  }

  // Reuse the old attribute/value chip layout with real PIM options, without Hive IDs.
  Widget _variant(BuildContext context) {
    final row = variantRow!;
    return InkWell(
      onTap: row.onTap,
      child: Container(
        color: row.selected
            ? AppColors.primaryLite.withValues(alpha: 0.3)
            : Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  Expanded(
                    child: ProductVariantOptions(
                      variant: row.variant,
                      attributes: row.attributes,
                    ),
                  ),
                  if (row.details != null) Flexible(child: row.details!),
                  const SizedBox(width: 5),
                  Icon(
                    row.selected
                        ? IconsaxPlusLinear.tick_square
                        : IconsaxPlusLinear.add_square,
                    size: 18,
                    color: row.selected ? AppColors.primary : Colors.grey,
                  ),
                ],
              ),
            ),
            EndLine(rightPadding: 20),
          ],
        ),
      ),
    );
  }

  RxBool selected = false.obs;
  @override
  Widget build(BuildContext context) {
    if (variantRow != null) return _variant(context);
    final row = remote;
    if (row != null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        color: row.selected
            ? AppColors.primaryLite.withValues(alpha: 0.3)
            : Colors.transparent,
        child: Column(
          children: [
            row.content,
            if (row.variants != null)
              Padding(
                padding: const EdgeInsets.only(right: 85),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: SingleChildScrollView(child: row.variants!),
                ),
              ),
          ],
        ),
      );
    }
    if (_selected.map((t) => t.uid).toList().contains(item.uid)) {
      selected.value = true;
    } else {
      selected.value = false;
    }
    return ((type == 'pf' ||
                type == 'buy' ||
                item.type == 'service' ||
                item.type != 'service' &&
                    (branchUID != null && branchUID != ''
                        ? ProductFX.productInBranch(
                                item.uid!,
                                '-',
                                branchUID!,
                              ) >
                              0
                        : warehouseUID != null
                        ? ProductFX.productInWarehouse(
                                item.uid!,
                                '-',
                                warehouseUID!,
                              ) >
                              0
                        : ProductFX.productInAllWarehouse(item.uid!) > 0)) &&
            !(item.archive ?? false))
        ? Container(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Column(
              children: [
                InkWell(
                  onTap: (!ProductFX.isPro(item.uid))
                      ? () {
                          if ((type == 'pf' ||
                                  item.type == 'service' ||
                                  item.type != 'service' &&
                                      (branchUID != null && branchUID != ''
                                          ? ProductFX.productInBranch(
                                                  item.uid!,
                                                  '-',
                                                  branchUID!,
                                                ) >
                                                0
                                          : warehouseUID != null
                                          ? ProductFX.productInWarehouseAccess(
                                                  item.uid!,
                                                  '-',
                                                  warehouseUID!,
                                                ) >
                                                0
                                          : ProductFX.productInAllWarehouseAccess(
                                                  item.uid!,
                                                ) >
                                                0)) &&
                              !(item.archive ?? false)) {
                            selected.toggle();
                            List wh = warehouse.values
                                .where(
                                  (w) =>
                                      w.puid == item.uid &&
                                      w.prouid == '-' &&
                                      w.inventory > 0,
                                )
                                .toList();
                            //////////
                            if (branchUID != null && branchUID != '') {
                              BranchDB br = branch.values.firstWhere(
                                (b) => b.uid == branchUID,
                              );
                              if (br.defaultWarehouse != null &&
                                  br.defaultWarehouse != '') {
                                if (ProductFX.productInWarehouse(
                                      item.uid!,
                                      '-',
                                      br.defaultWarehouse!,
                                    ) >
                                    0) {
                                  warehouseUID = br.defaultWarehouse!;
                                }
                              }
                              if (warehouseUID == null ||
                                  warehouseUID != null && warehouseUID == '') {
                                BranchAccessDB ba = branchAccess.values
                                    .firstWhere(
                                      (b) => b.branchUID == branchUID,
                                    );
                                if (ba.warehouseUID!.length == 1) {
                                  if (ProductFX.productInWarehouse(
                                        item.uid!,
                                        '-',
                                        ba.warehouseUID![0],
                                      ) >
                                      0) {
                                    warehouseUID = ba.warehouseUID![0];
                                  }
                                } else {
                                  for (var baw in ba.warehouseUID!) {
                                    if (ProductFX.productInWarehouse(
                                          item.uid!,
                                          '-',
                                          baw,
                                        ) >
                                        0) {
                                      warehouseUID = baw;
                                    }
                                    if (warehouseUID != null &&
                                        warehouseUID != '')
                                      break;
                                  }
                                }
                              }
                            }
                            //////////

                            String w =
                                itemSelect?.pro[0].warehouseUID ??
                                warehouseUID ??
                                '';
                            if (w == '' && wh.length == 1) {
                              w = wh[0].wuid;
                            }
                            int price = 0;
                            int buyPrice = 0;
                            if (type != 'buy') {
                              price = itemSelect?.pro.length == 1
                                  ? itemSelect!.pro[0].price
                                  : 0;
                              var pp = productPrice.values
                                  .where((p) => p.puid == item.uid)
                                  .toList();
                              if (price == 0 && pp.length == 1) {
                                price = pp[0].price ?? 0;
                              } else if (price == 0 && pp.length > 1) {
                                int i = pp.indexWhere((e) => e.defaultPrice);
                                if (i > -1) {
                                  price = pp[i].price ?? 0;
                                } else {
                                  price = pp[0].price ?? 0;
                                }
                              }

                              buyPrice = ProductFX.lastBuyPrice(item.uid!, '-');
                            }
                            callback({
                              'uid': item.uid,
                              'name': item.name,
                              'prouid': '-',
                              'amount': itemSelect?.pro[0].amount ?? 1.0,
                              'price': type == 'buy' ? 0 : price,
                              'buyPrice': type == 'buy' ? 0 : buyPrice,
                              'warehouseUID': w,
                            });
                          } else {
                            if (type == 'buy' && !(item.archive ?? false)) {
                              selected.toggle();
                              callback({
                                'uid': item.uid,
                                'name': item.name,
                                'prouid': '-',
                                'amount': itemSelect?.pro[0].amount ?? 1.0,
                                'buyPrice': 0,
                                'price': 0,
                                'warehouseUID':
                                    itemSelect?.pro[0].warehouseUID ?? '',
                              });
                            } else {
                              Alert.warning('این محصول در انبار موجود نیست');
                            }
                          }
                        }
                      : null,
                  child: Obx(
                    () => Container(
                      decoration: BoxDecoration(
                        color: selected.isTrue && !ProductFX.isPro(item.uid)
                            ? AppColors.primaryLite.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: 10),
                          ProductImage.img(context, item, 70),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        spacing: 2,
                                        children: [
                                          Icon(
                                            (item.type == null ||
                                                    (item.type != null &&
                                                        item.type == 'product'))
                                                ? IconsaxPlusLinear.box
                                                : IconsaxPlusLinear.tag_2,
                                            size: 20,
                                            color: Colors.grey.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              item.name.toString(),
                                              maxLines: 1,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.only(left: 10),
                                      child: Text(
                                        'کدکالا: ${ProductFX.showID(item.id!)}',
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  spacing: 10,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        spacing: 2,
                                        children: [
                                          if (ProductFX.isPro(item.uid))
                                            Icon(
                                              IconsaxPlusLinear.star,
                                              size: 20,
                                              color: Colors.grey.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                          // Icon(
                                          //   (item.type == null ||
                                          //           (item.type != null &&
                                          //               item.type == 'product'))
                                          //       ? IconsaxPlusBold.box
                                          //       : IconsaxPlusBold.tag_2,
                                          //   size: 20,
                                          //   color: Colors.grey.withValues(alpha: 0.5),
                                          // ),

                                          Flexible(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  IconsaxPlusLinear.category,
                                                  size: 15,
                                                  color: Colors.grey.withValues(
                                                    alpha: 0.5,
                                                  ),
                                                ),
                                                SizedBox(width: 5),
                                                Flexible(
                                                  child: Text(
                                                    ProductFX.catListName(
                                                      item.catIDList!,
                                                    ),
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (type != 'w2w' &&
                                        !ProductFX.isPro(item.uid!))
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.only(
                                            left: 10,
                                          ),
                                          child: Text(
                                            'قیمت: ${ProductFX.minMaxPrice(puid: item.uid!)}',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (!ProductFX.isPro(item.uid!))
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.type != 'service'
                                            ? branchUID != null &&
                                                      branchUID != ''
                                                  ? 'موجودی دردسترس: ${Number.addCommas(ProductFX.productInBranch(item.uid!, '-', branchUID!))} ${ProductFX.unitName(item.unitCode)}'
                                                  : warehouseUID != null
                                                  ? 'موجودی دردسترس: ${Number.addCommas(ProductFX.productInWarehouseAccess(item.uid!, '-', warehouseUID!))} ${ProductFX.unitName(item.unitCode)}'
                                                  : 'موجودی دردسترس: ${Number.addCommas(ProductFX.productInAllWarehouseAccess(item.uid!))} ${ProductFX.unitName(item.unitCode)}'
                                            : '',
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            item.type != 'service'
                                                ? branchUID != null &&
                                                          branchUID != ''
                                                      ? 'موجودی: ${Number.addCommas(ProductFX.productInBranch(item.uid!, '-', branchUID!))} ${ProductFX.unitName(item.unitCode)}'
                                                      : warehouseUID != null
                                                      ? 'موجودی: ${Number.addCommas(ProductFX.productInWarehouse(item.uid!, '-', warehouseUID!))} ${ProductFX.unitName(item.unitCode)}'
                                                      : 'موجودی: ${Number.addCommas(ProductFX.productInAllWarehouse(item.uid!))} ${ProductFX.unitName(item.unitCode)}'
                                                : '',
                                          ),
                                          SizedBox(width: 10),
                                        ],
                                      ),
                                    ],
                                  ),
                                if (ProductFX.isPro(item.uid!)) proItemList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                EndLine(rightPadding: 85),
              ],
            ),
          )
        : Container();
  }

  proItemList() {
    List<ProductProDB> pr = productPro.values
        .where(
          (e) =>
              e.productUID == item.uid! &&
              (ProductFX.productInAllWarehouse(e.productUID!, prouid: e.uid) >
                      0 ||
                  type == 'buy'),
        )
        .toList();
    if (pr.isEmpty) return SizedBox.shrink();

    // هر آیتم تقریبی 70px ارتفاع دارد؛ حداکثر ارتفاع نمایش را محدود می‌کنیم
    double itemHeight = 70.0;
    double maxHeight = pr.length * itemHeight;
    if (maxHeight > 350.0) maxHeight = 350.0; // حداکثر 350px برای لیست

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.builder(
        itemCount: pr.length,
        shrinkWrap: true,
        primary: false,
        itemBuilder: (context, index) => proItem(pr[index]),
      ),
    );
  }

  Widget proItem(ProductProDB p) {
    RxBool sel = false.obs;
    int index = _selected
        .map((t) => t.uid)
        .toList()
        .indexWhere((o) => o == item.uid);
    if (index > -1 &&
        _selected[index].pro.indexWhere((o) => o.uid == p.uid) > -1) {
      sel.value = true;
    } else {
      sel.value = false;
    }
    return InkWell(
      onTap: () {
        if ((type == 'pf' ||
                item.type == 'service' ||
                item.type != 'service' &&
                    (branchUID != null && branchUID != ''
                        ? ProductFX.productInBranch(
                                item.uid!,
                                p.uid!,
                                branchUID!,
                              ) >
                              0
                        : warehouseUID != null
                        ? ProductFX.productInWarehouseAccess(
                                item.uid!,
                                p.uid!,
                                warehouseUID!,
                              ) >
                              0
                        : ProductFX.productInAllWarehouseAccess(
                                item.uid!,
                                prouid: p.uid!,
                              ) >
                              0)) &&
            !(item.archive ?? false)) {
          sel.toggle();
          var ppp = itemSelect?.pro.where((t) => t.uid == p.uid).toList();
          List wh = warehouse.values
              .where(
                (w) =>
                    w.puid == item.uid && w.prouid == p.uid && w.inventory > 0,
              )
              .toList();
          //////////
          if (branchUID != '') {
            BranchDB br = branch.values.firstWhere((b) => b.uid == branchUID);
            if (br.defaultWarehouse != null && br.defaultWarehouse != '') {
              if (ProductFX.productInWarehouse(
                    item.uid!,
                    p.uid!,
                    br.defaultWarehouse!,
                  ) >
                  0) {
                warehouseUID = br.defaultWarehouse!;
              }
            }
            if (warehouseUID == null ||
                warehouseUID != null && warehouseUID == '') {
              BranchAccessDB ba = branchAccess.values.firstWhere(
                (b) => b.branchUID == branchUID,
              );
              if (ba.warehouseUID!.length == 1) {
                if (ProductFX.productInWarehouse(
                      item.uid!,
                      p.uid!,
                      ba.warehouseUID![0],
                    ) >
                    0) {
                  warehouseUID = ba.warehouseUID![0];
                }
              } else {
                for (var baw in ba.warehouseUID!) {
                  if (ProductFX.productInWarehouse(item.uid!, p.uid!, baw) >
                      0) {
                    warehouseUID = baw;
                  }
                  if (warehouseUID != null && warehouseUID != '') break;
                }
              }
            }
          }
          //////////

          String w = ppp != null && ppp.isNotEmpty
              ? ppp.first.warehouseUID
              : warehouseUID ?? '';
          if (w == '' && wh.length == 1) {
            w = wh[0].wuid;
          }
          int price = ppp != null && ppp.isNotEmpty ? ppp.first.price : 0;
          var pp = productPrice.values
              .where((p) => p.puid == item.uid)
              .toList();
          if (price == 0 && pp.length == 1) {
            price = pp[0].pro != null
                ? (pp[0].pro![p.uid] ?? pp[0].price ?? 0)
                : pp[0].price ?? 0;
          } else if (price == 0 && pp.length > 1) {
            int i = pp.indexWhere((e) => e.defaultPrice);
            if (pp[i].pro != null) {
              if (i > -1) {
                price = pp[i].pro != null
                    ? (pp[i].pro![p.uid] ?? pp[i].price ?? 0)
                    : pp[i].price ?? 0;
              } else {
                price = pp[0].pro != null
                    ? (pp[0].pro![p.uid] ?? pp[0].price ?? 0)
                    : pp[0].price;
              }
            } else {
              if (i > -1) {
                price = pp[i].price ?? 0;
              } else {
                price = pp[0].price ?? 0;
              }
            }
          }
          int buyPrice = 0;
          if (type != 'buy') {
            buyPrice = ProductFX.lastBuyPrice(item.uid!, p.uid!);
          }
          InvoiceProItemModel pr = ppp != null && ppp.isNotEmpty
              ? ppp.first
              : InvoiceProItemModel(
                  amount: 1.0,
                  uid: '',
                  price: price,
                  buyPrice: buyPrice,
                  warehouseUID: w,
                  parameters: [],
                );
          callback({
            'uid': item.uid,
            'name': item.name,
            'prouid': p.uid,
            'amount': pr.amount,
            'price': pr.price,
            'buyPrice': buyPrice,
            'warehouseUID': pr.warehouseUID,
          });
        } else {
          if (type == 'buy') {
            sel.toggle();
            var ppp = itemSelect?.pro.where((t) => t.uid == p.uid).toList();
            int buyPrice = 0;
            if (type != 'buy') {
              buyPrice = ProductFX.lastBuyPrice(item.uid!, p.uid!);
            }
            InvoiceProItemModel pr = ppp != null && ppp.isNotEmpty
                ? ppp.first
                : InvoiceProItemModel(
                    amount: 1.0,
                    uid: '-',
                    price: type != 'buy' ? ProductFX.findPrice(item.uid!) : 0,
                    buyPrice: buyPrice,
                    warehouseUID: '',
                    parameters: [],
                  );
            callback({
              'uid': item.uid,
              'name': item.name,
              'prouid': p.uid,
              'amount': pr.amount,
              'price': 0,
              'buyPrice': 0,
              'warehouseUID': pr.warehouseUID,
            });
          } else {
            Alert.warning('این محصول در انبار موجود نیست');
          }
        }
      },
      child: Obx(
        () => Container(
          decoration: BoxDecoration(
            color: sel.isTrue
                ? AppColors.primaryLite.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: ProductFX.productProNameWidget(p.property)),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 5,
                        children: [
                          Text(
                            item.type != 'service'
                                ? branchUID != null && branchUID != ''
                                      ? 'موجودی دردسترس: ${Number.addCommas(ProductFX.productInBranch(item.uid!, p.uid!, branchUID!))} ${ProductFX.unitName(item.unitCode)}'
                                      : warehouseUID != null
                                      ? 'موجودی دردسترس: ${Number.addCommas(ProductFX.productInWarehouseAccess(item.uid!, p.uid!, warehouseUID!))} ${ProductFX.unitName(item.unitCode)}'
                                      : 'موجودی دردسترس: ${Number.addCommas(ProductFX.productInAllWarehouseAccess(item.uid!, prouid: p.uid))} ${ProductFX.unitName(item.unitCode)}'
                                : '',
                            style: TextStyle(fontSize: 10),
                          ),
                          Text(
                            item.type != 'service'
                                ? branchUID != null && branchUID != ''
                                      ? 'موجودی: ${Number.addCommas(ProductFX.productInBranch(item.uid!, p.uid!, branchUID!))} ${ProductFX.unitName(item.unitCode)}'
                                      : warehouseUID != null
                                      ? 'موجودی: ${Number.addCommas(ProductFX.productInWarehouse(item.uid!, p.uid!, warehouseUID!))} ${ProductFX.unitName(item.unitCode)}'
                                      : 'موجودی: ${Number.addCommas(ProductFX.productInAllWarehouse(item.uid!, prouid: p.uid))} ${ProductFX.unitName(item.unitCode)}'
                                : '',
                            style: TextStyle(fontSize: 10),
                          ),
                          if (type != 'w2w')
                            Text(
                              'قیمت: ${ProductFX.minMaxPricePro(puid: item.uid, prouid: p.uid)}',
                              style: TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              EndLine(rightPadding: 20),
            ],
          ),
        ),
      ),
    );
  }
}
