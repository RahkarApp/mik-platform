import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/popNumberPad.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/invoice/add/components/model.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

class PriceChangeInvoice extends StatefulWidget {
  late final InvoiceItemModel item;
  late final InvoiceProItemModel pro;
  late final String type;
  late final int? price;
  late final dynamic callback;
  // Separate constructors keep remote rows independent of Hive fields.
  // ignore: prefer_const_constructors_in_immutables
  PriceChangeInvoice({
    required this.item,
    required this.pro,
    required this.type,
    required this.price,
    required this.callback,
    super.key,
  }) : remote = null;

  late final ({String value, VoidCallback? onTap})? remote;
  PriceChangeInvoice.remote({
    super.key,
    required String value,
    VoidCallback? onTap,
  }) {
    remote = (value: value, onTap: onTap);
  }

  @override
  State<PriceChangeInvoice> createState() => _PriceChangeInvoiceState();
}

class _PriceChangeInvoiceState extends State<PriceChangeInvoice> {
  bool error = false;
  @override
  void initState() {
    super.initState();
    if (widget.remote != null) return;
    var pr = productPrice.values
        .where((p) => p.puid == widget.item.uid)
        .toList();
    List<int?> pp = [];
    if (widget.pro.uid != '-') {
      pp = pr
          .map(
            (t) => int.parse(
              (t.pro != null ? (t.pro![widget.pro.uid] ?? t.price) : t.price)
                  .toString(),
            ),
          )
          .toList();
    } else {
      pp = pr.map((t) => t.price).toList();
    }
    int minP = (pp.isEmpty ? null : pp.reduce((a, b) => a! < b! ? a : b)) ?? 0;
    int maxP = (pp.isEmpty ? null : pp.reduce((a, b) => a! > b! ? a : b)) ?? 0;
    if (widget.type != 'buy' &&
        (widget.price! < minP || widget.price! > maxP)) {
      error = true;

      Alert.warning('قیمت وارد شده خارج از محدوده مجاز است.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.remote;
    if (row != null) {
      return Obx(
        () => InkWell(
          onTap: row.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 30,
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: darkMode.isFalse ? Colors.white : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: darkMode.isFalse
                    ? Colors.grey.shade300
                    : Colors.grey.shade700,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: darkMode.isFalse
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'قیمت واحد',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, height: 1),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Icon(
                    IconsaxPlusLinear.arrow_down,
                    size: 16,
                    color: row.onTap == null ? Colors.grey : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      height: 30,
      margin: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: darkMode.isFalse ? Colors.white : null,
        border: Border.all(
          color: error
              ? Colors.red
              : darkMode.isFalse
              ? Colors.grey.shade300
              : Colors.grey.shade700,
          width: error ? 1 : 1.1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => PopNumberPad.price(
          callback: (v) {
            var pr = productPrice.values
                .where((p) => p.puid == widget.item.uid)
                .toList();
            List<int?> pp = [];
            if (widget.pro.uid != '-') {
              pp = pr
                  .map(
                    (t) => int.parse(
                      (t.pro != null
                              ? (t.pro![widget.pro.uid] ?? t.price)
                              : t.price)
                          .toString(),
                    ),
                  )
                  .toList();
            } else {
              pp = pr.map((t) => t.price).toList();
            }
            int minP =
                (pp.isEmpty ? null : pp.reduce((a, b) => a! < b! ? a : b)) ?? 0;
            int maxP =
                (pp.isEmpty ? null : pp.reduce((a, b) => a! > b! ? a : b)) ?? 0;
            if (widget.type != 'buy' &&
                (widget.price! < minP || widget.price! > maxP)) {
              error = true;

              Alert.warning('قیمت وارد شده خارج از محدوده مجاز است.');
            }

            widget.callback(widget.pro.uid, int.parse(v));
          },
          productUID: widget.item.uid,
          prouid: widget.pro.uid,
          // sellPriceList: type != 'buy'
          //     ? pro.price
          //     ProductFX.price
          //     : null,
          isBuy: widget.type == 'buy',
          initVal: widget.pro.price,
        ),
        child: Row(
          children: [
            Container(
              width: 35,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                color: darkMode.isFalse
                    ? Colors.grey.shade300
                    : Colors.grey.shade700,
              ),
              child: const Text(
                'قیمت واحد',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1, fontSize: 10),
              ),
            ),
            Container(
              width: 100,
              alignment: Alignment.center,
              color:
                  widget.type != 'buy' &&
                      ProductFX.lastBuyPrice(widget.item.uid, widget.pro.uid) >
                          widget.pro.price
                  ? Colors.red
                  : null,
              child: Text(
                Price.showWithCurrencyMini(widget.pro.price),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(left: 5),
              child: (widget.type != 'buy')
                  ? InkWell(
                      // onTap: () {
                      //   changePrice(
                      //       item.sellPriceList[0]);
                      // },
                      child: const Icon(
                        IconsaxPlusBold.refresh_2,
                        color: Colors.grey,
                      ),
                    )
                  : SizedBox(width: 20),
            ),
          ],
        ),
      ),
    );
  }
}
